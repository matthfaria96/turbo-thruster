class_name WavePlan
extends RefCounted
## Deterministic spawn list for a sector, built act by act from its script
## (SectorScripts). Entries are sorted by distance `s`. Kinds starting with
## "pickup_" are power-ups placed in the tunnel instead of enemies.

const START := 160.0
const ACT_MARGIN := 40.0

## Which enemy kinds each pattern uses (drives the level-select legend).
const PATTERN_KINDS := {
	"drone_line": ["drone"], "drone_ring": ["drone"], "drone_v": ["drone"], "drone_flood": ["drone"],
	"weaver_snake": ["weaver"], "gunner_pair": ["gunner", "drone"], "gunner_wall": ["gunner"],
	"minefield": ["mine"], "mine_ring": ["mine"], "tank_escort": ["tank", "drone"],
	"seeker_dive": ["seeker"], "seeker_rain": ["seeker"], "swarm_spiral": ["swarm"], "storm": ["swarm"],
	"barrier_gate": ["barrier"], "rotor": ["rotor"], "gauntlet": ["barrier", "rotor"],
	"elite": ["tank", "gunner"], "bonus": [],
	"double_gate": ["barrier"], "pulse_gate": ["pulse_ring"], "mine_grid": ["spike"],
	"phantom_pack": ["phantom"], "splitter_pack": ["splitter"], "warden_guard": ["warden", "gunner", "drone"],
	"laser_post": ["laser"], "serpent": ["serpent"],
}
const POWERUP_KINDS := ["weapon", "shield", "rapid", "bomb", "repair", "missile", "slow", "magnet", "laser"]


static func build(level: Dictionary, index: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + index * 31
	var out: Array[Dictionary] = []
	var group := 0
	var act_start := 0.0
	for a: Dictionary in level.acts:
		var act_end: float = act_start + a.length
		var s := maxf(act_start + ACT_MARGIN, START)
		while s < act_end - ACT_MARGIN:
			group += 1
			out.append_array(_grouped(pattern(pick(rng, a.patterns), s, rng), group))
			s += rng.randf_range(62.0, 96.0) / float(a.density)
		for ev: Array in a.events:
			var at := minf(act_start + a.length * float(ev[0]), act_end - 120.0)
			group += 1
			out.append_array(_grouped(pattern(ev[1], at, rng), group))
		act_start = act_end
	var boss_line := act_start - 20.0
	out = out.filter(func(x: Dictionary) -> bool: return x.s < boss_line)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.s < y.s)
	return out


## Start distance of each act, in order.
static func act_starts(acts: Array) -> PackedFloat32Array:
	var starts := PackedFloat32Array()
	var s := 0.0
	for a: Dictionary in acts:
		starts.append(s)
		s += a.length
	return starts


static func kinds_in(acts: Array) -> Array[String]:
	var kinds: Array[String] = []
	for a: Dictionary in acts:
		var names: Array = a.patterns.keys()
		for ev: Array in a.events:
			names.append(ev[1])
		for p: String in names:
			for k: String in PATTERN_KINDS.get(p, []):
				if not (k in kinds):
					kinds.append(k)
	return kinds


static func _grouped(list: Array[Dictionary], group: int) -> Array[Dictionary]:
	for spec in list:
		spec["group"] = group
	return list


static func pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for w: float in weights.values():
		total += w
	var roll := rng.randf() * total
	for p: String in weights:
		roll -= float(weights[p])
		if roll <= 0.0:
			return p
	return weights.keys()[0]


static func _spawn(kind: String, s: float, th: float, phase := 0.0, extra := {}) -> Dictionary:
	return {"kind": kind, "s": s, "th": wrapf(th, -PI, PI), "phase": phase}.merged(extra)


