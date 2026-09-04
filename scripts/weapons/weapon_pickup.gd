extends Area3D
class_name WeaponPickup

@export var weapon_id  := "pistol"
@export var ammo_count := 12
@export var reserve    := 24
@export var lifetime   := 30.0

var _alive_timer := 0.0

func _ready() -> void:
	add_to_group("weapon_pickups")
	body_entered.connect(_on_body_entered)
	_alive_timer = lifetime

func _physics_process(delta: float) -> void:
	_alive_timer -= delta
	# Slow bobbing visual
	position.y = sin(Time.get_ticks_msec() * 0.002) * 0.15
	if _alive_timer <= 0.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("players"): return
	# Only local player picks up
	if body.get_multiplayer_authority() != multiplayer.get_unique_id(): return
	body.pickup_weapon(weapon_id, ammo_count, reserve)
	queue_free()
