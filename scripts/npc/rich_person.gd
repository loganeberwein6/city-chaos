extends "res://scripts/npc/npc_base.gd"
class_name RichPerson

var _surrendered := false
var _pay_cooldown := 0.0

func _ready() -> void:
	faction = Faction.RICH
	max_health = 60.0
	health = max_health
	walk_speed = 2.2
	run_speed = 4.5
	drop_cash_min = 200
	drop_cash_max = 800
	awareness_radius = 20.0
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD: return
	_pay_cooldown -= delta
	if _surrendered and _pay_cooldown <= 0.0:
		_try_pay_player()

func _check_threat() -> Node3D:
	var p := is_player_nearby()
	if p and WantedSystem.get_stars() >= 1:
		return p
	return null

func _tick_idle(_delta: float) -> void:
	var thr := _check_threat()
	if thr:
		_start_surrender(thr)
		return
	super._tick_idle(_delta)

func _tick_wander(delta: float) -> void:
	var thr := _check_threat()
	if thr:
		_start_surrender(thr)
		return
	super._tick_wander(delta)

func _start_surrender(threat: Node3D) -> void:
	_surrendered = true
	target = threat
	state = State.IDLE
	velocity = Vector3.ZERO
	_pay_cooldown = 1.5

func _try_pay_player() -> void:
	if target == null or not is_instance_valid(target): return
	var dist := global_position.distance_to(target.global_position)
	if dist > 5.0: return
	var bribe := _rng.randi_range(100, 400)
	SaveData.add_cash(bribe)
	_pay_cooldown = 8.0

func _build_visual(root: Node3D) -> void:
	_npc_build_humanoid(root,
		_npc_mat(Color(0.88, 0.75, 0.62)),
		_npc_mat(Color(0.16, 0.16, 0.20)),          # dark suit jacket
		_npc_mat(Color(0.14, 0.14, 0.18)),          # matching dark trousers
		_npc_mat(Color(0.12, 0.10, 0.08), 0.22, 0.32))  # polished dress shoes
	# White dress shirt visible at chest opening
	var shirt_m := _npc_mat(Color(0.95, 0.95, 0.94))
	var shirt_strip := BoxMesh.new(); shirt_strip.size = Vector3(0.11, 0.17, 0.015)
	_npc_mi(root, shirt_strip, shirt_m, Vector3(0, 1.385, -0.106))
	# Red power tie
	var tie_m := _npc_mat(Color(0.62, 0.06, 0.06))
	var tie := BoxMesh.new(); tie.size = Vector3(0.030, 0.190, 0.012)
	_npc_mi(root, tie, tie_m, Vector3(0, 1.345, -0.108))

func _on_hurt(attacker_id: int) -> void:
	var attacker := GameManager.get_player_node(attacker_id)
	if attacker:
		_start_surrender(attacker)
