extends Node

func _ready() -> void:
	_define_actions()

func _define_actions() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("interact", KEY_F)
	_add_key("open_menu", KEY_ESCAPE)
	_add_key("cheat_menu", KEY_QUOTELEFT)
	_add_key("enter_vehicle", KEY_G)
	_add_key("exit_vehicle", KEY_G)
	_add_key("weapon_1", KEY_1)
	_add_key("weapon_2", KEY_2)
	_add_key("weapon_3", KEY_3)
	_add_key("weapon_4", KEY_4)
	_add_key("weapon_5", KEY_5)
	_add_key("weapon_6", KEY_6)
	_add_key("weapon_7", KEY_7)
	_add_key("weapon_8", KEY_8)
	_add_key("weapon_9", KEY_9)
	_add_key("reload", KEY_R)
	_add_key("crouch", KEY_C)
	_add_key("brake", KEY_SPACE)
	_add_key("ability_1", KEY_Q)
	_add_key("ability_2", KEY_E)
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_mouse("shoot", MOUSE_BUTTON_LEFT)
	_add_mouse("aim", MOUSE_BUTTON_RIGHT)
	_add_mouse("next_weapon", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse("prev_weapon", MOUSE_BUTTON_WHEEL_UP)

func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
