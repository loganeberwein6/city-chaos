extends CanvasLayer

# ESC in-game menu. Host sees an extra "Game Rules" tab.

@onready var menu_root:   Control       = $MenuRoot
@onready var tab_bar:     TabContainer  = $MenuRoot/TabContainer
@onready var btn_resume:  Button        = $MenuRoot/BtnResume
@onready var btn_disc:    Button        = $MenuRoot/BtnDisconnect
@onready var btn_quit:    Button        = $MenuRoot/BtnQuit

# Rules tab nodes (host only)
@onready var rules_tab:       Control        = $MenuRoot/TabContainer/Rules
@onready var npc_density:     HSlider        = $MenuRoot/TabContainer/Rules/NPCDensity
@onready var traffic_density: HSlider        = $MenuRoot/TabContainer/Rules/TrafficDensity
@onready var star_speed:      HSlider        = $MenuRoot/TabContainer/Rules/StarSpeed
@onready var gravity_mult:    HSlider        = $MenuRoot/TabContainer/Rules/GravityMult
@onready var friendly_fire:   CheckBox       = $MenuRoot/TabContainer/Rules/FriendlyFire
@onready var time_slider:     HSlider        = $MenuRoot/TabContainer/Rules/TimeOfDay
@onready var weather_opt:     OptionButton   = $MenuRoot/TabContainer/Rules/Weather

# Player management tab (host only)
@onready var player_list: ItemList = $MenuRoot/TabContainer/Players/PlayerList
@onready var btn_op:      Button   = $MenuRoot/TabContainer/Players/BtnOp
@onready var btn_kick:    Button   = $MenuRoot/TabContainer/Players/BtnKick
@onready var btn_clear:   Button   = $MenuRoot/TabContainer/Players/BtnClearWanted
@onready var btn_tp:      Button   = $MenuRoot/TabContainer/Players/BtnTeleport

var _visible := false

func _ready() -> void:
	menu_root.hide()
	_visible = false

	var is_host := multiplayer.is_server()
	if not is_host:
		tab_bar.set_tab_hidden(tab_bar.get_tab_idx_from_control(rules_tab), true)

	btn_resume.pressed.connect(hide_menu)
	btn_disc.pressed.connect(_on_disconnect)
	btn_quit.pressed.connect(func(): get_tree().quit())

	if is_host:
		btn_op.pressed.connect(_on_op_pressed)
		btn_kick.pressed.connect(_on_kick_pressed)
		btn_clear.pressed.connect(_on_clear_wanted)
		btn_tp.pressed.connect(_on_teleport)
		npc_density.value_changed.connect(func(v): GameManager.set_rule("npc_density", v))
		traffic_density.value_changed.connect(func(v): GameManager.set_rule("traffic_density", v))
		star_speed.value_changed.connect(func(v): GameManager.set_rule("star_speed", v))
		gravity_mult.value_changed.connect(func(v): GameManager.set_rule("gravity_mult", v))
		friendly_fire.toggled.connect(func(v): GameManager.set_rule("friendly_fire", v))
		_populate_weather()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		if _visible:
			hide_menu()
		else:
			show_menu()

func show_menu() -> void:
	_visible = true
	menu_root.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if multiplayer.is_server():
		_refresh_player_list()
	get_tree().paused = false  # Game continues in background

func hide_menu() -> void:
	_visible = false
	menu_root.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _populate_weather() -> void:
	weather_opt.clear()
	weather_opt.add_item("Clear")
	weather_opt.add_item("Rain")
	weather_opt.add_item("Fog")
	weather_opt.add_item("Storm")
	weather_opt.item_selected.connect(func(idx):
		GameManager.set_rule("weather", ["clear","rain","fog","storm"][idx]))

func _refresh_player_list() -> void:
	player_list.clear()
	for pid in NetworkManager.connected_players:
		var data: Dictionary = NetworkManager.connected_players[pid]
		var tag := " [HOST]" if pid == 1 else ""
		var op  := " [OP]" if GameManager.is_opped(pid) else ""
		player_list.add_item("%s%s%s  (id %d)" % [data.get("name","?"), tag, op, pid])
		player_list.set_item_metadata(player_list.item_count - 1, pid)

func _get_selected_peer() -> int:
	var sel := player_list.get_selected_items()
	if sel.is_empty():
		return -1
	return player_list.get_item_metadata(sel[0])

func _on_op_pressed() -> void:
	var pid := _get_selected_peer()
	if pid < 0:
		return
	if GameManager.is_opped(pid):
		GameManager.deop_player(pid)
	else:
		GameManager.op_player(pid)
	_refresh_player_list()

func _on_kick_pressed() -> void:
	var pid := _get_selected_peer()
	if pid < 0 or pid == 1:
		return
	multiplayer.multiplayer_peer.disconnect_peer(pid)

func _on_clear_wanted() -> void:
	WantedSystem.reset_heat()

func _on_teleport() -> void:
	var pid := _get_selected_peer()
	if pid < 0:
		return
	var host_player := GameManager.get_player_node(1)
	if host_player:
		GameManager._rpc_respawn_player.rpc_id(pid, host_player.global_position + Vector3(2, 0, 0))

func _on_disconnect() -> void:
	NetworkManager.disconnect_from_session()
	SaveData.save()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
