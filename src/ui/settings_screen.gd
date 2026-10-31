class_name SettingsScreen
extends Screen
## Each row is one focusable button: ← → (or click) changes the value.

const PERCENT_STEPS := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

var _rows: Array[Dictionary] = []


func _init(p_main: Node) -> void:
	super(p_main)
	var col := centered_column(720)
	col.add_theme_constant_override("separation", 10)
	col.add_child(ArcadeTitle.make("CONFIGURAÇÕES", 40))
	var panel := PanelContainer.new()
	col.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)
	_add_row(list, "Modo de tela", "display_mode", ["Janela", "Tela cheia"])
	# On the web the page sizes the canvas and the browser paces frames.
	if not OS.has_feature("web"):
		_add_row(list, "Tamanho da janela", "window_size",
			Save.WINDOW_SIZES.map(func(v: Vector2i) -> String: return "%d × %d" % [v.x, v.y]))
		_add_row(list, "VSync", "vsync", [false, true])
	_add_row(list, "Estilo de som", "audio_style", Sfx.STYLE_NAMES)
	_add_row(list, "Música", "music", PERCENT_STEPS)
	_add_row(list, "Efeitos sonoros", "sfx", PERCENT_STEPS)
	_add_row(list, "Brilho (bloom)", "glow", PERCENT_STEPS)
	_add_row(list, "Tremor de tela", "shake", [false, true])
	_add_row(list, "Tiro automático", "autofire", [false, true])
	var back := UiStyle.button("Voltar", _go_back, 300)
	back.custom_minimum_size.y = 46
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(back)
	add_child(UiStyle.hint_bar("↑ ↓  Navegar      ← →  Alterar      Esc  Voltar"))
	focus_later(_rows[0].button)


func _ready() -> void:
	super()
	Save.settings_changed.connect(func() -> void:
		for row in _rows:
			_refresh(row))


## Hidden cheat: typing this word on the settings screen unlocks every
## sector. It avoids W/A/S/D so typing it never moves the menu focus.
const CHEAT := "TURBO"

var _typed := ""


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.unicode <= 0:
		return
	_typed = (_typed + char(key.unicode).to_upper()).right(CHEAT.length())
	if _typed == CHEAT:
		_typed = ""
		_cheat_unlock()


func _cheat_unlock() -> void:
	var changed := Save.unlock_all()
	Sfx.play("pickup", 0.0, 1.0)
	var text := "CÓDIGO ATIVADO — TODOS OS SETORES LIBERADOS" if changed else "TODOS OS SETORES JÁ ESTÃO LIBERADOS"
	var toast := UiStyle.label(text, 22, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	toast.label_settings.outline_size = 8
	toast.label_settings.outline_color = Color(0.2, 0.1, 0.0)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_top = 64
	toast.offset_left = -400
	toast.offset_right = 400
	add_child(toast)
	var flash := UiStyle.full_rect(ColorRect.new()) as ColorRect
	flash.color = Color(1.0, 0.85, 0.3, 0.35)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "color:a", 0.0, 0.6)
	tween.tween_property(toast, "modulate:a", 0.0, 0.6).set_delay(2.2)
	tween.chain().tween_callback(func() -> void:
		flash.queue_free()
		toast.queue_free())


func _add_row(parent: Control, text: String, key: String, values: Array) -> void:
	var row := HBoxContainer.new()
	var name_label := UiStyle.label(text, 22, UiStyle.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 38)
	b.focus_mode = Control.FOCUS_ALL
	UiStyle.wire(b)
	row.add_child(b)
	parent.add_child(row)
	var entry := {"key": key, "values": values, "button": b}
	_rows.append(entry)
	b.pressed.connect(_change.bind(entry, 1))
	b.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
			_change(entry, -1)
			b.accept_event()
		elif event.is_action_pressed("ui_right"):
			_change(entry, 1)
			b.accept_event())
	_refresh(entry)


func _index_of(entry: Dictionary) -> int:
	var current: Variant = Save.settings[entry.key]
	var values: Array = entry.values
	if typeof(current) == TYPE_FLOAT:
		var best := 0
		for i in values.size():
			if absf(float(values[i]) - current) < absf(float(values[best]) - current):
				best = i
		return best
	if typeof(current) == TYPE_BOOL:
		return values.find(current)
	return clampi(int(current), 0, values.size() - 1)


func _change(entry: Dictionary, delta: int) -> void:
	var values: Array = entry.values
	var next := posmod(_index_of(entry) + delta, values.size())
	var value: Variant = values[next]
	if typeof(value) == TYPE_STRING:
		value = next
	Save.set_setting(entry.key, value)
	Sfx.play("ui_confirm", -6.0)
	for row in _rows:
		_refresh(row)


func _refresh(entry: Dictionary) -> void:
	var values: Array = entry.values
	var value: Variant = values[_index_of(entry)]
	var text := ""
	match typeof(value):
		TYPE_BOOL: text = "Ligado" if value else "Desligado"
		TYPE_FLOAT: text = "%d%%" % int(round(value * 100.0))
		_: text = str(value)
	var button: Button = entry.button
	button.text = "◀   %s   ▶" % text
	if entry.key == "window_size":
		button.disabled = Save.settings.display_mode == 1


func _go_back() -> bool:
	main.show_main_menu()
	return true
