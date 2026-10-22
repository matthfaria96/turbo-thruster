class_name Tunnel
extends Node3D
## Streams tunnel mesh chunks around the player so the level can be any length.

const CHUNK := 120.0
const STEP := 1.5
const SEGMENTS := 36
const AHEAD := 320.0
const BEHIND := 30.0
const SHADER := preload("res://src/shaders/tunnel.gdshader")

var track: Track
var material: ShaderMaterial
var _chunks: Dictionary = {}


func setup(p_track: Track, tint: Color) -> void:
	track = p_track
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", tint)


func update_view(s: float) -> void:
	var first := int(floor(maxf(0.0, s - BEHIND) / CHUNK))
	var last := int(floor((s + AHEAD) / CHUNK))
	for ci in range(first, last + 1):
		if not _chunks.has(ci):
			_chunks[ci] = _build_chunk(ci)
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
	verts.resize(rings * cols)
	uvs.resize(rings * cols)
	var vi := 0
	for r in rings:
		var s := ci * CHUNK + r * STEP
		var fr := track.frame(s)
		for k in cols:
			var a := TAU * k / SEGMENTS
			verts[vi] = fr.origin + Track.radial(fr, a) * Track.RADIUS
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
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
