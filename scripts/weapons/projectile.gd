extends Node3D
class_name Projectile

@export var speed  := 120.0
@export var damage := 30.0
@export var owner_id := 1
@export var lifetime := 3.0

var velocity := Vector3.ZERO
var _timer   := 0.0

func _ready() -> void:
	_timer = lifetime

func launch(direction: Vector3) -> void:
	velocity = direction.normalized() * speed

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		queue_free()
		return
	global_position += velocity * delta
	_check_hit()

func _check_hit() -> void:
	var query := PhysicsRayQueryParameters3D.create(
		global_position - velocity.normalized() * 0.5,
		global_position
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return
	var col := result["collider"] as CollisionObject3D
	if col.has_method("take_damage"):
		col.take_damage(damage, owner_id)
	queue_free()
