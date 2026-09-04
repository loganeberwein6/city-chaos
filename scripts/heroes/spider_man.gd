extends Node

# Spider-Man hero component — attached as child of player_controller.
# Abilities: Web Swing (Q), Web Zip (E — ground only).

const WEB_SWING_RANGE := 30.0
const WEB_ZIP_RANGE   := 15.0
const SWING_ACCEL     := 18.0  # pull acceleration toward anchor (units/s²)
const ZIP_SPEED       := 25.0

var _swinging  := false
var _swing_pt  := Vector3.ZERO

func get_stat_overrides() -> Dictionary:
	return {
		"walk_speed":    6.0,
		"sprint_speed":  12.0,
		"jump_velocity": 11.0,
		"max_health":    100.0,
	}

func _physics_process(delta: float) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return
	if _swinging:
		_tick_swing(player as CharacterBody3D, delta)

func _unhandled_input(event: InputEvent) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return

	# Web Swing — Q press/release
	if event.is_action_pressed("ability_1"):
		_try_web_swing(player)
	if event.is_action_released("ability_1"):
		_swinging = false

	# Web Zip — E press (ground only)
	if event.is_action_pressed("ability_2"):
		var cb: CharacterBody3D = player as CharacterBody3D
		if cb and cb.is_on_floor():
			_try_web_zip(player, cb)

func _raycast_from_camera(player: Node, range_dist: float) -> Dictionary:
	var cam: Camera3D = player.get_node("SpringArm3D/Camera3D")
	var from := cam.global_position
	var to   := from + (-cam.global_transform.basis.z) * range_dist
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	return (player as Node3D).get_world_3d().direct_space_state.intersect_ray(query)

func _try_web_swing(player: Node) -> void:
	var result := _raycast_from_camera(player, WEB_SWING_RANGE)
	if result:
		_swing_pt = result["position"]
		_swinging = true

func _tick_swing(cb: CharacterBody3D, delta: float) -> void:
	if cb == null or cb.is_on_floor():
		_swinging = false
		return
	# Accelerate player toward the swing anchor point over ~1 second
	var to_anchor := _swing_pt - cb.global_position
	var dist := to_anchor.length()
	if dist < 1.5:
		_swinging = false
		return
	var pull := to_anchor.normalized() * SWING_ACCEL
	cb.velocity += pull * delta

func _try_web_zip(player: Node, cb: CharacterBody3D) -> void:
	var result := _raycast_from_camera(player, WEB_ZIP_RANGE)
	var target: Vector3
	if result:
		target = result["position"]
	else:
		var cam: Camera3D = player.get_node("SpringArm3D/Camera3D")
		var fwd := -cam.global_transform.basis.z
		target = cb.global_position + fwd * WEB_ZIP_RANGE
	cb.global_position = target
