extends Node
class_name PoliceResponse

# Spawns police units based on star level. Server-only.

const SPAWN_INTERVAL  := 8.0
const MAX_COPS_PER_STAR := 3

var _spawn_timer := 0.0
var _active_cops: Array[Node3D] = []

var _cop_scene: PackedScene
var _heli_scene: PackedScene

func _ready() -> void:
	if not multiplayer.is_server(): return
	_cop_scene  = preload("res://scenes/npc/police_officer.tscn")
	# Helicopter is a vehicle; placeholder until vehicle system done
	WantedSystem.stars_changed.connect(_on_stars_changed)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server(): return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_cleanup()
		_maybe_spawn()

func _cleanup() -> void:
	_active_cops = _active_cops.filter(func(n): return is_instance_valid(n))

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
	var cop: PoliceOfficer = _cop_scene.instantiate()

	# Pick spawn point out of LOS, near target
	var angle := randf() * TAU
	var dist  := randf_range(40.0, 70.0)
	var pos   := target.global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	cop.global_position = pos

	# Equip based on star level
	if stars >= 3:
		cop.weapon_id = "rifle"
	elif stars >= 2:
		cop.weapon_id = "pistol"
	else:
		cop.weapon_id = "pistol"

	cop.add_to_group("npcs")
	cop.add_to_group("police")
	get_tree().root.add_child(cop)
	cop.activate(target, stars)
	_active_cops.append(cop)

func _get_most_wanted_player() -> Node3D:
	# For now return any player; later use per-player heat
	for id in GameManager._players:
		var p: Node3D = GameManager._players[id]
		if p and is_instance_valid(p): return p
	return null

func _on_stars_changed(stars: int) -> void:
	if stars == 0:
		# Stand down all cops
		for cop in _active_cops:
			if is_instance_valid(cop) and cop is NpcBase:
				(cop as NpcBase)._enter_wander()
		_active_cops.clear()

func despawn_all() -> void:
	for cop in _active_cops:
		if is_instance_valid(cop): cop.queue_free()
	_active_cops.clear()
