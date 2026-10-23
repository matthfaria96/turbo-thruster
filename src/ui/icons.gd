class_name Icons
extends RefCounted
## Flat neon icons that mirror each 3D model's silhouette, so the HUD legend
## and on-screen markers can be matched to what is flying in the tunnel.

const LINE := 2.0


## Draws the icon for an enemy/obstacle `kind` or a power-up "pickup_<kind>".
static func draw(ci: CanvasItem, kind: String, c: Vector2, r: float, color: Color) -> void:
	if kind.begins_with("pickup_"):
		_pickup(ci, kind.trim_prefix("pickup_"), c, r)
		return
	match kind:
		"drone": _poly(ci, c, r, 3, -PI / 2.0, color, true)
		"swarm": _star(ci, c, r, r * 0.3, 4, color)
		"weaver": _pinwheel(ci, c, r, color)
		"gunner": _square(ci, c, r, color, true)
		"mine": _star(ci, c, r, r * 0.42, 6, color)
		"seeker": _spiky_orb(ci, c, r, color)
		"phantom": _diamond(ci, c, r, color, true)
		"splitter": _square(ci, c + Vector2(-r * 0.25, -r * 0.25), r * 0.7, color, false)
		"warden": _poly(ci, c, r, 6, 0.0, color, true)
		"laser": _laser(ci, c, r, color)
		"serpent": _serpent(ci, c, r, color)
		"tank": _poly(ci, c, r, 6, PI / 6.0, color, true)
		"drifter": _ship(ci, c, r, color)
		"barrier": _barrier(ci, c, r, color)
		"rotor": _rotor(ci, c, r, color)
		"pulse_ring": _ring(ci, c, r, color)
		"spike": _star(ci, c, r, r * 0.35, 5, color)
		"charge": _charge(ci, c, r, color)
		"nitro": _nitro(ci, c, r, color)
		_: _poly(ci, c, r, 8, 0.0, color, false)
	if kind == "splitter":
		_square(ci, c + Vector2(r * 0.3, r * 0.3), r * 0.55, color, false)


## Role of a kind for the player: "dodge", "bonus" or "shoot".
static func role(kind: String) -> String:
	if kind.begins_with("pickup_"):
		return "pickup"
	var spec := EnemyTypes.get_type(kind)
	if spec.get("invulnerable", false):
		return "dodge"
	if spec.get("bonus", false):
		return "bonus"
	return "shoot"


static func role_text(role_name: String) -> String:
	match role_name:
		"dodge": return "DESVIE"
		"bonus": return "BÔNUS"
		"pickup": return "PEGUE"
	return "ATIRE"


static func role_color(role_name: String) -> Color:
	match role_name:
		"dodge": return Color(1.0, 0.85, 0.3)
		"bonus": return Color(1.0, 0.75, 0.2)
		"pickup": return Color(0.4, 1.0, 0.55)
	return Color(1.0, 0.35, 0.4)


# ------------------------------------------------------------------ shapes

static func _points(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := rot + TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _fill(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	var open := pts.slice(0, pts.size() - 1)
	ci.draw_colored_polygon(open, Color(color, 0.22))


static func _poly(ci: CanvasItem, c: Vector2, r: float, n: int, rot: float, color: Color, filled: bool) -> void:
	var pts := _points(c, r, n, rot)
	if filled:
		_fill(ci, pts, color)
	ci.draw_polyline(pts, color, LINE, true)


static func _square(ci: CanvasItem, c: Vector2, r: float, color: Color, filled: bool) -> void:
	_poly(ci, c, r, 4, PI / 4.0, color, filled)


static func _diamond(ci: CanvasItem, c: Vector2, r: float, color: Color, dashed: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r),
		c + Vector2(-r * 0.7, 0), c + Vector2(0, -r)])
	_fill(ci, pts, color)
	ci.draw_polyline(pts, Color(color, 0.6 if dashed else 1.0), LINE, true)


