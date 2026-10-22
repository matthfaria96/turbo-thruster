class_name Overlay
extends Control
## Modal panel used for pause, sector results and game over.

var _cancel: Callable


static func create(heading: String, subtitle: String, rows: Array, buttons: Array,
		accent := UiStyle.ACCENT, cancel := Callable()) -> Overlay:
	var o := Overlay.new()
	o._cancel = cancel
	o._build(heading, subtitle, rows, buttons, accent)
	return o


func _build(heading: String, subtitle: String, rows: Array, buttons: Array, accent: Color) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiStyle.theme()
	UiStyle.full_rect(self)
	add_child(UiStyle.dim_layer(0.55))
	var center := CenterContainer.new()
	UiStyle.full_rect(center)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(ArcadeTitle.make(heading, 38, accent))
	if subtitle != "":
		vb.add_child(UiStyle.label(subtitle, 22, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if not rows.is_empty():
		vb.add_child(_rows(rows))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vb.add_child(spacer)
	var first: Button = null
	for spec: Array in buttons:
		var b := UiStyle.button(spec[0], spec[1], 460)
		b.custom_minimum_size.y = 50
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(b)
		if first == null:
			first = b
	add_child(UiStyle.hint_bar("↑ ↓  Navegar      Enter  Confirmar" + ("      Esc  Voltar" if _cancel.is_valid() else "")))
	if first:
		first.call_deferred("grab_focus")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


## rows: [label, value, color?]
func _rows(rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 2)
	for row: Array in rows:
		var name_label := UiStyle.label(row[0], 20, UiStyle.DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var color: Color = row[2] if row.size() > 2 else UiStyle.TEXT
		var size := 36 if row.size() > 3 else 22
		grid.add_child(UiStyle.label(str(row[1]), size, color, HORIZONTAL_ALIGNMENT_RIGHT, true))
	return grid


func _unhandled_input(event: InputEvent) -> void:
	if _cancel.is_valid() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_cancel.call()
