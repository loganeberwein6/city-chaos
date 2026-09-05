extends CharacterBody3D
class_name NpcBase

signal died(npc: NpcBase, killer_id: int)

enum Faction { CIVILIAN, POLICE, GANGSTER, PARAMEDIC, FIREFIGHTER, MILITARY, RICH, NEWS }
enum State   { IDLE, WANDER, FLEE, CHASE, ATTACK, DEAD }

@export var faction: Faction = Faction.CIVILIAN
@export var max_health := 100.0
@export var walk_speed := 2.5
@export var run_speed  := 5.5
@export var attack_range := 20.0
@export var awareness_radius := 24.0
@export var drop_cash_min := 0
@export var drop_cash_max := 0

var health := max_health
var state: State = State.IDLE
var target: Node3D = null

var _state_timer    := 0.0
var _wander_target  := Vector3.ZERO
var _rng            := RandomNumberGenerator.new()
var _staggered      := false
var _stagger_timer  := 0.0
var _walk_t         := 0.0

const GRAVITY := 20.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	_rng.randomize()
	_enter_idle()
	var mesh_root_node: Node3D = get_node_or_null("MeshRoot")
	if mesh_root_node:
		_build_visual(mesh_root_node)

func _build_visual(root: Node3D) -> void:
	# Default: civilian-style humanoid. Subclasses override this.
	var skin_m  := _npc_mat(Color(0.80, 0.68, 0.55))
	var shrt_m  := _npc_mat(Color(0.55, 0.55, 0.60))
	var pant_m  := _npc_mat(Color(0.30, 0.32, 0.38))
	var shoe_m  := _npc_mat(Color(0.20, 0.18, 0.15))
	_npc_build_humanoid(root, skin_m, shrt_m, pant_m, shoe_m)

func _npc_mat(color: Color, metallic: float = 0.0, roughness: float = 0.80) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color; m.metallic = metallic; m.roughness = roughness; return m

func _npc_mi(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)

