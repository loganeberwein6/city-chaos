extends Node
class_name FlashHero

const BASE_SPEED       := 40.0
const SPRINT_SPEED     := 80.0
const SPRINT_DURATION  := 2.0
const SPRINT_COOLDOWN  := 5.0

var _sprinting  := false
var _sprint_t   := 0.0
var _cooldown   := 0.0

@onready var _player: CharacterBody3D = get_parent()

func _ready() -> void:
	add_to_group("hero_component")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_1") and _cooldown <= 0.0:
		_sprinting = true
		_sprint_t  = SPRINT_DURATION

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _sprinting:
		_sprint_t -= delta
		if _sprint_t <= 0.0:
			_sprinting = false
			_cooldown  = SPRINT_COOLDOWN

func get_stat_overrides() -> Dictionary:
	var spd := SPRINT_SPEED if _sprinting else BASE_SPEED
	return {"walk_speed": BASE_SPEED, "sprint_speed": spd, "jump_velocity": 14.0}
