class_name UiStyle
extends RefCounted
## One theme for every screen: dark glass panels, a single cyan accent and a
## strong, obvious focus state (keyboard, mouse and gamepad share it).

const ACCENT := Color(0.35, 0.9, 1.0)
const TEXT := Color(0.93, 0.96, 1.0)
const DIM := Color(0.58, 0.65, 0.78)
const DANGER := Color(1.0, 0.32, 0.38)
const GOOD := Color(0.4, 1.0, 0.55)
const GOLD := Color(1.0, 0.82, 0.3)
const PANEL_BG := Color(0.03, 0.05, 0.1, 0.9)

static var _theme: Theme
static var _font: SystemFont
static var _bold: SystemFont


static func font(bold := false) -> SystemFont:
	if _font == null:
		_font = _make_font(600)
		_bold = _make_font(800)
	return _bold if bold else _font


static func _make_font(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["SF Pro Display", "Segoe UI", "Helvetica Neue", "Arial"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", box(Color(0.07, 0.1, 0.17, 0.92), Color(0.2, 0.28, 0.42), 2))
	t.set_stylebox("hover", "Button", box(Color(0.09, 0.2, 0.3, 0.95), ACCENT, 2))
	t.set_stylebox("pressed", "Button", box(Color(0.15, 0.35, 0.45, 1.0), ACCENT, 3))
	t.set_stylebox("disabled", "Button", box(Color(0.05, 0.06, 0.09, 0.8), Color(0.14, 0.16, 0.22), 2))
	var focus := box(Color(0.1, 0.24, 0.34, 0.96), ACCENT, 3)
	focus.shadow_color = Color(ACCENT, 0.45)
	focus.shadow_size = 14
	t.set_stylebox("focus", "Button", focus)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", TEXT if state == "font_color" else Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.55))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL_BG, Color(0.22, 0.32, 0.48, 0.8), 1, 18, 30))
	t.set_stylebox("background", "ProgressBar", box(Color(0.05, 0.07, 0.12, 0.85), Color(0.2, 0.28, 0.4), 1, 4, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, ACCENT, 0, 4, 0))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	_theme = t
	return t


static func box(bg: Color, border: Color, border_w := 2, corner := 12, pad := 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = pad + 6
	sb.content_margin_right = pad + 6
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	sb.anti_aliasing = true
	return sb


static func label(text: String, size := 22, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = font(bold)
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	return l


## Big glowing heading.
static func title(text: String, size := 64, color := ACCENT) -> Label:
	var l := label(text, size, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, true)
	l.label_settings.outline_size = int(size * 0.18)
	l.label_settings.outline_color = Color(color, 0.55)
	l.label_settings.shadow_size = int(size * 0.5)
	l.label_settings.shadow_color = Color(color, 0.35)
	l.label_settings.shadow_offset = Vector2.ZERO
	return l


static func button(text: String, on_press: Callable, min_width := 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 58)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 24)
	wire(b)
	b.pressed.connect(func() -> void:
		Sfx.play("pickup", -10.0, 1.4)
		on_press.call())
	return b


## Mouse hover moves keyboard focus, so exactly one item is ever highlighted.
static func wire(b: BaseButton) -> void:
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: Sfx.play("shot", -14.0, 1.6))


static func hint_bar(text: String) -> Label:
	var l := label(text, 17, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -48
	l.offset_bottom = -18
	return l


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func dim_layer(alpha := 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.0, 0.01, 0.03, alpha)
	full_rect(r)
	return r


static func rank_color(rank: String) -> Color:
	match rank:
		"S": return GOLD
		"A": return GOOD
		"B": return ACCENT
	return DIM
