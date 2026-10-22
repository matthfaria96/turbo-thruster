class_name Tunnel
extends Node3D
## Streams tunnel mesh chunks around the player so the level can be any length.

const CHUNK := 45.0
const PREFETCH := 120.0
const STEP := 1.5
const SEGMENTS := 36
const AHEAD := 320.0
const BEHIND := 30.0
const SHADER := preload("res://src/shaders/tunnel.gdshader")

const MAX_RIPPLES := 8

var track: Track
var material: ShaderMaterial
var _chunks: Dictionary = {}
var _now := 0.0
var _ripples := PackedVector4Array()
var _ripple_strength := PackedFloat32Array()
var _next_ripple := 0


func setup(p_track: Track, tint: Color) -> void:
	track = p_track
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", tint)
	material.render_priority = -10
	_ripples.resize(MAX_RIPPLES)
	_ripple_strength.resize(MAX_RIPPLES)
	for i in MAX_RIPPLES:
		_ripples[i] = Vector4(0, 0, 0, -100.0)
	_push_ripples()


func _process(delta: float) -> void:
	_now += delta
	material.set_shader_parameter("now", _now)


## Grid shock ripple (Geometry Wars style) centred at a world position.
func add_ripple(pos: Vector3, strength: float) -> void:
	_ripples[_next_ripple] = Vector4(pos.x, pos.y, pos.z, _now)
	_ripple_strength[_next_ripple] = strength
	_next_ripple = (_next_ripple + 1) % MAX_RIPPLES
	_push_ripples()


func _push_ripples() -> void:
	material.set_shader_parameter("ripples", _ripples)
	material.set_shader_parameter("ripple_strength", _ripple_strength)


## Keeps chunks around `s`. Chunks needed right now are built immediately;
## chunks further ahead (PREFETCH) are built at most one per frame so the
## game never hitches on tunnel generation.
func update_view(s: float) -> void:
	var first := int(floor(maxf(0.0, s - BEHIND) / CHUNK))
	var last := int(floor((s + AHEAD) / CHUNK))
	for ci in range(first, last + 1):
		if not _chunks.has(ci):
			_chunks[ci] = _build_chunk(ci)
	var prefetch := int(floor((s + AHEAD + PREFETCH) / CHUNK))
	for ci in range(last + 1, prefetch + 1):
		if not _chunks.has(ci):
			_chunks[ci] = _build_chunk(ci)
			break
	last = prefetch
	for ci: int in _chunks.keys():
		if ci < first or ci > last:
			(_chunks[ci] as Node).queue_free()
			_chunks.erase(ci)


func set_flash(value: float) -> void:
	material.set_shader_parameter("flash", value)


func set_brightness(value: float) -> void:
	material.set_shader_parameter("brightness", value)


func _build_chunk(ci: int) -> MeshInstance3D:
	var rings := int(CHUNK / STEP) + 1
	var cols := SEGMENTS + 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	verts.resize(rings * cols)
	uvs.resize(rings * cols)
	normals.resize(rings * cols)
	var vi := 0
	for r in rings:
		var s := ci * CHUNK + r * STEP
		var fr := track.frame(s)
		for k in cols:
			var a := TAU * k / SEGMENTS
			var out := Track.radial(fr, a)
			verts[vi] = fr.origin + out * Track.RADIUS
			normals[vi] = -out
			uvs[vi] = Vector2(float(k), s / 4.0)
			vi += 1
	var indices := PackedInt32Array()
	indices.resize((rings - 1) * SEGMENTS * 6)
	var ii := 0
	for r in rings - 1:
		for k in SEGMENTS:
			var a := r * cols + k
			var b := a + cols
			for v in [a, b, a + 1, a + 1, b, b + 1]:
				indices[ii] = v
				ii += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	add_child(mi)
	return mi
