extends Node
class_name SpiderManHero

const WEB_RANGE     := 80.0
const WEB_SPEED     := 22.0
const WEB_ZIP_SPEED := 35.0

var _swinging    := false
var _swing_pt    := Vector3.ZERO
var _zip_target  := Vector3.ZERO
var _zipping     := false

@onready var _player: CharacterBody3D = get_parent()

func _ready() -> void:
	add_to_group("hero_component")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_1"):
		_try_web_swing()
	if event.is_action_pressed("ability_2"):
		_try_web_zip()
	if event.is_action_released("ability_1"):
		_swinging = false
	if event.is_action_released("ability_2"):
		_zipping = false

func _physics_process(delta: float) -> void:
	if _zipping:
		_tick_zip(delta)
	elif _swinging:
		_tick_swing(delta)

func _raycast_from_camera() -> Dictionary:
	var cam: Camera3D = _player.get_node("SpringArm3D/Camera3D")
	var from := cam.global_position
	var to   := from + (-cam.global_transform.basis.z) * WEB_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [_player]
	return _player.get_world_3d().direct_space_state.intersect_ray(q)

func _try_web_swing() -> void:
	var result := _raycast_from_camera()
	if result:
		_swing_pt = result["position"]
		_swinging = true
		_zipping  = false

func _try_web_zip() -> void:
	var result := _raycast_from_camera()
	if result:
		_zip_target = result["position"]
		_zipping = true
		_swinging = false

func _tick_swing(delta: float) -> void:
	# Pendulum approximation: pull toward anchor, preserve momentum
	var to_anchor := _swing_pt - _player.global_position
	var len := to_anchor.length()
	if len < 2.0: return
	var pull := to_anchor.normalized() * (len - 8.0) * 5.0
	pull.y = absf(pull.y) * 0.5  # reduce downward pull during swing
	_player.velocity += pull * delta

func _tick_zip(delta: float) -> void:
	var dir := (_zip_target - _player.global_position)
	if dir.length() < 1.5:
		_zipping = false
		return
	_player.velocity = dir.normalized() * WEB_ZIP_SPEED

func get_stat_overrides() -> Dictionary:
	return {"walk_speed": 6.0, "sprint_speed": 12.0, "jump_velocity": 14.0}
