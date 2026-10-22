class_name Meshes
extends RefCounted
## All gameplay models, built from NeonGeo shapes (glowing edges + glass fill).

const PARTICLE_SHADER := preload("res://src/shaders/particle.gdshader")
const STREAK_SHADER := preload("res://src/shaders/streak.gdshader")
const VORTEX_SHADER := preload("res://src/shaders/vortex.gdshader")

static var _materials: Dictionary = {}


static func additive(energy := 2.5, core := 0.0, flare := 0.0) -> ShaderMaterial:
	return _cached("a%.2f|%.2f|%.2f" % [energy, core, flare], PARTICLE_SHADER, {"energy": energy, "core": core, "flare": flare})


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
		"seeker":
			var spin := _named("Spin", NeonGeo.build("seek_core", NeonGeo.icosa(0.75), color, 1.8, 0.2, 0.05))
			var spikes: Array = []
			var ico: Dictionary = NeonGeo.icosa(1.0)
			for v: Vector3 in ico.v:
				spikes.append([v * 0.7, v * 1.45])
			var spike_node := NeonGeo.instance_segments("seek_spikes", spikes, Color(0.75, 0.9, 1.0), 2.2, 0.04)
			spin.add_child(spike_node)
			root.add_child(spin)
			var glow_core := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE * 2.4
			glow_core.mesh = quad
			glow_core.material_override = additive(1.6, 0.8)
			root.add_child(glow_core)
		"swarm":
			var spin := _named("Spin", NeonGeo.build("swarm_star", NeonGeo.star(4, 0.9, 0.22, 0.15), color, 2.2, 0.3, 0.05))
			root.add_child(spin)
		"rotor":
			return rotor()
		"pulse_ring":
			return pulse_ring()
		"decoy":
			var d := boss(color)
			d.scale = Vector3.ONE * 0.45
			root.add_child(d)
		"phantom":
			var spin := _named("Spin", NeonGeo.build("phantom", NeonGeo.octa(1.0, 1.7), color, 1.9, 0.25))
			root.add_child(spin)
			var halo := NeonGeo.build("phantom_ring", NeonGeo.ring(1.4, 18), color.lightened(0.3), 1.6, 0.0, 0.04)
			root.add_child(halo)
		"splitter":
			root.add_child(_named("Spin", NeonGeo.build("split", NeonGeo.cube(1.1), color, 1.9, 0.18)))
			root.add_child(NeonGeo.build("split_in", NeonGeo.octa(0.7), color.lightened(0.4), 2.0, 0.2, 0.05))
		"warden":
			root.add_child(_named("Spin", NeonGeo.build("warden", NeonGeo.ring(1.3, 6, 0.4), color, 2.0, 0.2)))
			root.add_child(NeonGeo.build("warden_core", NeonGeo.octa(0.5), Color(1, 1, 1), 2.2, 0.3, 0.05))
		"laser":
			var base := NeonGeo.build("laser_base", NeonGeo.cube(1.0), color, 1.9, 0.2)
			base.scale = Vector3(1.2, 0.6, 1.2)
			root.add_child(base)
			root.add_child(_named("Spin", NeonGeo.build("laser_eye", NeonGeo.octa(0.55, 1.4), Color(1, 1, 1), 2.4, 0.4, 0.05)))
		"serpent":
			root.add_child(_named("Spin", NeonGeo.build("serp_head", NeonGeo.tetra(1.4), color, 2.0, 0.25)))
			root.add_child(NeonGeo.build("serp_eye", NeonGeo.octa(0.35), Color(1, 1, 1), 2.4, 0.4, 0.05))
		"serpent_body":
			root.add_child(_named("Spin", NeonGeo.build("serp_body", NeonGeo.icosa(0.8), color, 1.6, 0.12, 0.05)))
		"spike":
			root.add_child(_named("Spin", NeonGeo.build("spike", NeonGeo.star(5, 1.0, 0.35, 0.3), color, 2.2, 0.25)))
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
	var info := EnemyTypes.powerup(kind)
	var color: Color = info.color
	root.add_child(_named("Spin", NeonGeo.build("pick_" + kind, NeonGeo.octa(0.75, 1.4), color, 2.0, 0.18)))
	root.add_child(_named("Halo", NeonGeo.build("pick_ring", NeonGeo.ring(1.2, 24), color, 2.0, 0.0, 0.05)))
	var label := Label3D.new()
	label.text = info.letter
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


static func _radial(a: float, r: float) -> Vector3:
	return Vector3(sin(a), -cos(a), 0.0) * r


