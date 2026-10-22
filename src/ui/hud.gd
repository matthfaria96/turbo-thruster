class_name Hud
extends CanvasLayer
## In-game cockpit HUD. The instruments are drawn by CockpitGauges; this
## node adds the canopy glass, route map, centre announcements, damage
## vignette, white flash and modal overlays, and sways with the ship.

const VIGNETTE := preload("res://src/shaders/vignette.gdshader")
const GLASS := preload("res://src/shaders/cockpit_glass.gdshader")
const SWAY_PX := 16.0

var root: Control
var _gauges: CockpitGauges
var _panel: SidePanel
var _markers: TargetMarkers
var _route: RouteMap
var _route_holder: Control
var _announce: Label
var _announce_sub: Label
var _announce_box: Control
var _announce_tween: Tween
var _vignette_mat: ShaderMaterial
var _flash: ColorRect
var _damage := 0.0
var _boss_visible := false


func build(_index: int, level: Dictionary, arcade := false) -> void:
	layer = 5
	root = UiStyle.full_rect(Control.new())
	root.theme = UiStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.add_child(_canvas_rect(GLASS, {"tint": Color(level.tint, 1.0)}))
	var vignette := _canvas_rect(VIGNETTE, {})
	_vignette_mat = vignette.material
	root.add_child(vignette)
	_markers = TargetMarkers.new()
	UiStyle.full_rect(_markers)
	root.add_child(_markers)
	_panel = SidePanel.new()
	UiStyle.full_rect(_panel)
	root.add_child(_panel)
	_gauges = CockpitGauges.new()
	UiStyle.full_rect(_gauges)
	root.add_child(_gauges)
	if not arcade:
		_build_route()
	_build_announce()
	_flash = UiStyle.full_rect(ColorRect.new()) as ColorRect
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)


func _canvas_rect(shader: Shader, params: Dictionary) -> ColorRect:
	var rect := UiStyle.full_rect(ColorRect.new()) as ColorRect
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key: String in params:
		mat.set_shader_parameter(key, params[key])
	rect.material = mat
	return rect


func _build_route() -> void:
	_route = RouteMap.new()
	_route_holder = PanelContainer.new()
	_route_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiStyle.box(Color(0.02, 0.05, 0.1, 0.4), Color(UiStyle.ACCENT, 0.5), 1, 4, 0)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	_route_holder.add_theme_stylebox_override("panel", sb)
	_route_holder.add_child(_route)
	_route_holder.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_route_holder.position = Vector2(0, 0)
	root.add_child(_route_holder)


func _build_announce() -> void:
	var center := CenterContainer.new()
	UiStyle.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.offset_bottom = -150
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	center.add_child(vb)
	_announce = UiStyle.title("", 60)
	_announce.label_settings.shadow_color = Color(0, 0, 0, 0.6)
	vb.add_child(_announce)
	_announce_sub = UiStyle.label("", 26, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	_announce_sub.label_settings.outline_size = 10
	_announce_sub.label_settings.outline_color = Color(0, 0, 0, 0.85)
	vb.add_child(_announce_sub)
	vb.modulate.a = 0.0
	_announce_box = vb


func setup_route(track: Track, length: float, plan: Array[Dictionary], act_starts := PackedFloat32Array()) -> void:
	_route.setup(track, length, plan, act_starts)


## state: score, multiplier, weapon, hull, speed, charge, shield, rapid,
## distance, length, kills, total, act, acts, act_title, reticle, bank, hazard
func refresh(state: Dictionary, dt: float) -> void:
	var view := root.get_viewport_rect().size
	_gauges.position = Vector2(-float(state.bank) * SWAY_PX, absf(float(state.bank)) * 4.0)
	if _boss_visible and float(state.boss_ratio) >= 0.0:
		_gauges.boss_ratio = float(state.boss_ratio)
	_gauges.push(state, dt)
	_panel.push(state, dt)
	_markers.push(state.get("markers", []), dt)
	if _route:
		_route_holder.position = Vector2(view.x - _route_holder.size.x - 18.0, view.y * 0.5 - _route_holder.size.y * 0.5 - 10.0)
		_route.update_state(float(state.distance), _boss_visible, dt)
	_damage = maxf(0.0, _damage - dt * 1.6)
	var low_hull := 0.25 if int(state.hull) == 1 else 0.0
	_vignette_mat.set_shader_parameter("amount", maxf(_damage, low_hull * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008))))
	if _damage <= 0.0:
		_vignette_mat.set_shader_parameter("side", 0.0)
	_vignette_mat.set_shader_parameter("slow", 1.0 if state.slow else 0.0)


func show_boss(boss_name: String) -> void:
	_boss_visible = true
	_gauges.boss_name = boss_name
	_gauges.boss_ratio = 1.0


func hide_boss() -> void:
	_boss_visible = false
	_gauges.boss_ratio = -1.0


func set_boss_health(ratio: float) -> void:
	_gauges.boss_ratio = ratio


func announce(text: String, sub := "", duration := 1.8, color := UiStyle.ACCENT) -> void:
	_announce.text = text
	_announce.label_settings.outline_color = Color(color, 0.85)
	_announce_sub.text = sub
	if not UiStyle.supports_display(sub):
		_announce_sub.label_settings.font = UiStyle.font()
	else:
		_announce_sub.label_settings.font = UiStyle.display_font()
	if _announce_tween:
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_property(_announce_box, "modulate:a", 1.0, 0.15)
	_announce_tween.tween_interval(duration)
	_announce_tween.tween_property(_announce_box, "modulate:a", 0.0, 0.4)


## side: -1 hit from the left, 1 from the right, 0 around.
func damage_pulse(side := 0.0) -> void:
	_damage = 0.9
	_vignette_mat.set_shader_parameter("side", side)


func set_flash(alpha: float) -> void:
	_flash.color.a = clampf(alpha, 0.0, 1.0)


func add_overlay(overlay: Control) -> void:
	root.add_child(overlay)


static func format_int(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out