static func _star(ci: CanvasItem, c: Vector2, outer: float, inner: float, n: int, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in n * 2 + 1:
		var a := -PI / 2.0 + PI * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
	_fill(ci, pts, color)
	ci.draw_polyline(pts, color, LINE, true)


static func _pinwheel(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	for i in 4:
		var a := TAU * i / 4.0
		var tri := PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * r,
			c + Vector2(cos(a + 0.7), sin(a + 0.7)) * r * 0.65, c])
		_fill(ci, tri, color)
		ci.draw_polyline(tri, color, LINE, true)


static func _spiky_orb(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_circle(c, r * 0.55, Color(color, 0.3))
	ci.draw_arc(c, r * 0.55, 0.0, TAU, 20, color, LINE, true)
	for i in 8:
		var a := TAU * i / 8.0
		ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.55, c + Vector2(cos(a), sin(a)) * r, color, LINE, true)


static func _laser(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	_square(ci, c + Vector2(0, r * 0.35), r * 0.6, color, true)
	ci.draw_line(c + Vector2(0, -r * 0.1), c + Vector2(0, -r * 1.1), Color(1, 0.3, 0.3), LINE + 1.0, true)


static func _serpent(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	for i in 4:
		var p := c + Vector2(-r + i * r * 0.6, sin(i * 1.4) * r * 0.4)
		var rad := r * (0.42 if i == 3 else 0.28)
		ci.draw_circle(p, rad, Color(color, 0.3))
		ci.draw_arc(p, rad, 0.0, TAU, 14, color, LINE, true)


static func _ship(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.35, -r * 0.1), c + Vector2(r, r * 0.5),
		c + Vector2(r * 0.35, r * 0.25), c + Vector2(0, r * 0.6), c + Vector2(-r * 0.35, r * 0.25),
		c + Vector2(-r, r * 0.5), c + Vector2(-r * 0.35, -r * 0.1), c + Vector2(0, -r)])
	_fill(ci, pts, color)
	ci.draw_polyline(pts, color, LINE, true)


static func _barrier(ci: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	var c := center - Vector2(0, r * 0.75)
	ci.draw_arc(c, r * 1.15, PI * 0.12, PI * 0.88, 16, color, r * 0.6, false)
	for i in 4:
		var a := lerpf(PI * 0.22, PI * 0.78, i / 3.0)
		ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.85, c + Vector2(cos(a), sin(a)) * r * 1.45, Color(0, 0, 0, 0.55), 1.5)


static func _rotor(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_line(c - Vector2(r, r * 0.25), c + Vector2(r, r * 0.25), color, LINE + 2.0, true)
	ci.draw_circle(c, r * 0.25, Color(1, 1, 1))


static func _ring(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 24, color, LINE + 1.0, true)
	ci.draw_arc(c, r * 0.6, 0.0, TAU, 18, Color(color, 0.6), LINE, true)


## Charge shot: a filling ring around a bright core.
static func _charge(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 24, color, LINE, true)
	ci.draw_circle(c, r * 0.45, color)
	for i in 4:
		var a := PI / 4.0 + TAU * i / 4.0
		ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.6, c + Vector2(cos(a), sin(a)) * r * 0.9, color, LINE, true)


## Nitro: double chevron pointing forward.
static func _nitro(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	for k in 2:
		var y := c.y + r * 0.35 - k * r * 0.6
		var pts := PackedVector2Array([Vector2(c.x - r * 0.8, y + r * 0.35), Vector2(c.x, y - r * 0.35),
			Vector2(c.x + r * 0.8, y + r * 0.35)])
		ci.draw_polyline(pts, color, LINE + 1.0, true)


static func _pickup(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	var info := EnemyTypes.powerup(kind)
	var color: Color = info.color
	var pts := _points(c, r, 6, 0.0)
	_fill(ci, pts, color)
	ci.draw_polyline(pts, color, LINE, true)
	var font := UiStyle.font()
	var fs := int(r * 1.15)
	ci.draw_string(font, c + Vector2(-r, fs * 0.36), info.letter, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1))
