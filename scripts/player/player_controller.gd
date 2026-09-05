extends CharacterBody3D

const CharacterModel  = preload("res://scripts/player/character_model.gd")
const WeaponModel     = preload("res://scripts/player/weapon_model.gd")
const PlayerAnimator  = preload("res://scripts/player/player_animator.gd")

# ── Stats (overridden per hero) ────────────────────────────────────────────────
@export var walk_speed     := 5.0
@export var sprint_speed   := 10.0
@export var jump_velocity  := 9.0
@export var acceleration   := 14.0
@export var friction       := 10.0
@export var air_control    := 0.25
@export var max_health     := 100.0
@export var max_armor      := 100.0

# ── State ──────────────────────────────────────────────────────────────────────
var health     := max_health
var armor      := 0.0
var is_dead    := false
var is_immune  := false
var peer_id    := 1
var hero_id    := "normal_person"
var cash       := 0
var active_weapon_slot := 0
var weapon_slots: Array[Dictionary] = []  # [{id, ammo, reserve}, ...]

# ── Camera ─────────────────────────────────────────────────────────────────────
@export var camera_sensitivity := 0.003
@export var camera_min_pitch   := -90.0
@export var camera_max_pitch   := 90.0
@export var camera_distance    := 6.0

@onready var spring_arm:       SpringArm3D  = $SpringArm3D
@onready var camera:           Camera3D    = $SpringArm3D/Camera3D
@onready var mesh_root:        Node3D      = $MeshRoot
@onready var weapon_mesh_root: Node3D      = $WeaponMeshRoot

var _cam_pitch    := deg_to_rad(-20.0)
var _cam_yaw      := 0.0
var _cam_offset_x := 0.5
var _is_local     := false
var _crosshair: CanvasLayer = null

var _animator: Node = null
var _punch_cooldown := 0.0
var _name_tag: Label3D = null
var _in_finisher := false
var _mesh_root_base_y := 0.0

# ── Death camera ───────────────────────────────────────────────────────────────
var _death_cam_target: Node3D = null
var _death_timer := 0.0

# ── Vehicle ────────────────────────────────────────────────────────────────────
var current_vehicle: Node3D = null

# ── Hero component ─────────────────────────────────────────────────────────────
var _hero_component: Node = null
const HERO_SCRIPTS := {
	"batman":       "res://scripts/heroes/batman.gd",
	"flash":        "res://scripts/heroes/flash_hero.gd",
	"spider_man":   "res://scripts/heroes/spider_man.gd",
	"iron_man":     "res://scripts/heroes/iron_man.gd",
	"hulk":         "res://scripts/heroes/hulk.gd",
}

const GRAVITY := 20.0

func _ready() -> void:
	peer_id = name.to_int() if name.is_valid_int() else 1
	_is_local = (peer_id == multiplayer.get_unique_id())
	spring_arm.spring_length = camera_distance
	spring_arm.rotation.x = _cam_pitch
	spring_arm.add_excluded_object(get_rid())
	spring_arm.collision_mask = 0
	_mesh_root_base_y = mesh_root.position.y
	CharacterModel.build(mesh_root, hero_id)
	_animator = PlayerAnimator.new()
	add_child(_animator)
	_animator.setup(mesh_root)
	if _is_local:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
		_create_crosshair()
	GameManager.register_player(peer_id, self)
	_init_weapon_slots()
	_load_hero_component()
	add_to_group("players")
	_equip_slot(active_weapon_slot)
	_setup_name_tag()

func _exit_tree() -> void:
	GameManager.unregister_player(peer_id)
	if _is_local:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _init_weapon_slots() -> void:
	weapon_slots.clear()
	for i in 9:
		weapon_slots.append({"id": "", "ammo": 0, "reserve": 0})

func _load_hero_component() -> void:
	if _hero_component:
		_hero_component.queue_free()
		_hero_component = null
	var path: String = HERO_SCRIPTS.get(hero_id, "")
	if path == "": return
	var script: GDScript = load(path)
	if not script: return
	_hero_component = script.new()
	add_child(_hero_component)
	_apply_hero_stats()

