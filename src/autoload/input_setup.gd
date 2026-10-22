class_name InputSetup
extends RefCounted
## Registers the game's input actions (keyboard + gamepad) at startup.

const ACTIONS := {
	"move_left": {"keys": [KEY_A, KEY_LEFT], "buttons": [JOY_BUTTON_DPAD_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"accelerate": {"keys": [KEY_W, KEY_UP], "buttons": [JOY_BUTTON_DPAD_UP], "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	"brake": {"keys": [KEY_S, KEY_DOWN], "buttons": [JOY_BUTTON_DPAD_DOWN], "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	"fire": {"keys": [KEY_Z, KEY_SPACE, KEY_J], "buttons": [JOY_BUTTON_A], "axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
	"charge": {"keys": [KEY_X, KEY_K, KEY_SHIFT], "buttons": [JOY_BUTTON_X], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	"pause": {"keys": [KEY_ESCAPE, KEY_P], "buttons": [JOY_BUTTON_START], "axes": []},
}

## Rows shown on the Controls screen: [action label, keyboard, gamepad].
const HELP := [
	["Mover pelo túnel", "A / D  ou  ← / →", "Analógico / D-pad"],
	["Acelerar", "W  ou  ↑", "Analógico para cima"],
	["Frear", "S  ou  ↓", "Analógico para baixo"],
	["Atirar (segurar)", "Z / Espaço / J", "A / RT"],
	["Tiro carregado (segurar e soltar)", "X / K / Shift", "X / LT"],
	["Pausar", "Esc / P", "Start"],
	["Tela cheia", "F11", "—"],
]


static func register() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		var spec: Dictionary = ACTIONS[action]
		for key: int in spec.keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
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
