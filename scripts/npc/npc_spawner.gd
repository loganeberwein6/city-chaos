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

func _make_ghost(npc_type: String) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	match npc_type:
		"gangster":  mat.albedo_color = Color(0.2, 0.2, 0.2)
		"rich":      mat.albedo_color = Color(0.8, 0.75, 0.3)
		"paramedic": mat.albedo_color = Color(0.9, 0.9, 0.9)
		"news":      mat.albedo_color = Color(0.3, 0.5, 0.9)
		_:           mat.albedo_color = Color(0.6, 0.55, 0.5)
	var body_mi := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new(); body_mesh.radius = 0.3; body_mesh.height = 1.4
	body_mi.mesh = body_mesh; body_mi.material_override = mat; body_mi.position = Vector3(0, 0.7, 0)
	root.add_child(body_mi)
	var head_mi := MeshInstance3D.new()
	var head_mesh := SphereMesh.new(); head_mesh.radius = 0.22; head_mesh.height = 0.44
	head_mi.mesh = head_mesh; head_mi.material_override = mat; head_mi.position = Vector3(0, 1.62, 0)
	root.add_child(head_mi)
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
