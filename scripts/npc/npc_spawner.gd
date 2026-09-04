extends Node
class_name NpcSpawner

const SPAWN_RADIUS        := 80.0
const DESPAWN_RADIUS      := 120.0
const MAX_NPCS_PER_PLAYER := 20
const SPAWN_INTERVAL      := 3.0
const SPAWN_BATCH         := 3
const SYNC_INTERVAL       := 0.1

var _spawn_timer := 0.0
var _sync_timer  := 0.0
var _active_npcs: Array = []

var _npc_ids:  Dictionary = {}
var _next_id   := 0
var _client_npcs: Dictionary = {}

var _scenes := {}

func _ready() -> void:
	add_to_group("npc_spawner")
	if multiplayer.is_server():
		_preload_scenes()

func _preload_scenes() -> void:
	var paths := {
		"civilian":  "res://scenes/npc/civilian.tscn",
		"gangster":  "res://scenes/npc/gangster.tscn",
		"rich":      "res://scenes/npc/rich_person.tscn",
		"paramedic": "res://scenes/npc/paramedic.tscn",
		"news":      "res://scenes/npc/news_crew.tscn",
	}
	for key in paths:
		if ResourceLoader.exists(paths[key]):
			_scenes[key] = load(paths[key])

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_cleanup_dead()
		_despawn_far()
		_spawn_batch()
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = SYNC_INTERVAL
		_broadcast_sync()

func _cleanup_dead() -> void:
	var keep: Array = []
	for n in _active_npcs:
		if is_instance_valid(n):
			keep.append(n)
	_active_npcs = keep
	var stale: Array = []
	for node in _npc_ids:
		if not is_instance_valid(node):
			stale.append(node)
	for node in stale:
		_npc_ids.erase(node)

func _despawn_far() -> void:
	var players := _get_player_positions()
	var keep: Array = []
	for npc in _active_npcs:
		if not is_instance_valid(npc):
			continue
		var near := false
		for pp in players:
			if npc.global_position.distance_to(pp) < DESPAWN_RADIUS:
				near = true
				break
		if near:
			keep.append(npc)
		else:
			if _npc_ids.has(npc):
				_rpc_despawn_npc.rpc(_npc_ids[npc])
				_npc_ids.erase(npc)
			npc.queue_free()
	_active_npcs = keep

func _spawn_batch() -> void:
	var density: float = GameManager.rules.get("npc_density", 1.0)
	if density <= 0.0: return
	var max_total: int = int(MAX_NPCS_PER_PLAYER * GameManager._players.size() * density)
	if _active_npcs.size() >= max_total: return
	var players := _get_player_positions()
	if players.is_empty(): return
	for _i in range(SPAWN_BATCH):
		if _active_npcs.size() >= max_total: break
		var pp: Vector3 = players[randi() % players.size()]
		var angle := randf() * TAU
		var dist  := randf_range(30.0, SPAWN_RADIUS)
		var pos   := pp + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		_spawn_at(pos)

func _spawn_at(pos: Vector3) -> void:
	var type := _pick_type()
	if not _scenes.has(type): return
	var npc: Node3D = _scenes[type].instantiate()
	npc.add_to_group("npcs")
	get_tree().root.add_child(npc)
	npc.global_position = pos
	_active_npcs.append(npc)
	var nid := _next_id
	_next_id += 1
	_npc_ids[npc] = nid
	npc.tree_exited.connect(func():
		if _npc_ids.has(npc):
			_rpc_despawn_npc.rpc(_npc_ids[npc])
			_npc_ids.erase(npc)
	)
	_rpc_spawn_npc.rpc(nid, type, pos)

func _broadcast_sync() -> void:
	if _active_npcs.is_empty(): return
	var batch: Array = []
	for npc in _active_npcs:
		if is_instance_valid(npc) and _npc_ids.has(npc):
			var p: Vector3 = npc.global_position
			batch.append([_npc_ids[npc], p.x, p.y, p.z])
	if not batch.is_empty():
		_rpc_sync_npcs.rpc(batch)

@rpc("authority", "reliable", "call_remote")
func _rpc_spawn_npc(npc_id: int, npc_type: String, pos: Vector3) -> void:
	if _client_npcs.has(npc_id):
		return
	var ghost := _make_ghost(npc_type)
	get_tree().root.add_child(ghost)
	ghost.global_position = pos
	_client_npcs[npc_id] = ghost

@rpc("authority", "unreliable_ordered", "call_remote")
func _rpc_sync_npcs(batch: Array) -> void:
	for entry in batch:
		var npc_id: int = entry[0]
		var pos := Vector3(entry[1], entry[2], entry[3])
		if _client_npcs.has(npc_id) and is_instance_valid(_client_npcs[npc_id]):
			_client_npcs[npc_id].global_position = _client_npcs[npc_id].global_position.lerp(pos, 0.3)

@rpc("authority", "reliable", "call_remote")
func _rpc_despawn_npc(npc_id: int) -> void:
	if _client_npcs.has(npc_id) and is_instance_valid(_client_npcs[npc_id]):
		_client_npcs[npc_id].queue_free()
	_client_npcs.erase(npc_id)

