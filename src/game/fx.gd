class_name Fx
extends Node3D
## GPU particle effects: streak sparks, geometric shards, soft glows,
## shockwave rings, floating score text and camera shake. Explosions also
## ask the tunnel to ripple (see `ripple`).

signal ripple(pos: Vector3, strength: float, color: Color)

const SHOCK_TIME := 0.45

var shake := 0.0
var _process_mats: Dictionary = {}
var _spark_mesh: QuadMesh
var _glow_mesh: QuadMesh
var _shard_mesh: ArrayMesh
var _shocks: Array[Dictionary] = []


func _ready() -> void:
	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.12, 1.0)
	_glow_mesh = QuadMesh.new()
	_glow_mesh.size = Vector2.ONE
	_shard_mesh = NeonGeo.edge_mesh_from_segments([
		[Vector3(-0.3, -0.2, 0), Vector3(0.3, -0.2, 0)],
		[Vector3(0.3, -0.2, 0), Vector3(0, 0.35, 0)],
		[Vector3(0, 0.35, 0), Vector3(-0.3, -0.2, 0)]])


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	for shock in _shocks:
		shock.t += delta
		var k := minf(1.0, shock.t / SHOCK_TIME)
		var node: Node3D = shock.node
		node.scale = Vector3.ONE * lerpf(0.3, shock.size, ease(k, 0.4))
		if cam and node.global_position.distance_squared_to(cam.global_position) > 0.01:
			node.look_at(cam.global_position, cam.global_transform.basis.y)
		for g: GeometryInstance3D in shock.geo:
			Meshes.set_param(g, "fade", 1.0 - k)
		if k >= 1.0:
			node.queue_free()
	_shocks = _shocks.filter(func(s: Dictionary) -> bool: return s.t < SHOCK_TIME)


## Fast velocity-aligned streaks.
func sparks(pos: Vector3, color: Color, amount := 14, speed := 22.0, length := 1.2, life := 0.45) -> void:
	var mat := _process_material("spark", color, speed, length, true)
	_emit(pos, amount, life, mat, _spark_mesh, Meshes.streak(3.2, 0.7))


## Small spinning triangle outlines.
func shards(pos: Vector3, color: Color, amount := 6, speed := 10.0) -> void:
	var mat := _process_material("shard", color, speed, 1.0, false)
	_emit(pos, amount, 0.8, mat, _shard_mesh, NeonGeo.edge_material(color, 2.8, 0.05))


## Soft round glow puffs.
func glow(pos: Vector3, color: Color, amount := 4, size := 2.0, life := 0.35) -> void:
	var mat := _process_material("glow", color, 3.0, size, false)
	_emit(pos, amount, life, mat, _glow_mesh, Meshes.additive(2.2, 0.5))


func shockwave(pos: Vector3, color: Color, size := 4.0) -> void:
	var node := NeonGeo.build("shock", NeonGeo.ring(1.0, 32), color, 2.4, 0.0, 0.05)
	add_child(node)
	node.global_position = pos
	_shocks.append({"node": node, "t": 0.0, "size": size, "geo": Meshes.geometry_of(node)})


## Big, layered burst: fast sparks, a white core flash, slow lingering
## embers in the enemy colour plus a complementary accent, spinning shards,
## a shockwave ring and a coloured grid ripple.
func explosion(pos: Vector3, color: Color, scale_k := 1.0) -> void:
	var root_k := sqrt(scale_k)
	var accent := Color.from_hsv(fmod(color.h + 0.5, 1.0), 0.8, 1.0)
	sparks(pos, color, int(44 * scale_k), 26.0 * root_k, 1.4 * sqrt(root_k), 0.55)
	sparks(pos, Color(1, 1, 1), int(12 * scale_k), 18.0 * root_k, 0.9, 0.28)
	sparks(pos, accent, int(14 * scale_k), 14.0 * root_k, 0.7, 0.45)
	embers(pos, color, int(26 * scale_k), 5.0 * root_k)
	shards(pos, color, int(7 * scale_k), 9.0 * root_k)
	shards(pos, accent, int(3 * scale_k), 6.0 * root_k)
	glow(pos, Color(1, 1, 1), 1, 3.2 * root_k, 0.12)
	glow(pos, color, 3, 2.4 * root_k, 0.3)
	shockwave(pos, color, minf(3.2 * root_k, 7.0))
	ripple.emit(pos, clampf(0.55 * scale_k, 0.3, 2.5), color)
	shake = maxf(shake, 0.1 * scale_k)


## Slow glowing motes that hang in the air after a kill (Geometry Wars dust).
func embers(pos: Vector3, color: Color, amount := 20, speed := 5.0) -> void:
	var mat := _process_material("ember", color, speed, 0.22, false)
	_emit(pos, amount, 1.6, mat, _glow_mesh, Meshes.additive(2.6, 0.5))


