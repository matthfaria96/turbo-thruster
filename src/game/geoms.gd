class_name Geoms
extends Node3D
## Green multiplier "geoms" dropped by destroyed enemies. They scatter, then
## home in on the ship when it is near. Each one collected raises the
## score multiplier.

const MAX_GEOMS := 260
const LIFETIME := 7.0
const MAGNET := 11.0
const COLLECT := 1.6

signal collected(pos: Vector3)

var track: Track
var _items: Array[Dictionary] = []
var _mm: MultiMesh


func setup(p_track: Track) -> void:
	track = p_track
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = _diamond_mesh()
	_mm.instance_count = MAX_GEOMS
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = NeonGeo.edge_material(EnemyTypes.GEOM_COLOR, 3.0, 0.05)
	mmi.custom_aabb = AABB(Vector3.ONE * -1e5, Vector3.ONE * 2e5)
	add_child(mmi)


func drop(s: float, th: float, h: float, count: int) -> void:
	for i in count:
		if _items.size() >= MAX_GEOMS:
			return
		_items.append({"s": s, "th": th, "h": h, "vs": randf_range(-6.0, 10.0),
			"vth": randf_range(-1.6, 1.6), "age": 0.0, "spin": randf() * TAU})


func update(dt: float, player: Player) -> void:
	var taken: Array[Dictionary] = []
	for g in _items:
		g.age += dt
		g.spin += dt * 4.0
		var dist := Track.distance(g.s, g.th, g.h, player.s, player.th, Player.H)
		if dist < MAGNET and player.alive:
			var pull := minf(1.0, dt * (6.0 + 30.0 / maxf(dist, 1.0)))
			g.s = lerpf(g.s, player.s + 0.5, pull)
			g.th = lerp_angle(g.th, player.th, pull)
			g.h = lerpf(g.h, Player.H, pull)
			if dist < COLLECT:
				taken.append(g)
		else:
			g.s += g.vs * dt
			g.th = wrapf(g.th + g.vth * dt, -PI, PI)
			g.vs *= 1.0 - minf(1.0, dt * 2.5)
			g.vth *= 1.0 - minf(1.0, dt * 2.5)
			g.h = lerpf(g.h, 1.2 + sin(g.age * 3.0 + g.spin) * 0.3, dt * 2.0)
	for g in taken:
		collected.emit(track.point(g.s, g.th, g.h))
	_items = _items.filter(func(g: Dictionary) -> bool:
		return not (g in taken) and g.age < LIFETIME and g.s > player.s - 6.0)


func render() -> void:
	_mm.visible_instance_count = _items.size()
	for i in _items.size():
		var g: Dictionary = _items[i]
		var blink: float = 1.0 if g.age < LIFETIME - 1.5 or fmod(g.age, 0.2) < 0.12 else 0.0
		var pose := track.pose(g.s, g.th, g.h)
		var basis := pose.basis * Basis(Vector3.UP, g.spin)
		_mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * 0.5 * blink), pose.origin))


static func _diamond_mesh() -> ArrayMesh:
	var top := Vector3(0, 0.6, 0)
	var bottom := Vector3(0, -0.6, 0)
	var ring := [Vector3(0.4, 0, 0), Vector3(0, 0, 0.4), Vector3(-0.4, 0, 0), Vector3(0, 0, -0.4)]
	var segs: Array = []
	for i in 4:
		segs.append([ring[i], ring[(i + 1) % 4]])
		segs.append([top, ring[i]])
		segs.append([bottom, ring[i]])
	return NeonGeo.edge_mesh_from_segments(segs)
