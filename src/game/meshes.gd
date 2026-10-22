class_name Meshes
extends RefCounted
## All gameplay models, built from NeonGeo shapes (glowing edges + glass fill).

const PARTICLE_SHADER := preload("res://src/shaders/particle.gdshader")
const STREAK_SHADER := preload("res://src/shaders/streak.gdshader")
const VORTEX_SHADER := preload("res://src/shaders/vortex.gdshader")

static var _materials: Dictionary = {}


static func additive(energy := 2.5, core := 0.0) -> ShaderMaterial:
	return _cached("a%.2f|%.2f" % [energy, core], PARTICLE_SHADER, {"energy": energy, "core": core})


static func streak(energy := 3.0, core := 0.6) -> ShaderMaterial:
	return _cached("s%.2f|%.2f" % [energy, core], STREAK_SHADER, {"energy": energy, "core": core})


static func _cached(key: String, shader: Shader, params: Dictionary) -> ShaderMaterial:
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = shader
		for p: String in params:
			mat.set_shader_parameter(p, params[p])
		_materials[key] = mat
	return _materials[key]


static func _named(name: String, child: Node3D) -> Node3D:
	child.name = name
	return child


## Player: white-cyan claw, nose toward -Z.
static func ship() -> Node3D:
	var root := Node3D.new()
	var claw := PackedVector2Array([Vector2(0, 1.25), Vector2(0.38, 0.1), Vector2(1.15, -0.55),
		Vector2(0.45, -0.3), Vector2(0, -0.75), Vector2(-0.45, -0.3), Vector2(-1.15, -0.55), Vector2(-0.38, 0.1)])
	var body := NeonGeo.build("ship", NeonGeo.extrude(claw, 0.3), EnemyTypes.PLAYER_COLOR, 1.8, 0.12, 0.07)
	body.rotation = Vector3(-PI / 2, 0, 0)
	root.add_child(body)
	var cockpit := NeonGeo.build("ship_core", NeonGeo.octa(0.22, 1.6), Color(1, 1, 1), 2.0, 0.25, 0.05)
	cockpit.position = Vector3(0, 0.22, -0.15)
	root.add_child(cockpit)
	root.scale = Vector3.ONE * 0.95
	return root


## Enemies face +Z (toward the player). Animated parts are named "Spin".
static func enemy(kind: String) -> Node3D:
	var root := Node3D.new()
	var color: Color = EnemyTypes.get_type(kind).color
	match kind:
		"drone":
			var spin := _named("Spin", NeonGeo.build("tetra", NeonGeo.tetra(1.0), color, 1.7, 0.12))
			root.add_child(spin)
		"weaver":
			var spin := Node3D.new()
			spin.name = "Spin"
			for i in 4:
				var a := TAU * i / 4.0
				var tri := PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * 1.25,
					Vector2(cos(a + 0.7), sin(a + 0.7)) * 0.8])
				spin.add_child(NeonGeo.build("pin%d" % i, NeonGeo.extrude(tri, 0.12), color, 1.7, 0.14))
			root.add_child(spin)
		"gunner":
			var spin := _named("Spin", NeonGeo.build("cube", NeonGeo.cube(1.05), color, 1.7, 0.12))
			root.add_child(spin)
			var inner := NeonGeo.build("cube_in", NeonGeo.cube(0.45), Color(1, 0.9, 0.7), 2.0, 0.2, 0.05)
			root.add_child(inner)
		"mine":
			var spin := _named("Spin", NeonGeo.build("star", NeonGeo.star(6, 1.15, 0.45, 0.35), color, 1.7, 0.14))
			root.add_child(spin)
		"tank":
			var spin := _named("Spin", NeonGeo.build("icosa", NeonGeo.icosa(1.5), color, 1.7, 0.12))
			root.add_child(spin)
			var orbit := Node3D.new()
			orbit.name = "Orbit"
			for i in 3:
				var a := TAU * i / 3.0
				var shard := NeonGeo.build("shard", NeonGeo.tetra(0.38), color.lightened(0.3), 2.0, 0.15, 0.05)
				shard.position = Vector3(cos(a), sin(a), 0) * 2.2
				orbit.add_child(shard)
			root.add_child(orbit)
	return root


