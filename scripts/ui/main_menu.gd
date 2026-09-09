extends Control

var _discovered: Array[Dictionary] = []
var _pending_hero := "normal_person"
var _pending_player_name := ""
var _pending_host_data := {}

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

# ── Panel switching ─────────────────────────────────────────────────────────

func _show(screen: String) -> void:
	$MainScreen.visible    = (screen == "Main")
	$JoinScreen.visible    = (screen == "Join")
	$LobbyScreen.visible   = (screen == "Lobby")
	$OptionsScreen.visible = (screen == "Options")

# ── Button handlers ─────────────────────────────────────────────────────────

func _on_host_pressed() -> void:
	_show("Lobby")

func _on_join_pressed() -> void:
	_show("Join")
	($JoinScreen/VBox/ServerList as ItemList).clear()
	($JoinScreen/VBox/StatusLabel as Label).text = "Searching for servers on LAN..."
	_discovered.clear()
	NetworkManager.start_discovery()

func _on_options_pressed() -> void:
	_show("Options")

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
