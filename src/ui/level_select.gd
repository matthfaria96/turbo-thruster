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
	col.add_child(ArcadeTitle.make("ESCOLHA O SETOR", 44))
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
	# Upright phone: no room for the briefing; tapping a card starts the sector.
	if not UiStyle.is_tall():
		row.add_child(_detail_panel())
	add_child(UiStyle.hint_bar("← → ↑ ↓  Escolher      Enter  Iniciar      Esc  Voltar"))
	focus_later(first)


func _card(index: int) -> Button:
	var level := Levels.get_level(index)
	var unlocked := Save.is_unlocked(index)
	var b := Button.new()
	b.custom_minimum_size = Vector2(270, 84)
	b.clip_contents = true
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
	var title_label := UiStyle.label(level.name if unlocked else "BLOQUEADO", 24, UiStyle.TEXT if unlocked else Color(UiStyle.DIM, 0.6), HORIZONTAL_ALIGNMENT_LEFT, true)
	title_label.clip_text = true
	title_label.custom_minimum_size = Vector2(170, 0)
	vb.add_child(title_label)
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


const DETAIL_SIZE := Vector2(500, 430)
const LEGEND_COLUMNS := 2


## Fixed-size briefing: content is clipped inside so the panel (and the card
## grid next to it) never changes size between sectors.
func _detail_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var clip := Control.new()
	clip.custom_minimum_size = DETAIL_SIZE
	clip.clip_contents = true
	panel.add_child(clip)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	clip.add_child(vb)
	_detail_name = _fixed_label(28, UiStyle.TEXT, 1, true)
	vb.add_child(_detail_name)
	_detail_info = _fixed_label(17, UiStyle.DIM, 3)
	vb.add_child(_detail_info)
	_detail_best = _fixed_label(16, UiStyle.GOLD, 2)
	vb.add_child(_detail_best)
	vb.add_child(UiStyle.label("NESTE SETOR", 14, UiStyle.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, true))
	_legend = VBoxContainer.new()
	vb.add_child(_legend)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(grow)
	_start_hint = _fixed_label(18, UiStyle.GOOD, 1, true)
	vb.add_child(_start_hint)
	return panel


## Label with a fixed number of lines so its height never changes.
func _fixed_label(font_size: int, color: Color, lines: int, bold := false) -> Label:
	var l := UiStyle.label("", font_size, color, HORIZONTAL_ALIGNMENT_LEFT, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var line_h := l.label_settings.font.get_height(font_size)
	l.custom_minimum_size = Vector2(DETAIL_SIZE.x, line_h * lines + 2.0)
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return l


func _show_detail(index: int) -> void:
	if _detail_name == null:
		return
	var level := Levels.get_level(index)
	var unlocked := Save.is_unlocked(index)
	_detail_name.text = "Setor %d · %s" % [index + 1, level.name] if unlocked else "Setor %d · Bloqueado" % (index + 1)
	var acts: Array = level.acts
	var titles := acts.map(func(a: Dictionary) -> String: return a.title)
	_detail_info.text = ("%d atos · %.1f km · Chefe: %s\n%s" % [acts.size(), float(level.length) / 1000.0, level.boss,
		" › ".join(PackedStringArray(titles))]) if unlocked else "Conclua o setor anterior para liberar."
	var best := Save.best_for(index)
	var best_text := "Recorde: %s pts · Nota %s" % [Hud.format_int(int(best.score)), best.rank] if not best.is_empty() else "Sem recorde ainda"
	var names := Save.medals_for(index).map(func(m: String) -> String: return RunEnd.MEDALS[m][0])
	var medal_text := ("Medalhas: " + ", ".join(PackedStringArray(names))) if not names.is_empty() \
		else "Medalhas: Intocável · Exterminador · Multiplicador"
	_detail_best.text = (best_text + "\n" + medal_text) if unlocked else ""
	for child in _legend.get_children():
		child.queue_free()
	if unlocked:
		_legend.add_child(_legend_grid(level.kinds))
	_start_hint.text = "ENTER PARA DECOLAR  ▸" if unlocked else ""


## Two columns of icon + name + role; fixed row height.
func _legend_grid(kinds: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = LEGEND_COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	for kind: String in kinds:
		grid.add_child(_legend_cell(kind))
	return grid


func _legend_cell(kind: String) -> HBoxContainer:
	var spec := EnemyTypes.get_type(kind)
	var role := Icons.role(kind)
	var cell := HBoxContainer.new()
	cell.custom_minimum_size = Vector2((DETAIL_SIZE.x - 12.0) / LEGEND_COLUMNS, 26)
	cell.add_theme_constant_override("separation", 8)
	cell.add_child(IconView.make(kind, spec.color, 22.0))
	var name_label := UiStyle.label(spec.name, 16, spec.color.lightened(0.25))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	cell.add_child(name_label)
	cell.add_child(UiStyle.label(Icons.role_text(role), 13, Icons.role_color(role), HORIZONTAL_ALIGNMENT_RIGHT, true))
	return cell


func _start(index: int) -> void:
	if not Save.is_unlocked(index):
		Sfx.play("hit", -4.0, 0.6)
		return
	main.start_level(index)


func _go_back() -> bool:
	main.show_main_menu()
	return true