func _apply_hero_stats() -> void:
	if not _hero_component or not _hero_component.has_method("get_stat_overrides"): return
	var overrides: Dictionary = _hero_component.get_stat_overrides()
	if overrides.has("walk_speed"):   walk_speed  = overrides["walk_speed"]
	if overrides.has("sprint_speed"): sprint_speed = overrides["sprint_speed"]
	if overrides.has("jump_velocity"):jump_velocity = overrides["jump_velocity"]
	if overrides.has("max_health"):
		max_health = overrides["max_health"]
		health     = max_health

func _setup_name_tag() -> void:
	_name_tag = Label3D.new()
	_name_tag.pixel_size = 0.006
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.font_size = 42
	_name_tag.outline_size = 6
	_name_tag.position = Vector3(0, 2.3, 0)
	_name_tag.visible = not _is_local
	mesh_root.add_child(_name_tag)
	_update_name_tag()
	if not _is_local:
		get_tree().create_timer(1.0).timeout.connect(_update_name_tag, CONNECT_ONE_SHOT)

func _update_name_tag() -> void:
	if not is_instance_valid(_name_tag): return
	var pdata: Dictionary = NetworkManager.connected_players.get(peer_id, {})
	_name_tag.text = pdata.get("name", "P%d" % peer_id)

func set_hero(hid: String) -> void:
	hero_id = hid
	CharacterModel.build(mesh_root, hero_id)
	_load_hero_component()
	if _animator:
		_animator.setup(mesh_root)

# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _is_local or is_dead or _in_finisher:
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseMotion:
		_rotate_camera(event.relative)
	if event.is_action_pressed("jump") and is_on_floor() and current_vehicle == null:
		velocity.y = jump_velocity
	if event.is_action_pressed("interact"):
		_try_vehicle_interact()
	if current_vehicle != null: return
	if event.is_action_pressed("attack"):
		_try_attack()
	if event.is_action_pressed("next_weapon"):
		_cycle_weapon(1)
	if event.is_action_pressed("prev_weapon"):
		_cycle_weapon(-1)
	for i in 9:
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			_select_weapon_slot(i)

func _rotate_camera(delta: Vector2) -> void:
	_cam_yaw -= delta.x * camera_sensitivity
	spring_arm.rotation.y = _cam_yaw
	_cam_pitch = clampf(_cam_pitch - delta.y * camera_sensitivity, deg_to_rad(camera_min_pitch), deg_to_rad(camera_max_pitch))
	spring_arm.rotation.x = _cam_pitch

func _process(delta: float) -> void:
	if not _is_local:
		return
	_update_weapon_mesh()
	spring_arm.position.x = lerpf(spring_arm.position.x, _cam_offset_x, 8.0 * delta)

func _create_crosshair() -> void:
	_crosshair = CanvasLayer.new()
	var ctrl := Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.add_child(ctrl)
	var lbl := Label.new()
	lbl.text = "+"
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.add_child(lbl)
	add_child(_crosshair)
	_crosshair.visible = false

func _update_weapon_mesh() -> void:
	var local_offset := Vector3(0.35, 1.0, -0.45)
	var target_basis := mesh_root.global_transform.basis
	weapon_mesh_root.global_transform = Transform3D(target_basis,
		mesh_root.global_position + target_basis * local_offset)

# ── Physics ────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not _is_local:
		return
	if is_dead:
		_process_death_camera(delta)
		return
	if _in_finisher:
		velocity = Vector3.ZERO
		return
	if current_vehicle != null:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, 9.0, 0.12)
		_apply_vehicle_input()
		global_position = current_vehicle.global_position + Vector3(0, 1.2, 0)
		_sync_position()
		return
	if _punch_cooldown > 0.0:
		_punch_cooldown -= delta
	_apply_gravity(delta)
	_apply_movement(delta)
	move_and_slide()
	if _animator:
		_animator.set_speed(Vector2(velocity.x, velocity.z).length())
		_animator.set_in_air(not is_on_floor())
	_sync_position()

