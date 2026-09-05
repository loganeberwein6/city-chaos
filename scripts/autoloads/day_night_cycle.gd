extends Node

# One in-game day lasts DAY_DURATION real seconds (default: 10 minutes).
const DAY_DURATION := 600.0

var time_of_day := 10.0  # 0–24; starts at 10 AM

var _sun: DirectionalLight3D = null

func _ready() -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "DayNightSun"
	_sun.shadow_enabled = false
	call_deferred("_add_sun")

func _add_sun() -> void:
	get_tree().root.add_child(_sun)

func _process(delta: float) -> void:
	if not is_instance_valid(_sun):
		return
	time_of_day = fmod(time_of_day + (24.0 / DAY_DURATION) * delta, 24.0)
	_update_sun()

func _update_sun() -> void:
	# Elevation: 1.0 at noon (time=12), 0 at sunrise/sunset (time=6,18), negative at night
	var elevation := sin((time_of_day - 6.0) / 12.0 * PI)
	var azimuth   := (time_of_day / 24.0) * 360.0 - 90.0
	_sun.rotation_degrees = Vector3(-clampf(elevation * 75.0, -85.0, 85.0), azimuth, 0.0)

	var t := clampf(elevation, 0.0, 1.0)  # 0 = horizon, 1 = noon
	_sun.light_energy = lerpf(0.02, 1.3, t)
	_sun.light_color = Color(
		lerpf(0.90, 1.00, t),
		lerpf(0.55, 0.98, t),
		lerpf(0.35, 0.90, t)
	)

	# Ambient sky colour
	var night := Color(0.02, 0.02, 0.06)
	var dawn  := Color(0.55, 0.28, 0.12)
	var day   := Color(0.22, 0.48, 0.82)
	var sky: Color
	if elevation < 0.0:
		sky = night.lerp(dawn, clampf(1.0 + elevation * 6.0, 0.0, 1.0))
	else:
		sky = dawn.lerp(day, clampf(elevation * 2.0, 0.0, 1.0))
	RenderingServer.set_default_clear_color(sky)
