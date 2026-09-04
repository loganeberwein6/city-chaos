extends Node

# Batman hero component — attached as child of player_controller.
# Abilities: Grapple (Q), Glide (E hold).

const GRAPPLE_RANGE  := 40.0
const GRAPPLE_TIME   := 0.5
const GLIDE_MAX_FALL := -5.0

var _gliding   := false
var _grappling := false

func get_stat_overrides() -> Dictionary:
	return {
		"walk_speed":    6.0,
		"sprint_speed":  11.0,
		"jump_velocity": 10.0,
		"max_health":    120.0,
	}

func _physics_process(_delta: float) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return
	_handle_glide(player)

func _unhandled_input(event: InputEvent) -> void:
	var player: Node = get_parent()
	if not player.get("_is_local"):
		return

	# Grapple — Q press
	if event.is_action_pressed("ability_1"):
		_try_grapple(player)

func _try_grapple(player: Node) -> void:
	if _grappling:
		return
	var cam: Camera3D = player.get_node("SpringArm3D/Camera3D")
	var from := cam.global_position
	var to   := from + (-cam.global_transform.basis.z) * GRAPPLE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player as RID if player is PhysicsBody3D else player.get_rid()]
	var result := (player as Node3D).get_world_3d().direct_space_state.intersect_ray(query)
	if not result:
		return
	var hit_point: Vector3 = result["position"]
	_grappling = true
	var tween := (player as Node).create_tween()
	tween.tween_property(player, "global_position", hit_point, GRAPPLE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _grappling = false)

func _handle_glide(player: Node) -> void:
	var cb: CharacterBody3D = player as CharacterBody3D
	if cb == null:
		return
	# E held and in air → glide
	if Input.is_action_pressed("ability_2") and not cb.is_on_floor():
		_gliding = true
		cb.velocity.y = maxf(GLIDE_MAX_FALL, cb.velocity.y)
	else:
		_gliding = false
