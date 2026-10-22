class_name InitialsEntry
extends Control
## Arcade-style three-letter name entry. W/S (or ↑/↓) change the letter,
## A/D (or ←/→) move between slots, Enter confirms.

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var _letters := [0, 0, 0]
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
	vb.add_child(UiStyle.title("NOVO RECORDE!", 44, UiStyle.GOLD))
	vb.add_child(UiStyle.label("%s pontos · %s" % [Hud.format_int(score), time_text], 24, UiStyle.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, true))
	vb.add_child(UiStyle.label("Digite suas iniciais", 20, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER))
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
		row.add_child(l)
		_labels.append(l)
	add_child(UiStyle.hint_bar("W S  Letra      A D  Posição      Enter  Confirmar"))
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_refresh()


func _refresh() -> void:
	for i in 3:
		var l := _labels[i]
		l.text = ALPHABET[_letters[i]]
		var active := i == _slot and not _done
		l.label_settings.font_color = UiStyle.GOLD if active else UiStyle.TEXT
		l.label_settings.outline_color = Color(UiStyle.GOLD, 0.6 if active and fmod(_t, 0.6) < 0.4 else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	# Ignore input briefly so a player still mashing fire can't submit "AAA".
	if _done or _t < 0.8:
		return
	if event.is_action_pressed("ui_up"):
		_letters[_slot] = posmod(_letters[_slot] + 1, ALPHABET.length())
	elif event.is_action_pressed("ui_down"):
		_letters[_slot] = posmod(_letters[_slot] - 1, ALPHABET.length())
	elif event.is_action_pressed("ui_left"):
		_slot = maxi(0, _slot - 1)
	elif event.is_action_pressed("ui_right"):
		_slot = mini(2, _slot + 1)
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER] \
			or event.is_action_pressed("ui_accept") and event is InputEventJoypadButton:
		_done = true
		var name := ""
		for i in 3:
			name += ALPHABET[_letters[i]]
		Sfx.play("ui_confirm", -2.0)
		_on_done.call(name)
	else:
		return
	Sfx.play("ui_move", -8.0)
	_accept()


func _accept() -> void:
	get_viewport().set_input_as_handled()
