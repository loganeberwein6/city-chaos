extends "res://scripts/npc/npc_base.gd"
class_name NewsCrew

var _filming := false
var _film_target: Node3D = null
var _film_timer := 0.0
const FILM_RANGE := 20.0
const FILM_CHECK := 2.0

func _ready() -> void:
	faction = Faction.NEWS
	max_health = 70.0
	health = max_health
	walk_speed = 2.5
	run_speed = 5.5
	drop_cash_min = 0
	drop_cash_max = 0
	awareness_radius = 40.0
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD: return
	_film_timer -= delta
	if _film_timer <= 0.0:
		_film_timer = FILM_CHECK
		_update_filming()

func _update_filming() -> void:
	var stars := WantedSystem.get_stars()
	if stars < 2:
		if _filming:
			_stop_filming()
		return

	var closest_player := is_player_nearby()
	if closest_player == null:
		if _filming: _stop_filming()
		_enter_wander()
		return

	# Move to film position
	_film_target = closest_player
	var dist := global_position.distance_to(_film_target.global_position)
	if dist > FILM_RANGE:
		if state != State.CHASE:
			enter_chase(_film_target)
	else:
		if not _filming:
			_start_filming()
		state = State.IDLE
		velocity = Vector3.ZERO
		# Face the action
		var look_dir := (_film_target.global_position - global_position)
		look_dir.y = 0.0
		if look_dir.length() > 0.1:
			look_at(global_position + look_dir, Vector3.UP)

func _start_filming() -> void:
	_filming = true
	WantedSystem.set_news_multiplier(true)

func _stop_filming() -> void:
	_filming = false
	WantedSystem.set_news_multiplier(false)

func _tick_chase(delta: float) -> void:
	if _film_target == null or not is_instance_valid(_film_target): _enter_wander(); return
	var dist := global_position.distance_to(_film_target.global_position)
	if dist <= FILM_RANGE:
		_start_filming()
		state = State.IDLE
	else:
		_move_toward(_film_target.global_position, run_speed, delta)

func _on_hurt(attacker_id: int) -> void:
	if _filming: _stop_filming()
	var p := GameManager.get_player_node(attacker_id)
	if p: enter_flee(p)
	# Attacking news crew raises stars significantly
	WantedSystem.report_crime("kill_civilian")

func _die(killer_id: int) -> void:
	_stop_filming()
	super._die(killer_id)
