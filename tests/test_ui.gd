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
	_check(first is Button and (first as Button).text == "Campanha", "menu focuses Campanha")
	await _press(KEY_S)
	var second := root.gui_get_focus_owner()
	_check(second is Button and (second as Button).text.begins_with("Modo Arcade"), "S moves focus down")
	await _press(KEY_W)
	_check((root.gui_get_focus_owner() as Button).text == "Campanha", "W moves focus up")
	await _press(KEY_ENTER)
	await process_frame
	var card := root.gui_get_focus_owner()
	_check(card != null, "level select focuses a card")
	await _press(KEY_S)
	var below := root.gui_get_focus_owner()
	_check(below != card, "S moves down the sector grid")
	# Step sideways and back; which way first depends on the card's column.
	var on_left := (below as Control).find_valid_focus_neighbor(SIDE_RIGHT) != null
	await _press(KEY_D if on_left else KEY_A)
	_check(root.gui_get_focus_owner() != below, "A/D moves across the sector grid")
	await _press(KEY_A if on_left else KEY_D)
	_check(root.gui_get_focus_owner() == below, "stepping back returns to the same card")
	await _press(KEY_ESCAPE)
	await process_frame
	_check((root.gui_get_focus_owner() as Button).text == "Campanha", "Esc returns to menu")
	# The briefing must keep the same size for unlocked and locked sectors.
	await _press(KEY_ESCAPE)
	await _press(KEY_ENTER)
	await process_frame
	var panel := _find_briefing(root)
	var size_a := panel.size if panel else Vector2.ZERO
	await _press(KEY_D)
	await _press(KEY_S)
	await _press(KEY_S)
	await process_frame
	_check(panel != null and panel.size == size_a, "sector briefing keeps a fixed size (%s)" % size_a)
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


func _find_briefing(node: Node) -> Control:
	for child in node.find_children("*", "PanelContainer", true, false):
		if (child as Control).size.x >= 500.0:
			return child
	return null
