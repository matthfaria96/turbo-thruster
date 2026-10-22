class_name LevelSelect
extends Screen
## Sector cards on the left, briefing (boss, best score, enemy legend) on the right.

var _detail_name: Label
var _detail_info: Label
var _detail_best: Label
var _legend: VBoxContainer
var _start_hint: Label


func _init(p_main: Node) -> void:
	super(p_main)
	var col := centered_column()
	col.add_child(UiStyle.title("ESCOLHA O SETOR", 50))
	col.add_child(spacer(4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	row.add_child(grid)
	var first: Button = null
	for i in Levels.count():
		var card := _card(i)
		grid.add_child(card)
		if first == null or (Save.is_unlocked(i) and i == Save.unlocked - 1):
			first = card
	row.add_child(_detail_panel())
	add_child(UiStyle.hint_bar("← → ↑ ↓  Escolher      Enter  Iniciar      Esc  Voltar"))
	focus_later(first)


func _card(index: int) -> Button:
	var level := Levels.get_level(index)
	var unlocked := Save.is_unlocked(index)
	var b := Button.new()
	b.custom_minimum_size = Vector2(270, 84)
	b.focus_mode = Control.FOCUS_ALL
	UiStyle.wire(b)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_top = 12
	b.add_child(vb)
	var tint: Color = level.tint
	vb.add_child(UiStyle.label("SETOR %02d" % (index + 1), 14, tint.lightened(0.3) if unlocked else UiStyle.DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	vb.add_child(UiStyle.label(level.name if unlocked else "Bloqueado", 26, UiStyle.TEXT if unlocked else Color(UiStyle.DIM, 0.6), HORIZONTAL_ALIGNMENT_LEFT, true))
	var best := Save.best_for(index)
	if not best.is_empty():
		var rank := UiStyle.label(String(best.rank), 34, UiStyle.rank_color(best.rank), HORIZONTAL_ALIGNMENT_RIGHT, true)
		rank.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		rank.offset_left = -50
		rank.offset_right = -18
		rank.offset_top = -24
		b.add_child(rank)
	if unlocked:
		var earned := Save.medals_for(index).size()
		var stars := UiStyle.label("★".repeat(earned) + "☆".repeat(Save.MEDAL_IDS.size() - earned), 16,
			UiStyle.GOLD if earned > 0 else Color(UiStyle.DIM, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
		stars.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		stars.offset_left = -90
		stars.offset_right = -14
		stars.offset_top = 8
		b.add_child(stars)
	b.focus_entered.connect(_show_detail.bind(index))
	b.pressed.connect(_start.bind(index))
	return b


func _detail_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 420)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	_detail_name = UiStyle.label("", 34, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	vb.add_child(_detail_name)
	_detail_info = UiStyle.label("", 19, UiStyle.DIM)
	vb.add_child(_detail_info)
	_detail_best = UiStyle.label("", 19, UiStyle.GOLD)
	vb.add_child(_detail_best)
	vb.add_child(spacer(6))
	vb.add_child(UiStyle.label("INIMIGOS DESTE SETOR", 15, UiStyle.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, true))
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 6)
	vb.add_child(_legend)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(grow)
	_start_hint = UiStyle.label("", 18, UiStyle.GOOD, HORIZONTAL_ALIGNMENT_LEFT, true)
	vb.add_child(_start_hint)
	return panel


func _show_detail(index: int) -> void:
	var level := Levels.get_level(index)
	var unlocked := Save.is_unlocked(index)
	_detail_name.text = "Setor %d · %s" % [index + 1, level.name] if unlocked else "Setor %d · ???" % (index + 1)
	var acts: Array = level.acts
	var titles := acts.map(func(a: Dictionary) -> String: return a.title)
	_detail_info.text = ("%d atos · %.1f km · Chefe: %s\n%s" % [acts.size(), float(level.length) / 1000.0, level.boss,
		"  ›  ".join(PackedStringArray(titles))]) if unlocked else "Conclua o setor anterior para liberar."
	_detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var best := Save.best_for(index)
	_detail_best.text = "Recorde: %s pts  ·  Nota %s" % [Hud.format_int(int(best.score)), best.rank] if not best.is_empty() else ""
	var names := Save.medals_for(index).map(func(m: String) -> String: return RunEnd.MEDALS[m][0])
	if unlocked:
		_detail_best.text += ("\nMedalhas: " + ", ".join(PackedStringArray(names))) if not names.is_empty() \
			else "\nMedalhas: Intocável · Exterminador · Multiplicador (x50)"
	for child in _legend.get_children():
		child.queue_free()
	if unlocked:
		for kind: String in level.kinds:
			_legend.add_child(_legend_row(kind))
	_start_hint.text = "Enter para decolar  ▸" if unlocked else ""


func _legend_row(kind: String) -> HBoxContainer:
	var spec := EnemyTypes.get_type(kind)
	var row := HBoxContainer.new()
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.add_theme_stylebox_override("panel", UiStyle.box(spec.color, Color(1, 1, 1, 0.6), 1, 8, 0))
	row.add_child(swatch)
	var name_label := UiStyle.label(spec.name, 19, spec.color.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT, true)
	name_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_label)
	row.add_child(UiStyle.label(spec.desc, 17, UiStyle.DIM))
	return row


func _start(index: int) -> void:
	if not Save.is_unlocked(index):
		Sfx.play("hit", -4.0, 0.6)
		return
	main.start_level(index)


func _go_back() -> bool:
	main.show_main_menu()
	return true
