class_name SidePanel
extends Control
## Left-hand cockpit panel. "PODERES": what the player can use right now,
## how many, which key, and timers of active power-ups. "NA ÁREA": every kind
## of thing ahead in the tunnel with its icon, name, count and what to do
## with it (ATIRE / DESVIE / PEGUE / BÔNUS). New kinds flash "NOVO".

const WIDTH := 236.0
const TOP := 108.0
const ROW := 30.0
const AREA_ROW := 34.0
const MAX_AREA := 7
const NEW_TIME := 5.0
const BG := Color(0.02, 0.05, 0.1, 0.62)
const DIM := Color(0.55, 0.65, 0.8)
const WHITE := Color(0.93, 0.97, 1.0)

var _state: Dictionary = {}
var _seen: Dictionary = {}
var _t := 0.0
var _k := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(state: Dictionary, dt: float) -> void:
	_state = state
	_t += dt
	for entry: Dictionary in state.get("area", []):
		if not _seen.has(entry.kind):
			_seen[entry.kind] = _t
	queue_redraw()


func _draw() -> void:
	if _state.is_empty():
		return
	_k = size.y / 720.0
	var y := TOP
	y = _draw_powers(y)
	y += 10.0
	_draw_area(y)


func _p(v: Vector2) -> Vector2:
	return v * _k


func _text(pos: Vector2, text: String, fs: float, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := WIDTH) -> void:
	var x := pos.x if align == HORIZONTAL_ALIGNMENT_LEFT else pos.x - width
	draw_string(UiStyle.term_font(), _p(Vector2(x, pos.y)), text, align, width * _k, int(fs * _k), color)


func _header(y: float, text: String, accent: Color, height: float) -> void:
	draw_rect(Rect2(_p(Vector2(18, y)), _p(Vector2(WIDTH, height))), BG)
	draw_rect(Rect2(_p(Vector2(18, y)), _p(Vector2(3, height))), accent)
	_text(Vector2(30, y + 16), text, 12, accent)


# ------------------------------------------------------------------ powers

func _draw_powers(y: float) -> float:
	var rows: Array = _state.get("powers", [])
	var height := 24.0 + rows.size() * ROW + 6.0
	_header(y, "PODERES", Color(1.0, 0.35, 0.9), height)
	var ry := y + 26.0
	for row: Dictionary in rows:
		_power_row(ry, row)
		ry += ROW
	return y + height


func _power_row(y: float, row: Dictionary) -> void:
	var color: Color = row.color
	var ready: bool = row.get("ready", true)
	var c := Vector2(42, y + 12)
	Icons.draw(self, String(row.icon), _p(c), 10.0 * _k, color if ready else Color(color, 0.35))
	_text(Vector2(60, y + 10), String(row.name), 14, WHITE if ready else DIM)
	if row.has("key"):
		_key_cap(Vector2(60, y + 15), String(row.key), color if ready else DIM)
	var right := 18.0 + WIDTH - 8.0
	if row.has("count"):
		var count := int(row.count)
		var maximum := int(row.max)
		for i in maximum:
			var x := right - (maximum - 1 - i) * 13.0 - 5.0
			var pts := PackedVector2Array([_p(Vector2(x, y + 4)), _p(Vector2(x + 5, y + 10)),
				_p(Vector2(x, y + 16)), _p(Vector2(x - 5, y + 10))])
			draw_colored_polygon(pts, color if i < count else Color(0.15, 0.18, 0.26))
	elif row.has("ratio"):
		var ratio := clampf(float(row.ratio), 0.0, 1.0)
		var bar := Rect2(_p(Vector2(right - 70, y + 6)), _p(Vector2(70, 7)))
		draw_rect(bar, Color(0.08, 0.1, 0.16))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), color)
		if row.has("label"):
			_text(Vector2(right, y + 24), String(row.label), 11, color, HORIZONTAL_ALIGNMENT_RIGHT, 90)


func _key_cap(pos: Vector2, key: String, color: Color) -> void:
	var w := 9.0 + key.length() * 7.0
	var rect := Rect2(_p(pos + Vector2(0, 0)), _p(Vector2(w, 13)))
	draw_rect(rect, Color(color, 0.12))
	draw_rect(rect, Color(color, 0.7), false, 1.0)
	_text(pos + Vector2(4, 10), key, 10, color)


# -------------------------------------------------------------------- area

func _draw_area(y: float) -> void:
	var entries: Array = _state.get("area", [])
	var shown := mini(entries.size(), MAX_AREA)
	var height := 24.0 + maxf(shown, 1) * AREA_ROW + 4.0
	_header(y, "NA ÁREA", Color(0.35, 0.9, 1.0), height)
	if shown == 0:
		_text(Vector2(30, y + 44), "caminho livre", 13, DIM)
		return
	var ry := y + 26.0
	for i in shown:
		_area_row(ry, entries[i])
		ry += AREA_ROW


func _area_row(y: float, entry: Dictionary) -> void:
	var kind := String(entry.kind)
	var role := Icons.role(kind)
	var role_color := Icons.role_color(role)
	var color: Color
	var name: String
	if kind.begins_with("pickup_"):
		var info := EnemyTypes.powerup(kind.trim_prefix("pickup_"))
		color = info.color
		name = String(info.name).capitalize()
	else:
		var spec := EnemyTypes.get_type(kind)
		color = spec.color
		name = String(spec.name)
	var fresh := _t - float(_seen.get(kind, -100.0)) < NEW_TIME
	if fresh and fmod(_t, 0.5) < 0.3:
		draw_rect(Rect2(_p(Vector2(22, y)), _p(Vector2(WIDTH - 8, AREA_ROW - 4))), Color(role_color, 0.14))
	Icons.draw(self, kind, _p(Vector2(42, y + 14)), 11.0 * _k, color)
	var label := name + ("  x%d" % int(entry.count) if int(entry.count) > 1 else "")
	_text(Vector2(62, y + 13), label, 14, WHITE)
	_text(Vector2(62, y + 27), "%dm" % int(entry.dist), 11, DIM)
	var right := 18.0 + WIDTH - 8.0
	var tag := "NOVO! " + Icons.role_text(role) if fresh else Icons.role_text(role)
	_text(Vector2(right, y + 20), tag, 12, role_color, HORIZONTAL_ALIGNMENT_RIGHT, 110)
