extends Node

# Iron Man hero component — attached as child of player_controller.
# Abilities: Flight (double-jump toggle), Repulsor blast (Q — knockback only).

const FLY_SPEED        := 15.0
const FLY_UP_SPEED     := 8.0
const FLY_DOWN_SPEED   := 8.0
const REPULSOR_RANGE   := 20.0
const REPULSOR_FORCE   := 30.0
const REPULSOR_COOLDOWN := 0.8

var _flying     := false
var _jump_count := 0
var _repulsor_cd := 0.0

func get_stat_overrides() -> Dictionary:
	return {
		"walk_speed":    6.0,
		"sprint_speed":  10.0,
		"jump_velocity": 12.0,
		"max_health":    150.0,
	}

func _physics_process(delta: float) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return

	_repulsor_cd = maxf(0.0, _repulsor_cd - delta)

	var cb: CharacterBody3D = player as CharacterBody3D
	if cb == null:
		return

	# Reset jump count on landing
	if cb.is_on_floor():
		_jump_count = 0
		if _flying:
			_flying = false

	if _flying:
		_tick_flight(cb)

func _unhandled_input(event: InputEvent) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return

	# Track jump presses for double-jump detection
	if event.is_action_pressed("jump"):
		var cb: CharacterBody3D = player as CharacterBody3D
		if cb == null:
			return
		if not cb.is_on_floor():
			_jump_count += 1
			if _jump_count >= 2:
				_flying = true
		else:
			_jump_count = 1  # first jump (on floor → airborne next frame)

	# Toggle flight off with E
	if event.is_action_pressed("ability_2") and _flying:
		_flying = false

	# Repulsor blast — Q press
	if event.is_action_pressed("ability_1") and _repulsor_cd <= 0.0:
		_fire_repulsor(player)

func _tick_flight(cb: CharacterBody3D) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input_dir.x, 0.0, input_dir.y)
	dir = cb.transform.basis * dir
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()

	var vy := 0.0
	if Input.is_action_pressed("jump"):
		vy = FLY_UP_SPEED
	elif Input.is_action_pressed("brake"):
		vy = -FLY_DOWN_SPEED

	cb.velocity = dir * FLY_SPEED + Vector3(0.0, vy, 0.0)

func _fire_repulsor(player: Node) -> void:
	_repulsor_cd = REPULSOR_COOLDOWN
	var cam: Camera3D = player.get_node("SpringArm3D/Camera3D")
	var from := cam.global_position
	var to   := from + (-cam.global_transform.basis.z) * REPULSOR_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var result := (player as Node3D).get_world_3d().direct_space_state.intersect_ray(query)
	if not result:
		return
	var hit: Object = result["collider"]
	# Knockback only — push the hit body away, no damage
	if hit is CharacterBody3D:
		var push_dir := (result["position"] - from).normalized()
		(hit as CharacterBody3D).velocity += push_dir * REPULSOR_FORCE
