class_name RouteMap
extends Control
## Mini-map of the sector: the tunnel's winding route from start to the boss,
## the distance already flown, upcoming enemy groups and the finish.

const SAMPLE_STEP := 12.0
const PAD := Vector2(14, 30)

var _length := 1.0
var _points := PackedVector2Array()
var _ratios := PackedFloat32Array()
var _groups := PackedFloat32Array()
var _progress := 0.0
var _boss := false
var _t := 0.0


func setup(track: Track, length: float, plan: Array[Dictionary]) -> void:
	_length = length
	custom_minimum_size = Vector2(300, 128)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var raw: Array[Vector2] = []
	var s := 0.0
	var min_x := INF
	var max_x := -INF
	while s <= length:
		var c := track.center(s)
		var lateral := c.x + c.y * 0.6
		raw.append(Vector2(s, lateral))
		min_x = minf(min_x, lateral)
		max_x = maxf(max_x, lateral)
		s += SAMPLE_STEP
	var span := maxf(max_x - min_x, 1.0)
	for p in raw:
		_points.append(Vector2(p.x / length, (p.y - min_x) / span))
		_ratios.append(p.x / length)
	var last := -999.0
	for spawn in plan:
		if spawn.s - last > 30.0:
			_groups.append(spawn.s / length)
			last = spawn.s


func update_state(distance: float, boss_active: bool, dt: float) -> void:
	_progress = clampf(distance / _length, 0.0, 1.0)
	_boss = boss_active
	_t += dt
	queue_redraw()


func _to_local(p: Vector2) -> Vector2:
	var area := size - PAD * Vector2(2.0, 1.0) - Vector2(0, 10)
	return Vector2(PAD.x + p.x * area.x, PAD.y + (1.0 - p.y) * area.y)


func _point_at(ratio: float) -> Vector2:
	var idx := clampi(int(ratio * (_points.size() - 1)), 0, _points.size() - 1)
	return _to_local(_points[idx])


func _draw() -> void:
	if _points.size() < 2:
		return
	var font := UiStyle.font()
	draw_string(font, Vector2(PAD.x, 20), "ROTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.DIM)
	var remaining := int(maxf(0.0, _length * (1.0 - _progress)))
	var info := "CHEFE!" if _boss else "faltam %d m" % remaining
	draw_string(font, Vector2(size.x - PAD.x - 150, 20), info, HORIZONTAL_ALIGNMENT_RIGHT, 150, 14,
		UiStyle.DANGER if _boss else UiStyle.TEXT)
	var all := PackedVector2Array()
	var done := PackedVector2Array()
	for i in _points.size():
		var p := _to_local(_points[i])
		all.append(p)
		if _ratios[i] <= _progress:
			done.append(p)
	draw_polyline(all, Color(0.4, 0.55, 0.8, 0.45), 3.0, true)
	if done.size() >= 2:
		draw_polyline(done, Color(UiStyle.ACCENT, 0.35), 7.0, true)
		draw_polyline(done, UiStyle.ACCENT, 3.0, true)
	for g in _groups:
		if g > _progress:
			draw_circle(_point_at(g), 2.5, Color(1.0, 0.35, 0.4, 0.85))
	var end := _point_at(1.0)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	_draw_diamond(end, 8.0 + pulse * 2.0, UiStyle.DANGER)
	draw_string(font, end + Vector2(-40, 22), "CHEFE", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, UiStyle.DANGER)
	var me := _point_at(_progress)
	draw_circle(me, 9.0 + pulse * 3.0, Color(UiStyle.ACCENT, 0.25))
	draw_circle(me, 5.0, Color(1, 1, 1))


func _draw_diamond(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
	draw_polyline(pts, color, 2.5, true)
	draw_circle(c, r * 0.35, color)
