class_name WavePlan
extends RefCounted
## Deterministic list of enemy spawns for a sector, sorted by distance.

const START := 160.0

const PATTERNS_BY_KIND := {
	"drone": ["drone_line", "drone_ring", "drone_v"],
	"weaver": ["weaver_snake"],
	"gunner": ["gunner_pair"],
	"mine": ["minefield"],
	"tank": ["tank_escort"],
	"seeker": ["seeker_dive"],
	"swarm": ["swarm_spiral", "swarm_spiral"],
	"barrier": ["barrier_gate", "barrier_gate"],
	"rotor": ["rotor"],
}


static func build(level: Dictionary, index: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + index * 31
	var length: float = level.length
	var density: float = level.density
	var out: Array[Dictionary] = []
	var s := START
	while s < length - 120.0:
		var pattern := _pick(rng, level.kinds, s / length)
		out.append_array(_pattern(pattern, s, rng))
		s += rng.randf_range(62.0, 96.0) / density
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.s < b.s)
	return out


static func _pick(rng: RandomNumberGenerator, kinds: Array, progress: float) -> String:
	var options: Array[String] = []
	for kind: String in kinds:
		if kind == "tank" and progress < 0.3:
			continue
		for p: String in PATTERNS_BY_KIND[kind]:
			options.append(p)
	return options[rng.randi_range(0, options.size() - 1)]


static func _spawn(kind: String, s: float, th: float, phase := 0.0) -> Dictionary:
	return {"kind": kind, "s": s, "th": wrapf(th, -PI, PI), "phase": phase}


static func _pattern(name: String, s: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var c := rng.randf_range(-PI, PI)
	var out: Array[Dictionary] = []
	match name:
		"drone_line":
			for i in 5:
				out.append(_spawn("drone", s, c + (i - 2) * 0.34, i * 0.4))
		"drone_ring":
			for i in 8:
				out.append(_spawn("drone", s, c + TAU * i / 8.0, i * 0.3))
		"drone_v":
			for i in 5:
				out.append(_spawn("drone", s + absi(i - 2) * 6.0, c + (i - 2) * 0.3, 0.0))
		"weaver_snake":
			for i in 5:
				out.append(_spawn("weaver", s + i * 8.0, c, i * 0.7))
		"gunner_pair":
			out.append(_spawn("gunner", s, c - 0.7))
			out.append(_spawn("gunner", s, c + 0.7))
			for i in 3:
				out.append(_spawn("drone", s - 14.0, c + (i - 1) * 0.3, i * 0.5))
		"minefield":
			for i in 7:
				out.append(_spawn("mine", s + i * 9.0, rng.randf_range(-PI, PI)))
		"seeker_dive":
			for i in 3:
				out.append(_spawn("seeker", s + i * 10.0, c + (i - 1) * 0.8, i * 0.9))
		"swarm_spiral":
			for i in 12:
				out.append(_spawn("swarm", s + i * 2.5, c + i * TAU / 6.0, c + i * TAU / 6.0))
		"barrier_gate":
			out.append(_spawn("barrier", s, c, rng.randf_range(1.0, 2.0)))
			if rng.randf() < 0.45:
				out.append(_spawn("barrier", s + 26.0, c + PI, rng.randf_range(1.0, 1.8)))
		"rotor":
			out.append(_spawn("rotor", s, c, 1.0 if rng.randf() < 0.5 else -1.0))
		"tank_escort":
			out.append(_spawn("tank", s, c))
			out.append(_spawn("drone", s - 8.0, c - 0.55))
			out.append(_spawn("drone", s - 8.0, c + 0.55))
	return out
