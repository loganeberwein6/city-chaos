extends VehicleBody3D
class_name VehicleBase

signal vehicle_destroyed(vb: VehicleBase)

@export var max_health    := 800.0
@export var engine_power  := 180.0
@export var brake_force   := 40.0
@export var steer_limit   := 0.4
@export var max_speed_kmh := 140.0

var health := max_health
var driver: Node3D = null
var is_on_fire  := false
var _fire_timer := 0.0

@onready var _wheels: Array[VehicleWheel3D] = []

func _ready() -> void:
	add_to_group("vehicles")
	health = max_health
	for child in get_children():
		if child is VehicleWheel3D:
			_wheels.append(child)

func _physics_process(delta: float) -> void:
	if is_on_fire:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = 0.5
			take_damage(15.0, -1)

func take_damage(amount: float, attacker_id: int) -> void:
	health -= amount
	if health <= 0.0 and not is_on_fire:
		_start_fire()
	if health <= -200.0:
		_explode(attacker_id)

func _start_fire() -> void:
	is_on_fire = true
	_fire_timer = 0.5
	# Report stolen/destroyed crime
	WantedSystem.report_crime("destroy_car")

func _explode(killer_id: int) -> void:
	vehicle_destroyed.emit(self)
	# Damage nearby players
	var radius := 8.0
	for id in GameManager._players:
		var p: Node3D = GameManager._players[id]
		if p and is_instance_valid(p):
			var dist := global_position.distance_to(p.global_position)
			if dist < radius:
				var dmg: float = lerp(200.0, 20.0, dist / radius)
				p.take_damage(dmg, killer_id)
	queue_free()

# ── Driver interface ──────────────────────────────────────────────────────────

func enter_vehicle(player: Node3D) -> void:
	if driver != null: return
	driver = player
	WantedSystem.report_crime("steal_car")

func exit_vehicle() -> void:
	driver = null
	engine_force = 0.0
	brake = brake_force

func apply_input(throttle: float, steer: float, braking: bool) -> void:
	if driver == null: return
	var speed_ms := linear_velocity.length()
	var speed_kmh := speed_ms * 3.6
	if speed_kmh < max_speed_kmh:
		engine_force = throttle * engine_power
	else:
		engine_force = 0.0
	steering = move_toward(steering, steer * steer_limit, 0.08)
	brake = brake_force if braking else 0.0
