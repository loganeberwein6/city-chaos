extends Node

# Flash hero component — attached as child of player_controller.
# Ability: Speed Dash (Q) — instant velocity burst with 0.5s cooldown.

const DASH_SPEED     := 40.0
const DASH_COOLDOWN  := 0.5

var _dash_cd := 0.0

func get_stat_overrides() -> Dictionary:
	return {
		"walk_speed":    12.0,
		"sprint_speed":  30.0,
		"jump_velocity": 9.0,
		"max_health":    80.0,
	}

func _physics_process(delta: float) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return
	_dash_cd = maxf(0.0, _dash_cd - delta)

func _unhandled_input(event: InputEvent) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return

	# Speed Dash — Q press
	if event.is_action_pressed("ability_1") and _dash_cd <= 0.0:
		_do_dash(player)

func _do_dash(player: Node) -> void:
	var cb: CharacterBody3D = player as CharacterBody3D
	if cb == null:
		return
	# Dash in the direction the player is facing (camera forward, horizontal)
	var cam: Camera3D = player.get_node("SpringArm3D/Camera3D")
	var forward := -cam.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.length_squared() < 0.01:
		forward = -cb.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
	cb.velocity.x = forward.x * DASH_SPEED
	cb.velocity.z = forward.z * DASH_SPEED
	_dash_cd = DASH_COOLDOWN
