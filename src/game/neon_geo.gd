class_name NeonGeo
extends RefCounted
## Geometric neon shapes: a shape is a vertex list + polygon faces. Each one
## renders as a glassy translucent fill plus thick glowing edges.

const EDGE_SHADER := preload("res://src/shaders/neon_edge.gdshader")
const FILL_SHADER := preload("res://src/shaders/neon_fill.gdshader")
const PHI := 1.618034

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


# ------------------------------------------------------------------ shapes
# Each returns {"v": PackedVector3Array, "f": Array[PackedInt32Array]}.

static func tetra(r := 1.0) -> Dictionary:
	var v := PackedVector3Array([Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1)])
	return _scaled({"v": v, "f": [PackedInt32Array([0, 1, 2]), PackedInt32Array([0, 3, 1]),
		PackedInt32Array([0, 2, 3]), PackedInt32Array([1, 3, 2])]}, r / sqrt(3.0))


static func cube(r := 1.0) -> Dictionary:
	var v := PackedVector3Array()
	for i in 8:
		v.append(Vector3(-1 if i & 1 == 0 else 1, -1 if i & 2 == 0 else 1, -1 if i & 4 == 0 else 1))
	var f := [PackedInt32Array([0, 1, 3, 2]), PackedInt32Array([4, 6, 7, 5]), PackedInt32Array([0, 4, 5, 1]),
		PackedInt32Array([2, 3, 7, 6]), PackedInt32Array([0, 2, 6, 4]), PackedInt32Array([1, 5, 7, 3])]
	return _scaled({"v": v, "f": f}, r / sqrt(3.0))


static func octa(r := 1.0, stretch := 1.0) -> Dictionary:
	var v := PackedVector3Array([Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, stretch, 0),
		Vector3(0, -stretch, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)])
	var f := [PackedInt32Array([0, 2, 4]), PackedInt32Array([4, 2, 1]), PackedInt32Array([1, 2, 5]),
		PackedInt32Array([5, 2, 0]), PackedInt32Array([0, 4, 3]), PackedInt32Array([4, 1, 3]),
		PackedInt32Array([1, 5, 3]), PackedInt32Array([5, 0, 3])]
	return _scaled({"v": v, "f": f}, r)


static func icosa(r := 1.0) -> Dictionary:
	var v := PackedVector3Array([
		Vector3(-1, PHI, 0), Vector3(1, PHI, 0), Vector3(-1, -PHI, 0), Vector3(1, -PHI, 0),
		Vector3(0, -1, PHI), Vector3(0, 1, PHI), Vector3(0, -1, -PHI), Vector3(0, 1, -PHI),
		Vector3(PHI, 0, -1), Vector3(PHI, 0, 1), Vector3(-PHI, 0, -1), Vector3(-PHI, 0, 1)])
	var tris := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var f: Array = []
	for t: Array in tris:
		f.append(PackedInt32Array(t))
	return _scaled({"v": v, "f": f}, r / sqrt(1.0 + PHI * PHI))


## Flat 2D outline (XY, facing +Z) extruded along Z.
static func extrude(points: PackedVector2Array, depth: float) -> Dictionary:
	var n := points.size()
	var v := PackedVector3Array()
	for p in points:
		v.append(Vector3(p.x, p.y, depth * 0.5))
	for p in points:
		v.append(Vector3(p.x, p.y, -depth * 0.5))
	var front := PackedInt32Array()
	var back := PackedInt32Array()
	for i in n:
		front.append(i)
		back.append(2 * n - 1 - i)
	var f := [front, back]
	for i in n:
		var j := (i + 1) % n
		f.append(PackedInt32Array([i, n + i, n + j, j]))
	return {"v": v, "f": f}


static func ring(radius: float, segments: int, thickness := 0.0) -> Dictionary:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	if thickness <= 0.0:
		return {"v": PackedVector3Array(Array(pts).map(func(p: Vector2) -> Vector3: return Vector3(p.x, p.y, 0))),
			"f": [PackedInt32Array(range(segments))]}
	return extrude(pts, thickness)


