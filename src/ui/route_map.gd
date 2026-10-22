class_name RouteMap
extends Control
## Vertical route strip on the right edge: start at the bottom, boss at the
## top. Shows the tunnel's winding, the distance flown, upcoming enemy
## groups, act boundaries and the remaining distance.

const SAMPLE_STEP := 15.0
const STRIP := Vector2(64, 330)
const PAD := Vector2(10, 34)

var _length := 1.0
var _points := PackedVector2Array()
var _groups := PackedFloat32Array()
var _acts := PackedFloat32Array()
var _progress := 0.0
var _boss := false
var _t := 0.0


func setup(track: Track, length: float, plan: Array[Dictionary], act_starts := PackedFloat32Array()) -> void:
	_length = length
	custom_minimum_size = STRIP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var raw: Array[Vector2] = []
	var lo := INF
	var hi := -INF
	var s := 0.0
	while s <= length:
		var c := track.center(s)
		var lateral := c.x + c.y * 0.6
		raw.append(Vector2(lateral, s / length))
		lo = minf(lo, lateral)
		hi = maxf(hi, lateral)
		s += SAMPLE_STEP
	var span := maxf(hi - lo, 1.0)
	for p in raw:
		_points.append(Vector2((p.x - lo) / span, p.y))
	var last := -999.0
	for spawn in plan:
		if spawn.s - last > 40.0 and not String(spawn.kind).begins_with("pickup_"):
			_groups.append(spawn.s / length)
			last = spawn.s
	for a in act_starts:
		if a > 0.0:
			_acts.append(a / length)


func update_state(distance: float, boss_active: bool, dt: float) -> void:
	_progress = clampf(distance / _length, 0.0, 1.0)
	_boss = boss_active
	_t += dt
	queue_redraw()


## Ratio 0 = bottom (start), 1 = top (boss).
func _to_local(p: Vector2) -> Vector2:
	var area := size - PAD * 2.0
	return Vector2(PAD.x + p.x * area.x, size.y - PAD.y - p.y * area.y)


func _point_at(ratio: float) -> Vector2:
	var idx := clampi(int(ratio * (_points.size() - 1)), 0, _points.size() - 1)
	return _to_local(_points[idx])


func _draw() -> void:
	if _points.size() < 2:
		return
	var font := UiStyle.term_font()
	draw_string(font, Vector2(0, 14), "ROTA", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UiStyle.DIM)
	var all := PackedVector2Array()
	var done := PackedVector2Array()
	for p in _points:
		var q := _to_local(p)
		all.append(q)
		if p.y <= _progress:
			done.append(q)
	draw_polyline(all, Color(0.4, 0.55, 0.8, 0.4), 2.0, true)
	if done.size() >= 2:
		draw_polyline(done, Color(UiStyle.ACCENT, 0.3), 6.0, true)
		draw_polyline(done, UiStyle.ACCENT, 2.5, true)
	for a in _acts:
		var y := _to_local(Vector2(0, a)).y
		draw_line(Vector2(2, y), Vector2(10, y), Color(UiStyle.GOLD, 0.8), 2.0)
		draw_line(Vector2(size.x - 10, y), Vector2(size.x - 2, y), Color(UiStyle.GOLD, 0.8), 2.0)
	for g in _groups:
		if g > _progress:
			draw_circle(_point_at(g), 2.0, Color(1.0, 0.35, 0.4, 0.85))
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var end := _to_local(Vector2(0.5, 1.0))
	_draw_diamond(end + Vector2(0, -10), 6.0 + pulse * 2.0, UiStyle.DANGER)
	var me := _point_at(_progress)
	draw_circle(me, 8.0 + pulse * 3.0, Color(UiStyle.ACCENT, 0.25))
	_draw_ship(me)
	var remaining := int(maxf(0.0, _length * (1.0 - _progress)))
	var info := "CHEFE" if _boss else "%dm" % remaining
	draw_string(font, Vector2(0, size.y - 8), info, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
		UiStyle.DANGER if _boss else UiStyle.TEXT)


func _draw_ship(c: Vector2) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 5), c + Vector2(0, 2), c + Vector2(-5, 5)])
	draw_colored_polygon(pts, Color(1, 1, 1))


func _draw_diamond(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
	draw_polyline(pts, color, 2.0, true)
	draw_circle(c, r * 0.35, color)