func _apply_gravity(delta: float) -> void:
	if _hero_component and _hero_component.get("_flying"):
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * GameManager.rules.get("gravity_mult", 1.0) * delta

func _apply_vehicle_input() -> void:
	if current_vehicle == null: return
	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var steer    := Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	var braking  := Input.is_action_pressed("brake")
	current_vehicle.call("apply_input", throttle, steer, braking)

func _apply_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_yaw_basis := Basis(Vector3.UP, _cam_yaw)
	var move_dir := (cam_yaw_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var ctrl := 1.0 if is_on_floor() else air_control

	var input_rate := (acceleration + friction * 6.0) * delta if is_on_floor() else acceleration * ctrl * delta
	if move_dir.length() > 0.01:
		velocity.x = move_toward(velocity.x, move_dir.x * target_speed, input_rate)
		velocity.z = move_toward(velocity.z, move_dir.z * target_speed, input_rate)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, atan2(move_dir.x, move_dir.z), 12.0 * delta)
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, friction * 14.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * 14.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * air_control * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * air_control * delta)

# ── Sync (basic position sync for multiplayer) ────────────────────────────────

func _sync_position() -> void:
	if Engine.get_physics_frames() % 2 == 0:
		_rpc_sync.rpc(global_position, mesh_root.rotation.y, velocity)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _rpc_sync(pos: Vector3, mesh_yaw: float, vel: Vector3) -> void:
	if _is_local:
		return
	global_position = global_position.lerp(pos, 0.3)
	mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, mesh_yaw, 0.3)
	velocity = vel

# ── Combat ─────────────────────────────────────────────────────────────────────

func take_damage(amount: float, attacker_id: int) -> void:
	if is_dead or is_immune:
		return
	if not _is_local:
		return

	# Friendly fire check: block player-on-player damage when friendly fire is off
	if attacker_id != peer_id and attacker_id in GameManager._players:
		if not GameManager.rules.get("friendly_fire", false):
			return

	# Armor absorbs 60% of damage
	if armor > 0.0:
		var absorbed := minf(amount * 0.6, armor)
		armor -= absorbed
		amount -= absorbed

	health -= amount
	if health <= 0.0:
		health = 0.0
		_die(attacker_id)

func heal(amount: float) -> void:
	health = minf(health + amount, max_health)

@rpc("authority", "reliable", "call_local")
func arrested() -> void:
	if not _is_local:
		return
	# Stun: disable input for 3 seconds, show message
	is_immune = true
	await get_tree().create_timer(3.0).timeout
	respawn(GameManager.get_spawn_point())
	WantedSystem.reset_heat()
	is_immune = false

func give_armor(amount: float) -> void:
	armor = minf(armor + amount, max_armor)

func _die(killer_id: int) -> void:
	is_dead = true
	var killer_node := GameManager.get_player_node(killer_id)
	_death_cam_target = killer_node
	_death_timer = 0.0

	# Drop active weapon
	var active := weapon_slots[active_weapon_slot]
	if active["id"] != "":
		_spawn_dropped_weapon(active["id"])
		weapon_slots[active_weapon_slot] = {"id": "", "ammo": 0, "reserve": 0}

	GameManager.on_player_died(peer_id, killer_id, "", global_position)

func _process_death_camera(delta: float) -> void:
	_death_timer += delta
	if _death_cam_target and is_instance_valid(_death_cam_target):
		spring_arm.top_level = true
		spring_arm.global_position = spring_arm.global_position.lerp(
			_death_cam_target.global_position + Vector3(0, 2, 0), 5.0 * delta)

func respawn(pos: Vector3) -> void:
	is_dead = false
	is_immune = true
	spring_arm.top_level = false
	global_position = pos
	health = max_health
	armor = 0.0
	velocity = Vector3.ZERO
	_start_immunity()

func _start_immunity() -> void:
	var tween := create_tween().set_loops(6)
	tween.tween_property(mesh_root, "visible", false, 0.25)
	tween.tween_property(mesh_root, "visible", true, 0.25)
	await get_tree().create_timer(3.0).timeout
	is_immune = false
	mesh_root.visible = true

