extends SceneTree
## UI smoke test: boots the real main scene and drives menus with WASD.
## godot --headless -s tests/test_ui.gd

var _fail := 0


func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var first := root.gui_get_focus_owner()
	_check(first is Button and (first as Button).text == "Jogar", "menu focuses Jogar")
	await _press(KEY_S)
	var second := root.gui_get_focus_owner()
	_check(second is Button and (second as Button).text == "Configurações", "S moves focus down")
	await _press(KEY_W)
	_check((root.gui_get_focus_owner() as Button).text == "Jogar", "W moves focus up")
	await _press(KEY_ENTER)
	await process_frame
	var card := root.gui_get_focus_owner()
	_check(card != null, "level select focuses a card")
	await _press(KEY_S)
	var below := root.gui_get_focus_owner()
	_check(below != card, "S moves down the sector grid")
	await _press(KEY_A)
	await _press(KEY_D)
	_check(root.gui_get_focus_owner() == below, "A then D returns to the same card")
	await _press(KEY_ESCAPE)
	await process_frame
	_check((root.gui_get_focus_owner() as Button).text == "Jogar", "Esc returns to menu")
	print("ui checks done, failures: %d" % _fail)
	quit(1 if _fail > 0 else 0)


func _press(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fail += 1
		printerr("FAIL: " + what)
	else:
		print("ok: " + what)
