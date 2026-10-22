class_name SpaceBackdrop
extends Node3D
## Far background that follows the camera: soft bokeh discs and a slowly
## turning "plexus" of thin connected lines. Dim on purpose.

const BOKEH_COUNT := 36
const PLEXUS_POINTS := 70
const DISTANCE := 260.0

var _plexus: Node3D
var _bokeh: MultiMeshInstance3D


func setup(tint: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	_bokeh = _make_bokeh(rng, tint)
	add_child(_bokeh)
	_plexus = _make_plexus(rng, tint)
	add_child(_plexus)


func follow(cam: Camera3D, delta: float) -> void:
	global_position = cam.global_position
	_plexus.rotate_y(delta * 0.02)
	_plexus.rotate_x(delta * 0.011)
	_bokeh.rotate_z(delta * 0.01)


func _make_bokeh(rng: RandomNumberGenerator, tint: Color) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = BOKEH_COUNT
	var palette := [tint, Color(0.2, 0.9, 0.8), Color(0.6, 0.3, 1.0), Color(1.0, 0.4, 0.7)]
	for i in BOKEH_COUNT:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var size := rng.randf_range(18.0, 50.0)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), dir * DISTANCE))
		var c: Color = palette[i % palette.size()]
		mm.set_instance_color(i, Color(c, rng.randf_range(0.05, 0.13)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	var mat := Meshes.additive(0.5, 0.0).duplicate() as ShaderMaterial
	mat.render_priority = -20
	node.material_override = mat
	node.custom_aabb = AABB(Vector3.ONE * -400.0, Vector3.ONE * 800.0)
	return node


func _make_plexus(rng: RandomNumberGenerator, tint: Color) -> Node3D:
	var pts: Array[Vector3] = []
	for i in PLEXUS_POINTS:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		pts.append(dir * DISTANCE * rng.randf_range(0.85, 1.0))
	var segments: Array = []
	for i in pts.size():
		var near := range(pts.size())
		near.sort_custom(func(a: int, b: int) -> bool: return pts[i].distance_squared_to(pts[a]) < pts[i].distance_squared_to(pts[b]))
		for k in range(1, 4):
			if i < near[k]:
				segments.append([pts[i], pts[near[k]]])
	var mesh := NeonGeo.edge_mesh_from_segments(segments)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := NeonGeo.edge_material(tint.lightened(0.3), 0.26, 0.45).duplicate() as ShaderMaterial
	mat.render_priority = -20
	mi.material_override = mat
	mi.custom_aabb = AABB(Vector3.ONE * -400.0, Vector3.ONE * 800.0)
	var root := Node3D.new()
	root.add_child(mi)
	return root
