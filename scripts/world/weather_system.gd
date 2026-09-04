extends Node

enum WeatherType { CLEAR, RAIN, FOG, STORM }

var _current_weather := WeatherType.CLEAR
var _env: Environment

func _ready() -> void:
	var we: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment")
	if we:
		_env = we.environment
	_apply_weather(GameManager.rules.get("weather", "clear"))

func _apply_weather(weather_name: String) -> void:
	if not _env:
		return
	match weather_name:
		"clear":
			_env.fog_enabled = true
			_env.fog_density = 0.002
			_env.fog_light_color = Color(0.6, 0.65, 0.7)
		"rain":
			_env.fog_enabled = true
			_env.fog_density = 0.008
			_env.fog_light_color = Color(0.5, 0.55, 0.6)
			_env.ambient_light_color = Color(0.35, 0.38, 0.45)
			_env.ambient_light_energy = 0.4
		"fog":
			_env.fog_enabled = true
			_env.fog_density = 0.025
			_env.fog_light_color = Color(0.7, 0.72, 0.75)
		"storm":
			_env.fog_enabled = true
			_env.fog_density = 0.015
			_env.fog_light_color = Color(0.3, 0.32, 0.38)
			_env.ambient_light_color = Color(0.2, 0.22, 0.28)
			_env.ambient_light_energy = 0.25
