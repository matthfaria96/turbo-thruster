class_name InitialsEntry
extends Control
## Arcade-style three-letter name entry: just type the letters (Backspace
## erases, Enter confirms). ↑/↓ and a gamepad can also cycle letters.

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

const BLANK := -1

var _letters := [BLANK, BLANK, BLANK]
var _slot := 0
var _labels: Array[Label] = []
var _on_done: Callable
var _done := false
var _t := 0.0


static func create(score: int, time_text: String, on_done: Callable) -> InitialsEntry:
	var e := InitialsEntry.new()
	e._on_done = on_done
	e._build(score, time_text)
	return e


func _build(score: int, time_text: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiStyle.theme()
	UiStyle.full_rect(self)
	add_child(UiStyle.dim_layer(0.6))
	var center := CenterContainer.new()
	UiStyle.full_rect(center)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(ArcadeTitle.make("NOVO RECORDE!", 40, UiStyle.GOLD))
	vb.add_child(UiStyle.label("%s pontos · %s" % [Hud.format_int(score), time_text], 24, UiStyle.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true))
	var prompt := "Toque ▲ ▼ para escolher as 3 iniciais" if Mobile.enabled else "Digite suas 3 iniciais"
	vb.add_child(UiStyle.label(prompt, 20, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vb.add_child(row)
	for i in 3:
		var l := Label.new()
		var ls := LabelSettings.new()
		ls.font = UiStyle.display_font()
		ls.font_size = 72
		ls.outline_size = 8
		l.label_settings = ls
		l.custom_minimum_size = Vector2(70, 90)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_labels.append(l)
		if Mobile.enabled:
			row.add_child(_touch_slot(i, l))
		else:
			row.add_child(l)
	if Mobile.enabled:
		var ok := UiStyle.button("Confirmar", _confirm, 300)
		ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(ok)
	add_child(UiStyle.hint_bar("Digite as letras      Backspace  Apagar      Enter  Confirmar"))
	_refresh()


## Touch screens have no keyboard: ▲ / ▼ buttons around each letter.
func _touch_slot(index: int, letter: Label) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	for step in [1, -1]:
		var b := Button.new()
		b.text = "▲" if step > 0 else "▼"
		b.custom_minimum_size = Vector2(80, 56)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			if _done:
				return
			_slot = index
			_cycle(step)
			Sfx.play("ui_move", -8.0))
		vb.add_child(b)
		if step > 0:
			vb.add_child(letter)
	return vb


func _process(delta: float) -> void:
	_t += delta
	_refresh()


func _refresh() -> void:
	for i in 3:
		var l := _labels[i]
		l.text = "_" if _letters[i] == BLANK else ALPHABET[_letters[i]]
		var active := i == _slot and not _done
		l.label_settings.font_color = UiStyle.GOLD if active else UiStyle.TEXT
		l.label_settings.outline_color = Color(UiStyle.GOLD, 0.6 if active and fmod(_t, 0.6) < 0.4 else 0.0)


## Uses _input so typing always reaches this screen first.
func _input(event: InputEvent) -> void:
	# Ignore input briefly so a player still mashing fire can't submit early.
	if _done or _t < 0.5:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if _handle_key(key):
			_accept()
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if _handle_pad(event):
			_accept()


func _handle_key(key: InputEventKey) -> bool:
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_confirm()
			return true
		KEY_BACKSPACE:
			if _letters[_slot] == BLANK and _slot > 0:
				_slot -= 1
			_letters[_slot] = BLANK
		KEY_LEFT:
			_slot = maxi(0, _slot - 1)
		KEY_RIGHT:
			_slot = mini(2, _slot + 1)
		KEY_UP:
			_cycle(1)
		KEY_DOWN:
			_cycle(-1)
		_:
			var ch := char(key.unicode).to_upper() if key.unicode > 0 else ""
			var idx := ALPHABET.find(ch) if ch.length() == 1 else -1
			if idx < 0:
				return false
			_letters[_slot] = idx
			_slot = mini(2, _slot + 1)
	Sfx.play("ui_move", -8.0)
	return true


func _handle_pad(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		_cycle(1)
	elif event.is_action_pressed("ui_down"):
		_cycle(-1)
	elif event.is_action_pressed("ui_left"):
		_slot = maxi(0, _slot - 1)
	elif event.is_action_pressed("ui_right"):
		_slot = mini(2, _slot + 1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
		return true
	else:
		return false
	Sfx.play("ui_move", -8.0)
	return true


func _cycle(step: int) -> void:
	var current: int = _letters[_slot]
	_letters[_slot] = posmod((0 if current == BLANK and step > 0 else current) + (0 if current == BLANK else step), ALPHABET.length())


## Empty slots become "-" so a run can be saved with fewer letters.
func _confirm() -> void:
	if _done:
		return
	_done = true
	var name := ""
	for i in 3:
		name += "-" if _letters[i] == BLANK else ALPHABET[_letters[i]]
	Sfx.play("ui_confirm", -2.0)
	_on_done.call(name)


func _accept() -> void:
	get_viewport().set_input_as_handled()