# ── Weapons ────────────────────────────────────────────────────────────────────

func pickup_weapon(weapon_id: String, ammo: int, reserve: int) -> void:
	pick_up_weapon(weapon_id, ammo, reserve)

func pick_up_weapon(weapon_id: String, ammo: int, reserve: int) -> void:
	# Fill first empty slot, or add reserve to existing
	for i in weapon_slots.size():
		if weapon_slots[i]["id"] == weapon_id:
			weapon_slots[i]["reserve"] += reserve
			return
	for i in weapon_slots.size():
		if weapon_slots[i]["id"] == "":
			weapon_slots[i] = {"id": weapon_id, "ammo": ammo, "reserve": reserve}
			if active_weapon_slot == i:
				_equip_slot(i)
			return

func _try_attack() -> void:
	var slot := weapon_slots[active_weapon_slot]
	if slot["id"] == "":
		_punch()
		return
	if slot["ammo"] <= 0:
		if slot["reserve"] > 0:
			_reload_slot(active_weapon_slot)
		return
	slot["ammo"] -= 1
	_fire_weapon(slot["id"])

func _punch() -> void:
	if _punch_cooldown > 0.0:
		return
	_punch_cooldown = 0.5
	AudioManager.play_3d("punch", global_position)

	if _animator:
		_animator.play_punch()

	WantedSystem.report_crime("punch_civilian")

	# Hit nearest NPC within arm's reach (2 m)
	var best: Node3D = null
	var best_dist := 2.0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(npc):
			continue
		var d := global_position.distance_to(npc.global_position)
		if d < best_dist:
			best_dist = d
			best = npc
	if best != null:
		var npc_health: float = best.get("health") if "health" in best else 0.0
		if npc_health > 0.0 and npc_health <= 25.0 and best.has_method("prepare_finisher"):
			_do_finisher(best)
		elif best.has_method("take_punch"):
			best.take_punch(25.0, peer_id)
		elif best.has_method("take_damage"):
			best.take_damage(25.0, peer_id)

func _fire_weapon(weapon_id: String) -> void:
	AudioManager.play_3d("gunshot_" + weapon_id, camera.global_position)
	var from := camera.global_position
	var dir  := -camera.global_basis.z
	var client_time := Time.get_ticks_msec()
	if multiplayer.is_server():
		_server_process_shot(from, dir, client_time, weapon_id)
	else:
		_rpc_fire_shot.rpc_id(1, from, dir, client_time, weapon_id)

@rpc("any_peer", "reliable", "call_remote")
func _rpc_fire_shot(from: Vector3, dir: Vector3, client_time: int, weapon_id: String) -> void:
	if not multiplayer.is_server():
		return
	_server_process_shot(from, dir, client_time, weapon_id)

func _server_process_shot(from: Vector3, dir: Vector3, client_time: int, weapon_id: String) -> void:
	var snapshot: Dictionary = LagCompensator.get_snapshot_at(client_time)
	var saved_positions: Dictionary = {}
	for pid in snapshot:
		if pid == peer_id:
			continue
		var p: Node3D = GameManager.get_player_node(pid)
		if p and is_instance_valid(p):
			saved_positions[pid] = p.global_position
			p.global_position = snapshot[pid]

	var to := from + dir * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var dmg := _weapon_damage(weapon_id)
	if result and result["collider"].has_method("take_damage"):
		result["collider"].take_damage(dmg, peer_id)

	for pid in saved_positions:
		var p: Node3D = GameManager.get_player_node(pid)
		if p and is_instance_valid(p):
			p.global_position = saved_positions[pid]

func _weapon_damage(wid: String) -> float:
	var dmg_table := {"pistol": 25.0, "revolver": 60.0, "dual_pistols": 20.0,
		"smg": 15.0, "assault_rifle": 30.0, "lmg": 20.0,
		"shotgun": 80.0, "combat_shotgun": 60.0,
		"sniper": 150.0, "crossbow": 120.0,
		"flamethrower": 8.0, "taser": 0.0}
	return dmg_table.get(wid, 25.0)

