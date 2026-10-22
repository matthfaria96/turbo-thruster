class_name Hud
extends CanvasLayer
## In-game HUD: score/combo, sector progress or boss health, weapon level,
## hull, charge meter, centre announcements, damage vignette and white flash.

const VIGNETTE := preload("res://src/shaders/vignette.gdshader")

var root: Control
var _score: Label
var _combo: Label
var _title: Label
var _progress: ProgressBar
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _weapon_label: Label
var _weapon_pips: Array[ColorRect] = []
var _hull_pips: Array[ColorRect] = []
var _speed: Label
var _charge_box: VBoxContainer
var _charge_bar: ProgressBar
var _charge_label: Label
var _announce: Label
var _announce_sub: Label
var _vignette_mat: ShaderMaterial
var _flash: ColorRect
var _announce_tween: Tween
var _damage := 0.0


func build(index: int, level: Dictionary) -> void:
	layer = 5
	root = UiStyle.full_rect(Control.new())
	root.theme = UiStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_effects()
	var margin := MarginContainer.new()
	UiStyle.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	column.add_child(_build_top(index, level))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	column.add_child(_build_bottom())
	_build_announce()


func _build_effects() -> void:
	var vignette := UiStyle.full_rect(ColorRect.new())
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = VIGNETTE
	vignette.material = _vignette_mat
	root.add_child(vignette)
	_flash = UiStyle.full_rect(ColorRect.new()) as ColorRect
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _side_box(align: int) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(300, 0)
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_meta("align", align)
	return vb