## Energy gate spanning an arc of the tunnel cross-section (centre angle 0).
static func barrier(half_width: float) -> Node3D:
	var segments := 12
	var v := PackedVector3Array()
	for i in segments + 1:
		var a := -half_width + 2.0 * half_width * i / segments
		v.append(_radial(a, Track.RADIUS - 0.15))
		v.append(_radial(a, Track.RADIUS - 3.6))
	var faces: Array = []
	for i in segments:
		var o := i * 2
		faces.append(PackedInt32Array([o, o + 2, o + 3, o + 1]))
	var color: Color = EnemyTypes.get_type("barrier").color
	var root := Node3D.new()
	root.add_child(NeonGeo.build("barrier%.2f" % half_width, {"v": v, "f": faces}, color, 2.2, 0.16, 0.09))
	return root


## Two laser blades sweeping the whole cross-section around the axis.
static func rotor() -> Node3D:
	var color: Color = EnemyTypes.get_type("rotor").color
	var spin := Node3D.new()
	spin.name = "Spin"
	var outer := Track.RADIUS - 0.1
	for k in 2:
		var blade := PackedVector2Array([Vector2(-0.22, -0.7), Vector2(0.22, -0.7), Vector2(0.32, -outer), Vector2(-0.32, -outer)])
		var node := NeonGeo.build("rotor_blade", NeonGeo.extrude(blade, 0.3), color, 2.6, 0.3, 0.08)
		node.rotation.z = k * PI
		spin.add_child(node)
	spin.add_child(NeonGeo.build("rotor_hub", NeonGeo.octa(0.8), Color(1, 1, 1), 2.2, 0.2, 0.06))
	var root := Node3D.new()
	root.add_child(spin)
	return root


## Full-circle hazard ring that pulses lethal (cross-section frame).
static func pulse_ring() -> Node3D:
	var color: Color = EnemyTypes.get_type("pulse_ring").color
	var root := Node3D.new()
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.add_child(NeonGeo.build("pulse_outer", NeonGeo.ring(Track.RADIUS - 0.3, 48, 0.4), color, 2.2, 0.1, 0.1))
	spin.add_child(NeonGeo.build("pulse_inner", NeonGeo.star(16, Track.RADIUS - 0.6, Track.RADIUS - 1.6, 0.2), color, 1.8, 0.1, 0.06))
	root.add_child(spin)
	return root


## Destructible boss piece: "head" (orb with eye) or "plate" (armour hexagon).
static func boss_part(shape: String, color: Color) -> Node3D:
	var root := Node3D.new()
	if shape == "head":
		root.add_child(NeonGeo.build("bpart_head", NeonGeo.icosa(1.0), color, 2.0, 0.18))
		root.add_child(NeonGeo.build("bpart_eye", NeonGeo.octa(0.35), Color(1, 1, 1), 2.6, 0.4, 0.05))
	else:
		var plate := NeonGeo.build("bpart_plate", NeonGeo.ring(1.0, 6, 0.35), color, 2.0, 0.25)
		root.add_child(plate)
	return root


## Hexagonal-looking geodesic energy bubble (subdivided icosahedron).
static func shield_bubble() -> Node3D:
	var ico: Dictionary = NeonGeo.icosa(1.0)
	var v: PackedVector3Array = ico.v
	var faces: Array = []
	var verts := PackedVector3Array(v)
	var mid: Dictionary = {}
	var midpoint := func(a: int, b: int) -> int:
		var key := Vector2i(mini(a, b), maxi(a, b))
		if not mid.has(key):
			verts.append(((verts[a] + verts[b]) * 0.5).normalized())
			mid[key] = verts.size() - 1
		return mid[key]
	for f: PackedInt32Array in ico.f:
		var ab: int = midpoint.call(f[0], f[1])
		var bc: int = midpoint.call(f[1], f[2])
		var ca: int = midpoint.call(f[2], f[0])
		for t in [[f[0], ab, ca], [ab, f[1], bc], [ca, bc, f[2]], [ab, bc, ca]]:
			faces.append(PackedInt32Array(t))
	var normalized := PackedVector3Array()
	for p in verts:
		normalized.append(p.normalized() * 1.9)
	var root := NeonGeo.build("shield", {"v": normalized, "f": faces}, Color(0.35, 0.8, 1.0), 1.4, 0.05, 0.03)
	root.name = "Shield"
	return root


## Collects every mesh under a node so hit-flash/fade can be applied.
static func geometry_of(node: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		out.append(child as GeometryInstance3D)
	return out
