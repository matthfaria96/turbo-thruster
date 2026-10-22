class_name ActDirector
extends RefCounted
## Tracks which act of the sector script the ship is in and eases the act's
## modifiers in, so every act feels different (darkness, sway, strobe...).

signal act_started(index: int, title: String)

const DEFAULTS := {
	"speed_floor": 0.0, "spawn_ahead": 150.0, "brightness": 1.0,
	"strobe": 0.0, "sway": 0.0, "quake": 0.0, "heat": 1.0,
	"lane": PI, "lane_pulse": 0.0, "scorch": 0.0, "flip": 0.0,
}
const EASE_RATE := 0.8
const BEAT_HZ := 2.3

var index := -1
var title := ""
var count := 0
var values: Dictionary = DEFAULTS.duplicate()

var _acts: Array = []
var _starts := PackedFloat32Array()
var _t := 0.0
var _quake_cd := 2.0


func _init(acts: Array) -> void:
	_acts = acts
	_starts = WavePlan.act_starts(acts)
	count = acts.size()


func act_at(s: float) -> int:
	var found := 0
	for i in _starts.size():
		if s >= _starts[i]:
			found = i
	return found


## Advances time and blends the modifiers toward the current act's targets.
func update(s: float, dt: float) -> void:
	_t += dt
	var current := act_at(s)
	if current != index:
		index = current
		title = _acts[index].title
		act_started.emit(index, title)
	var mods: Dictionary = _acts[index].mods
	var k := minf(1.0, dt * EASE_RATE)
	var next := {}
	for key: String in DEFAULTS:
		next[key] = lerpf(float(values[key]), float(mods.get(key, DEFAULTS[key])), k)
	values = next


## 0 = calm respite, 1 = full intensity (drives the music filter).
func intensity() -> float:
	if index < 0 or _acts.is_empty():
		return 1.0
	var density: float = _acts[index].density
	return clampf(0.35 + (density - 0.6) + get_value("strobe") * 0.5, 0.0, 1.0)


func get_value(key: String) -> float:
	return float(values[key])


## 0..1 pulse on the beat, scaled by the act's strobe amount.
func strobe_pulse() -> float:
	var beat := pow(maxf(0.0, sin(_t * TAU * BEAT_HZ)), 10.0)
	return beat * get_value("strobe")


## Camera roll in radians from the act's sway amount.
func roll() -> float:
	return sin(_t * 0.55) * get_value("sway") + sin(_t * 1.7) * get_value("sway") * 0.25


## True when a quake shock should fire this frame.
func quake_due(dt: float) -> bool:
	var q := get_value("quake")
	if q < 0.05:
		return false
	_quake_cd -= dt
	if _quake_cd > 0.0:
		return false
	_quake_cd = lerpf(3.0, 1.1, q) * randf_range(0.7, 1.3)
	return true
