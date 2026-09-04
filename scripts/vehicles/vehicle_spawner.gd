extends Node
class_name VehicleSpawner

const SPAWN_RADIUS            := 100.0
const DESPAWN_RADIUS          := 150.0
const SPAWN_INTERVAL          := 5.0
const SYNC_INTERVAL           := 0.05
const MAX_VEHICLES_PER_PLAYER := 8

var _spawn_timer := 0.0
var _sync_timer  := 0.0
var _active: Array = []

var _vehicle_ids: Dictionary = {}
var _next_id := 0
var _client_vehicles: Dictionary = {}

var _scenes: Dictionary = {}

const VEHICLE_TYPES := [
	"sedan","suv","truck","sports_car","van","bus",
	"motorcycle","pickup","taxi","police_car","ambulance"
]

func _ready() -> void:
	if multiplayer.is_server():
		_preload_scenes()

func _preload_scenes() -> void:
	for t in VEHICLE_TYPES:
		var path := "res://scenes/vehicles/%s.tscn" % t
		if ResourceLoader.exists(path):
			_scenes[t] = load(path)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server(): return
	_spawn_timer -= delta
	_sync_timer  -= delta
	if _sync_timer <= 0.0:
		_sync_timer = SYNC_INTERVAL
		_broadcast_vehicle_sync()
	if _spawn_timer > 0.0: return
	_spawn_timer = SPAWN_INTERVAL
	_cleanup()
	_despawn_far()
	_spawn_batch()

func _cleanup() -> void:
	var keep: Array = []
	for v in _active:
		if is_instance_valid(v): keep.append(v)
	_active = keep
	var stale: Array = []
	for node in _vehicle_ids:
		if not is_instance_valid(node): stale.append(node)
	for node in stale: _vehicle_ids.erase(node)

func _despawn_far() -> void:
	var positions := _get_player_positions()
	var keep: Array = []
	for v in _active:
		if not is_instance_valid(v): continue
		if v.get("driver") != null: keep.append(v); continue
		var near := false
		for pp in positions:
			if v.global_position.distance_to(pp) < DESPAWN_RADIUS:
				near = true; break
		if near:
			keep.append(v)
		else:
			if _vehicle_ids.has(v):
				_rpc_despawn_vehicle.rpc(_vehicle_ids[v])
				_vehicle_ids.erase(v)
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
	var v: Node3D
	var vtype := "placeholder"
	if keys.is_empty():
		v = _make_placeholder(pos)
		vtype = "placeholder"
	else:
		vtype = keys[randi() % keys.size()]
		v = _scenes[vtype].instantiate()
		get_tree().root.add_child(v)
		v.global_position = pos
	_active.append(v)
	var vid := _next_id; _next_id += 1
	_vehicle_ids[v] = vid
	v.tree_exited.connect(func():
		if _vehicle_ids.has(v):
			_rpc_despawn_vehicle.rpc(_vehicle_ids[v])
			_vehicle_ids.erase(v)
	)
	_rpc_spawn_vehicle.rpc(vid, vtype, pos)

func _make_placeholder(pos: Vector3) -> Node3D:
	var body := RigidBody3D.new()
	var col  := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(2.2, 1.4, 4.5)
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(2.2, 1.4, 4.5)
	mesh.mesh = bm
	body.add_child(mesh)
	get_tree().root.add_child(body)
	body.global_position = pos
	return body

func _broadcast_vehicle_sync() -> void:
	if _active.is_empty(): return
	var batch: Array = []
	for v in _active:
		if is_instance_valid(v) and _vehicle_ids.has(v):
			var p: Vector3 = v.global_position
			var r: Vector3 = v.global_rotation
			batch.append([_vehicle_ids[v], p.x, p.y, p.z, r.x, r.y, r.z])
	if not batch.is_empty():
		_rpc_sync_vehicles.rpc(batch)

@rpc("authority", "reliable", "call_remote")
func _rpc_spawn_vehicle(vid: int, vtype: String, pos: Vector3) -> void:
	if _client_vehicles.has(vid): return
	var ghost := _make_vehicle_ghost(vtype)
	get_tree().root.add_child(ghost)
	ghost.global_position = pos
	_client_vehicles[vid] = ghost

@rpc("authority", "unreliable_ordered", "call_remote")
func _rpc_sync_vehicles(batch: Array) -> void:
	for entry in batch:
		var vid: int = entry[0]
		var pos := Vector3(entry[1], entry[2], entry[3])
		var rot := Vector3(entry[4], entry[5], entry[6])
		if _client_vehicles.has(vid) and is_instance_valid(_client_vehicles[vid]):
			var ghost: Node3D = _client_vehicles[vid]
			ghost.global_position = ghost.global_position.lerp(pos, 0.4)
			ghost.global_rotation = rot

@rpc("authority", "reliable", "call_remote")
func _rpc_despawn_vehicle(vid: int) -> void:
	if _client_vehicles.has(vid) and is_instance_valid(_client_vehicles[vid]):
		_client_vehicles[vid].queue_free()
	_client_vehicles.erase(vid)

func _make_vehicle_ghost(vtype: String) -> Node3D:
	var root := Node3D.new()
	var mi   := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size = Vector3(2.8, 2.4, 7.5) if vtype == "truck" or vtype == "bus" else Vector3(2.2, 1.4, 4.5)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	match vtype:
		"police_car": mat.albedo_color = Color(0.1, 0.1, 0.7)
		"ambulance":  mat.albedo_color = Color(0.9, 0.9, 0.9)
		"taxi":       mat.albedo_color = Color(0.95, 0.8, 0.0)
		"bus":        mat.albedo_color = Color(0.8, 0.6, 0.1)
		"truck":      mat.albedo_color = Color(0.5, 0.45, 0.4)
		_:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(vtype)
			mat.albedo_color = Color(rng.randf_range(0.3, 0.9), rng.randf_range(0.3, 0.9), rng.randf_range(0.3, 0.9))
	mi.material_override = mat
	mi.position = Vector3(0, 0.7, 0)
	root.add_child(mi)
	return root

func _get_player_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for id in GameManager._players:
		var p: Node3D = GameManager._players[id]
		if p and is_instance_valid(p): out.append(p.global_position)
	return out

func despawn_all() -> void:
	for v in _active:
		if is_instance_valid(v) and v.get("driver") == null: v.queue_free()
	_active.clear()
	_vehicle_ids.clear()
	for id in _client_vehicles:
		if is_instance_valid(_client_vehicles[id]): _client_vehicles[id].queue_free()
	_client_vehicles.clear()
