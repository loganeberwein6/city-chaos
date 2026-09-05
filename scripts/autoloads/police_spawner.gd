extends Node

const MAX_PER_STAR  := 2
const SPAWN_DIST    := 25.0
const OFFICER_SCENE := "res://scenes/npc/police_officer.tscn"

var _scene: PackedScene = null
var _officers: Array   = []
var _current_stars     := 0
var _spawn_timer       := 0.0

func _ready() -> void:
	if ResourceLoader.exists(OFFICER_SCENE):
		_scene = load(OFFICER_SCENE)
	WantedSystem.stars_changed.connect(_on_stars_changed)

func _on_stars_changed(stars: int) -> void:
	_current_stars = stars
	if stars == 0 and multiplayer.is_server():
		_despawn_all()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _current_stars == 0:
		return
	_officers = _officers.filter(func(o): return is_instance_valid(o))
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = 3.0
	if _officers.size() < _current_stars * MAX_PER_STAR:
		_spawn_one(_current_stars)

func _spawn_one(stars: int) -> void:
	if _scene == null:
		return
	var positions: Array[Vector3] = _get_player_positions()
	if positions.is_empty():
		return
	var pp: Vector3 = positions[randi() % positions.size()]
	var angle := randf() * TAU
	var pos   := pp + Vector3(cos(angle) * SPAWN_DIST, 0.0, sin(angle) * SPAWN_DIST)

	var officer: Node3D = _scene.instantiate()
	officer.add_to_group("npcs")
	get_tree().root.add_child(officer)
	officer.global_position = pos

	var target := _nearest_player(pos)
	if target != null and officer.has_method("activate"):
		officer.activate(target, stars)

	_officers.append(officer)
	officer.tree_exited.connect(func(): _officers.erase(officer))

func _despawn_all() -> void:
	for o in _officers:
		if is_instance_valid(o):
			o.queue_free()
	_officers.clear()

func _get_player_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for id in GameManager._players:
		var p: Node3D = GameManager._players[id]
		if p and is_instance_valid(p):
			out.append(p.global_position)
	return out

func _nearest_player(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 9999.0
	for id in GameManager._players:
		var p: Node3D = GameManager._players[id]
		if p and is_instance_valid(p):
			var d := pos.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = p
	return best