func _build_top(index: int, level: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := _side_box(HORIZONTAL_ALIGNMENT_LEFT)
	left.add_child(UiStyle.label("PONTOS", 15, UiStyle.DIM))
	_score = UiStyle.label("0", 38, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	left.add_child(_score)
	_combo = UiStyle.label("", 22, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	left.add_child(_combo)
	row.add_child(left)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_theme_constant_override("separation", 6)
	_title = UiStyle.label("SETOR %d  ·  %s" % [index + 1, String(level.name).to_upper()], 18,
		UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
	center.add_child(_title)
	_progress = _bar(Vector2(480, 10), UiStyle.ACCENT)
	center.add_child(_progress)
	_boss_box = VBoxContainer.new()
	_boss_box.visible = false
	_boss_box.add_theme_constant_override("separation", 4)
	_boss_name = UiStyle.label("", 22, UiStyle.DANGER, HORIZONTAL_ALIGNMENT_CENTER, true)
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Vector2(560, 16), UiStyle.DANGER)
	_boss_box.add_child(_boss_bar)
	center.add_child(_boss_box)
	row.add_child(center)
	var right := _side_box(HORIZONTAL_ALIGNMENT_RIGHT)
	_weapon_label = UiStyle.label("ARMA  NV 1", 15, UiStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_weapon_label)
	right.add_child(_pips(Player.MAX_WEAPON, EnemyTypes.WEAPON_COLOR, _weapon_pips, BoxContainer.ALIGNMENT_END))
	_speed = UiStyle.label("", 17, UiStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_speed)
	row.add_child(right)
	return row


func _build_bottom() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := _side_box(HORIZONTAL_ALIGNMENT_LEFT)
	left.add_child(UiStyle.label("CASCO", 15, UiStyle.DIM))
	left.add_child(_pips(Player.MAX_HULL, EnemyTypes.PLAYER_COLOR, _hull_pips, BoxContainer.ALIGNMENT_BEGIN))
	row.add_child(left)
	_charge_box = VBoxContainer.new()
	_charge_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_charge_box.alignment = BoxContainer.ALIGNMENT_END
	_charge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_label = UiStyle.label("CARGA", 15, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
	_charge_box.add_child(_charge_label)
	_charge_bar = _bar(Vector2(260, 8), Color(0.8, 1.0, 1.0))
	_charge_box.add_child(_charge_bar)
	_charge_box.modulate.a = 0.0
	row.add_child(_charge_box)
	var right := _side_box(HORIZONTAL_ALIGNMENT_RIGHT)
	var hint := UiStyle.label("X  tiro carregado     Esc  pausa", 15, Color(UiStyle.DIM, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(hint)
	row.add_child(right)
	return row


func _build_announce() -> void:
	var center := CenterContainer.new()
	UiStyle.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.offset_bottom = -140
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	center.add_child(vb)
	_announce = UiStyle.title("", 64)
	_announce.label_settings.shadow_color = Color(0, 0, 0, 0.6)
	vb.add_child(_announce)
	_announce_sub = UiStyle.label("", 26, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	_announce_sub.label_settings.outline_size = 10
	_announce_sub.label_settings.outline_color = Color(0, 0, 0, 0.85)
	vb.add_child(_announce_sub)
	vb.modulate.a = 0.0
	root.add_child(_flash)


func _bar(size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", UiStyle.box(color, color, 0, 4, 0))
	return bar


func _pips(count: int, color: Color, store: Array[ColorRect], align: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = align
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in count:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(34, 12)
		pip.color = color
		pip.set_meta("on", color)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(pip)
		store.append(pip)
	return hb


## state: score, combo, progress, weapon, hull, speed, charge
func refresh(state: Dictionary, dt: float) -> void:
	_score.text = _format_int(state.score)
	_combo.text = "COMBO x%d" % state.combo if state.combo > 1 else ""
	_progress.value = state.progress
	_weapon_label.text = "ARMA  NV %d%s" % [state.weapon, "  MÁX" if state.weapon >= Player.MAX_WEAPON else ""]
	_set_pips(_weapon_pips, state.weapon)
	_set_pips(_hull_pips, state.hull)
	_speed.text = "%d km/h" % int(state.speed * 9.0)
	var charge: float = state.charge
	_charge_bar.value = charge
	_charge_label.text = "PRONTO — SOLTE!" if charge >= 1.0 else "CARREGANDO"
	_charge_box.modulate.a = move_toward(_charge_box.modulate.a, 1.0 if charge > 0.05 else 0.0, dt * 6.0)
	_damage = maxf(0.0, _damage - dt * 1.6)
	var low_hull := 0.25 if state.hull == 1 else 0.0
	_vignette_mat.set_shader_parameter("amount", maxf(_damage, low_hull * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008))))


func _set_pips(pips: Array[ColorRect], value: int) -> void:
	for i in pips.size():
		var on: Color = pips[i].get_meta("on")
		pips[i].color = on if i < value else Color(0.15, 0.18, 0.25, 0.8)


func show_boss(boss_name: String) -> void:
	_progress.visible = false
	_title.visible = false
	_boss_box.visible = true
	_boss_name.text = "CHEFE  ·  " + boss_name.to_upper()


func hide_boss() -> void:
	_boss_box.visible = false


func set_boss_health(ratio: float) -> void:
	_boss_bar.value = ratio


func announce(text: String, sub := "", duration := 1.8, color := UiStyle.ACCENT) -> void:
	_announce.text = text
	_announce.label_settings.outline_color = Color(color, 0.55)
	_announce.label_settings.shadow_color = Color(0, 0, 0, 0.6)
	_announce_sub.text = sub
	var box := _announce.get_parent() as Control
	if _announce_tween:
		_announce_tween.kill()
	box.scale = Vector2.ONE
	_announce_tween = create_tween()
	_announce_tween.tween_property(box, "modulate:a", 1.0, 0.15)
	_announce_tween.tween_interval(duration)
	_announce_tween.tween_property(box, "modulate:a", 0.0, 0.4)


func damage_pulse() -> void:
	_damage = 0.9


func set_flash(alpha: float) -> void:
	_flash.color.a = clampf(alpha, 0.0, 1.0)


func add_overlay(overlay: Control) -> void:
	root.add_child(overlay)


static func _format_int(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out
