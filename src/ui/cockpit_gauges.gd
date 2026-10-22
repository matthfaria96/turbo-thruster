class_name CockpitGauges
extends Control
## Ship-cockpit HUD drawn by hand in a retro instrument style: numbers use a
## seven-segment LCD face with unlit "8" ghost segments behind them, labels
## use a monospaced terminal face. Scales with window height (ref. 720 px).

const CYAN := Color(0.35, 0.9, 1.0)
const WHITE := Color(0.93, 0.97, 1.0)
const DIM := Color(0.55, 0.65, 0.8)
const RED := Color(1.0, 0.3, 0.35)
const GREEN := Color(0.4, 1.0, 0.5)
const GOLD := Color(1.0, 0.82, 0.3)
const GHOST_ALPHA := 0.09

var state: Dictionary = {}
var boss_name := ""
var boss_ratio := -1.0
var _t := 0.0
var _k := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(next_state: Dictionary, dt: float) -> void:
	state = next_state
	_t += dt
	queue_redraw()


func _draw() -> void:
	if state.is_empty():
		return
	_k = size.y / 720.0
	_draw_frame()
	_draw_score()
	_draw_act_strip()
	_draw_kills()
	_draw_distance()
	_draw_speed_dial()
	_draw_ring_gauge(Vector2(150, size.y / _k - 92), "CASCO", int(state.hull), Player.MAX_HULL, CYAN,
		float(state.shield) / 10.0, Color(0.4, 0.8, 1.0))
	_draw_ring_gauge(Vector2(size.x / _k - 150, size.y / _k - 92), "ARMA", int(state.weapon),
		Player.MAX_WEAPON, GREEN, float(state.rapid) / 9.0, Color(1.0, 0.6, 0.15))
	_draw_reticle()
	_draw_hazard()


# ------------------------------------------------------------------ helpers

func _p(v: Vector2) -> Vector2:
	return v * _k


func _aligned_x(pos_x: float, width: float, align: int) -> float:
	match align:
		HORIZONTAL_ALIGNMENT_CENTER: return (pos_x - width * 0.5) * _k
		HORIZONTAL_ALIGNMENT_RIGHT: return (pos_x - width) * _k
	return pos_x * _k


## Monospaced terminal label.
func _label(pos: Vector2, text: String, font_size: float, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, width := 400.0) -> void:
	var font := UiStyle.term_font()
	var x := _aligned_x(pos.x, width, align)
	var fs := int(font_size * _k)
	draw_string(font, Vector2(x + 1, pos.y * _k + 1), text, align, width * _k, fs, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(x, pos.y * _k), text, align, width * _k, fs, color)


## Seven-segment number with unlit ghost segments ("888") behind it.
## `digits` pads the ghost so the readout keeps a fixed width.
func _lcd(pos: Vector2, text: String, font_size: float, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER, digits := 0, width := 400.0) -> void:
	var font := UiStyle.lcd_font()
	var fs := int(font_size * _k)
	var x := _aligned_x(pos.x, width, align)
	# In DSEG fonts "!" is a blank with the full width of a digit.
	var lit := text.lpad(maxi(digits, text.length()), "!")
	var ghost := ""
	for ch in lit:
		ghost += ch if ch == "." or ch == ":" else "8"
	draw_string(font, Vector2(x, pos.y * _k), ghost, align, width * _k, fs, Color(color, GHOST_ALPHA))
	draw_string(font, Vector2(x, pos.y * _k), lit, align, width * _k, fs, color)


