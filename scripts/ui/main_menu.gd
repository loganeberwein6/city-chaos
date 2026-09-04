extends Control

var _discovered: Array[Dictionary] = []

func _ready() -> void:
	var map_opt := $LobbyPanel/VBox/MapSize as OptionButton
	if map_opt:
		map_opt.clear()
		for s in ["Small", "Medium", "Large"]:
			map_opt.add_item(s)
		map_opt.select(1)

	var cheats_opt := $LobbyPanel/VBox/CheatsModeOpt as OptionButton
	if cheats_opt:
		cheats_opt.clear()
		for s in ["Host Only", "Op List", "All Players", "Off"]:
			cheats_opt.add_item(s)
		cheats_opt.select(0)

	NetworkManager.server_found.connect(_on_server_found)
	NetworkManager.connected_to_host.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)

	_show("Main")

# ── Panel switching ─────────────────────────────────────────────────────────

func _show(panel: String) -> void:
	$MainPanel.visible   = (panel == "Main")
	$JoinPanel.visible   = (panel == "Join")
	$LobbyPanel.visible  = (panel == "Lobby")
	$OptionsPanel.visible = (panel == "Options")

# ── Button handlers (connected via scene [connection] entries) ──────────────

func _on_host_pressed() -> void:
	_show("Lobby")

func _on_join_pressed() -> void:
	_show("Join")
	($JoinPanel/VBox/ServerList as ItemList).clear()
	_discovered.clear()
	NetworkManager.start_discovery()

func _on_options_pressed() -> void:
	_show("Options")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_connect_pressed() -> void:
	var list := $JoinPanel/VBox/ServerList as ItemList
	var sel  := list.get_selected_items()
	if sel.size() > 0:
		var info := _discovered[sel[0]]
		NetworkManager.join(info["ip"], info.get("port", 7777))
		return
	var ip   := ($JoinPanel/VBox/HBox/IPInput as LineEdit).text.strip_edges()
	var port := ($JoinPanel/VBox/HBox/PortInput as LineEdit).text.to_int()
	if ip != "":
		NetworkManager.join(ip, port if port > 0 else 7777)

func _on_join_cancel_pressed() -> void:
	NetworkManager.stop_discovery()
	_show("Main")

func _on_start_pressed() -> void:
	var pname := ($LobbyPanel/VBox/NameInput as LineEdit).text.strip_edges()
	if pname == "": pname = "Player"
	var sizes  := ["small", "medium", "large"]
	var modes  := ["host", "op_list", "all", "off"]
	var map_size: String    = sizes[($LobbyPanel/VBox/MapSize as OptionButton).selected]
	var cheats_mode: String = modes[($LobbyPanel/VBox/CheatsModeOpt as OptionButton).selected]
	var raw_seed    := ($LobbyPanel/VBox/SeedInput as LineEdit).text.strip_edges()
	var world_seed  := raw_seed.hash() if raw_seed != "" else randi()
	GameManager.rules["map_size"]    = map_size
	GameManager.rules["world_seed"]  = world_seed
	GameManager.rules["cheats_mode"] = cheats_mode
	if NetworkManager.host(pname):
		NetworkManager.register_self(pname, "normal_person")
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	else:
		printerr("Failed to host")

func _on_lobby_cancel_pressed() -> void:
	_show("Main")

func _on_options_back_pressed() -> void:
	_show("Main")

# ── Network callbacks ───────────────────────────────────────────────────────

func _on_server_found(info: Dictionary) -> void:
	_discovered.append(info)
	var list := $JoinPanel/VBox/ServerList as ItemList
	list.add_item("[%s] %d players — %s" % [info.get("name","?"), info.get("players",0), info.get("ip","?")])

func _on_connected() -> void:
	var pname := ($LobbyPanel/VBox/NameInput as LineEdit).text.strip_edges()
	if pname == "": pname = "Player"
	NetworkManager.register_self(pname, "normal_person")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_connection_failed() -> void:
	printerr("Connection failed")
