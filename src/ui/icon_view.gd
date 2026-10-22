class_name IconView
extends Control
## Small fixed-size control that draws one Icons glyph (used in menus).

var kind := ""
var color := Color.WHITE


static func make(p_kind: String, p_color: Color, px := 22.0) -> IconView:
	var v := IconView.new()
	v.kind = p_kind
	v.color = p_color
	v.custom_minimum_size = Vector2(px, px)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _draw() -> void:
	Icons.draw(self, kind, size * 0.5, minf(size.x, size.y) * 0.42, color)
