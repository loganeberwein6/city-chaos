extends Node
class_name NpcSpawner

const SPAWN_RADIUS     := 80.0
const DESPAWN_RADIUS   := 120.0
const MAX_NPCS_PER_PLAYER := 20
const SPAWN_INTERVAL   := 3.0
const SPAWN_BATCH      := 3

var _spawn_timer := 0.0
var _active_npcs: Array[NpcBase] = []

# Scene preloads
var _scenes := {}

func _ready() -> void:
	if not multiplayer.is_server(): return
	add_to_group("npc_spawner")
	_preload_scenes()

func _preload_scenes() -> void:
	_scenes = {
		"civilian":   preload("res://scenes/npc/civilian.tscn"),
		"gangster":   preload("res://scenes/npc/gangster.tscn"),
		"rich":       preload("res://scenes/npc/rich_person.tscn"),
		"paramedic":  preload("res://scenes/npc/paramedic.tscn"),
		"news":       preload("res://scenes/npc/news_crew.tscn"),
	}

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server(): return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_cleanup_dead()
		_despawn_far()
		_spawn_batch()

func _cleanup_dead() -> void:
	_active_npcs = _active_npcs.filter(func(n): return is_instance_valid(n) and n.state != NpcBase.State.DEAD)

func _despawn_far() -> void:
	var players := _get_player_positions()
	var to_remove: Array[NpcBase] = []
	for npc in _active_npcs:
		if not is_instance_valid(npc): continue
		var near := false
		for pp in players:
			if npc.global_position.distance_to(pp) < DESPAWN_RADIUS:
				near = true; break
		if not near:
			npc.queue_free()
			to_remove.append(npc)
	for r in to_remove:
		_active_npcs.erase(r)

func _spawn_batch() -> void:
	var density: float = GameManager.rules.get("npc_density", 1.0)
	if density <= 0.0: return
	var max_total := int(MAX_NPCS_PER_PLAYER * GameManager._players.size() * density)
	if _active_npcs.size() >= max_total: return

	var players := _get_player_positions()
	if players.is_empty(): return

	var spawned := 0
	for _i in range(SPAWN_BATCH):
		if _active_npcs.size() >= max_total: break
		var pp := players[randi() % players.size()]
		var angle := randf() * TAU
		var dist  := randf_range(30.0, SPAWN_RADIUS)
		var pos   := pp + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		_spawn_at(pos)
		spawned += 1

func _spawn_at(pos: Vector3) -> void:
	var type := _pick_type()
	if not _scenes.has(type): return
	var npc: NpcBase = _scenes[type].instantiate()
	npc.global_position = pos
	npc.add_to_group("npcs")
	get_tree().root.add_child(npc)
	_active_npcs.append(npc)

func _pick_type() -> String:
	var roll := randf()
	var stars := WantedSystem.get_stars()
	if stars >= 2 and roll < 0.05:  return "news"
	if roll < 0.03:  return "rich"
	if roll < 0.08:  return "paramedic"
	if roll < 0.13:  return "gangster"
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