func popup(pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UiStyle.display_font()
	label.font_size = 36
	label.outline_size = 10
	label.pixel_size = 0.0011
	label.fixed_size = true
	label.modulate = color.lightened(0.5)
	label.outline_modulate = Color(0, 0, 0, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.position = pos
	label.scale = Vector3.ONE * 0.6
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * 1.2, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tween.tween_callback(label.queue_free)


## Particles pulled into a point (charge-up at the ship's nose).
static func make_suction(color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	mat.emission_sphere_radius = 1.8
	mat.radial_accel_min = -55.0
	mat.radial_accel_max = -40.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.12
	mat.scale_max = 0.25
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	mat.scale_curve = grow_tex
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(color, 0.0), color, Color(1, 1, 1, 1)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	mat.color_ramp = ramp
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	p.draw_pass_1 = quad
	p.material_override = Meshes.additive(2.6, 0.6)
	p.amount = 40
	p.lifetime = 0.28
	p.local_coords = true
	p.emitting = false
	return p


## Jagged electric bolt between two points that flickers out.
func lightning(a: Vector3, b: Vector3, color: Color, life := 0.22, width := 0.08) -> void:
	var segs: Array = []
	var steps := clampi(int(a.distance_to(b) / 1.6), 4, 18)
	var dir := (b - a)
	var side := dir.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var up := side.cross(dir).normalized()
	var jag := minf(dir.length() * 0.08, 1.2)
	var prev := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a + dir * t
		if i < steps:
			p += side * randf_range(-jag, jag) + up * randf_range(-jag, jag)
		segs.append([prev, p])
		if i < steps and randf() < 0.25:
			var fork := p + (side * randf_range(-1, 1) + up * randf_range(-1, 1)) * jag * 1.5
			segs.append([p, fork])
		prev = p
	var mi := MeshInstance3D.new()
	mi.mesh = NeonGeo.edge_mesh_from_segments(segs)
	mi.material_override = NeonGeo.edge_material(color, 3.2, width)
	mi.custom_aabb = AABB(Vector3.ONE * -1e5, Vector3.ONE * 2e5)
	add_child(mi)
	var tween := mi.create_tween()
	tween.tween_method(func(v: float) -> void: Meshes.set_param(mi, "fade", v), 1.0, 0.0, life)
	tween.tween_callback(mi.queue_free)


## Short bolts crackling out of a point in random directions.
func zap(center: Vector3, radius: float, color: Color, count := 2) -> void:
	for i in count:
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		lightning(center, center + dir * radius * randf_range(0.5, 1.0), color, 0.1, 0.04)


## Speed streaks flying past the camera (attach to the camera; local space).
static func make_warp() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(10.0, 7.0, 12.0)
	mat.emission_ring_axis = Vector3.FORWARD
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 0.0
	mat.initial_velocity_min = 55.0
	mat.initial_velocity_max = 90.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.2
	mat.scale_max = 2.6
	mat.particle_flag_align_y = true
	mat.scale_curve = _fade_curve_texture()
	mat.color_ramp = _ramp_texture(Color(0.55, 0.85, 1.0, 0.55))
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 1.0)
	p.draw_pass_1 = quad
	p.material_override = Meshes.streak(1.1, 0.3)
	p.amount = 80
	p.lifetime = 0.7
	p.local_coords = true
	p.position = Vector3(0, 0, -36.0)
	p.visibility_aabb = AABB(Vector3(-40, -40, -60), Vector3(80, 80, 120))
	return p


## Continuous trail for ships/enemies (world-space particles).
static func make_trail(color: Color, amount := 40, life := 0.35, size := 0.45) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 8.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = size * 0.8
	mat.scale_max = size
	mat.scale_curve = _fade_curve_texture()
	mat.color_ramp = _ramp_texture(color)
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	p.draw_pass_1 = quad
	p.material_override = Meshes.additive(2.4, 0.6)
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	return p


func _emit(pos: Vector3, amount: int, life: float, mat: ParticleProcessMaterial, mesh: Mesh, draw_mat: Material) -> void:
	if amount <= 0:
		return
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.material_override = draw_mat
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = pos
	p.emitting = true


func _process_material(kind: String, color: Color, speed: float, size: float, align: bool) -> ParticleProcessMaterial:
	var key := "%s|%s|%.1f|%.2f" % [kind, color.to_html(), speed, size]
	if _process_mats.has(key):
		return _process_mats[key]
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 180.0
	mat.initial_velocity_min = speed * 0.35
	mat.initial_velocity_max = speed
	mat.gravity = Vector3.ZERO
	mat.damping_min = speed * 0.6
	mat.damping_max = speed * 1.2
	mat.scale_min = size * 0.6
	mat.scale_max = size * 1.2
	mat.scale_curve = _fade_curve_texture()
	mat.color_ramp = _ramp_texture(color)
	mat.particle_flag_align_y = align
	if kind == "ember":
		mat.damping_min = speed * 0.3
		mat.damping_max = speed * 0.6
		mat.turbulence_enabled = true
		mat.turbulence_noise_strength = 1.4
		mat.turbulence_noise_scale = 3.0
		mat.turbulence_influence_min = 0.05
		mat.turbulence_influence_max = 0.12
	if kind == "shard":
		mat.particle_flag_rotate_y = true
		mat.angular_velocity_min = -540.0
		mat.angular_velocity_max = 540.0
	_process_mats[key] = mat
	return mat


static func _fade_curve_texture() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


static func _ramp_texture(color: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), color, Color(color, 0.0)])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex
