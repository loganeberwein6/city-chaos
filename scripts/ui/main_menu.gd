extends Control

var _discovered: Array[Dictionary] = []
var _pending_hero := "normal_person"
var _pending_player_name := ""
var _pending_host_data := {}
var _server_screen: Control

const _SAVE_PATH := "user://player_config.cfg"

func _ready() -> void:
	var map_opt := $LobbyScreen/VBox/MapSize as OptionButton
	if map_opt:
		map_opt.clear()
		for s in ["Small", "Medium", "Large"]:
			map_opt.add_item(s)
		map_opt.select(1)

	var cheats_opt := $LobbyScreen/VBox/CheatsModeOpt as OptionButton
	if cheats_opt:
		cheats_opt.clear()
		for s in ["Host Only", "Op List", "All Players", "Off"]:
			cheats_opt.add_item(s)
		cheats_opt.select(0)

	_load_name()

	NetworkManager.server_found.connect(_on_server_found)
	NetworkManager.connected_to_host.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.game_starting.connect(_on_game_starting)

	_build_server_screen()
	_show("Main")

func _load_name() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	var saved: String = cfg.get_value("player", "name", "")
	if saved != "":
		($LobbyScreen/VBox/NameInput as LineEdit).text = saved
		($JoinScreen/VBox/NameInput as LineEdit).text = saved

func _save_name(pname: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", pname)
	cfg.save(_SAVE_PATH)

# ── Server screen (matchmaker host UI) ───────────────────────────────────────

func _build_server_screen() -> void:
	_server_screen = Control.new()
	_server_screen.name = "ServerScreen"
	_server_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_server_screen.visible = false
	add_child(_server_screen)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.14, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_server_screen.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(400, 0)
	vbox.position = Vector2(-200, -120)
	vbox.add_theme_constant_override("separation", 18)
	_server_screen.add_child(vbox)

	var title := Label.new()
	title.text = "MATCHMAKER SERVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var status := Label.new()
	status.name = "StatusLabel"
	status.text = "Listening on port 7779"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status)

	var hint := Label.new()
	hint.text = "Port-forward TCP 7779 so laptops can reach this PC."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

	var games := Label.new()
	games.name = "GamesLabel"
	games.text = "Active games: 0"
	games.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(games)

	var stop := Button.new()
	stop.name = "BtnStop"
	stop.text = "Stop Server"
	stop.custom_minimum_size = Vector2(200, 48)
	stop.pressed.connect(_on_stop_server_pressed)
	vbox.add_child(stop)

func _refresh_server_screen() -> void:
	if not _server_screen or not _server_screen.visible:
		return
	var vbox := _server_screen.get_node_or_null("VBox") as VBoxContainer
	if not vbox:
		return
	var gl := vbox.get_node_or_null("GamesLabel") as Label
	if gl:
		gl.text = "Active games: %d" % Matchmaker.entry_count()

# ── Panel switching ─────────────────────────────────────────────────────────

func _show(screen: String) -> void:
	$MainScreen.visible    = (screen == "Main")
	$JoinScreen.visible    = (screen == "Join")
	$LobbyScreen.visible   = (screen == "Lobby")
	$OptionsScreen.visible = (screen == "Options")
	if _server_screen:
		_server_screen.visible = (screen == "Server")

# ── Button handlers ─────────────────────────────────────────────────────────

func _on_host_pressed() -> void:
	_show("Lobby")

func _on_join_pressed() -> void:
	_show("Join")
	($JoinScreen/VBox/ServerList as ItemList).clear()
	_discovered.clear()
	var has_matchmaker := NetworkManager.matchmaker_url != ""
	($JoinScreen/VBox/StatusLabel as Label).text = \
		"Searching LAN and internet..." if has_matchmaker else "Searching for servers on LAN..."
	NetworkManager.start_discovery()
	NetworkManager.query_matchmaker()

func _on_server_pressed() -> void:
	Matchmaker.start()
	if Matchmaker.active:
		_show("Server")

func _on_stop_server_pressed() -> void:
	Matchmaker.stop()
	_show("Main")