func _npc_colors(npc_type: String) -> Array:
	match npc_type:
		"gangster":  return [Color(0.30,0.22,0.18), Color(0.12,0.12,0.14), Color(0.10,0.10,0.12), Color(0.08,0.08,0.08)]
		"rich":      return [Color(0.88,0.75,0.62), Color(0.95,0.95,0.92), Color(0.20,0.20,0.25), Color(0.15,0.12,0.10)]
		"paramedic": return [Color(0.75,0.62,0.50), Color(0.92,0.92,0.92), Color(0.92,0.92,0.92), Color(0.25,0.25,0.25)]
		"news":      return [Color(0.82,0.68,0.55), Color(0.30,0.50,0.90), Color(0.20,0.22,0.28), Color(0.15,0.12,0.10)]
		_:           return [Color(0.80,0.68,0.55), Color(0.55,0.55,0.60), Color(0.30,0.32,0.38), Color(0.20,0.18,0.15)]

func _npc_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color; m.roughness = 0.8; return m

func _npc_mi(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)

func _make_ghost(npc_type: String) -> Node3D:
	var root   := Node3D.new()
	var cols   := _npc_colors(npc_type)
	var skin_m := _npc_mat(cols[0])
	var shrt_m := _npc_mat(cols[1])
	var pant_m := _npc_mat(cols[2])
	var shoe_m := _npc_mat(cols[3])

	# Head + neck
	var head_mesh := SphereMesh.new(); head_mesh.radius = 0.115; head_mesh.height = 0.23
	_npc_mi(root, head_mesh, skin_m, Vector3(0, 1.72, 0))
	var neck_mesh := CylinderMesh.new(); neck_mesh.top_radius = 0.048; neck_mesh.bottom_radius = 0.048; neck_mesh.height = 0.09
	_npc_mi(root, neck_mesh, skin_m, Vector3(0, 1.615, 0))

	# Torso + pelvis
	var torso_mesh := BoxMesh.new(); torso_mesh.size = Vector3(0.34, 0.46, 0.19)
	_npc_mi(root, torso_mesh, shrt_m, Vector3(0, 1.28, 0))
	var pelvis_mesh := BoxMesh.new(); pelvis_mesh.size = Vector3(0.30, 0.18, 0.17)
	_npc_mi(root, pelvis_mesh, pant_m, Vector3(0, 0.88, 0))

	# Shoulder pads
	var sp_mesh := BoxMesh.new(); sp_mesh.size = Vector3(0.10, 0.08, 0.10)
	_npc_mi(root, sp_mesh, shrt_m, Vector3(-0.22, 1.50, 0))
	_npc_mi(root, sp_mesh, shrt_m, Vector3( 0.22, 1.50, 0))

	# Arms
	var ua_mesh := CapsuleMesh.new(); ua_mesh.radius = 0.055; ua_mesh.height = 0.26
	_npc_mi(root, ua_mesh, shrt_m, Vector3(-0.25, 1.22, 0))
	_npc_mi(root, ua_mesh, shrt_m, Vector3( 0.25, 1.22, 0))
	var la_mesh := CapsuleMesh.new(); la_mesh.radius = 0.045; la_mesh.height = 0.24
	_npc_mi(root, la_mesh, shrt_m, Vector3(-0.26, 0.94, 0))
	_npc_mi(root, la_mesh, shrt_m, Vector3( 0.26, 0.94, 0))
	var hand_mesh := BoxMesh.new(); hand_mesh.size = Vector3(0.07, 0.055, 0.038)
	_npc_mi(root, hand_mesh, skin_m, Vector3(-0.26, 0.78, 0))
	_npc_mi(root, hand_mesh, skin_m, Vector3( 0.26, 0.78, 0))

	# Legs
	var ul_mesh := CapsuleMesh.new(); ul_mesh.radius = 0.072; ul_mesh.height = 0.36
	_npc_mi(root, ul_mesh, pant_m, Vector3(-0.10, 0.60, 0))
	_npc_mi(root, ul_mesh, pant_m, Vector3( 0.10, 0.60, 0))
	var ll_mesh := CapsuleMesh.new(); ll_mesh.radius = 0.058; ll_mesh.height = 0.33
	_npc_mi(root, ll_mesh, pant_m, Vector3(-0.10, 0.26, 0))
	_npc_mi(root, ll_mesh, pant_m, Vector3( 0.10, 0.26, 0))
	var foot_mesh := BoxMesh.new(); foot_mesh.size = Vector3(0.09, 0.055, 0.20)
	_npc_mi(root, foot_mesh, shoe_m, Vector3(-0.10, 0.03, 0.04))
	_npc_mi(root, foot_mesh, shoe_m, Vector3( 0.10, 0.03, 0.04))

	return root

func _pick_type() -> String:
	var roll := randf()
	var stars := WantedSystem.get_stars()
	if stars >= 2 and roll < 0.05: return "news"
	if roll < 0.03: return "rich"
	if roll < 0.08: return "paramedic"
	if roll < 0.13: return "gangster"
	return "civilian"

func _get_player_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for id in GameManager._players:
		var p: Node3D = GameManager._players[id]
		if p and is_instance_valid(p):
			out.append(p.global_position)
	return out

func despawn_all() -> void:
	for npc in _active_npcs:
		if is_instance_valid(npc): npc.queue_free()
	_active_npcs.clear()
	_npc_ids.clear()
	for id in _client_npcs:
		if is_instance_valid(_client_npcs[id]):
			_client_npcs[id].queue_free()
	_client_npcs.clear()
