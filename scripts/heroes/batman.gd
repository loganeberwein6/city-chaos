extends Node
class_name BatmanHero

# Attached as child of player_controller when Batman is selected.

const GRAPPLE_RANGE   := 60.0
const GRAPPLE_SPEED   := 28.0
const GLIDE_GRAVITY   := 2.5
const GLIDE_MAX_FALL  := 4.0

var _grappling  := false
var _grapple_pt := Vector3.ZERO
var _gliding    := false

@onready var _player: CharacterBody3D = get_parent()

func _ready() -> void:
	add_to_group("hero_component")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_1"):
		_try_grapple()
	if event.is_action_pressed("ability_2"):
		_toggle_glide()

func _physics_process(delta: float) -> void:
	if _grappling:
		_tick_grapple(delta)
	elif _gliding:
		_tick_glide(delta)

func _try_grapple() -> void:
	if _grappling:
		_grappling = false
		return
	var cam: Camera3D = _player.get_node("SpringArm3D/Camera3D")
	var from := cam.global_position
	var to   := from + (-cam.global_transform.basis.z) * GRAPPLE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player]
	var result := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		_grapple_pt = result["position"]
		_grappling  = true
		_gliding    = false

func _tick_grapple(delta: float) -> void:
	var dir := (_grapple_pt - _player.global_position).normalized()
	_player.velocity = dir * GRAPPLE_SPEED
	if _player.global_position.distance_to(_grapple_pt) < 2.0:
		_grappling = false

func _toggle_glide() -> void:
	if _player.is_on_floor(): return
	_gliding = not _gliding
	if _gliding: _grappling = false

func _tick_glide(delta: float) -> void:
	if _player.is_on_floor():
		_gliding = false
		return
	# Reduce gravity while moving forward
	_player.velocity.y = maxf(_player.velocity.y, -GLIDE_MAX_FALL)

func get_stat_overrides() -> Dictionary:
	return {"walk_speed": 6.0, "sprint_speed": 11.0, "jump_velocity": 10.0}
