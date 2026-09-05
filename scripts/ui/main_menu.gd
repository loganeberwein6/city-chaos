extends Control

var _discovered: Array[Dictionary] = []
var _pending_hero := "normal_person"
var _pending_host_data := {}
var _waiting_screen: Control = null
var _host_lobby_screen: Control = null
var _host_players_list: Label = null

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
	_build_waiting_screen()
	_build_host_lobby_screen()

	NetworkManager.server_found.connect(_on_server_found)
	NetworkManager.connected_to_host.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.game_starting.connect(_on_game_starting)
	NetworkManager.player_joined.connect(_refresh_host_players)
	NetworkManager.player_left.connect(_refresh_host_players)

	_show("Main")

func _load_name() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	var saved: String = cfg.get_value("player", "name", "")
	if saved != "":
		($LobbyScreen/VBox/NameInput as LineEdit).text = saved

func _save_name(pname: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", pname)
	cfg.save(_SAVE_PATH)

# ── Panel switching ─────────────────────────────────────────────────────────

func _show(screen: String) -> void:
	$MainScreen.visible    = (screen == "Main")
	$JoinScreen.visible    = (screen == "Join")
	$LobbyScreen.visible   = (screen == "Lobby")
	$OptionsScreen.visible = (screen == "Options")
	if _waiting_screen:
		_waiting_screen.visible    = (screen == "Waiting")
	if _host_lobby_screen:
		_host_lobby_screen.visible = (screen == "HostLobby")

func _build_waiting_screen() -> void:
	_waiting_screen = Control.new()
	_waiting_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_waiting_screen.hide()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 180)
	_waiting_screen.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "Connected!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	var lbl := Label.new()
	lbl.text = "Waiting for host to start the game..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)
	add_child(_waiting_screen)

func _build_host_lobby_screen() -> void:
	_host_lobby_screen = Control.new()
	_host_lobby_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host_lobby_screen.hide()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 300)
	_host_lobby_screen.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "HOST LOBBY — Waiting for players"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "(Players discover your server automatically via LAN)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)
	_host_players_list = Label.new()
	_host_players_list.text = "Players: 0"
	_host_players_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_host_players_list)
	var launch_btn := Button.new()
	launch_btn.text = "Launch Game"
	launch_btn.pressed.connect(_on_launch_pressed)
	vbox.add_child(launch_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func():
		NetworkManager.disconnect_from_session()
		_show("Main")
	)
	vbox.add_child(cancel_btn)
	add_child(_host_lobby_screen)

func _refresh_host_players(_a = null, _b = null) -> void:
	if not _host_players_list:
		return
	var lines := ""
	for pid in NetworkManager.connected_players:
		var data: Dictionary = NetworkManager.connected_players[pid]
		lines += "  %s\n" % data.get("name", "P%d" % pid)
	_host_players_list.text = "Players (%d):\n%s" % [NetworkManager.connected_players.size(), lines]

# ── Button handlers (connected via scene [connection] entries) ──────────────

func _on_host_pressed() -> void:
	_show("Lobby")

func _on_join_pressed() -> void:
	_show("Join")
	($JoinScreen/VBox/ServerList as ItemList).clear()
	_discovered.clear()
	NetworkManager.start_discovery()

func _on_options_pressed() -> void:
	_show("Options")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_connect_pressed() -> void:
	var list := $JoinScreen/VBox/ServerList as ItemList
	var sel  := list.get_selected_items()
	var ip   := ""
	var port := 7777
	if sel.size() > 0:
		var info: Dictionary = _discovered[sel[0]]
		ip   = info["ip"]
		port = info.get("port", 7777)
	else:
		ip   = ($JoinScreen/VBox/HBox/IPInput as LineEdit).text.strip_edges()
		port = ($JoinScreen/VBox/HBox/PortInput as LineEdit).text.to_int()
		if port <= 0: port = 7777
	if ip == "": return
	_pending_host_data = {"ip": ip, "port": port}
	_show_character_select(false)

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
				_refresh_host_players()
				_show("HostLobby")
			else:
				printerr("Failed to host")
		else:
			NetworkManager.join(_pending_host_data["ip"], _pending_host_data.get("port", 7777))
	)

# ── Network callbacks ───────────────────────────────────────────────────────

func _on_server_found(info: Dictionary) -> void:
	_discovered.append(info)
	var list := $JoinScreen/VBox/ServerList as ItemList
	list.add_item("[%s] %d players — %s" % [info.get("name","?"), info.get("players",0), info.get("ip","?")])

func _on_connected() -> void:
	var pname := ($LobbyScreen/VBox/NameInput as LineEdit).text.strip_edges()
	if pname == "": pname = "Player"
	_save_name(pname)
	NetworkManager.register_self(pname, _pending_hero)
	_show("Waiting")

func _on_launch_pressed() -> void:
	NetworkManager.start_game_for_all()

func _on_game_starting() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_connection_failed() -> void:
	printerr("Connection failed")
	_show("Main")
