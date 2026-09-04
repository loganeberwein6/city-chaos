extends Node
class_name IronManHero

const FLY_ACCEL   := 30.0
const FLY_MAX     := 35.0
const REPULSOR_DMG := 80.0
const REPULSOR_CD  := 0.8
const HOVER_GRAVITY := 3.0

var _flying    := false
var _repulsor_cd := 0.0

@onready var _player: CharacterBody3D = get_parent()

func _ready() -> void:
	add_to_group("hero_component")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not _player.is_on_floor():
		_flying = not _flying
	if event.is_action_pressed("shoot") and _repulsor_cd <= 0.0:
		_fire_repulsor()

func _physics_process(delta: float) -> void:
	_repulsor_cd = maxf(0.0, _repulsor_cd - delta)
	if _flying: _tick_flight(delta)

func _tick_flight(delta: float) -> void:
	# WASD moves in camera direction, space/ctrl for up/down
	var cam: Camera3D = _player.get_node("SpringArm3D/Camera3D")
	var wish := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):  wish -= cam.global_transform.basis.z
	if Input.is_action_pressed("move_back"):     wish += cam.global_transform.basis.z
	if Input.is_action_pressed("move_left"):     wish -= cam.global_transform.basis.x
	if Input.is_action_pressed("move_right"):    wish += cam.global_transform.basis.x
	if Input.is_action_pressed("jump"):          wish.y += 1.0
	if Input.is_action_pressed("crouch"):        wish.y -= 1.0

	wish = wish.normalized()
	_player.velocity = _player.velocity.move_toward(wish * FLY_MAX, FLY_ACCEL * delta)
	if wish == Vector3.ZERO:
		_player.velocity.y = move_toward(_player.velocity.y, 0.0, HOVER_GRAVITY * delta)

	if _player.is_on_floor():
		_flying = false

func _fire_repulsor() -> void:
	_repulsor_cd = REPULSOR_CD
	var cam: Camera3D = _player.get_node("SpringArm3D/Camera3D")
	var from := cam.global_position
	var to   := from + (-cam.global_transform.basis.z) * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [_player]
	var result := _player.get_world_3d().direct_space_state.intersect_ray(q)
	if result and result["collider"].has_method("take_damage"):
		result["collider"].take_damage(REPULSOR_DMG, multiplayer.get_unique_id())

func get_stat_overrides() -> Dictionary:
	return {"walk_speed": 5.0, "sprint_speed": 9.0, "jump_velocity": 14.0}
