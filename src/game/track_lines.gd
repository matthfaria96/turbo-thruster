class_name TrackLines
extends Node3D
## Thick neon lines that follow the tunnel's curve, rebuilt every frame:
## laser beams (warning + firing), the player's laser power-up and the
## energy walls of narrowed lanes. One mesh per colour group.

const STEP := 4.0

var track: Track
var _layers: Dictionary = {}
var _pending: Dictionary = {}


func setup(p_track: Track) -> void:
	track = p_track


## Queues a line along the track at angle `th`, height `h`, from s0 to s1.
func line(key: String, color: Color, s0: float, s1: float, th: float, h: float, width := 0.1, energy := 2.4) -> void:
	if not _pending.has(key):
		_pending[key] = {"color": color, "width": width, "energy": energy, "segments": []}
	var segs: Array = _pending[key].segments
	var a := minf(s0, s1)
	var b := maxf(s0, s1)
	var prev := track.point(a, th, h)
	var s := a + STEP
	while s < b + STEP:
		var p := track.point(minf(s, b), th, h)
		segs.append([prev, p])
		prev = p
		s += STEP


## Builds the queued lines into meshes; layers with nothing queued are hidden.
func flush() -> void:
	for key: String in _layers:
		(_layers[key] as MeshInstance3D).visible = _pending.has(key)
	for key: String in _pending:
		var spec: Dictionary = _pending[key]
		var mi: MeshInstance3D = _layers.get(key)
		if mi == null:
			mi = MeshInstance3D.new()
			mi.custom_aabb = AABB(Vector3.ONE * -1e5, Vector3.ONE * 2e5)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_layers[key] = mi
		mi.material_override = NeonGeo.edge_material(spec.color, spec.energy, spec.width)
		var mesh := mi.mesh as ArrayMesh
		if mesh == null:
			mesh = ArrayMesh.new()
			mi.mesh = mesh
		NeonGeo.fill_edge_mesh(mesh, spec.segments)
	_pending = {}
