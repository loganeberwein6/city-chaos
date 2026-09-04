extends "res://scripts/npc/npc_base.gd"
class_name Civilian

@export var fights_back := false
@export var is_female   := false

var _aware_timer := 0.0
const AWARENESS_CHECK := 1.5

func _ready() -> void:
	faction = Faction.CIVILIAN
	drop_cash_min = 5
	drop_cash_max = 40
	super._ready()
	# 30% of males fight back, 5% of females
	fights_back = (_rng.randf() < (0.05 if is_female else 0.30))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD: return
	_aware_timer += delta
	if _aware_timer >= AWARENESS_CHECK:
		_aware_timer = 0.0
		_check_awareness()

func _check_awareness() -> void:
	var player := is_player_nearby()
	if not player: return
	var stars := WantedSystem.get_stars()
	if state == State.ATTACK or state == State.FLEE: return
	if stars >= 1:
		if fights_back:
			enter_attack(player)
		else:
			enter_flee(player)

func _tick_attack(delta: float) -> void:
	if target == null or not is_instance_valid(target): _enter_idle(); return
	var dist := global_position.distance_to(target.global_position)
	if dist > 2.5:
		_move_toward(target.global_position, run_speed, delta)
	else:
		# Punch
		if _state_timer <= 0.0:
			_state_timer = 1.2
			if target.has_method("take_damage"):
				target.take_damage(8.0, -1)
			WantedSystem.report_crime("punch_civilian")

func _on_hurt(attacker_id: int) -> void:
	if state != State.ATTACK:
		if fights_back:
			var attacker := GameManager.get_player_node(attacker_id)
			if attacker:
				enter_attack(attacker)
		else:
			var attacker := GameManager.get_player_node(attacker_id)
			if attacker:
				enter_flee(attacker)
