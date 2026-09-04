extends "res://scripts/npc/npc_base.gd"
class_name PoliceOfficer

@export var weapon_id := "pistol"

var _shoot_cooldown := 0.0
var _stars_when_spawned := 0
const SHOOT_INTERVAL  := 1.5
const ARREST_DIST     := 1.8

func _ready() -> void:
	faction     = Faction.POLICE
	max_health  = 120.0
	health      = max_health
	walk_speed  = 3.0
	run_speed   = 6.5
	awareness_radius = 40.0
	drop_cash_min = 0; drop_cash_max = 0
	super._ready()

func activate(target_player: Node3D, star_level: int) -> void:
	_stars_when_spawned = star_level
	enter_chase(target_player)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD: return
	_shoot_cooldown -= delta
	# Re-acquire target if lost
	if (state == State.CHASE or state == State.ATTACK) and (target == null or not is_instance_valid(target)):
		var p := is_player_nearby()
		if p: target = p
		else: _enter_wander()

func _tick_chase(delta: float) -> void:
	if target == null or not is_instance_valid(target): _enter_wander(); return
	var dist := global_position.distance_to(target.global_position)
	var stars := WantedSystem.get_stars()

	if stars <= 1:
		# Try to arrest — get very close
		if dist <= ARREST_DIST:
			_attempt_arrest()
		else:
			_move_toward(target.global_position, run_speed, delta)
	else:
		if dist <= attack_range:
			enter_attack(target)
		else:
			_move_toward(target.global_position, run_speed, delta)

func _tick_attack(delta: float) -> void:
	if target == null or not is_instance_valid(target): _enter_wander(); return
	var dist := global_position.distance_to(target.global_position)
	# Keep distance for shooting
	if dist > attack_range:
		_move_toward(target.global_position, run_speed, delta)
	elif dist < 4.0:
		# Back away
		var away := global_position + (global_position - target.global_position).normalized() * 6.0
		_move_toward(away, walk_speed, delta)

	look_at(target.global_position, Vector3.UP)
	rotation.x = 0.0

	if _shoot_cooldown <= 0.0:
		_shoot_cooldown = SHOOT_INTERVAL
		_shoot_at(target)

func _attempt_arrest() -> void:
	# Flash arrest — just reset player stars for now; full mechanic later
	WantedSystem.reset_heat()

func _shoot_at(tgt: Node3D) -> void:
	if tgt.has_method("take_damage"):
		var dmg := 18.0 if weapon_id == "pistol" else (40.0 if weapon_id == "rifle" else 80.0)
		# Simple line-of-sight check
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0,1,0), tgt.global_position + Vector3(0,1,0))
		query.exclude = [self]
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result and result["collider"] == tgt:
			tgt.take_damage(dmg, -1)

func _on_hurt(_attacker_id: int) -> void:
	var p := is_player_nearby()
	if p and state != State.ATTACK:
		enter_attack(p)

func _die(killer_id: int) -> void:
	# Drop armor and pistol
	SaveData.add_weapon("pistol", 6, 12)
	if _rng.randf() < 0.4:
		SaveData.give_armor(25.0)
	super._die(killer_id)