## Boss: geodesic core inside a rotating chain of triangle "teeth".
static func boss(color: Color) -> Node3D:
	var root := Node3D.new()
	root.add_child(_named("Core", NeonGeo.build("boss_core", NeonGeo.icosa(2.2), color, 1.7, 0.1, 0.09)))
	root.add_child(NeonGeo.build("boss_heart", NeonGeo.octa(0.8), Color(1, 1, 1), 2.2, 0.25, 0.06))
	var ring_a := Node3D.new()
	ring_a.name = "RingA"
	for i in 14:
		var a := TAU * i / 14.0
		var tooth := NeonGeo.build("tooth", NeonGeo.extrude(PackedVector2Array([Vector2(-0.45, 0), Vector2(0.45, 0), Vector2(0, 0.85)]), 0.25),
			color.lightened(0.15), 1.8, 0.15, 0.06)
		tooth.position = Vector3(cos(a), sin(a), 0) * 3.4
		tooth.rotation.z = a - PI / 2
		ring_a.add_child(tooth)
	root.add_child(ring_a)
	var ring_b := _named("RingB", NeonGeo.build("boss_ring", NeonGeo.ring(4.3, 40), color, 1.6, 0.0, 0.06))
	root.add_child(ring_b)
	root.scale = Vector3.ONE * 0.8
	return root


static func pickup(kind: String) -> Node3D:
	var root := Node3D.new()
	var color := EnemyTypes.WEAPON_COLOR if kind == "weapon" else EnemyTypes.REPAIR_COLOR
	root.add_child(_named("Spin", NeonGeo.build("pick_" + kind, NeonGeo.octa(0.75, 1.4), color, 2.0, 0.18)))
	root.add_child(_named("Halo", NeonGeo.build("pick_ring", NeonGeo.ring(1.2, 24), color, 2.0, 0.0, 0.05)))
	var label := Label3D.new()
	label.text = "P" if kind == "weapon" else "+"
	label.font = UiStyle.display_font()
	label.font_size = 72
	label.outline_size = 16
	label.pixel_size = 0.012
	label.modulate = Color(1, 1, 1)
	label.outline_modulate = color.darkened(0.5)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.position = Vector3(0, 1.7, 0)
	root.add_child(label)
	root.scale = Vector3.ONE * 0.75
	return root


static func portal() -> Node3D:
	var root := Node3D.new()
	var ring := Node3D.new()
	ring.name = "Ring"
	ring.add_child(NeonGeo.build("portal_ring", NeonGeo.ring(6.2, 48), Color(0.6, 0.95, 1.0), 3.2, 0.0, 0.18))
	ring.add_child(NeonGeo.build("portal_star", NeonGeo.star(12, 6.0, 5.2, 0.25), Color(1, 1, 1), 2.4, 0.0, 0.08))
	root.add_child(ring)
	var inner := NeonGeo.build("portal_inner", NeonGeo.ring(4.2, 6), Color(1.0, 0.5, 1.0), 2.6, 0.0, 0.1)
	inner.name = "Inner"
	root.add_child(inner)
	var disc_mat := ShaderMaterial.new()
	disc_mat.shader = VORTEX_SHADER
	var disc := QuadMesh.new()
	disc.size = Vector2(12.5, 12.5)
	var disc_node := MeshInstance3D.new()
	disc_node.mesh = disc
	disc_node.material_override = disc_mat
	disc_node.name = "Disc"
	root.add_child(disc_node)
	return root


## Collects every mesh under a node so hit-flash/fade can be applied.
static func geometry_of(node: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		out.append(child as GeometryInstance3D)
	return out
