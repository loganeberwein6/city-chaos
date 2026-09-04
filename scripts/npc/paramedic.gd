extends "res://scripts/npc/npc_base.gd"
class_name Paramedic

var _heal_target: Node3D = null
var _heal_timer := 0.0
const HEAL_RATE    := 5.0
const HEAL_INTERVAL := 0.5
const HEAL_RANGE   := 2.5

func _ready() -> void:
	faction = Faction.PARAMEDIC
	max_health = 80.0
	health = max_health
	walk_speed = 3.0
	run_speed = 6.0
	drop_cash_min = 0
	drop_cash_max = 0
	awareness_radius = 30.0
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD: return
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = HEAL_INTERVAL
		_tick_healing(delta)

func _tick_healing(_delta: float) -> void:
	# Flee from players with stars
	if WantedSystem.get_stars() >= 1:
		var p := is_player_nearby()
		if p and state != State.FLEE:
			enter_flee(p)
		return

	# Look for downed NPCs nearby to heal
	if state == State.FLEE:
		_enter_wander()
		_heal_target = null

	if _heal_target == null or not is_instance_valid(_heal_target):
		_find_heal_target()

func _find_heal_target() -> void:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == self: continue
		var nb: Node3D = npc as Node3D
		if nb == null: continue
		if nb.get("state") == State.DEAD: continue
		var h: float  = nb.get("health")
		var mh: float = nb.get("max_health")
		if h < mh * 0.5:
			_heal_target = nb
			enter_chase(nb)
			return
	# Also check players
	for player in get_tree().get_nodes_in_group("players"):
		var pb: Node3D = player as Node3D
		if pb == null: continue
		var ph: float = pb.get("health")
		var pmh: float = pb.get("max_health")
		if ph < pmh * 0.5 and global_position.distance_to(pb.global_position) < 6.0:
			if pb.has_method("heal"):
				pb.heal(10.0)
			return
	_heal_target = null

func _tick_chase(delta: float) -> void:
	if _heal_target == null or not is_instance_valid(_heal_target):
		_enter_wander(); return
	var dist := global_position.distance_to(_heal_target.global_position)
	if dist <= HEAL_RANGE:
		# Perform healing
		var cur_h: float = _heal_target.get("health")
		var max_h: float = _heal_target.get("max_health")
		_heal_target.set("health", minf(cur_h + HEAL_RATE, max_h))
		if _heal_target.get("health") >= max_h:
			_heal_target = null
			_enter_wander()
	else:
		_move_toward(_heal_target.global_position, run_speed, delta)

func _build_visual(root: Node3D) -> void:
	_npc_build_humanoid(root,
		_npc_mat(Color(0.75, 0.62, 0.50)),
		_npc_mat(Color(0.92, 0.92, 0.92)),
		_npc_mat(Color(0.92, 0.92, 0.92)),
		_npc_mat(Color(0.25, 0.25, 0.25)))

func _on_hurt(_attacker_id: int) -> void:
	var p := is_player_nearby()
	if p: enter_flee(p)