func _reload_slot(slot_idx: int) -> void:
	var slot := weapon_slots[slot_idx]
	if slot["reserve"] <= 0:
		return
	var cap: int = _weapon_mag_size(slot["id"])
	var needed: int = cap - (slot["ammo"] as int)
	var take: int = mini(needed, slot["reserve"] as int)
	slot["ammo"] += take
	slot["reserve"] -= take

func _weapon_mag_size(wid: String) -> int:
	var caps := {"pistol": 12, "revolver": 6, "dual_pistols": 24,
		"smg": 30, "assault_rifle": 30, "lmg": 100,
		"shotgun": 8, "combat_shotgun": 12,
		"sniper": 5, "crossbow": 1,
		"rpg": 1, "grenade_launcher": 6,
		"flamethrower": 200, "taser": 1,
		"minigun": 200}
	return caps.get(wid, 30)

func _cycle_weapon(dir: int) -> void:
	var start := active_weapon_slot
	var i := active_weapon_slot
	for _n in weapon_slots.size():
		i = (i + dir) % weapon_slots.size()
		if i < 0:
			i += weapon_slots.size()
		if weapon_slots[i]["id"] != "" or i == 0:
			_select_weapon_slot(i)
			return
	_select_weapon_slot(start)

func _select_weapon_slot(idx: int) -> void:
	active_weapon_slot = idx
	_equip_slot(idx)
	_rpc_equip.rpc(idx)

func _equip_slot(idx: int) -> void:
	var wid: String = weapon_slots[idx].get("id", "")
	WeaponModel.build(weapon_mesh_root, wid)
	weapon_mesh_root.visible = true
	if _is_local:
		_cam_offset_x = 0.35 if wid != "" else 0.0
		if _crosshair:
			_crosshair.visible = (wid != "")

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _rpc_equip(idx: int) -> void:
	if _is_local: return
	active_weapon_slot = idx
	_equip_slot(idx)

func _spawn_dropped_weapon(weapon_id: String) -> void:
	if not multiplayer.is_server(): return
	var pickup_scene := load("res://scenes/weapons/weapon_pickup.tscn") as PackedScene
	if not pickup_scene: return
	var pickup: Node3D = pickup_scene.instantiate()
	pickup.set("weapon_id", weapon_id)
	pickup.global_position = global_position + Vector3(0, 0.5, 0)
	get_tree().root.add_child(pickup)

# ── Vehicle interaction ────────────────────────────────────────────────────────

func _try_vehicle_interact() -> void:
	if current_vehicle:
		# Exit to the side of the vehicle
		var exit_offset := current_vehicle.global_basis.x * 2.5 + Vector3(0, 0.6, 0)
		global_position = current_vehicle.global_position + exit_offset
		current_vehicle.call("exit_vehicle")
		current_vehicle = null
		spring_arm.spring_length = camera_distance
		return
	for v in get_tree().get_nodes_in_group("vehicles"):
		if not is_instance_valid(v): continue
		if v.get("driver") != null: continue
		if global_position.distance_to(v.global_position) >= 4.0: continue
		v.call("enter_vehicle", self)
		current_vehicle = v
		return

# ── Finisher system ────────────────────────────────────────────────────────────

func _do_finisher(npc: Node3D) -> void:
	_in_finisher = true
	if _animator: _animator.set("locked", true)
	npc.call("prepare_finisher")
	var dir := (npc.global_position - global_position)
	dir.y = 0.0
	if dir.length() > 0.1:
		mesh_root.rotation.y = atan2(dir.x, dir.z)
	var choice := randi() % 3
	if choice == 0:
		await _finisher_kick(npc)
	elif choice == 1:
		await _finisher_uppercut(npc)
	else:
		await _finisher_wwe(npc)
	if _animator: _animator.set("locked", false)
	_in_finisher = false

