class_name Fx
extends Node3D
## Particle bursts, explosions, floating score text and camera shake.

var shake := 0.0
var _quad: QuadMesh
var _fade_curve: Curve
var _ramps: Dictionary = {}


func _ready() -> void:
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_fade_curve = Curve.new()
	_fade_curve.add_point(Vector2(0.0, 1.0))
	_fade_curve.add_point(Vector2(1.0, 0.0))


func burst(pos: Vector3, color: Color, amount := 24, speed := 14.0, size := 0.35, life := 0.7) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _quad
	p.material_override = Meshes.additive(2.4, 0.4)
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3.ZERO
	p.damping_min = speed * 0.5
	p.damping_max = speed * 1.1
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	p.scale_amount_curve = _fade_curve
	p.color_ramp = _ramp(color)
	p.position = pos
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


func explosion(pos: Vector3, color: Color, scale_k := 1.0) -> void:
	burst(pos, color, int(26 * scale_k), 20.0 * scale_k, 0.32 * scale_k, 0.7)
	burst(pos, Color(1, 1, 1), 4, 4.0 * scale_k, 0.8 * scale_k, 0.25)
	burst(pos, color, int(5 * scale_k), 5.0 * scale_k, 0.9 * scale_k, 0.8)
	shake = maxf(shake, 0.12 * scale_k)


func sparks(pos: Vector3, color: Color) -> void:
	burst(pos, color, 7, 9.0, 0.22, 0.3)


func popup(pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.0011
	label.fixed_size = true
	label.modulate = color.lightened(0.4)
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.position = pos
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(label.queue_free)


static func make_trail(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	p.mesh = quad
	p.material_override = Meshes.additive(2.2, 0.6)
	p.amount = 50
	p.lifetime = 0.32
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)
	p.spread = 6.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.5
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), color, Color(color, 0.0)])
	p.color_ramp = g
	return p


func _ramp(color: Color) -> Gradient:
	var key := color.to_html()
	if not _ramps.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), color, Color(color, 0.0)])
		_ramps[key] = g
	return _ramps[key]
