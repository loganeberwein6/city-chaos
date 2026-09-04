extends CanvasLayer

# Tilde key (~) toggles this overlay. Only opped players see it.

const CHEAT_ITEMS := [
	{"label": "Heal to Full",       "fn": "cheat_heal"},
	{"label": "Give $10,000",       "fn": "cheat_cash"},
	{"label": "Full Ammo",          "fn": "cheat_ammo"},
	{"label": "Give All Weapons",   "fn": "cheat_weapons"},
	{"label": "Clear Wanted",       "fn": "cheat_clear_wanted"},
	{"label": "Max Wanted (5★)",    "fn": "cheat_max_wanted"},
	{"label": "God Mode Toggle",    "fn": "cheat_godmode"},
	{"label": "Noclip Toggle",      "fn": "cheat_noclip"},
	{"label": "Spawn Civilian",     "fn": "cheat_spawn_civ"},
	{"label": "Spawn Police",       "fn": "cheat_spawn_cop"},
	{"label": "Kill All NPCs",      "fn": "cheat_kill_npcs"},
]

var _visible := false
var _godmode  := false

@onready var _root: Control = $Root

func _ready() -> void:
	layer = 20
	_root.hide()
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cheat_menu"):
		if GameManager.is_opped(multiplayer.get_unique_id()):
			_toggle()

func _toggle() -> void:
	_visible = not _visible
	_root.visible = _visible
	if _visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_root.add_child(panel)

	var title := Label.new()
	title.text = "Cheat Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	for item in CHEAT_ITEMS:
		var btn := Button.new()
		btn.text = item["label"]
		var fn_name: String = item["fn"]
		btn.pressed.connect(Callable(self, fn_name))
		vbox.add_child(btn)

func cheat_heal() -> void:
	var p := _local_player()
	if p: p.health = p.max_health

func cheat_cash() -> void:
	SaveData.add_cash(10000)
	GameManager.cash_changed.emit(SaveData.cash)

func cheat_ammo() -> void:
	var p := _local_player()
	if not p: return
	for i in p.weapon_slots.size():
		var slot: Dictionary = p.weapon_slots[i]
		if slot["id"] != "":
			slot["reserve"] = 999

func cheat_weapons() -> void:
	var weapons := ["pistol","assault_rifle","sniper","shotgun","rpg","minigun"]
	var p := _local_player()
	if not p: return
	for w in weapons:
		p.pick_up_weapon(w, 30, 120)

func cheat_clear_wanted() -> void:
	WantedSystem.reset_heat()

func cheat_max_wanted() -> void:
	WantedSystem.report_crime("kill_military")
	WantedSystem.report_crime("kill_military")
	WantedSystem.report_crime("kill_military")
	WantedSystem.report_crime("kill_military")
	WantedSystem.report_crime("kill_military")

func cheat_godmode() -> void:
	_godmode = not _godmode
	var p := _local_player()
	if p: p.is_immune = _godmode

func cheat_noclip() -> void:
	var p := _local_player()
	if not p: return
	p.collision_layer = 0 if p.collision_layer != 0 else 1

func cheat_spawn_civ() -> void:
	var p := _local_player()
	if not p: return
	var s := preload("res://scenes/npc/civilian.tscn").instantiate()
	s.global_position = p.global_position + Vector3(2, 0, 2)
	get_tree().root.add_child(s)

func cheat_spawn_cop() -> void:
	var p := _local_player()
	if not p: return
	var s := preload("res://scenes/npc/police_officer.tscn").instantiate()
	s.global_position = p.global_position + Vector3(3, 0, 0)
	get_tree().root.add_child(s)

func cheat_kill_npcs() -> void:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.has_method("take_damage"):
			npc.take_damage(9999.0, multiplayer.get_unique_id())

func _local_player() -> Node:
	return GameManager.get_player_node(multiplayer.get_unique_id())
