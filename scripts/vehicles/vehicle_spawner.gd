extends Node
class_name VehicleSpawner

const SPAWN_RADIUS   := 100.0
const DESPAWN_RADIUS := 150.0
const SPAWN_INTERVAL := 5.0
const MAX_VEHICLES_PER_PLAYER := 8

var _spawn_timer := 0.0
var _active: Array = []

var _scenes: Dictionary = {}

const VEHICLE_TYPES := [
	"sedan", "suv", "truck", "sports_car", "van", "bus",
	"motorcycle", "pickup", "taxi", "police_car", "ambulance"
]

func _ready() -> void:
	if not multiplayer.is_server(): return
	_preload_scenes()

func _preload_scenes() -> void:
	for t in VEHICLE_TYPES:
		var path := "res://scenes/vehicles/%s.tscn" % t
		if ResourceLoader.exists(path):
			_scenes[t] = load(path)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server(): return
	_spawn_timer -= delta
	if _spawn_timer > 0.0: return
	_spawn_timer = SPAWN_INTERVAL
	_cleanup()
	_despawn_far()
	_spawn_batch()

func _cleanup() -> void:
	var keep: Array = []
	for v in _active:
		if is_instance_valid(v):
			keep.append(v)
	_active = keep

func _despawn_far() -> void:
	var positions := _get_player_positions()
	var keep: Array = []
	for v in _active:
		if not is_instance_valid(v):
			continue
		if v.get("driver") != null:
			keep.append(v)
			continue
		var near := false
		for pp in positions:
			if v.global_position.distance_to(pp) < DESPAWN_RADIUS:
				near = true
				break
		if near:
			keep.append(v)
		else:
			v.queue_free()
	_active = keep

func _spawn_batch() -> void:
	var density: float = GameManager.rules.get("traffic_density", 1.0)
	if density <= 0.0: return
	var cap: int = int(MAX_VEHICLES_PER_PLAYER * GameManager._players.size() * density)
	if _active.size() >= cap: return

	var positions := _get_player_positions()
	if positions.is_empty(): return

	for _i in range(2):
		if _active.size() >= cap: break
		var pp: Vector3 = positions[randi() % positions.size()]
		var angle := randf() * TAU
		var dist  := randf_range(40.0, SPAWN_RADIUS)
		var pos   := pp + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		_spawn_at(pos)

func _spawn_at(pos: Vector3) -> void:
	var keys := _scenes.keys()
	if keys.is_empty():
		_spawn_placeholder(pos)
		return
	var type: String = keys[randi() % keys.size()]
	var v: Node3D = _scenes[type].instantiate()
	get_tree().root.add_child(v)
	v.global_position = pos
	_active.append(v)

func _spawn_placeholder(pos: Vector3) -> void:
	var body := RigidBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 1.4, 4.5)
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 1.4, 4.5)
	mesh.mesh = bm
	body.add_child(mesh)
	get_tree().root.add_child(body)
	body.global_position = pos

func _get_player_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for id in GameManager._players:
		var p: Node3D = GameManager._players[id]
		if p and is_instance_valid(p):
			out.append(p.global_position)
	return out

func despawn_all() -> void:
	for v in _active:
		if is_instance_valid(v) and v.get("driver") == null:
			v.queue_free()
	_active.clear()
