extends Node

var time_of_day: float = 12.0  # 0-24 hours

func _ready() -> void:
	time_of_day = GameManager.rules.get("time_of_day", 12.0)
	_apply_time(time_of_day)

func _apply_time(hour: float) -> void:
	var sun: DirectionalLight3D = get_parent().get_node_or_null("Sun")
	if not sun:
		return
	# Sun angle: 0h = below horizon (-90°), 6h = sunrise (0°), 12h = overhead (60°), 18h = sunset (0°), 24h = below
	var angle_deg: float = (hour / 24.0) * 360.0 - 90.0
	sun.rotation_degrees.x = angle_deg - 90.0
	# Brightness based on time
	var brightness: float = clampf(sin(hour / 24.0 * PI * 2.0 - PI * 0.5) * 0.6 + 0.6, 0.0, 1.2)
	sun.light_energy = brightness
	# Ambient drops at night
	var we: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment")
	if we and we.environment:
		we.environment.ambient_light_energy = clampf(brightness * 0.5, 0.05, 0.6)
