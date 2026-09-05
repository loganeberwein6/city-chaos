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

	var look_dir := (target.global_position - global_position)
	look_dir.y = 0.0
	if look_dir.length_squared() > 0.01:
		rotation.y = atan2(look_dir.x, look_dir.z)

	if _shoot_cooldown <= 0.0:
		_shoot_cooldown = SHOOT_INTERVAL
		_shoot_at(target)

func _attempt_arrest() -> void:
	if target == null or not is_instance_valid(target):
		return
	var dist := global_position.distance_to(target.global_position)
	if dist > 2.0:
		return
	if target.has_method("arrested"):
		target.rpc("arrested")

func _shoot_at(tgt: Node3D) -> void:
	if tgt.has_method("take_damage"):
		var dmg := 18.0 if weapon_id == "pistol" else (40.0 if weapon_id == "rifle" else 80.0)
		# Simple line-of-sight check
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0,1,0), tgt.global_position + Vector3(0,1,0))
		query.exclude = [self]
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result and result["collider"] == tgt:
			tgt.take_damage(dmg, -1)

func _build_visual(root: Node3D) -> void:
	_npc_build_humanoid(root,
		_npc_mat(Color(0.78, 0.66, 0.54)),          # skin
		_npc_mat(Color(0.20, 0.35, 0.82)),          # police blue shirt
		_npc_mat(Color(0.10, 0.13, 0.36)),          # dark navy pants
		_npc_mat(Color(0.10, 0.09, 0.09), 0.15, 0.4))  # black leather boots

	# ── Police cap ──────────────────────────────────────────────────────────────
	var hat_m  := _npc_mat(Color(0.13, 0.15, 0.30))
	var band_m := _npc_mat(Color(0.06, 0.05, 0.04))
	var gold_m := _npc_mat(Color(0.88, 0.72, 0.18), 0.50, 0.30)
	# Crown (slightly tapered top)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.088; crown.bottom_radius = 0.106; crown.height = 0.112
	_npc_mi(root, crown, hat_m, Vector3(0, 1.857, 0))
	# Brim
	var brim := CylinderMesh.new()
	brim.top_radius = 0.158; brim.bottom_radius = 0.152; brim.height = 0.018
	_npc_mi(root, brim, hat_m, Vector3(0, 1.793, -0.014))
	# Hat band
	var band := CylinderMesh.new()
	band.top_radius = 0.108; band.bottom_radius = 0.108; band.height = 0.018
	_npc_mi(root, band, band_m, Vector3(0, 1.800, 0))
	# Badge on cap front
	var cbadge := BoxMesh.new(); cbadge.size = Vector3(0.036, 0.028, 0.012)
	_npc_mi(root, cbadge, gold_m, Vector3(0, 1.862, -0.096))

	# ── Chest badge ─────────────────────────────────────────────────────────────
	var badge := BoxMesh.new(); badge.size = Vector3(0.052, 0.038, 0.014)
	_npc_mi(root, badge, gold_m, Vector3(-0.105, 1.405, -0.106))

	# ── Sunglasses ──────────────────────────────────────────────────────────────
	var glass_m := _npc_mat(Color(0.06, 0.06, 0.06))
	var gl := BoxMesh.new(); gl.size = Vector3(0.060, 0.024, 0.010)
	_npc_mi(root, gl, glass_m, Vector3(-0.046, 1.720, -0.116))
	_npc_mi(root, gl, glass_m, Vector3( 0.046, 1.720, -0.116))
	# Bridge between lenses
	var bridge := BoxMesh.new(); bridge.size = Vector3(0.018, 0.010, 0.008)
	_npc_mi(root, bridge, glass_m, Vector3(0, 1.720, -0.116))

	# ── Holster (right hip) ─────────────────────────────────────────────────────
	var holster_m := _npc_mat(Color(0.14, 0.10, 0.08))
	var holster := BoxMesh.new(); holster.size = Vector3(0.052, 0.095, 0.038)
	_npc_mi(root, holster, holster_m, Vector3(0.215, 1.000, 0))
	# Gun handle visible at holster top
	var gun_m := _npc_mat(Color(0.18, 0.18, 0.18), 0.45, 0.35)
	var gun := BoxMesh.new(); gun.size = Vector3(0.024, 0.058, 0.015)
	_npc_mi(root, gun, gun_m, Vector3(0.215, 1.042, -0.018))

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
