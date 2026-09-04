extends Node

var time_of_day: float = 12.0  # 0-24 hours

func _ready() -> void:
	time_of_day = GameManager.rules.get("time_of_day", 12.0)
	_apply_time(time_of_day)

func _apply_time(hour: float) -> void:
	var sun: DirectionalLight3D = get_parent().get_node_or_null("Sun")
	var we: WorldEnvironment    = get_parent().get_node_or_null("WorldEnvironment")
	if not sun or not we:
		return

	var t: float = hour / 24.0
	var angle_deg: float = t * 360.0 - 180.0
	sun.rotation_degrees = Vector3(angle_deg, 30.0, 0.0)

	var brightness: float = clampf(sin(t * PI * 2.0 - PI * 0.5) * 0.7 + 0.7, 0.0, 1.4)
	sun.light_energy = brightness

	# Sky colours depend on time of day
	var sky_top: Color
	var sky_horizon: Color
	var sun_color: Color
	if hour < 5.0 or hour > 22.0:  # night
		sky_top     = Color(0.02, 0.02, 0.08)
		sky_horizon = Color(0.04, 0.04, 0.12)
		sun_color   = Color(0.3,  0.3,  0.5)
	elif hour < 7.0 or hour > 20.0:  # dawn / dusk
		var d: float
		if hour < 12.0:
			d = 1.0 - absf(hour - 6.0) / 2.0
		else:
			d = 1.0 - absf(hour - 21.0) / 2.0
		sky_top     = Color(0.08, 0.10, 0.28).lerp(Color(0.18, 0.45, 0.78), d)
		sky_horizon = Color(0.9,  0.4,  0.1 ).lerp(Color(0.65, 0.75, 0.85), d)
		sun_color   = Color(1.0,  0.6,  0.3 ).lerp(Color(1.0,  0.95, 0.85), d)
	else:  # day
		sky_top     = Color(0.18, 0.45, 0.78)
		sky_horizon = Color(0.65, 0.75, 0.85)
		sun_color   = Color(1.0,  0.95, 0.85)

	sun.light_color = sun_color

	var env: Environment = we.environment
	if env and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
		sky_mat.sky_top_color     = sky_top
		sky_mat.sky_horizon_color = sky_horizon
	if env:
		env.ambient_light_energy = clampf(brightness * 0.45, 0.03, 0.6)