func _finisher_kick(npc: Node3D) -> void:
	var npc_mr: Node3D = npc.get_node_or_null("MeshRoot")
	var rul: Node3D = mesh_root.find_child("RUL", true, false)
	var rll: Node3D = mesh_root.find_child("RLL", true, false)
	var rua: Node3D = mesh_root.find_child("RUA", true, false)
	var rla: Node3D = mesh_root.find_child("RLA", true, false)

	var kick_dir := (npc.global_position - global_position)
	kick_dir.y = 0.0
	kick_dir = kick_dir.normalized()

	# ── Kick ──
	var kick_tw := create_tween().set_parallel(true)
	if rul: kick_tw.tween_property(rul, "rotation:x", -1.35, 0.14)
	if rll: kick_tw.tween_property(rll, "rotation:x", -0.70, 0.14)
	await get_tree().create_timer(0.10).timeout

	# ── NPC ragdoll parabolic arc ──
	if is_instance_valid(npc):
		var start_pos := npc.global_position
		var mid_pos   := start_pos + kick_dir * 3.0 + Vector3(0, 2.5, 0)
		var end_pos   := start_pos + kick_dir * 6.0
		var fly_tw    := npc.create_tween()
		fly_tw.tween_property(npc, "global_position", mid_pos, 0.30)
		fly_tw.tween_property(npc, "global_position", end_pos, 0.35)
		if npc_mr:
			var tumble_tw := npc.create_tween().set_parallel(true)
			tumble_tw.tween_property(npc_mr, "rotation:x", deg_to_rad(90.0), 0.65)
			tumble_tw.tween_property(npc_mr, "rotation:z", kick_dir.x * deg_to_rad(-120.0), 0.65)

	await get_tree().create_timer(0.14).timeout
	if rul: create_tween().tween_property(rul, "rotation:x", 0.0, 0.25)
	if rll: create_tween().tween_property(rll, "rotation:x", 0.0, 0.25)

	# ── Player turns body 90° left (pivots away from NPC) ──
	await get_tree().create_timer(0.22).timeout
	create_tween().tween_property(mesh_root, "rotation:y",
		mesh_root.rotation.y - deg_to_rad(90.0), 0.25)

	# ── NPC lands ──
	await get_tree().create_timer(0.35).timeout

	# ── Camera swings to look at NPC; arm rises to aim ──
	if is_instance_valid(npc):
		var to_npc := npc.global_position - global_position
		to_npc.y = 0.0
		if to_npc.length() > 0.1:
			var raw_yaw := atan2(to_npc.x, to_npc.z) + PI
			# normalize to shortest arc from current yaw so camera doesn't spin the wrong way
			var diff := fmod(raw_yaw - _cam_yaw + PI * 3.0, TAU) - PI
			_cam_yaw += diff
			create_tween().tween_property(spring_arm, "rotation:y", _cam_yaw, 0.22)
	if rua:
		var aim_tw := create_tween().set_parallel(true)
		aim_tw.tween_property(rua, "rotation:x", -0.85, 0.22)
		aim_tw.tween_property(rua, "rotation:z",  0.55, 0.22)  # splay toward NPC side
		if rla: aim_tw.tween_property(rla, "rotation:x", 0.10, 0.22)
	await get_tree().create_timer(0.32).timeout

	# ── Shoot ──
	_finisher_shoot_cosmetic()
	await get_tree().create_timer(0.25).timeout

	# ── Arm returns ──
	if rua:
		var ret_tw := create_tween().set_parallel(true)
		ret_tw.tween_property(rua, "rotation:x", 0.0, 0.22)
		ret_tw.tween_property(rua, "rotation:z", 0.0, 0.22)
		if rla: ret_tw.tween_property(rla, "rotation:x", 0.0, 0.22)

	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(npc) and npc.has_method("complete_finisher"):
		npc.call("complete_finisher", peer_id)

