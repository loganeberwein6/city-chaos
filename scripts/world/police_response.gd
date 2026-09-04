extends Node
class_name PoliceResponse

const SPAWN_INTERVAL  := 8.0
const MAX_COPS_PER_STAR := 3

var _spawn_timer := 0.0
var _active_cops: Array[Node3D] = []

var _cop_scene: PackedScene

func _ready() -> void:
	if not multiplayer.is_server(): return
	_cop_scene  = preload("res://scenes/npc/police_officer.tscn")
	WantedSystem.stars_changed.connect(_on_stars_changed)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server(): return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_cleanup()
		_maybe_spawn()

func _cleanup() -> void:
	var keep: Array[Node3D] = []
	for n in _active_cops:
		if is_instance_valid(n):
			keep.append(n)
	_active_cops = keep

func _maybe_spawn() -> void:
	var stars := WantedSystem.get_stars()
	if stars == 0: return
	var target_player := _get_most_wanted_player()
	if target_player == null: return

	var cap := MAX_COPS_PER_STAR * stars
	if _active_cops.size() >= cap: return

	var count := mini(stars, 3)
	for _i in range(count):
		_spawn_cop(target_player, stars)

func _spawn_cop(target: Node3D, stars: int) -> void:
	if not _cop_scene: return
	var cop: Node3D = _cop_scene.instantiate()

	var angle := randf() * TAU
	var dist  := randf_range(40.0, 70.0)
	var pos   := target.global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	cop.global_position = pos

	var wid := "pistol" if stars < 3 else "rifle"
	cop.set("weapon_id", wid)

	cop.add_to_group("npcs")
	cop.add_to_group("police")
	get_tree().root.add_child(cop)
	cop.call("activate", target, stars)
	_active_cops.append(cop)

func _get_most_wanted_player() -> Node3D:
	for id in GameManager._players:
		var p: Node3D = GameManager._players[id]
		if p and is_instance_valid(p): return p
	return null

func _on_stars_changed(stars: int) -> void:
	if stars == 0:
		for cop in _active_cops:
			if is_instance_valid(cop):
				cop.call("_enter_wander")
		_active_cops.clear()

func despawn_all() -> void:
	for cop in _active_cops:
		if is_instance_valid(cop): cop.queue_free()
	_active_cops.clear()