func _arc(center: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> void:
	if absf(to - from) < 0.001:
		return
	var points := maxi(8, int(absf(to - from) * 24.0))
	draw_arc(_p(center), radius * _k, from, to, points, color, width * _k, true)


func _bar(pos: Vector2, length: float, thickness: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(_p(pos), _p(Vector2(length, thickness))), Color(0.05, 0.08, 0.14, 0.85))
	draw_rect(Rect2(_p(pos), _p(Vector2(length * clampf(ratio, 0.0, 1.0), thickness))), color)


# -------------------------------------------------------------------- parts

func _draw_frame() -> void:
	var w := size.x / _k
	var h := size.y / _k
	var c := RED if int(state.hull) == 1 and fmod(_t, 0.5) < 0.25 else Color(CYAN, 0.55)
	var l := 46.0
	for corner in [Vector2(14, 14), Vector2(w - 14, 14), Vector2(14, h - 14), Vector2(w - 14, h - 14)]:
		var sx := 1.0 if corner.x < w * 0.5 else -1.0
		var sy := 1.0 if corner.y < h * 0.5 else -1.0
		draw_line(_p(corner), _p(corner + Vector2(l * sx, 0)), c, 2.5 * _k)
		draw_line(_p(corner), _p(corner + Vector2(0, l * sy)), c, 2.5 * _k)
	for i in 9:
		var x := w * 0.5 + (i - 4) * 26.0
		draw_line(_p(Vector2(x, 8)), _p(Vector2(x, 13 if i % 4 else 18)), Color(CYAN, 0.35), 1.5 * _k)


func _draw_score() -> void:
	var cx := size.x / _k * 0.5
	_label(Vector2(cx, 28), "PONTOS", 13, DIM)
	_lcd(Vector2(cx, 66), str(int(state.score)), 30, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8)
	var mult := int(state.multiplier)
	var pulse := 1.0 + (0.2 if fmod(_t * 2.0, 1.0) < 0.1 and mult > 1 else 0.0)
	_label(Vector2(cx + 178, 28), "MULT", 13, DIM, HORIZONTAL_ALIGNMENT_LEFT, 120)
	_label(Vector2(cx + 178, 64), "x", 20, GREEN, HORIZONTAL_ALIGNMENT_LEFT, 20)
	_lcd(Vector2(cx + 194, 66), str(mult), 24 * pulse, GREEN, HORIZONTAL_ALIGNMENT_LEFT, 2, 120)


func _draw_act_strip() -> void:
	var cx := size.x / _k * 0.5
	var width := 460.0
	var left := cx - width * 0.5
	var y := 96.0
	if boss_ratio >= 0.0:
		_label(Vector2(cx, y), "!! CHEFE :: " + boss_name.to_upper() + " !!", 17, RED, HORIZONTAL_ALIGNMENT_CENTER, 700)
		_bar(Vector2(left - 40, y + 8), width + 80, 10, boss_ratio, RED)
		return
	var acts := maxi(int(state.acts), 1)
	var progress := clampf(float(state.distance) / float(state.length), 0.0, 1.0)
	var label := "ATO %d/%d :: %s" % [int(state.act) + 1, acts, String(state.act_title).to_upper()]
	if state.arcade:
		label = "NÍVEL %d/%d :: %s" % [int(state.act) + 1, acts, String(state.act_title).to_upper()]
		progress = clampf(float(state.elapsed) / 360.0, 0.0, 1.0)
	_label(Vector2(cx, y), label, 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 700)
	_bar(Vector2(left, y + 8), width, 6, progress, CYAN)
	for i in range(1, acts):
		var x := left + width * float(i) / acts
		draw_line(_p(Vector2(x, y + 4)), _p(Vector2(x, y + 18)), Color(GOLD, 0.8), 2.0 * _k)


func _draw_kills() -> void:
	var total := maxi(int(state.total), 1)
	var kills := int(state.kills)
	_label(Vector2(40, 30), "ELIMINAÇÕES", 13, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_lcd(Vector2(40, 66), "%d" % kills, 28, WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4, 200)
	if state.arcade:
		return
	_label(Vector2(156, 66), "/%d" % total, 17, DIM, HORIZONTAL_ALIGNMENT_LEFT, 120)
	_bar(Vector2(40, 78), 190, 4, float(kills) / total, RED)


func _draw_distance() -> void:
	var right := size.x / _k - 40
	var secs := int(state.elapsed)
	_label(Vector2(right, 30), "DISTÂNCIA", 13, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(Vector2(right, 66), "KM", 15, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 40)
	_lcd(Vector2(right - 32, 66), "%.2f" % (float(state.distance) / 1000.0), 28, WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 4)
	if not state.arcade:
		_label(Vector2(right - 92, 92), "DE %.1f KM" % (float(state.length) / 1000.0), 13, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_label(Vector2(right - 92, 92), "SOBREVIVIDO", 13, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_lcd(Vector2(right, 92), "%02d:%02d" % [secs / 60, secs % 60], 14, CYAN, HORIZONTAL_ALIGNMENT_RIGHT, 0, 120)


func _draw_speed_dial() -> void:
	var center := Vector2(size.x / _k * 0.5, size.y / _k - 12)
	var ratio := clampf((float(state.speed) - Player.MIN_SPEED) / (Player.MAX_SPEED - Player.MIN_SPEED + 30.0), 0.0, 1.0)
	var start := PI * 1.12
	var finish := PI * 1.88
	_arc(center, 96, start, finish, Color(0.06, 0.1, 0.18, 0.85), 12)
	var col := CYAN.lerp(RED, clampf((ratio - 0.6) / 0.4, 0.0, 1.0))
	var segments := 24
	for i in int(ratio * segments):
		var a0 := lerpf(start, finish, float(i) / segments) + 0.008
		var a1 := lerpf(start, finish, float(i + 1) / segments) - 0.008
		_arc(center, 96, a0, a1, col, 12)
	for i in 11:
		var a := lerpf(start, finish, i / 10.0)
		var inner := 80.0 if i % 5 == 0 else 85.0
		draw_line(_p(center + Vector2(cos(a), sin(a)) * inner), _p(center + Vector2(cos(a), sin(a)) * 89.0),
			Color(WHITE, 0.6), 1.5 * _k)
	var charge := float(state.charge)
	if charge > 0.0:
		_arc(center, 72, start, lerpf(start, finish, charge), WHITE if charge >= 1.0 else Color(0.8, 1, 1), 6)
	_lcd(center + Vector2(0, -30), "%d" % int(float(state.speed) * 9.0), 24, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3)
	_label(center + Vector2(0, -12), "KM/H", 12, DIM)
	if charge >= 1.0:
		_label(center + Vector2(0, -78), "> SOLTE! <", 14, WHITE)


func _draw_ring_gauge(center: Vector2, label: String, value: int, maximum: int, color: Color,
		timer: float, timer_color: Color) -> void:
	var gap := 0.12
	var span := TAU / maximum
	for i in maximum:
		var a := -PI / 2.0 + i * span
		var c := color if i < value else Color(0.12, 0.16, 0.24, 0.9)
		_arc(center, 40, a + gap, a + span - gap, c, 9)
	if timer > 0.0:
		_arc(center, 52, -PI / 2.0, -PI / 2.0 + TAU * clampf(timer, 0.0, 1.0), timer_color, 4)
	_lcd(center + Vector2(0, 10), "%d" % value, 22, color)
	_label(center + Vector2(0, 68), label, 13, DIM)


func _draw_specials() -> void:
	var count := int(state.get("specials", 0))
	var center := Vector2(size.x / _k * 0.5, size.y / _k - 150)
	var color := Color(1.0, 0.35, 0.9)
	for i in Player.MAX_SPECIALS:
		var x := center.x + (i - (Player.MAX_SPECIALS - 1) * 0.5) * 22.0
		var c := color if i < count else Color(0.12, 0.16, 0.24, 0.9)
		var pts := PackedVector2Array([_p(Vector2(x, center.y - 7)), _p(Vector2(x + 7, center.y)),
			_p(Vector2(x, center.y + 7)), _p(Vector2(x - 7, center.y))])
		draw_colored_polygon(pts, c)
	_label(center + Vector2(0, 22), "ESPAÇO  BOMBA", 12, DIM if count == 0 else color)


func _draw_reticle() -> void:
	var pos: Vector2 = state.reticle
	if pos.x < -500.0:
		return
	var c := RED if state.hazard else Color(CYAN, 0.8)
	var r := 16.0 * _k
	for i in 4:
		var a := i * PI / 2.0 + PI / 4.0 + _t * 0.6
		draw_arc(pos, r, a - 0.4, a + 0.4, 8, c, 2.0 * _k, true)
	draw_circle(pos, 2.5 * _k, c)


func _draw_hazard() -> void:
	if not state.hazard or fmod(_t, 0.4) > 0.26:
		return
	var center := Vector2(size.x / _k * 0.5, size.y / _k - 205)
	_label(center, "/!\\ OBSTÁCULO À FRENTE /!\\", 19, RED, HORIZONTAL_ALIGNMENT_CENTER, 600)


func _draw_power() -> void:
	var text := String(state.get("power", ""))
	if text == "":
		return
	var center := Vector2(size.x / _k * 0.5, size.y / _k - 178)
	_label(center, "[ " + text + "s ]", 17, GOLD if fmod(_t, 0.5) < 0.4 else WHITE)
