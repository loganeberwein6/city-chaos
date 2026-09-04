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

var _state_timer := 0.0
var _wander_target := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

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

func _npc_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color; m.roughness = 0.8; return m

func _npc_mi(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)

func _npc_build_humanoid(root: Node3D,
		skin_m: StandardMaterial3D, shrt_m: StandardMaterial3D,
		pant_m: StandardMaterial3D, shoe_m: StandardMaterial3D) -> void:
	# Head + neck
	var head_mesh := SphereMesh.new(); head_mesh.radius = 0.115; head_mesh.height = 0.23
	_npc_mi(root, head_mesh, skin_m, Vector3(0, 1.72, 0))
	var neck_mesh := CylinderMesh.new(); neck_mesh.top_radius = 0.048; neck_mesh.bottom_radius = 0.048; neck_mesh.height = 0.09
	_npc_mi(root, neck_mesh, skin_m, Vector3(0, 1.615, 0))
	# Torso + pelvis
	var torso_mesh := BoxMesh.new(); torso_mesh.size = Vector3(0.34, 0.46, 0.19)
	_npc_mi(root, torso_mesh, shrt_m, Vector3(0, 1.28, 0))
	var pelvis_mesh := BoxMesh.new(); pelvis_mesh.size = Vector3(0.30, 0.18, 0.17)
	_npc_mi(root, pelvis_mesh, pant_m, Vector3(0, 0.88, 0))
	# Shoulder pads
	var sp_mesh := BoxMesh.new(); sp_mesh.size = Vector3(0.10, 0.08, 0.10)
	_npc_mi(root, sp_mesh, shrt_m, Vector3(-0.22, 1.50, 0))
	_npc_mi(root, sp_mesh, shrt_m, Vector3( 0.22, 1.50, 0))
	# Arms
	var ua_mesh := CapsuleMesh.new(); ua_mesh.radius = 0.055; ua_mesh.height = 0.26
	_npc_mi(root, ua_mesh, shrt_m, Vector3(-0.25, 1.22, 0))
	_npc_mi(root, ua_mesh, shrt_m, Vector3( 0.25, 1.22, 0))
	var la_mesh := CapsuleMesh.new(); la_mesh.radius = 0.045; la_mesh.height = 0.24
	_npc_mi(root, la_mesh, shrt_m, Vector3(-0.26, 0.94, 0))
	_npc_mi(root, la_mesh, shrt_m, Vector3( 0.26, 0.94, 0))
	var hand_mesh := BoxMesh.new(); hand_mesh.size = Vector3(0.07, 0.055, 0.038)
	_npc_mi(root, hand_mesh, skin_m, Vector3(-0.26, 0.78, 0))
	_npc_mi(root, hand_mesh, skin_m, Vector3( 0.26, 0.78, 0))
	# Upper legs
	var ul_mesh := CapsuleMesh.new(); ul_mesh.radius = 0.072; ul_mesh.height = 0.36
	_npc_mi(root, ul_mesh, pant_m, Vector3(-0.10, 0.60, 0))
	_npc_mi(root, ul_mesh, pant_m, Vector3( 0.10, 0.60, 0))
	# Lower legs
	var ll_mesh := CapsuleMesh.new(); ll_mesh.radius = 0.058; ll_mesh.height = 0.33
	_npc_mi(root, ll_mesh, pant_m, Vector3(-0.10, 0.26, 0))
	_npc_mi(root, ll_mesh, pant_m, Vector3( 0.10, 0.26, 0))
	# Feet
	var foot_mesh := BoxMesh.new(); foot_mesh.size = Vector3(0.09, 0.055, 0.20)
	_npc_mi(root, foot_mesh, shoe_m, Vector3(-0.10, 0.03, 0.04))
	_npc_mi(root, foot_mesh, shoe_m, Vector3( 0.10, 0.03, 0.04))

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_tick_state(delta)
	move_and_slide()

# ── State machine ─────────────────────────────────────────────────────────────

func _tick_state(delta: float) -> void:
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
	_move_toward(away, run_speed, delta)

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
	var look_target := global_position + dir
	look_at(look_target, Vector3.UP)
	rotation.x = 0.0

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

func _on_hurt(_attacker_id: int) -> void:
	pass  # Override to react

func _die(killer_id: int) -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	set_physics_process(false)
	died.emit(self, killer_id)
	_drop_loot()
	await get_tree().create_timer(8.0).timeout
	queue_free()

func _drop_loot() -> void:
	if drop_cash_max > 0:
		var amount := _rng.randi_range(drop_cash_min, drop_cash_max)
		SaveData.add_cash(amount)

# ── Awareness ──────────────────────────────────────────────────────────────────

func is_player_nearby() -> Node3D:
	var space := get_world_3d().direct_space_state
	for peer_id in GameManager._players:
		var p: Node3D = GameManager._players[peer_id]
		if p and is_instance_valid(p) and global_position.distance_to(p.global_position) < awareness_radius:
			return p
	return null