func _on_options_pressed() -> void:
	($OptionsScreen/VBox/MatchmakerInput as LineEdit).text = NetworkManager.matchmaker_url
	_show("Options")

func _on_save_options_pressed() -> void:
	NetworkManager.matchmaker_url = ($OptionsScreen/VBox/MatchmakerInput as LineEdit).text.strip_edges()
	NetworkManager.save_network_config()
	_show("Main")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_connect_pressed() -> void:
	var list := $JoinScreen/VBox/ServerList as ItemList
	var sel  := list.get_selected_items()
	if sel.size() == 0:
		return
	_do_join(_discovered[sel[0]])

func _on_server_list_item_activated(index: int) -> void:
	if index < _discovered.size():
		_do_join(_discovered[index])

func _do_join(info: Dictionary) -> void:
	_pending_player_name = ($JoinScreen/VBox/NameInput as LineEdit).text.strip_edges()
	if _pending_player_name == "": _pending_player_name = "Player"
	_save_name(_pending_player_name)
	_pending_host_data = {"ip": info["ip"], "port": info.get("port", 7777)}
	_show_character_select(false)

func _on_manual_connect_pressed() -> void:
	var ip := ($JoinScreen/VBox/ManualHBox/ManualIP as LineEdit).text.strip_edges()
	if ip == "":
		return
	_do_join({"ip": ip, "port": NetworkManager.GAME_PORT})

func _on_join_cancel_pressed() -> void:
	NetworkManager.stop_discovery()
	_show("Main")

func _on_start_pressed() -> void:
	var pname := ($LobbyScreen/VBox/NameInput as LineEdit).text.strip_edges()
	if pname == "": pname = "Player"
	var sizes: Array  = ["small", "medium", "large"]
	var modes: Array  = ["host", "op_list", "all", "off"]
	var map_size: String    = sizes[($LobbyScreen/VBox/MapSize as OptionButton).selected]
	var cheats_mode: String = modes[($LobbyScreen/VBox/CheatsModeOpt as OptionButton).selected]
	var raw_seed    := ($LobbyScreen/VBox/SeedInput as LineEdit).text.strip_edges()
	var world_seed  := raw_seed.hash() if raw_seed != "" else randi()
	GameManager.rules["map_size"]    = map_size
	GameManager.rules["world_seed"]  = world_seed
	GameManager.rules["cheats_mode"] = cheats_mode
	_pending_host_data = {"name": pname}
	_show_character_select(true)

func _on_lobby_cancel_pressed() -> void:
	_show("Main")

func _on_options_back_pressed() -> void:
	_show("Main")

func _process(_delta: float) -> void:
	_refresh_server_screen()

func _show_character_select(is_hosting: bool) -> void:
	var cs := load("res://scenes/character_select.tscn").instantiate() as Control
	add_child(cs)
	cs.hero_chosen.connect(func(hero: String):
		_pending_hero = hero
		if is_hosting:
			var pname: String = _pending_host_data.get("name", "Player")
			if NetworkManager.host(pname):
				_save_name(pname)
				NetworkManager.register_self(pname, hero)
				NetworkManager.start_game_for_all()
				# game_starting signal (call_local via RPC) handles the scene change
			else:
				printerr("Failed to host")
		else:
			NetworkManager.join(_pending_host_data["ip"], _pending_host_data.get("port", 7777))
	)

# ── Network callbacks ────────────────────────────────────────────────────────

func _on_server_found(info: Dictionary) -> void:
	_discovered.append(info)
	var list := $JoinScreen/VBox/ServerList as ItemList
	list.add_item("%s  (%d players)" % [info.get("name", "Server"), info.get("players", 0)])
	($JoinScreen/VBox/StatusLabel as Label).text = "Found %d server(s) — click to join" % _discovered.size()

func _on_connected() -> void:
	NetworkManager.register_self(_pending_player_name, _pending_hero)
	# Server sends game_starting RPC back immediately (via _receive_registration late-join path)

func _on_game_starting() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_connection_failed() -> void:
	printerr("Connection failed")
	_show("Main")
