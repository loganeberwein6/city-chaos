extends Node

signal player_died(player_id: int, killer_id: int)
signal player_respawned(player_id: int)
signal cash_changed(new_cash: int)
signal game_rules_changed()

# ── Game rules (host-editable) ────────────────────────────────────────────────
var rules := {
	"cheats_enabled":      false,
	"friendly_fire":       false,
	"npc_density":         1.0,
	"traffic_density":     1.0,
	"star_speed":          1.0,
	"gravity_mult":        1.0,
	"invincible_players":  [],   # Array of peer_ids
	"infinite_ammo_players": [],
	"map_size":            "medium",  # small / medium / large
	"world_seed":          0,
	"cheats_mode":         "host",  # host / op_list / all / off
	"opped_players":       [],
}

var opped_players: Array[int] = []

const MAP_SIZES := {
	"small":  {"grid": 4, "label": "Small"},
	"medium": {"grid": 7, "label": "Medium"},
	"large":  {"grid": 11, "label": "Large"},
}

const RESPAWN_TIME    := 5.0
const IMMUNITY_TIME   := 3.0
const DEATH_STREAK_WINDOW := 120.0
const DEATH_STREAK_THRESHOLD := 3

var _players: Dictionary = {}        # peer_id -> PlayerController node
var _spawn_points: Array[Vector3] = []
var _death_streaks: Dictionary = {}  # peer_id -> {count, timer}

func _ready() -> void:
	NetworkManager.player_left.connect(_on_player_left)

# ── Player registration ────────────────────────────────────────────────────────

func register_player(peer_id: int, node: Node) -> void:
	_players[peer_id] = node
	_death_streaks[peer_id] = {"count": 0, "timer": 0.0}

func unregister_player(peer_id: int) -> void:
	_players.erase(peer_id)
	_death_streaks.erase(peer_id)

func get_player_node(peer_id: int) -> Node:
	return _players.get(peer_id, null)

# ── Spawn points ───────────────────────────────────────────────────────────────

func register_spawn_point(pos: Vector3) -> void:
	_spawn_points.append(pos)

func get_spawn_point(away_from: Vector3 = Vector3.ZERO) -> Vector3:
	if _spawn_points.is_empty():
		return Vector3(0, 2, 0)
	# Pick the spawn point furthest from the death location (camp prevention)
	var best := _spawn_points[0]
	var best_dist := 0.0
	for pt in _spawn_points:
		var d := pt.distance_to(away_from)
		if d > best_dist:
			best_dist = d
			best = pt
	return best

# ── Death handling ─────────────────────────────────────────────────────────────

func on_player_died(victim_id: int, killer_id: int, dropped_weapon: String, death_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return

	var streak := _death_streaks.get(victim_id, {"count": 0, "timer": 0.0})
	streak["count"] += 1
	streak["timer"] = DEATH_STREAK_WINDOW
	_death_streaks[victim_id] = streak

	# Reset wanted on death
	WantedSystem.reset_heat()

	# Cash penalty (halved if on death streak)
	var loss := SaveData.deduct_cash_on_death()
	if streak["count"] >= DEATH_STREAK_THRESHOLD:
		loss = loss / 2

	# Rep penalty
	SaveData.deduct_rep_on_death()
	SaveData.deplete_ammo_on_death()

	# PvP bonus for killer
	if killer_id != victim_id and killer_id != 0:
		var bonus := loss / 2
		_give_cash_to_peer(killer_id, bonus)

	# Broadcast death event
	_rpc_player_died.rpc(victim_id, killer_id)

	# Schedule respawn
	_schedule_respawn(victim_id, death_pos)

func _schedule_respawn(peer_id: int, death_pos: Vector3) -> void:
	await get_tree().create_timer(RESPAWN_TIME).timeout
	var spawn := get_spawn_point(death_pos)
	_rpc_respawn_player.rpc_id(peer_id, spawn)
	player_respawned.emit(peer_id)

@rpc("authority", "reliable", "call_local")
func _rpc_player_died(victim_id: int, killer_id: int) -> void:
	player_died.emit(victim_id, killer_id)

@rpc("authority", "reliable")
func _rpc_respawn_player(spawn_pos: Vector3) -> void:
	var local_player := get_player_node(multiplayer.get_unique_id())
	if local_player and local_player.has_method("respawn"):
		local_player.respawn(spawn_pos)
	player_respawned.emit(multiplayer.get_unique_id())

func _give_cash_to_peer(peer_id: int, amount: int) -> void:
	if peer_id == multiplayer.get_unique_id() or peer_id == 1:
		SaveData.add_cash(amount)
		cash_changed.emit(SaveData.cash)
	else:
		_rpc_give_cash.rpc_id(peer_id, amount)

@rpc("authority", "reliable")
func _rpc_give_cash(amount: int) -> void:
	SaveData.add_cash(amount)
	cash_changed.emit(SaveData.cash)

# ── Death streak timer ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	for pid in _death_streaks.keys():
		var s: Dictionary = _death_streaks[pid]
		s["timer"] -= delta
		if s["timer"] <= 0.0:
			s["count"] = 0
			s["timer"] = 0.0

# ── Player management ──────────────────────────────────────────────────────────

func _on_player_left(peer_id: int) -> void:
	unregister_player(peer_id)

func is_opped(peer_id: int) -> bool:
	match rules["cheats_mode"]:
		"all":      return true
		"host":     return peer_id == 1
		"op_list":  return peer_id in opped_players
		_:          return false

func op_player(peer_id: int) -> void:
	if not peer_id in opped_players:
		opped_players.append(peer_id)
	_rpc_set_opped.rpc_id(peer_id, true)

func deop_player(peer_id: int) -> void:
	opped_players.erase(peer_id)
	_rpc_set_opped.rpc_id(peer_id, false)

@rpc("authority", "reliable")
func _rpc_set_opped(_opped: bool) -> void:
	pass  # Client tracks this locally via is_opped()

# ── Game rules sync ────────────────────────────────────────────────────────────

func set_rule(key: String, value: Variant) -> void:
	if not multiplayer.is_server():
		return
	rules[key] = value
	_rpc_sync_rules.rpc(rules)
	game_rules_changed.emit()

@rpc("authority", "reliable", "call_local")
func _rpc_sync_rules(new_rules: Dictionary) -> void:
	rules = new_rules
	game_rules_changed.emit()