func _npc_build_humanoid(root: Node3D,
		skin_m: StandardMaterial3D, shrt_m: StandardMaterial3D,
		pant_m: StandardMaterial3D, shoe_m: StandardMaterial3D) -> void:

	# ── Head & neck ────────────────────────────────────────────────────────────
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.112; head_mesh.height = 0.272  # oval: slightly taller than wide
	_npc_mi(root, head_mesh, skin_m, Vector3(0, 1.72, 0))
	# Tapered neck — slightly wider at base
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.040; neck_mesh.bottom_radius = 0.052; neck_mesh.height = 0.090
	_npc_mi(root, neck_mesh, skin_m, Vector3(0, 1.615, 0))
	# Shirt collar ring visible below neck
	var collar_m := CylinderMesh.new()
	collar_m.top_radius = 0.055; collar_m.bottom_radius = 0.065; collar_m.height = 0.052
	_npc_mi(root, collar_m, shrt_m, Vector3(0, 1.558, 0))

	# ── Torso — wider chest narrows to waist ───────────────────────────────────
	var chest_mesh := BoxMesh.new(); chest_mesh.size = Vector3(0.38, 0.27, 0.20)
	_npc_mi(root, chest_mesh, shrt_m, Vector3(0, 1.405, 0))
	var waist_mesh := BoxMesh.new(); waist_mesh.size = Vector3(0.30, 0.22, 0.18)
	_npc_mi(root, waist_mesh, shrt_m, Vector3(0, 1.155, 0))

	# ── Pelvis / hips ──────────────────────────────────────────────────────────
	var pelvis_mesh := BoxMesh.new(); pelvis_mesh.size = Vector3(0.33, 0.20, 0.18)
	_npc_mi(root, pelvis_mesh, pant_m, Vector3(0, 0.880, 0))

	# Belt — dark strip between shirt and pants
	var belt_mat := _npc_mat(Color(0.14, 0.11, 0.08))
	var belt_mesh := BoxMesh.new(); belt_mesh.size = Vector3(0.36, 0.056, 0.21)
	_npc_mi(root, belt_mesh, belt_mat, Vector3(0, 1.050, 0))

	# Shoulder caps — give upper arm definition
	var sp_mesh := BoxMesh.new(); sp_mesh.size = Vector3(0.115, 0.080, 0.115)
	_npc_mi(root, sp_mesh, shrt_m, Vector3(-0.245, 1.525, 0))
	_npc_mi(root, sp_mesh, shrt_m, Vector3( 0.245, 1.525, 0))

	# ── Arm joints (NpcLUA / NpcRUA) — animated by _update_walk_anim ──────────
	var ua_mesh   := CapsuleMesh.new(); ua_mesh.radius   = 0.058; ua_mesh.height   = 0.27
	var la_mesh   := CapsuleMesh.new(); la_mesh.radius   = 0.048; la_mesh.height   = 0.24
	var hand_mesh := BoxMesh.new();     hand_mesh.size   = Vector3(0.075, 0.058, 0.040)

	var nlua := Node3D.new(); nlua.name = "NpcLUA"
	nlua.position = Vector3(-0.265, 1.40, 0)
	root.add_child(nlua)
	_npc_mi(nlua, ua_mesh,   shrt_m, Vector3(0, -0.135, 0))
	_npc_mi(nlua, la_mesh,   shrt_m, Vector3(0, -0.410, 0))
	_npc_mi(nlua, hand_mesh, skin_m, Vector3(0, -0.575, 0))

	var nrua := Node3D.new(); nrua.name = "NpcRUA"
	nrua.position = Vector3(0.265, 1.40, 0)
	root.add_child(nrua)
	_npc_mi(nrua, ua_mesh,   shrt_m, Vector3(0, -0.135, 0))
	_npc_mi(nrua, la_mesh,   shrt_m, Vector3(0, -0.410, 0))
	_npc_mi(nrua, hand_mesh, skin_m, Vector3(0, -0.575, 0))

	# ── Leg joints (NpcLUL / NpcRUL) — animated by _update_walk_anim ──────────
	var ul_mesh   := CapsuleMesh.new(); ul_mesh.radius   = 0.075; ul_mesh.height   = 0.38
	var ll_mesh   := CapsuleMesh.new(); ll_mesh.radius   = 0.060; ll_mesh.height   = 0.34
	# Two-piece shoe: flat sole + shoe upper sitting on it
	var sole_mesh  := BoxMesh.new(); sole_mesh.size  = Vector3(0.092, 0.038, 0.240)
	var upper_mesh := BoxMesh.new(); upper_mesh.size = Vector3(0.082, 0.055, 0.178)

	var nlul := Node3D.new(); nlul.name = "NpcLUL"
	nlul.position = Vector3(-0.11, 0.78, 0)
	root.add_child(nlul)
	_npc_mi(nlul, ul_mesh,    pant_m, Vector3(0, -0.190, 0))
	_npc_mi(nlul, ll_mesh,    pant_m, Vector3(0, -0.540, 0))
	_npc_mi(nlul, sole_mesh,  shoe_m, Vector3(0, -0.756, 0.040))
	_npc_mi(nlul, upper_mesh, shoe_m, Vector3(0, -0.724, 0.015))

	var nrul := Node3D.new(); nrul.name = "NpcRUL"
	nrul.position = Vector3(0.11, 0.78, 0)
	root.add_child(nrul)
	_npc_mi(nrul, ul_mesh,    pant_m, Vector3(0, -0.190, 0))
	_npc_mi(nrul, ll_mesh,    pant_m, Vector3(0, -0.540, 0))
	_npc_mi(nrul, sole_mesh,  shoe_m, Vector3(0, -0.756, 0.040))
	_npc_mi(nrul, upper_mesh, shoe_m, Vector3(0, -0.724, 0.015))

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		if _stagger_timer <= 0.0:
			_staggered = false
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_tick_state(delta)
	move_and_slide()
	_update_walk_anim(delta)

# ── State machine ─────────────────────────────────────────────────────────────

func _tick_state(delta: float) -> void:
	if _staggered:
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		return
	_state_timer -= delta
	match state:
		State.IDLE:   _tick_idle(delta)
		State.WANDER: _tick_wander(delta)
		State.FLEE:   _tick_flee(delta)
		State.CHASE:  _tick_chase(delta)
		State.ATTACK: _tick_attack(delta)

func _tick_idle(_delta: float) -> void:
	if _state_timer <= 0.0:
		if _rng.randf() < 0.6:
			_enter_wander()
		else:
			_state_timer = _rng.randf_range(2.0, 5.0)

func _tick_wander(delta: float) -> void:
	var dist := global_position.distance_to(_wander_target)
	if dist < 1.0 or _state_timer <= 0.0:
		_enter_idle()
		return
	nav_agent.set_target_position(_wander_target)
	var next := nav_agent.get_next_path_position()
	_move_toward(next, walk_speed, delta)

func _tick_flee(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_enter_idle()
		return
	var away := global_position + (global_position - target.global_position).normalized() * 10.0
	_move_toward(away, run_speed * 0.72, delta)

func _tick_chase(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_enter_idle()
		return
	nav_agent.set_target_position(target.global_position)
	var next := nav_agent.get_next_path_position()
	_move_toward(next, run_speed, delta)

func _tick_attack(_delta: float) -> void:
	pass  # Override in subclasses

# ── Movement ──────────────────────────────────────────────────────────────────

func _move_toward(pos: Vector3, speed: float, delta: float) -> void:
	var dir := (pos - global_position)
	dir.y = 0.0
	if dir.length() < 0.1:
		velocity.x = 0.0; velocity.z = 0.0
		return
	dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 20.0 * delta)
	# rotate CharacterBody3D so +Z (and thus MeshRoot) faces movement direction
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 12.0 * delta)

