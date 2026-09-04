extends Control

signal hero_chosen(hero_id: String)

const HERO_INFO := {
	"normal_person": {"name": "Normal Person", "rep": 0,  "desc": "Balanced. Starts with no abilities."},
	"batman":        {"name": "Batman",         "rep": 10, "desc": "Grapple hook + glide. Q=Grapple, E=Glide."},
	"flash":         {"name": "The Flash",      "rep": 25, "desc": "Super speed burst. Q=Speed Dash."},
	"spider_man":    {"name": "Spider-Man",     "rep": 40, "desc": "Web swing + zip. Q=Swing, E=Zip."},
	"iron_man":      {"name": "Iron Man",       "rep": 60, "desc": "Flight + repulsor. Jump twice=Fly, LMB=Repulsor."},
	"hulk":          {"name": "Hulk",           "rep": 80, "desc": "Grab+throw NPCs, ground slam. Q=Grab/Throw, E=Slam."},
}

var _selected := "normal_person"

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var title := Label.new()
	title.text = "Choose Your Hero"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	var unlocked := SaveData.get_unlocked_heroes()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	for hero_id in HERO_INFO:
		var info: Dictionary = HERO_INFO[hero_id]
		var is_unlocked: bool = hero_id in unlocked

		var btn := Button.new()
		var rep_need: int = info["rep"]
		btn.text = "%s\nRep %d" % [info["name"], rep_need]
		btn.custom_minimum_size = Vector2(180, 80)
		btn.disabled = not is_unlocked

		if not is_unlocked:
			btn.tooltip_text = "Unlock at %d rep (you have %d)" % [rep_need, SaveData.total_rep]
		else:
			btn.tooltip_text = info["desc"]

		var hid := hero_id
		btn.pressed.connect(func(): _select(hid))
		grid.add_child(btn)

	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = HERO_INFO[_selected]["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	var confirm := Button.new()
	confirm.text = "Play"
	confirm.custom_minimum_size = Vector2(200, 50)
	confirm.pressed.connect(_confirm)
	vbox.add_child(confirm)

func _select(hero_id: String) -> void:
	_selected = hero_id
	var desc_label := get_node_or_null("VBoxContainer/DescLabel")
	if desc_label:
		desc_label.text = HERO_INFO.get(hero_id, {}).get("desc", "")

func _confirm() -> void:
	hero_chosen.emit(_selected)
	queue_free()
