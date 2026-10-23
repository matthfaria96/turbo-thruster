class_name InputSetup
extends RefCounted
## Registers the game's input actions (keyboard + gamepad) at startup.

const ACTIONS := {
	"move_left": {"keys": [KEY_A, KEY_LEFT], "buttons": [JOY_BUTTON_DPAD_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"fire": {"keys": [KEY_J], "mouse": [MOUSE_BUTTON_LEFT], "buttons": [JOY_BUTTON_A], "axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
	"charge": {"keys": [KEY_SHIFT, KEY_K], "mouse": [MOUSE_BUTTON_RIGHT], "buttons": [JOY_BUTTON_X], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	"special": {"keys": [KEY_SPACE], "buttons": [JOY_BUTTON_Y, JOY_BUTTON_B], "axes": []},
	"nitro": {"keys": [KEY_Q], "buttons": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER], "axes": []},
	"pause": {"keys": [KEY_ESCAPE, KEY_P], "buttons": [JOY_BUTTON_START], "axes": []},
}

## Rows shown on the Controls screen: [action label, keyboard, gamepad].
const HELP := [
	["Ir para os lados", "A / D", "Analógico / D-pad"],
	["Atirar (segurar)", "Botão esquerdo do mouse", "A / RT"],
	["Anel de energia (segure e solte)", "Botão direito do mouse", "X / LT"],
	["Especial: bomba (limpa a tela)", "Espaço", "Y / B"],
	["Nitro (quando a barra encher)", "Q", "LB / RB"],
	["Pausar", "Esc / P", "Start"],
	["Tela cheia", "F11", "—"],
]


## Menus also navigate with WASD (Godot's ui_* actions only have arrows).
const UI_KEYS := {"ui_up": KEY_W, "ui_down": KEY_S, "ui_left": KEY_A, "ui_right": KEY_D}


static func register() -> void:
	for action: String in UI_KEYS:
		var ev := InputEventKey.new()
		ev.physical_keycode = UI_KEYS[action]
		InputMap.action_add_event(action, ev)
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		var spec: Dictionary = ACTIONS[action]
		for key: int in spec.keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for mb: int in spec.get("mouse", []):
			var ev := InputEventMouseButton.new()
			ev.button_index = mb
			InputMap.action_add_event(action, ev)
		for button: int in spec.buttons:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
		for axis: Array in spec.axes:
			var ev := InputEventJoypadMotion.new()
			ev.axis = axis[0]
			ev.axis_value = axis[1]
			InputMap.action_add_event(action, ev)
