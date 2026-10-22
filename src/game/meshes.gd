class_name Meshes
extends RefCounted
## Procedural neon models. Every enemy type has a distinct silhouette.

const GLOW_SHADER := preload("res://src/shaders/glow.gdshader")
const PARTICLE_SHADER := preload("res://src/shaders/particle.gdshader")
const VORTEX_SHADER := preload("res://src/shaders/vortex.gdshader")

static var _materials: Dictionary = {}


static func glow(color: Color, energy := 1.5) -> ShaderMaterial:
	var key := "g%s|%.2f" % [color.to_html(), energy]
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		mat.set_shader_parameter("color", color)
		mat.set_shader_parameter("energy", energy)
		_materials[key] = mat
	return _materials[key]


static func additive(energy := 2.5, core := 0.0) -> ShaderMaterial:
	var key := "a%.2f|%.2f" % [energy, core]
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = PARTICLE_SHADER
		mat.set_shader_parameter("energy", energy)
		mat.set_shader_parameter("core", core)
		_materials[key] = mat
	return _materials[key]


static func add_part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO,
		rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m


static func sphere(radius: float, segments := 12, rings := 6) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = rings
	return m


static func torus(inner: float, outer: float, segments := 32) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = segments
	m.ring_segments = 8
	return m


static func cylinder(radius: float, height: float, segments := 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	return m


## Player ship: nose toward -Z (forward), cyan/white.
static func ship() -> Node3D:
	var root := Node3D.new()
	var body := glow(EnemyTypes.PLAYER_COLOR, 1.25)
	var wing := glow(Color(0.2, 0.55, 1.0), 1.1)
	var hot := glow(Color(1.0, 1.0, 1.0), 2.6)
	add_part(root, prism(Vector3(0.9, 2.4, 0.35)), body, Vector3(0, 0, -0.2), Vector3(-PI / 2, 0, 0))
	add_part(root, box(Vector3(2.6, 0.08, 0.55)), wing, Vector3(0, -0.05, 0.55))
	add_part(root, box(Vector3(0.1, 0.35, 0.7)), hot, Vector3(-1.3, 0.1, 0.55))
	add_part(root, box(Vector3(0.1, 0.35, 0.7)), hot, Vector3(1.3, 0.1, 0.55))
	add_part(root, sphere(0.2), glow(Color(0.7, 1.0, 1.0), 2.2), Vector3(0, 0.2, -0.3))
	add_part(root, sphere(0.17), hot, Vector3(0, 0, 1.0))
	root.scale = Vector3.ONE * 0.8
	return root


## Enemy models face +Z (toward the approaching player).
static func enemy(kind: String) -> Node3D:
	var root := Node3D.new()
	var color: Color = EnemyTypes.get_type(kind).color
	var mat := glow(color, 1.7)
	var core := glow(Color(1.0, 0.95, 0.85), 2.6)
	match kind:
		"drone":
			add_part(root, prism(Vector3(1.6, 1.8, 0.5)), mat, Vector3.ZERO, Vector3(PI / 2, 0, 0))
			add_part(root, sphere(0.28), core, Vector3(0, 0.25, 0.1))
		"weaver":
			var spin := Node3D.new()
			spin.name = "Spin"
			root.add_child(spin)
			add_part(spin, box(Vector3(2.4, 0.3, 0.18)), mat, Vector3.ZERO, Vector3(0, 0, PI / 4))
			add_part(spin, box(Vector3(2.4, 0.3, 0.18)), mat, Vector3.ZERO, Vector3(0, 0, -PI / 4))
			add_part(root, sphere(0.35), core)
		"gunner":
			add_part(root, box(Vector3(1.5, 0.9, 1.3)), mat)
			add_part(root, cylinder(0.2, 1.3), core, Vector3(0, 0, 0.9), Vector3(PI / 2, 0, 0))
			add_part(root, box(Vector3(0.25, 1.6, 0.8)), mat, Vector3(-0.95, 0, 0))
			add_part(root, box(Vector3(0.25, 1.6, 0.8)), mat, Vector3(0.95, 0, 0))
		"mine":
			var spin := Node3D.new()
			spin.name = "Spin"
			root.add_child(spin)
			add_part(spin, sphere(0.6, 8, 4), mat)
			add_part(spin, box(Vector3(2.0, 0.2, 0.2)), mat)
			add_part(spin, box(Vector3(0.2, 2.0, 0.2)), mat)
			add_part(spin, box(Vector3(0.2, 0.2, 2.0)), mat)
			add_part(spin, sphere(0.3), core)
		"tank":
			add_part(root, cylinder(1.5, 0.8, 6), mat, Vector3.ZERO, Vector3(PI / 2, 0, 0))
			var spin := Node3D.new()
			spin.name = "Spin"
			root.add_child(spin)
			add_part(spin, torus(1.7, 2.0, 24), glow(color.lightened(0.3), 1.8), Vector3.ZERO, Vector3(PI / 2, 0, 0))
			add_part(root, sphere(0.55), core, Vector3(0, 0, 0.5))
	return root


static func boss(color: Color) -> Node3D:
	var root := Node3D.new()
	var mat := glow(color, 1.05)
	add_part(root, sphere(2.0, 16, 8), mat)
	add_part(root, sphere(0.8), glow(Color(1, 0.95, 0.85), 1.8), Vector3(0, 0, 1.6))
	var ring_a := Node3D.new()
	ring_a.name = "RingA"
	root.add_child(ring_a)
	add_part(ring_a, torus(2.7, 3.1, 32), glow(color.lightened(0.25), 1.2), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for i in 4:
		var a := TAU * i / 4.0
		add_part(ring_a, box(Vector3(0.8, 0.8, 0.8)), mat, Vector3(cos(a), sin(a), 0) * 3.4, Vector3(0, 0, a))
	var ring_b := Node3D.new()
	ring_b.name = "RingB"
	root.add_child(ring_b)
	add_part(ring_b, torus(3.8, 4.05, 40), glow(color, 0.9), Vector3.ZERO, Vector3(PI / 2 + 0.3, 0, 0))
	root.scale = Vector3.ONE * 0.75
	return root


static func pickup(kind: String) -> Node3D:
	var root := Node3D.new()
	var color := EnemyTypes.WEAPON_COLOR if kind == "weapon" else EnemyTypes.REPAIR_COLOR
	var spin := Node3D.new()
	spin.name = "Spin"
	root.add_child(spin)
	add_part(spin, sphere(0.75, 4, 2), glow(color, 1.8), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.3, 1))
	add_part(root, torus(1.05, 1.2, 24), glow(color, 1.4), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	var label := Label3D.new()
	label.text = "P" if kind == "weapon" else "+"
	label.font_size = 96
	label.outline_size = 18
	label.pixel_size = 0.01
	label.modulate = Color(1, 1, 1)
	label.outline_modulate = color.darkened(0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.position = Vector3(0, 1.6, 0)
	root.add_child(label)
	root.scale = Vector3.ONE * 0.7
	return root


static func portal() -> Node3D:
	var root := Node3D.new()
	var ring := Node3D.new()
	ring.name = "Ring"
	root.add_child(ring)
	add_part(ring, torus(5.7, 6.5, 64), glow(Color(0.6, 0.95, 1.0), 2.4), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for i in 12:
		var a := TAU * i / 12.0
		add_part(ring, box(Vector3(0.5, 1.2, 0.5)), glow(Color(1, 1, 1), 3.0),
			Vector3(cos(a), sin(a), 0) * 6.1, Vector3(0, 0, a + PI / 2))
	var disc_mat := ShaderMaterial.new()
	disc_mat.shader = VORTEX_SHADER
	var disc := QuadMesh.new()
	disc.size = Vector2(12.5, 12.5)
	var disc_node := add_part(root, disc, disc_mat)
	disc_node.name = "Disc"
	return root


## Collects every mesh under a node so hit-flash can be applied.
static func geometry_of(node: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		out.append(child as GeometryInstance3D)
	return out
