extends CharacterBody3D

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
@export var camera_min_pitch   := -60.0
@export var camera_max_pitch   := 75.0
@export var camera_distance    := 6.0

@onready var spring_arm: SpringArm3D  = $SpringArm3D
@onready var camera:     Camera3D    = $SpringArm3D/Camera3D
@onready var mesh_root:  Node3D      = $MeshRoot

var _cam_pitch := deg_to_rad(20.0)
var _is_local  := false

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
	if _is_local:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
	GameManager.register_player(peer_id, self)
	_init_weapon_slots()
	_load_hero_component()
	add_to_group("players")

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

func set_hero(hid: String) -> void:
	hero_id = hid
	_load_hero_component()

# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _is_local or is_dead:
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseMotion and current_vehicle == null:
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
	rotate_y(-delta.x * camera_sensitivity)
	_cam_pitch = clampf(_cam_pitch - delta.y * camera_sensitivity, deg_to_rad(camera_min_pitch), deg_to_rad(camera_max_pitch))
	spring_arm.rotation.x = _cam_pitch

# ── Physics ────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not _is_local:
		return
	if is_dead:
		_process_death_camera(delta)
		return
	if current_vehicle != null:
		_apply_vehicle_input()
		global_position = current_vehicle.global_position + Vector3(0, 1.2, 0)
		_sync_position()
		return
	_apply_gravity(delta)
	_apply_movement(delta)
	move_and_slide()
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
	var move_dir := (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var ctrl := 1.0 if is_on_floor() else air_control

	if move_dir.length() > 0.01:
		velocity.x = move_toward(velocity.x, move_dir.x * target_speed, acceleration * ctrl * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * target_speed, acceleration * ctrl * delta)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, atan2(-move_dir.x, -move_dir.z), 12.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * ctrl * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * ctrl * delta)

# ── Sync (basic position sync for multiplayer) ────────────────────────────────

func _sync_position() -> void:
	if Engine.get_physics_frames() % 2 == 0:
		_rpc_sync.rpc(global_position, global_rotation, velocity)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _rpc_sync(pos: Vector3, rot: Vector3, vel: Vector3) -> void:
	if _is_local:
		return
	global_position = global_position.lerp(pos, 0.3)
	global_rotation = rot
	velocity = vel

# ── Combat ─────────────────────────────────────────────────────────────────────

func take_damage(amount: float, attacker_id: int) -> void:
	if is_dead or is_immune:
		return
	if not _is_local:
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
	WantedSystem.report_crime("punch_civilian")

func _fire_weapon(_weapon_id: String) -> void:
	# Raycast from camera
	var from := camera.global_position
	var to   := from + (-camera.global_basis.z * 200.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result["collider"].has_method("take_damage"):
		var dmg := _weapon_damage(_weapon_id)
		result["collider"].take_damage(dmg, peer_id)

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

func _equip_slot(_idx: int) -> void:
	pass  # Hook for 3D weapon model swap — implemented per hero

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
		current_vehicle.call("exit_vehicle")
		current_vehicle = null
		return
	for v in get_tree().get_nodes_in_group("vehicles"):
		if not is_instance_valid(v): continue
		if v.get("driver") != null: continue
		if global_position.distance_to(v.global_position) >= 4.0: continue
		v.call("enter_vehicle", self)
		current_vehicle = v
		return
