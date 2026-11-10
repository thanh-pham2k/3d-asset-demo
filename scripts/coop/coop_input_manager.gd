class_name CoopInputManager
extends Node

## Independent input mapper and controller manager for 2-player local co-op.
## Player 1: Keyboard (WASD, E, F, Space, Shift, Q)
## Player 2: Gamepad (Device 0: Sticks, A, X, B, RB) + Secondary Keyboard (Arrows, K, L, Semicolon, R-Shift)
## Safely handles gamepad connection/disconnection without interruptions or crashes.

signal gamepad_connected(device_id: int)
signal gamepad_disconnected(device_id: int)

static var is_gamepad_connected: bool = false
static var gamepad_device_id: int = 0

func _ready() -> void:
	setup_coop_inputs()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_check_connected_joypads()

func _check_connected_joypads() -> void:
	var connected_joypads := Input.get_connected_joypads()
	is_gamepad_connected = connected_joypads.size() > 0
	if is_gamepad_connected:
		gamepad_device_id = connected_joypads[0]

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		is_gamepad_connected = true
		gamepad_device_id = device
		gamepad_connected.emit(device)
	else:
		if device == gamepad_device_id:
			is_gamepad_connected = false
			gamepad_disconnected.emit(device)

static func setup_coop_inputs() -> void:
	# -------------------------------------------------------------
	# Player 1: Keyboard Inputs
	# -------------------------------------------------------------
	var p1_keys := {
		"p1_left": KEY_A,
		"p1_right": KEY_D,
		"p1_up": KEY_W,
		"p1_down": KEY_S,
		"p1_interact": KEY_E,
		"p1_throw": KEY_F,
		"p1_dash": KEY_SPACE,
		"p1_swing": KEY_Q
	}
	for action in p1_keys:
		_ensure_key_action(action, p1_keys[action])
	
	_ensure_key_action("p1_run", KEY_SHIFT, KEY_LOCATION_LEFT)
	_ensure_action_alias("p1_confirm", "p1_interact")
	_ensure_action_alias("p1_cancel", "p1_throw")

	# -------------------------------------------------------------
	# Player 2: Secondary Keyboard Fallback (Arrows + K/L)
	# -------------------------------------------------------------
	var p2_keys := {
		"p2_left": KEY_LEFT,
		"p2_right": KEY_RIGHT,
		"p2_up": KEY_UP,
		"p2_down": KEY_DOWN,
		"p2_interact": KEY_K,
		"p2_throw": KEY_L,
		"p2_dash": KEY_SEMICOLON,
		"p2_swing": KEY_J
	}
	for action in p2_keys:
		_ensure_key_action(action, p2_keys[action])
	
	# Also allow Enter for P2 interact & Right Shift for P2 run
	_add_key_to_action("p2_interact", KEY_ENTER)
	_ensure_key_action("p2_run", KEY_SHIFT, KEY_LOCATION_RIGHT)
	_ensure_action_alias("p2_confirm", "p2_interact")
	_ensure_action_alias("p2_cancel", "p2_throw")

	# -------------------------------------------------------------
	# Player 2: Gamepad (Device 0) Inputs
	# -------------------------------------------------------------
	# Buttons
	_add_joy_button("p2_interact", JOY_BUTTON_A)
	_add_joy_button("p2_confirm", JOY_BUTTON_A)
	_add_joy_button("p2_throw", JOY_BUTTON_X)
	_add_joy_button("p2_cancel", JOY_BUTTON_B)
	_add_joy_button("p2_dash", JOY_BUTTON_B)
	_add_joy_button("p2_swing", JOY_BUTTON_Y)
	_add_joy_button("p2_run", JOY_BUTTON_RIGHT_SHOULDER)
	
	# D-Pad
	_add_joy_button("p2_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("p2_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("p2_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("p2_down", JOY_BUTTON_DPAD_DOWN)
	
	# Left Stick Motion
	_add_joy_axis("p2_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("p2_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("p2_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("p2_down", JOY_AXIS_LEFT_Y, 1.0)

static func get_player_button_hint(player_id: int, action_type: String) -> String:
	if player_id == 1:
		match action_type:
			"interact": return "E"
			"throw": return "F"
			"dash": return "Space"
			"run": return "Shift"
			_: return "E"
	else:
		if is_gamepad_connected:
			match action_type:
				"interact": return "Nút A"
				"throw": return "Nút X"
				"dash": return "Nút B"
				"run": return "RB"
				_: return "Nút A"
		else:
			match action_type:
				"interact": return "K / Enter"
				"throw": return "L"
				"dash": return "Phím ;"
				"run": return "R-Shift"
				_: return "K"

static func _ensure_key_action(action: String, keycode: int, location: int = KEY_LOCATION_UNSPECIFIED) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	
	var ev := InputEventKey.new()
	if location != KEY_LOCATION_UNSPECIFIED:
		ev.keycode = keycode
		ev.location = location
	else:
		ev.physical_keycode = keycode
		ev.keycode = keycode
		
	# Check if already added
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.keycode == keycode:
			return
	InputMap.action_add_event(action, ev)

static func _add_key_to_action(action: String, keycode: int) -> void:
	_ensure_key_action(action, keycode)

static func _add_joy_button(action: String, button: JoyButton, device: int = 0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == button and existing.device == device:
			return
	InputMap.action_add_event(action, ev)

static func _add_joy_axis(action: String, axis: JoyAxis, direction: float, device: int = 0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = direction
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion and existing.axis == axis and signf(existing.axis_value) == signf(direction):
			return
	InputMap.action_add_event(action, ev)

static func _ensure_action_alias(alias: String, source_action: String) -> void:
	if not InputMap.has_action(alias):
		InputMap.add_action(alias)
	for ev in InputMap.action_get_events(source_action):
		if not InputMap.action_has_event(alias, ev):
			InputMap.action_add_event(alias, ev)
