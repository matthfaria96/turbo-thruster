class_name TargetMarkers
extends Control
## Screen-space markers over everything in the tunnel so every glow can be
## identified: red corner brackets = enemy (shoot), yellow hazard frame +
## "DESVIE" = indestructible obstacle, gold frame + "BÔNUS" = lost ship,
## icon + name = power-up to collect.

var _markers: Array = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## markers: [{kind, pos: Vector2 (screen), dist: float}]
func push(markers: Array, dt: float) -> void:
	_markers = markers
	_t += dt
	queue_redraw()


func _draw() -> void:
	var k := size.y / 720.0
	for m: Dictionary in _markers:
		var kind := String(m.kind)
		var role := Icons.role(kind)
		var color := Icons.role_color(role)
		var pos: Vector2 = m.pos
		var dist: float = m.dist
		var r := clampf(700.0 / maxf(dist, 1.0), 9.0, 34.0) * k
		var alpha := clampf(1.3 - dist / 140.0, 0.35, 1.0)
		match role:
			"shoot":
				_brackets(pos, r, Color(color, 0.8 * alpha), 2.0 * k)
			"dodge":
				_hazard(pos, r * 1.25, Color(color, alpha), k)
				_tag(pos + Vector2(0, -r * 1.25 - 6.0 * k), "DESVIE", Color(color, alpha), k)
			"bonus":
				_brackets(pos, r * 1.2, Color(color, alpha), 2.5 * k)
				_tag(pos + Vector2(0, -r * 1.2 - 6.0 * k), "BÔNUS", Color(color, alpha), k)
			"pickup":
				var info := EnemyTypes.powerup(kind.trim_prefix("pickup_"))
				var pulse := 1.0 + 0.12 * sin(_t * 8.0)
				Icons.draw(self, kind, pos + Vector2(0, -r * 1.6), 10.0 * k * pulse, Color(1, 1, 1))
				_tag(pos + Vector2(0, -r * 1.6 - 15.0 * k), String(info.name), Color(info.color, alpha), k)


func _brackets(c: Vector2, r: float, color: Color, width: float) -> void:
	var l := r * 0.45
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = c + corner * r
		draw_line(p, p - Vector2(corner.x * l, 0), color, width, true)
		draw_line(p, p - Vector2(0, corner.y * l), color, width, true)


func _hazard(c: Vector2, r: float, color: Color, k: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
	var blink := 1.0 if fmod(_t, 0.4) < 0.25 else 0.55
	draw_polyline(pts, Color(color, color.a * blink), 2.5 * k, true)


func _tag(pos: Vector2, text: String, color: Color, k: float) -> void:
	var fs := int(12 * k)
	var font := UiStyle.term_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_rect(Rect2(pos + Vector2(-w * 0.5 - 4.0 * k, -fs), Vector2(w + 8.0 * k, fs + 4.0 * k)), Color(0, 0, 0, 0.55 * color.a))
	draw_string(font, pos + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
