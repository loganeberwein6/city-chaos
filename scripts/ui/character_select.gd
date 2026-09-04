extends Control

signal hero_chosen(hero_id: String)

const HERO_INFO := {
	"normal_person": {"name": "Normal Person", "rep": 0,  "desc": "Balanced. No special abilities.", "color": Color(0.3, 0.5, 0.8)},
	"batman":        {"name": "Batman",         "rep": 10, "desc": "Grapple hook + glide. Q=Grapple, E=Glide.", "color": Color(0.12, 0.12, 0.2)},
	"flash":         {"name": "The Flash",      "rep": 25, "desc": "Super speed burst. Q=Speed Dash.", "color": Color(0.85, 0.08, 0.08)},
	"spider_man":    {"name": "Spider-Man",     "rep": 40, "desc": "Web swing + zip. Q=Swing, E=Zip.", "color": Color(0.8, 0.05, 0.05)},
	"iron_man":      {"name": "Iron Man",       "rep": 60, "desc": "Flight + repulsor. Jump twice=Fly.", "color": Color(0.9, 0.65, 0.0)},
	"hulk":          {"name": "Hulk",           "rep": 80, "desc": "Grab+throw NPCs, ground slam.", "color": Color(0.15, 0.55, 0.15)},
}

var _selected := "normal_person"

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(620, 0)
	vbox.position = Vector2(-310, -280)
	add_child(vbox)

	var title := Label.new()
	title.text = "Choose Your Hero"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var unlocked: Array = HERO_INFO.keys()

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	for hero_id in HERO_INFO:
		var info: Dictionary = HERO_INFO[hero_id]
		var is_unlocked: bool = hero_id in unlocked

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(185, 95)

		var inner := VBoxContainer.new()
		var col_rect := ColorRect.new()
		col_rect.color = info["color"] if is_unlocked else Color(0.15, 0.15, 0.15)
		col_rect.custom_minimum_size = Vector2(0, 14)
		inner.add_child(col_rect)

		var name_lbl := Label.new()
		name_lbl.text = info["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		inner.add_child(name_lbl)

		var rep_lbl := Label.new()
		rep_lbl.text = "UNLOCKED" if is_unlocked else "Rep %d" % info["rep"]
		rep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rep_lbl.add_theme_font_size_override("font_size", 10)
		inner.add_child(rep_lbl)

		panel.add_child(inner)

		if is_unlocked:
			var hid: String = hero_id
			panel.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					_select(hid)
			)
			panel.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			panel.modulate.a = 0.45
		grid.add_child(panel)

	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = HERO_INFO[_selected]["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(desc_label)

	var confirm := Button.new()
	confirm.text = "Play as %s" % HERO_INFO[_selected]["name"]
	confirm.name = "ConfirmBtn"
	confirm.custom_minimum_size = Vector2(220, 50)
	confirm.pressed.connect(_confirm)
	vbox.add_child(confirm)

func _select(hero_id: String) -> void:
	_selected = hero_id
	var vbox := get_node_or_null("VBoxContainer")
	if not vbox: return
	var desc: Label = vbox.get_node_or_null("DescLabel")
	if desc:
		desc.text = HERO_INFO.get(hero_id, {}).get("desc", "")
	var btn: Button = vbox.get_node_or_null("ConfirmBtn")
	if btn:
		btn.text = "Play as %s" % HERO_INFO.get(hero_id, {}).get("name", hero_id)

func _confirm() -> void:
	hero_chosen.emit(_selected)
	queue_free()