func _finisher_uppercut(npc: Node3D) -> void:
	var npc_mr: Node3D = npc.get_node_or_null("MeshRoot")
	var rua: Node3D = mesh_root.find_child("RUA", true, false)
	var rla: Node3D = mesh_root.find_child("RLA", true, false)
	var lua: Node3D = mesh_root.find_child("LUA", true, false)
	var npc_start_y: float = npc.global_position.y

	# Uppercut swing
	var swing_tw := create_tween().set_parallel(true)
	if rua: swing_tw.tween_property(rua, "rotation:x", -1.65, 0.14)
	if rla: swing_tw.tween_property(rla, "rotation:x", -0.90, 0.14)
	if lua: swing_tw.tween_property(lua, "rotation:x", 0.50, 0.14)
	await get_tree().create_timer(0.12).timeout

	# NPC launches HIGH with smooth ease-out
	if is_instance_valid(npc):
		var up_tw := npc.create_tween()
		up_tw.set_ease(Tween.EASE_OUT)
		up_tw.set_trans(Tween.TRANS_SINE)
		up_tw.tween_property(npc, "global_position:y", npc_start_y + 5.5, 0.65)
		if npc_mr:
			npc.create_tween().tween_property(npc_mr, "rotation:x", deg_to_rad(-30.0), 0.65)
	await get_tree().create_timer(0.30).timeout

	# Arm raises — knife held STRAIGHT UP, elbow fully extended
	if rua:
		var arm_tw := create_tween().set_parallel(true)
		arm_tw.tween_property(rua, "rotation:x", -2.20, 0.18)  # arm nearly overhead, pointing up
		if rla: arm_tw.tween_property(rla, "rotation:x", 0.0, 0.18)  # elbow fully extended
	var knife := _spawn_knife_mesh()
	await get_tree().create_timer(0.58).timeout

	# NPC falls back down — smooth ease-in
	if is_instance_valid(npc):
		var down_tw := npc.create_tween()
		down_tw.set_ease(Tween.EASE_IN)
		down_tw.set_trans(Tween.TRANS_SINE)
		down_tw.tween_property(npc, "global_position:y", npc_start_y, 0.58)
		if npc_mr:
			npc.create_tween().tween_property(npc_mr, "rotation:x", deg_to_rad(80.0), 0.58)
	await get_tree().create_timer(0.52).timeout

	if is_instance_valid(knife): knife.queue_free()
	var ret_tw := create_tween().set_parallel(true)
	if rua: ret_tw.tween_property(rua, "rotation:x", 0.0, 0.22)
	if rla: ret_tw.tween_property(rla, "rotation:x", 0.0, 0.22)
	if lua: ret_tw.tween_property(lua, "rotation:x", 0.0, 0.22)
	AudioManager.play_3d("punch", global_position)
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(npc) and npc.has_method("complete_finisher"):
		npc.call("complete_finisher", peer_id)