# ── State transitions ──────────────────────────────────────────────────────────

func _enter_idle() -> void:
	state = State.IDLE
	_state_timer = _rng.randf_range(1.5, 4.0)
	velocity.x = 0.0; velocity.z = 0.0

func _enter_wander() -> void:
	state = State.WANDER
	_state_timer = _rng.randf_range(4.0, 10.0)
	var angle := _rng.randf_range(0.0, TAU)
	var dist  := _rng.randf_range(5.0, 15.0)
	_wander_target = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)

func enter_flee(from: Node3D) -> void:
	if state == State.DEAD: return
	target = from
	state = State.FLEE
	_state_timer = _rng.randf_range(6.0, 12.0)

func enter_attack(who: Node3D) -> void:
	if state == State.DEAD: return
	target = who
	state = State.ATTACK

func enter_chase(who: Node3D) -> void:
	if state == State.DEAD: return
	target = who
	state = State.CHASE

# ── Damage / Death ────────────────────────────────────────────────────────────

func take_damage(amount: float, attacker_id: int) -> void:
	if state == State.DEAD: return
	health -= amount
	if health <= 0.0:
		health = 0.0
		_die(attacker_id)
	else:
		_on_hurt(attacker_id)
		if health < max_health * 0.5 and not _staggered:
			_stagger()

func take_punch(amount: float, attacker_id: int) -> void:
	if state == State.DEAD: return
	health -= amount
	if health <= 0.0:
		health = 0.0
		_die(attacker_id)
		return
	_stagger()  # always stagger from punch regardless of current health

func _on_hurt(_attacker_id: int) -> void:
	pass  # Override to react

func _stagger() -> void:
	_staggered = true
	_stagger_timer = 0.65   # reset each call so consecutive punches extend stagger
	var mr: Node3D = get_node_or_null("MeshRoot")
	if mr:
		var tw := create_tween()
		tw.tween_property(mr, "rotation:z", deg_to_rad(22.0),  0.10)
		tw.tween_property(mr, "rotation:z", deg_to_rad(-12.0), 0.08)
		tw.tween_property(mr, "rotation:z", 0.0,               0.30)
	# global_basis.z now faces FORWARD (same direction as movement), so knockback is negative
	var back := -global_basis.z * 2.5
	back.y = 0.15
	velocity += back

func prepare_finisher() -> void:
	state = State.DEAD
	health = 0.0
	_staggered = false
	set_physics_process(false)
	velocity = Vector3.ZERO

func complete_finisher(killer_id: int) -> void:
	died.emit(self, killer_id)
	_drop_loot()
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(self): queue_free()

func _ragdoll_fall() -> void:
	var mr: Node3D = get_node_or_null("MeshRoot")
	if not mr: return
	create_tween().tween_property(mr, "rotation:x", deg_to_rad(72.0), 0.38)

func _die(killer_id: int) -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	set_physics_process(false)
	_ragdoll_fall()
	died.emit(self, killer_id)
	_drop_loot()
	await get_tree().create_timer(8.0).timeout
	if is_instance_valid(self): queue_free()

func _drop_loot() -> void:
	if drop_cash_max > 0:
		var amount := _rng.randi_range(drop_cash_min, drop_cash_max)
		SaveData.add_cash(amount)

# ── Walk animation ────────────────────────────────────────────────────────────

func _update_walk_anim(delta: float) -> void:
	if not is_on_floor(): return
	var spd := Vector2(velocity.x, velocity.z).length()
	_walk_t += delta * maxf(spd * 1.5, 0.0)
	var mr := get_node_or_null("MeshRoot")
	if not mr: return
	var nlua: Node3D = mr.find_child("NpcLUA", true, false) as Node3D
	var nrua: Node3D = mr.find_child("NpcRUA", true, false) as Node3D
	var nlul: Node3D = mr.find_child("NpcLUL", true, false) as Node3D
	var nrul: Node3D = mr.find_child("NpcRUL", true, false) as Node3D
	var amp := clampf(spd * 0.060, 0.0, 0.45)
	if nlua: nlua.rotation.x =  sin(_walk_t) * amp
	if nrua: nrua.rotation.x = -sin(_walk_t) * amp
	if nlul: nlul.rotation.x = -sin(_walk_t) * amp
	if nrul: nrul.rotation.x =  sin(_walk_t) * amp

# ── Awareness ──────────────────────────────────────────────────────────────────

func is_player_nearby() -> Node3D:
	var space := get_world_3d().direct_space_state
	for peer_id in GameManager._players:
		var p: Node3D = GameManager._players[peer_id]
		if p and is_instance_valid(p) and global_position.distance_to(p.global_position) < awareness_radius:
			return p
	return null
