extends Area3D
class_name WeaponShop

# Add this node to your game scene (game.tscn). Give it a CollisionShape3D child
# (e.g. SphereShape3D radius 3). Players press [E] inside to open the shop.

const ITEMS: Array = [
	{"id": "pistol",        "label": "Pistol",        "ammo": 12,  "reserve": 36,  "price": 200},
	{"id": "smg",           "label": "SMG",           "ammo": 30,  "reserve": 90,  "price": 500},
	{"id": "assault_rifle", "label": "Assault Rifle", "ammo": 30,  "reserve": 90,  "price": 800},
	{"id": "shotgun",       "label": "Shotgun",       "ammo": 8,   "reserve": 24,  "price": 600},
	{"id": "sniper",        "label": "Sniper",        "ammo": 5,   "reserve": 15,  "price": 1200},
	{"id": "rpg",           "label": "RPG",           "ammo": 1,   "reserve": 3,   "price": 2500},
	{"id": "minigun",       "label": "Minigun",       "ammo": 200, "reserve": 400, "price": 5000},
	{"id": "full_armor",    "label": "Full Armor",    "ammo": 0,   "reserve": 0,   "price": 400},
]

var _nearby_player: Node = null
var _canvas: CanvasLayer = null
var _showing := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_marker()

func _build_marker() -> void:
	var lbl := Label3D.new()
	lbl.text = "WEAPON SHOP\n[E] to open"
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.006
	lbl.position = Vector3(0, 2.8, 0)
	lbl.modulate = Color(1.0, 0.85, 0.1)
	add_child(lbl)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") and body.get("_is_local"):
		_nearby_player = body

func _on_body_exited(body: Node3D) -> void:
	if body == _nearby_player:
		_nearby_player = null
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _nearby_player:
		return
	if _showing: _close() else: _open()

func _open() -> void:
	_showing = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_canvas = CanvasLayer.new()
	_canvas.layer = 15
	add_child(_canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340, 0)
	_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "WEAPON SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var cash_lbl := Label.new()
	cash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cash_lbl.text = "Cash: $%d" % SaveData.cash
	vbox.add_child(cash_lbl)

	for item in ITEMS:
		var btn := Button.new()
		btn.text = "%-15s  $%d" % [item["label"], item["price"]]
		var ic: Dictionary = item.duplicate()
		btn.pressed.connect(func(): _buy(ic, cash_lbl))
		vbox.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "Close  [E]"
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)

func _buy(item: Dictionary, cash_lbl: Label) -> void:
	if not _nearby_player:
		return
	var price: int = item["price"]
	if SaveData.cash < price:
		return
	SaveData.add_cash(-price)
	GameManager.cash_changed.emit(SaveData.cash)
	cash_lbl.text = "Cash: $%d" % SaveData.cash
	if item["id"] == "full_armor":
		_nearby_player.call("give_armor", _nearby_player.max_armor)
	else:
		_nearby_player.call("pick_up_weapon", item["id"], item["ammo"], item["reserve"])

func _close() -> void:
	_showing = false
	if _canvas:
		_canvas.queue_free()
		_canvas = null
	if _nearby_player and _nearby_player.get("_is_local"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