static func pattern(name: String, s: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
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
				out.append(_spawn("drone", s + absi(i - 2) * 6.0, c + (i - 2) * 0.3))
		"drone_flood":
			for ring in 3:
				for i in 8:
					out.append(_spawn("drone", s + ring * 14.0, c + ring * 0.4 + TAU * i / 8.0, i * 0.3))
		"weaver_snake":
			for i in 5:
				out.append(_spawn("weaver", s + i * 8.0, c, i * 0.7))
		"gunner_pair":
			out.append(_spawn("gunner", s, c - 0.7))
			out.append(_spawn("gunner", s, c + 0.7))
			for i in 3:
				out.append(_spawn("drone", s - 14.0, c + (i - 1) * 0.3, i * 0.5))
		"gunner_wall":
			for i in 4:
				out.append(_spawn("gunner", s + i * 3.0, c + (i - 1.5) * 0.9))
		"minefield":
			for i in 7:
				out.append(_spawn("mine", s + i * 9.0, rng.randf_range(-PI, PI)))
		"mine_ring":
			for i in 8:
				out.append(_spawn("mine", s, c + TAU * i / 10.0))
		"tank_escort":
			out.append(_spawn("tank", s, c))
			out.append(_spawn("drone", s - 8.0, c - 0.55))
			out.append(_spawn("drone", s - 8.0, c + 0.55))
		"elite":
			out.append(_spawn("tank", s, c, 0.0, {"elite": true}))
			out.append(_spawn("gunner", s - 6.0, c - 0.9))
			out.append(_spawn("gunner", s - 6.0, c + 0.9))
		"seeker_dive":
			for i in 3:
				out.append(_spawn("seeker", s + i * 10.0, c + (i - 1) * 0.8, i * 0.9))
		"seeker_rain":
			for i in 6:
				out.append(_spawn("seeker", s + i * 7.0, c + i * 1.05, i * 0.6))
		"swarm_spiral":
			for i in 12:
				out.append(_spawn("swarm", s + i * 2.5, c + i * TAU / 6.0, c + i * TAU / 6.0))
		"storm":
			for arm in 3:
				for i in 10:
					var a := c + arm * TAU / 3.0 + i * 0.5
					out.append(_spawn("swarm", s + arm * 6.0 + i * 2.2, a, a))
		"barrier_gate":
			out.append(_spawn("barrier", s, c, rng.randf_range(1.0, 2.0)))
			if rng.randf() < 0.45:
				out.append(_spawn("barrier", s + 26.0, c + PI, rng.randf_range(1.0, 1.8)))
		"rotor":
			out.append(_spawn("rotor", s, c, 1.0 if rng.randf() < 0.5 else -1.0))
		"gauntlet":
			for i in 4:
				if i % 2 == 0:
					out.append(_spawn("barrier", s + i * 24.0, c + i * 1.7, rng.randf_range(1.2, 1.9)))
				else:
					out.append(_spawn("rotor", s + i * 24.0, c, 1.0 if i % 4 == 1 else -1.0))
		"double_gate":
			out.append(_spawn("barrier", s, c, 2.3))
			out.append(_spawn("barrier", s + 14.0, c + PI, 2.3))
		"pulse_gate":
			for i in 3:
				out.append(_spawn("pulse_ring", s + i * 30.0, 0.0, i * 0.8))
		"mine_grid":
			for row in 4:
				for i in 6:
					if i != row % 6 and i != (row + 3) % 6:
						out.append(_spawn("spike", s + row * 12.0, c + TAU * i / 6.0))
		"phantom_pack":
			for i in 4:
				out.append(_spawn("phantom", s + i * 6.0, c + (i - 1.5) * 0.7, i * 0.7))
		"splitter_pack":
			out.append(_spawn("splitter", s, c - 0.6))
			out.append(_spawn("splitter", s + 8.0, c + 0.6))
		"warden_guard":
			out.append(_spawn("warden", s + 4.0, c))
			out.append(_spawn("gunner", s, c - 0.5))
			out.append(_spawn("gunner", s, c + 0.5))
			for i in 4:
				out.append(_spawn("drone", s - 6.0, c + (i - 1.5) * 0.35, i * 0.5))
		"laser_post":
			out.append(_spawn("laser", s, c))
			if rng.randf() < 0.5:
				out.append(_spawn("laser", s + 6.0, c + rng.randf_range(1.5, 3.0)))
		"serpent":
			out.append(_spawn("serpent", s, c, 0.0, {"segments": 9}))
		"bonus":
			for i in 3:
				var item: String = POWERUP_KINDS[rng.randi_range(0, POWERUP_KINDS.size() - 1)]
				out.append(_spawn("pickup_" + item, s + i * 12.0, c + (i - 1) * 0.5))
	return out
