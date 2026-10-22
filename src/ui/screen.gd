class_name Screen
extends Control
## Base for full-screen menus: theme, layout helpers and Esc = back.

var main: Node


func _init(p_main: Node) -> void:
	main = p_main
	theme = UiStyle.theme()
	UiStyle.full_rect(self)
	add_child(UiStyle.dim_layer(0.35))


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


## Override to go back. Returning false means Esc does nothing.
func _go_back() -> bool:
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _go_back():
		get_viewport().set_input_as_handled()


func centered_column(width := 0.0) -> VBoxContainer:
	var center := CenterContainer.new()
	UiStyle.full_rect(center)
	center.offset_bottom = -40
	add_child(center)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(width, 0)
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	return vb


func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func focus_later(control: Control) -> void:
	control.call_deferred("grab_focus")
