extends NpcBase
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
	var space := get_world_3d().direct_space_state
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == self: continue
		var nb := npc as NpcBase
		if nb and nb.state != State.DEAD and nb.health < nb.max_health * 0.5:
			_heal_target = nb
			enter_chase(nb)
			return
	_heal_target = null

func _tick_chase(delta: float) -> void:
	if _heal_target == null or not is_instance_valid(_heal_target):
		_enter_wander(); return
	var dist := global_position.distance_to(_heal_target.global_position)
	if dist <= HEAL_RANGE:
		# Perform healing
		if _heal_target.has_method("take_damage"):
			_heal_target.health = minf(_heal_target.health + HEAL_RATE, _heal_target.max_health)
		if _heal_target.health >= _heal_target.max_health:
			_heal_target = null
			_enter_wander()
	else:
		_move_toward(_heal_target.global_position, run_speed, delta)

func _on_hurt(_attacker_id: int) -> void:
	var p := is_player_nearby()
	if p: enter_flee(p)