static func star(points: int, outer: float, inner: float, depth: float) -> Dictionary:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := PI * i / points + PI / 2.0
		pts.append(Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
	return extrude(pts, depth)


static func _scaled(shape: Dictionary, k: float) -> Dictionary:
	var v := PackedVector3Array()
	for p: Vector3 in shape.v:
		v.append(p * k)
	return {"v": v, "f": shape.f}


# ---------------------------------------------------------------- building

## Builds a Node3D with fill + edges. `key` caches the generated meshes.
static func build(key: String, shape: Dictionary, color: Color, energy := 2.4, fill := 0.22, width := 0.07) -> Node3D:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = [_fill_mesh(shape), _edge_mesh(shape)]
	var meshes: Array = _mesh_cache[key]
	var root := Node3D.new()
	if fill > 0.0:
		root.add_child(_instance(meshes[0], fill_material(color, fill)))
	root.add_child(_instance(meshes[1], edge_material(color, energy, width)))
	return root


## Raw line segments (e.g. spikes) as a cached thick-line mesh instance.
static func instance_segments(key: String, segments: Array, color: Color, energy := 2.4, width := 0.07) -> MeshInstance3D:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = [null, edge_mesh_from_segments(segments)]
	return _instance(_mesh_cache[key][1], edge_material(color, energy, width))


static func edge_material(color: Color, energy := 2.4, width := 0.07) -> ShaderMaterial:
	var key := "e%s|%.2f|%.3f" % [color.to_html(), energy, width]
	if not _mat_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = EDGE_SHADER
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("energy", energy)
		m.set_shader_parameter("width", width)
		_mat_cache[key] = m
	return _mat_cache[key]


static func fill_material(color: Color, strength := 0.22) -> ShaderMaterial:
	var key := "f%s|%.2f" % [color.to_html(), strength]
	if not _mat_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = FILL_SHADER
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("strength", strength)
		_mat_cache[key] = m
	return _mat_cache[key]


static func _instance(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	return mi


static func _fill_mesh(shape: Dictionary) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var v: PackedVector3Array = shape.v
	for face: PackedInt32Array in shape.f:
		if face.size() < 3:
			continue
		var n := (v[face[1]] - v[face[0]]).cross(v[face[2]] - v[face[0]]).normalized()
		for i in range(1, face.size() - 1):
			for idx in [face[0], face[i], face[i + 1]]:
				verts.append(v[idx])
				normals.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _edge_mesh(shape: Dictionary) -> ArrayMesh:
	var v: PackedVector3Array = shape.v
	var seen: Dictionary = {}
	var edges: Array[Vector2i] = []
	for face: PackedInt32Array in shape.f:
		for i in face.size():
			var a := face[i]
			var b := face[(i + 1) % face.size()]
			var k := Vector2i(mini(a, b), maxi(a, b))
			if not seen.has(k):
				seen[k] = true
				edges.append(k)
	return edge_mesh_from_segments(edges.map(func(e: Vector2i) -> Array: return [v[e.x], v[e.y]]))


## segments: Array of [Vector3, Vector3]. Each becomes a camera-facing quad.
static func edge_mesh_from_segments(segments: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	fill_edge_mesh(mesh, segments)
	return mesh


## Rebuilds `mesh` in place (reused every frame by TrackLines).
static func fill_edge_mesh(mesh: ArrayMesh, segments: Array) -> void:
	mesh.clear_surfaces()
	var verts := PackedVector3Array()
	var others := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for seg: Array in segments:
		var p: Vector3 = seg[0]
		var q: Vector3 = seg[1]
		var base := verts.size()
		for spec in [[p, q, 1.0], [p, q, -1.0], [q, p, 1.0], [q, p, -1.0]]:
			verts.append(spec[0])
			var o: Vector3 = spec[1]
			others.append_array(PackedFloat32Array([o.x, o.y, o.z, 0.0]))
			uvs.append(Vector2(spec[2], 0.0))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_CUSTOM0] = others
	arrays[Mesh.ARRAY_INDEX] = indices
	if not verts.is_empty():
		var fmt := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
