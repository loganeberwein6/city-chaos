extends Node

signal stars_changed(stars: int)
signal heat_changed(heat: float)

const STAR_THRESHOLDS: Array[float] = [0.0, 100.0, 500.0, 2000.0, 5000.0, 9000.0]
const DECAY_RATE_NORMAL := 8.0
const DECAY_RATE_BUILDING := 20.0
const STAR_DISPLAY_LAG := 3.0
const NEWS_MULTIPLIER := 1.5

const CRIME_VALUES: Dictionary = {
	"punch_civilian":    5.0,
	"ko_civilian":       15.0,
	"kill_civilian":     60.0,
	"steal_car":         20.0,
	"destroy_car":       35.0,
	"shoot_civilian":    40.0,
	"kill_cop":          180.0,
	"destroy_cop_car":   90.0,
	"kill_military":     250.0,
	"destroy_military":  120.0,
	"rob_rich":          60.0,
	"destroy_news":      50.0,
}

const KILL_CASH: Dictionary = {
	"civilian":  20,
	"gangster":  75,
	"cop":       150,
	"military":  250,
	"rich":      500,
}

var heat: float = 0.0
var _display_stars: int = 0
var _star_lag_timer: float = 0.0
var in_building: bool = false
var police_in_sight: bool = false
var news_watching: bool = false

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_tick_decay(delta)
	_tick_star_display(delta)

func _tick_decay(delta: float) -> void:
	if police_in_sight:
		return
	var rate := DECAY_RATE_BUILDING if in_building else DECAY_RATE_NORMAL
	var speed_mult: float = GameManager.rules.get("star_speed", 1.0)
	heat = maxf(0.0, heat - rate * speed_mult * delta)

func _tick_star_display(delta: float) -> void:
	_star_lag_timer += delta
	if _star_lag_timer < STAR_DISPLAY_LAG:
		return
	_star_lag_timer = 0.0
	var real_stars := _calc_stars()
	if real_stars != _display_stars:
		_display_stars = real_stars
		stars_changed.emit(_display_stars)
		rpc("_client_update_stars", _display_stars)

func _calc_stars() -> int:
	for i in range(STAR_THRESHOLDS.size() - 1, -1, -1):
		if heat >= STAR_THRESHOLDS[i]:
			return i
	return 0

func get_stars() -> int:
	return _display_stars

# Called by any peer to report a crime; server owns the heat value
func report_crime(crime_type: String) -> void:
	if multiplayer.is_server():
		_apply_crime(crime_type)
	else:
		_server_report_crime.rpc_id(1, crime_type)

@rpc("any_peer", "reliable", "call_local")
func _server_report_crime(crime_type: String) -> void:
	if not multiplayer.is_server():
		return
	_apply_crime(crime_type)

func _apply_crime(crime_type: String) -> void:
	var value: float = CRIME_VALUES.get(crime_type, 0.0)
	if news_watching:
		value *= NEWS_MULTIPLIER
	var speed_mult: float = GameManager.rules.get("star_speed", 1.0)
	heat = minf(10000.0, heat + value * speed_mult)
	heat_changed.emit(heat)

func reset_heat() -> void:
	heat = 0.0
	_display_stars = 0
	_star_lag_timer = 0.0
	stars_changed.emit(0)
	if multiplayer.is_server():
		rpc("_client_update_stars", 0)

@rpc("authority", "reliable", "call_local")
func _client_update_stars(stars: int) -> void:
	_display_stars = stars
	stars_changed.emit(stars)

func set_news_multiplier(active: bool) -> void:
	news_watching = active

func cash_for_kill(npc_type: String) -> int:
	return KILL_CASH.get(npc_type, 10)