func _finisher_wwe(npc: Node3D) -> void:
	var npc_mr: Node3D = npc.get_node_or_null("MeshRoot")
	var rua: Node3D = mesh_root.find_child("RUA", true, false)
	var lua: Node3D = mesh_root.find_child("LUA", true, false)

	var to_npc := npc.global_position - global_position
	to_npc.y = 0.0
	var slam_dir := to_npc.normalized() if to_npc.length_squared() > 0.01 else mesh_root.basis.z
	var npc_pos  := npc.global_position

	# Phase 1 (0.18 s): charge lunge — slight sideways lean begins
	var tw_charge := create_tween().set_parallel(true)
	tw_charge.tween_property(mesh_root, "rotation:x", deg_to_rad(-15.0), 0.18)
	tw_charge.tween_property(mesh_root, "rotation:z", deg_to_rad(-25.0), 0.18)
	if rua: tw_charge.tween_property(rua, "rotation:x", 0.45, 0.18)
	if lua: tw_charge.tween_property(lua, "rotation:x", 0.45, 0.18)
	tw_charge.tween_property(self, "global_position",
		global_position + slam_dir * maxf(to_npc.length() - 1.2, 0.4), 0.18)
	await get_tree().create_timer(0.18).timeout

	# Phase 2a (0.24 s): leap up — player rotates fully on their SIDE (like a spear tackle)
	var arc_top := npc_pos + Vector3(0, 3.2, 0) - slam_dir * 0.4
	var tw_rise := create_tween().set_parallel(true)
	tw_rise.set_ease(Tween.EASE_OUT)
	tw_rise.set_trans(Tween.TRANS_QUAD)
	tw_rise.tween_property(mesh_root, "rotation:x", 0.0, 0.24)
	tw_rise.tween_property(mesh_root, "rotation:z", deg_to_rad(-90.0), 0.24)
	if rua: tw_rise.tween_property(rua, "rotation:x", 0.30, 0.24)
	if lua: tw_rise.tween_property(lua, "rotation:x", 0.30, 0.24)
	tw_rise.tween_property(self, "global_position", arc_top, 0.24)
	await get_tree().create_timer(0.24).timeout

	# Phase 2b (0.20 s): fall sideways down onto NPC torso
	var tw_fall := create_tween().set_parallel(true)
	tw_fall.set_ease(Tween.EASE_IN)
	tw_fall.set_trans(Tween.TRANS_QUAD)
	tw_fall.tween_property(self, "global_position",
		Vector3(npc_pos.x, npc_pos.y, npc_pos.z), 0.20)
	if is_instance_valid(npc) and npc_mr:
		npc.create_tween().tween_property(npc_mr, "rotation:z", deg_to_rad(-70.0), 0.20)
	await get_tree().create_timer(0.20).timeout

	# Impact
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("camera_shake"):
			hud.camera_shake(0.65)
	AudioManager.play_3d("punch", global_position)

	# NPC gets slammed sideways and skids away
	if is_instance_valid(npc):
		if npc_mr:
			npc.create_tween().tween_property(npc_mr, "rotation:x", deg_to_rad(90.0), 0.22)
		var npc_slide := npc.create_tween()
		npc_slide.set_ease(Tween.EASE_OUT)
		npc_slide.tween_property(npc, "global_position",
			npc_pos + slam_dir * 3.0 + Vector3(0, 0.4, 0), 0.15)
		npc_slide.tween_property(npc, "global_position",
			npc_pos + slam_dir * 3.8, 0.22)

	# Phase 3 (0.30 s): player rolls back upright
	var tw_stand := create_tween().set_parallel(true)
	tw_stand.tween_property(mesh_root, "rotation:z", 0.0, 0.30)
	tw_stand.tween_property(mesh_root, "rotation:x", 0.0, 0.30)
	if rua: tw_stand.tween_property(rua, "rotation:x", 0.0, 0.30)
	if lua: tw_stand.tween_property(lua, "rotation:x", 0.0, 0.30)
	await get_tree().create_timer(0.30).timeout

	mesh_root.position.y = _mesh_root_base_y
	mesh_root.rotation.x = 0.0
	mesh_root.rotation.z = 0.0
	if rua: rua.rotation.x = 0.0
	if lua: lua.rotation.x = 0.0
	if is_instance_valid(npc) and npc.has_method("complete_finisher"):
		npc.call("complete_finisher", peer_id)

func _finisher_shoot_cosmetic() -> void:
	var rhand: Node3D = mesh_root.find_child("RHand", true, false)
	if not rhand: return
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.10; sm.height = 0.20
	flash.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.70, 0.0)
	mat.emission_energy_multiplier = 6.0
	flash.material_override = mat
	rhand.add_child(flash)
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("camera_shake"):
			hud.camera_shake(0.25)
	AudioManager.play_3d("gunshot_pistol", global_position)
	await get_tree().create_timer(0.14).timeout
	if is_instance_valid(flash): flash.queue_free()

func _spawn_knife_mesh() -> MeshInstance3D:
	var rhand: Node3D = mesh_root.find_child("RHand", true, false)
	var knife := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.22, 0.018)
	knife.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.80, 0.84)
	mat.metallic = 0.90
	mat.roughness = 0.15
	knife.material_override = mat
	knife.position = Vector3(0.0, 0.12, 0.0)  # blade points straight up above hand
	if rhand:
		rhand.add_child(knife)
	else:
		mesh_root.add_child(knife)
	return knife
