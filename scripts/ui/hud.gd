extends CanvasLayer

var _shake_intensity := 0.0
var _shake_timer := 0.0

@onready var health_bar:    ProgressBar = $HUDRoot/TopLeft/HealthBar
@onready var armor_bar:     ProgressBar = $HUDRoot/TopLeft/ArmorBar
@onready var star_row:      HBoxContainer = $HUDRoot/TopCenter/StarRow
@onready var cash_label:    Label = $HUDRoot/TopRight/CashLabel
@onready var weapon_hotbar: HBoxContainer = $HUDRoot/Bottom/WeaponHotbar
@onready var death_overlay: Control = $DeathOverlay
@onready var respawn_timer_label: Label = $DeathOverlay/RespawnLabel
@onready var minimap_rect:  Control = $HUDRoot/TopLeft/MinimapRect

var _star_icons: Array[TextureRect] = []
var _hotbar_slots: Array[PanelContainer] = []
var _respawn_countdown := 0.0
var _is_dead := false

func _ready() -> void:
	add_to_group("hud")
	_build_star_display()
	_build_hotbar()
	death_overlay.hide()
	WantedSystem.stars_changed.connect(_on_stars_changed)
	GameManager.player_died.connect(_on_player_died)
	GameManager.player_respawned.connect(_on_player_respawned)
	GameManager.cash_changed.connect(_on_cash_changed)
	_on_cash_changed(SaveData.cash)

func _process(delta: float) -> void:
	_update_player_bars()
	_apply_camera_shake(delta)
	if _is_dead and _respawn_countdown > 0.0:
		_respawn_countdown -= delta
		respawn_timer_label.text = "Respawning in %.1f..." % maxf(_respawn_countdown, 0.0)
	if minimap_rect:
		minimap_rect.queue_redraw()

func _update_player_bars() -> void:
	var local_id := multiplayer.get_unique_id()
	var player := GameManager.get_player_node(local_id)
	if not player:
		return
	health_bar.value = player.health
	health_bar.max_value = player.max_health
	armor_bar.value = player.armor
	armor_bar.max_value = player.max_armor
	_update_hotbar(player)

# ── Stars ──────────────────────────────────────────────────────────────────────

func _build_star_display() -> void:
	for child in star_row.get_children():
		child.queue_free()
	_star_icons.clear()
	for i in 5:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(28, 28)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_row.add_child(tr)
		_star_icons.append(tr)
	_on_stars_changed(0)

func _on_stars_changed(stars: int) -> void:
	for i in _star_icons.size():
		var icon := _star_icons[i]
		if i < stars:
			icon.modulate = Color(1.0, 0.85, 0.0)   # gold — active
		else:
			icon.modulate = Color(0.3, 0.3, 0.3, 0.5)  # dim — inactive

# ── Hotbar ─────────────────────────────────────────────────────────────────────

func _build_hotbar() -> void:
	for child in weapon_hotbar.get_children():
		child.queue_free()
	_hotbar_slots.clear()
	for i in 9:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(52, 52)
		var vbox := VBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.name = "WeaponName"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		var ammo_lbl := Label.new()
		ammo_lbl.name = "AmmoLabel"
		ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammo_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(name_lbl)
		vbox.add_child(ammo_lbl)
		panel.add_child(vbox)
		weapon_hotbar.add_child(panel)
		_hotbar_slots.append(panel)

func _update_hotbar(player: Node) -> void:
	if not player.has_method("pick_up_weapon"):
		return
	for i in _hotbar_slots.size():
		var slot_data: Dictionary = player.weapon_slots[i] if i < player.weapon_slots.size() else {}
		var panel := _hotbar_slots[i]
		var name_lbl: Label = panel.get_node("VBoxContainer/WeaponName")
		var ammo_lbl: Label = panel.get_node("VBoxContainer/AmmoLabel")
		var is_active := (i == player.active_weapon_slot)

		var sc := panel.get_theme_stylebox("panel")
		if is_active:
			panel.modulate = Color(1.2, 1.2, 0.5)
		else:
			panel.modulate = Color(1, 1, 1)

		var wid: String = slot_data.get("id", "")
		if wid == "":
			name_lbl.text = str(i + 1)
			ammo_lbl.text = ""
		else:
			name_lbl.text = wid.replace("_", " ").left(8)
			var ammo: int = slot_data.get("ammo", 0)
			var res:  int = slot_data.get("reserve", 0)
			ammo_lbl.text = "%d/%d" % [ammo, res]

# ── Cash ───────────────────────────────────────────────────────────────────────

func _on_cash_changed(new_cash: int) -> void:
	cash_label.text = "$%s" % _format_cash(new_cash)

func _format_cash(amount: int) -> String:
	var s := str(amount)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

# ── Death overlay ──────────────────────────────────────────────────────────────

func _on_player_died(victim_id: int, _killer_id: int) -> void:
	var local_id := multiplayer.get_unique_id()
	if victim_id != local_id:
		return
	_is_dead = true
	_respawn_countdown = 5.0
	death_overlay.show()

func _on_player_respawned(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	_is_dead = false
	death_overlay.hide()

# ── Camera shake ───────────────────────────────────────────────────────────────

func camera_shake(intensity: float) -> void:
	_shake_intensity = intensity
	_shake_timer = 0.3

func _apply_camera_shake(delta: float) -> void:
	if _shake_timer <= 0.0: return
	_shake_timer -= delta
	var local_id := multiplayer.get_unique_id()
	var player := GameManager.get_player_node(local_id)
	if player:
		var cam_arm: SpringArm3D = player.get_node("SpringArm3D")
		cam_arm.rotation.z = randf_range(-_shake_intensity, _shake_intensity) * 0.05
		if _shake_timer <= 0.0:
			cam_arm.rotation.z = 0.0

# ── Minimap (radar-style) ──────────────────────────────────────────────────────

func _draw_minimap() -> void:
	if minimap_rect == null: return
	# Draw onto the Control using _draw — we queue_redraw here
	minimap_rect.queue_redraw()

