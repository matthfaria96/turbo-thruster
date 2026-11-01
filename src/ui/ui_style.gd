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
static var _body: FontVariation
static var _display: FontVariation

const BODY_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")


const ARCADE_FONT := preload("res://assets/fonts/Audiowide-Regular.ttf")
const LCD_FONT := preload("res://assets/fonts/DSEG7Classic-Bold.ttf")
## Arrows, stars and bars the text faces lack (DejaVu Sans Bold, cut down to
## those glyphs). The desktop app borrowed them from system fonts; browsers
## have none to lend, so they showed as empty boxes.
const SYMBOL_FONT := preload("res://assets/fonts/DejaVuSans-Bold-Symbols.ttf")
static var _symbols_attached := _attach_symbols()


static func _attach_symbols() -> bool:
	for f: Font in [BODY_FONT, ARCADE_FONT, TERM_FONT]:
		f.fallbacks = [SYMBOL_FONT]
	return true


## Digital arcade face for headings (Audiowide, full Portuguese accents).
static func arcade_font() -> Font:
	return ARCADE_FONT

const TERM_FONT := preload("res://assets/fonts/ShareTechMono-Regular.ttf")


## Seven-segment display digits (DSEG7). Supports 0-9 . : - and space.
static func lcd_font() -> Font:
	return LCD_FONT


## Retro monospaced terminal face for cockpit labels (Share Tech Mono).
static func term_font() -> Font:
	return TERM_FONT


## Clean condensed sans for text (Rajdhani).
static func font(_bold := false) -> Font:
	if _body == null:
		_body = FontVariation.new()
		_body.base_font = BODY_FONT
		_body.spacing_glyph = 1
	return _body


## Digital display face for titles and numbers (Audiowide).
static func display_font() -> Font:
	if _display == null:
		_display = FontVariation.new()
		_display.base_font = ARCADE_FONT
		_display.spacing_glyph = 1
	return _display


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
	t.set_stylebox("panel", "PanelContainer", box(PANEL_BG, Color(0.22, 0.32, 0.48, 0.8), 1, 8, 30))
	t.set_stylebox("background", "ProgressBar", box(Color(0.05, 0.07, 0.12, 0.85), Color(0.2, 0.28, 0.4), 1, 4, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, ACCENT, 0, 4, 0))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	_theme = t
	return t


static func box(bg: Color, border: Color, border_w := 2, corner := 6, pad := 16) -> StyleBoxFlat:
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
	ls.font = display_font() if bold and supports_display(text) else font()
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	return l


## Kept for callers: the display face now covers every Portuguese accent.
static func supports_display(_text: String) -> bool:
	return true


## Big glowing heading (Rajdhani, wide tracking — reads well with accents).
static func title(text: String, size := 64, color := ACCENT) -> Label:
	var l := label(text, size, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, false)
	var tracked := FontVariation.new()
	tracked.base_font = BODY_FONT
	tracked.spacing_glyph = int(size * 0.08)
	tracked.variation_embolden = 0.6
	l.label_settings.font = tracked
	l.label_settings.outline_size = int(size * 0.045)
	l.label_settings.outline_color = Color(color, 0.85)
	l.label_settings.shadow_size = int(size * 0.6)
	l.label_settings.shadow_color = Color(color, 0.45)
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
		Sfx.play("ui_confirm", -6.0)
		on_press.call())
	return b


## Mouse hover moves keyboard focus, so exactly one item is ever highlighted.
static func wire(b: BaseButton) -> void:
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move", -8.0))


static func hint_bar(text: String) -> Label:
	var l := label(text, 17, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	# Keyboard hints mean nothing on a touch screen.
	l.visible = not Mobile.enabled
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -48
	l.offset_bottom = -18
	return l


## Phone held upright: screens stack their parts instead of placing them side by side.
static func is_tall() -> bool:
	var view := (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size
	return view.x < view.y


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
