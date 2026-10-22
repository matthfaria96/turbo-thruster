class_name Track
extends RefCounted
## Analytic tunnel centre-line. Positions are expressed as
## (s = distance along the tunnel, th = angle around it, 0 = floor and
## positive = screen right, h = height above the wall).

const RADIUS := 7.0
const RAMP := 160.0
const CACHE_STEP := 0.5

var _waves_x: Array[Vector3] = []
var _waves_y: Array[Vector3] = []
var _origins := PackedVector3Array()
var _forwards := PackedVector3Array()


func _init(curve: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 2:
		var k := float(i + 1)
		_waves_x.append(Vector3(rng.randf_range(20.0, 34.0) * curve / k,
			rng.randf_range(0.006, 0.010) * k, rng.randf_range(0.0, TAU)))
		_waves_y.append(Vector3(rng.randf_range(10.0, 20.0) * curve / k,
			rng.randf_range(0.005, 0.008) * k, rng.randf_range(0.0, TAU)))


func center(s: float) -> Vector3:
	var x := 0.0
	var y := 0.0
	for w in _waves_x:
		x += w.x * sin(s * w.y + w.z)
	for w in _waves_y:
		y += w.x * sin(s * w.y + w.z)
	var ramp := smoothstep(0.0, RAMP, s)
	return Vector3(x * ramp, y * ramp, -s)


## Frame at distance s: x = right, y = up, -z = forward. Served from a
## lazily-grown lookup table (step CACHE_STEP) with linear interpolation.
func frame(s: float) -> Transform3D:
	var x := maxf(s, -CACHE_STEP * 2.0) / CACHE_STEP + 2.0
	var i := int(x)
	_ensure_cached(i + 1)
	var f := x - i
	var origin := _origins[i].lerp(_origins[i + 1], f)
	var forward := _forwards[i].lerp(_forwards[i + 1], f).normalized()
	var up := (Vector3.UP - forward * forward.dot(Vector3.UP)).normalized()
	return Transform3D(Basis(forward.cross(up), up, -forward), origin)


func _ensure_cached(index: int) -> void:
	while _origins.size() <= index:
		var cs := (_origins.size() - 2) * CACHE_STEP
		_origins.append(center(cs))
		_forwards.append((center(cs + 0.5) - center(cs - 0.5)).normalized())


## Unit vector from the axis toward the wall at angle th.
static func radial(fr: Transform3D, th: float) -> Vector3:
	return fr.basis.y * -cos(th) + fr.basis.x * sin(th)


func point(s: float, th: float, h: float) -> Vector3:
	var fr := frame(s)
	return fr.origin + radial(fr, th) * (RADIUS - h)


## Transform of an object standing on the wall: -z forward, +y toward the axis.
func pose(s: float, th: float, h: float) -> Transform3D:
	var fr := frame(s)
	var out := radial(fr, th)
	var up := -out
	var forward := -fr.basis.z
	var right := forward.cross(up).normalized()
	return Transform3D(Basis(right, up, -forward), fr.origin + out * (RADIUS - h))


static func angle_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


## Distance between two track-space points (approximated on the cylinder).
static func distance(s1: float, th1: float, h1: float, s2: float, th2: float, h2: float) -> float:
	var arc := angle_diff(th1, th2) * (RADIUS - (h1 + h2) * 0.5)
	return Vector3(s1 - s2, arc, h1 - h2).length()
