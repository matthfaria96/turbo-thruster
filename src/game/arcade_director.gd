class_name ArcadeDirector
extends ActDirector
## Endless arcade difficulty. Stages by time; density follows
## 0.8 + 1.2 * (t / 360)^1.4 and keeps growing 15% every 30 s after 6 min.
## A mini-boss (elite) arrives every 90 s.

const STAGES := [
	{"until": 60.0, "title": "Aquecimento", "music": "sector_a",
		"patterns": {"drone_line": 3.0, "drone_v": 2.0, "swarm_spiral": 2.0, "weaver_snake": 1.0}},
	{"until": 150.0, "title": "Engrenando", "music": "sector_b",
		"patterns": {"drone_flood": 1.0, "weaver_snake": 2.0, "gunner_pair": 2.0, "seeker_dive": 2.0,
			"barrier_gate": 2.0, "swarm_spiral": 1.0, "splitter_pack": 1.0}},
	{"until": 240.0, "title": "Intenso", "music": "sector_c",
		"patterns": {"rotor": 2.0, "tank_escort": 2.0, "storm": 2.0, "seeker_rain": 1.0, "gauntlet": 1.0,
			"phantom_pack": 1.0, "laser_post": 1.0, "mine_ring": 1.0}},
	{"until": 360.0, "title": "Brutal", "music": "sector_e",
		"patterns": {"gunner_wall": 2.0, "storm": 2.0, "gauntlet": 2.0, "warden_guard": 1.0, "serpent": 1.0,
			"pulse_gate": 1.0, "drone_flood": 2.0, "laser_post": 1.0}},
	{"until": INF, "title": "Impossível", "music": "boss",
		"patterns": {"gunner_wall": 2.0, "storm": 2.0, "seeker_rain": 2.0, "gauntlet": 2.0, "serpent": 1.0,
			"warden_guard": 1.0, "double_gate": 1.0, "drone_flood": 2.0}},
]
const ELITE_EVERY := 90.0

var _rng := RandomNumberGenerator.new()
var _next_s := 160.0
var _elapsed := 0.0
var _next_elite := ELITE_EVERY
var _group := 0


func _init() -> void:
	super(STAGES.map(func(st: Dictionary) -> Dictionary:
		return {"title": st.title, "length": 0.0, "density": 1.0, "patterns": st.patterns, "mods": {}, "events": []}))
	_rng.randomize()


static func density_at(t: float) -> float:
	var d := 0.8 + 1.2 * pow(minf(t, 360.0) / 360.0, 1.4)
	if t > 360.0:
		d *= pow(1.15, (t - 360.0) / 30.0)
	return d


func stage_at(t: float) -> int:
	for i in STAGES.size():
		if t < STAGES[i].until:
			return i
	return STAGES.size() - 1


func music_for_stage() -> String:
	return STAGES[maxi(index, 0)].music


## Time-driven: picks the stage and ramps the modifiers.
func update(_s: float, dt: float) -> void:
	_t += dt
	var stage := stage_at(_elapsed)
	if stage != index:
		index = stage
		title = STAGES[stage].title
		act_started.emit(index, title)
	var k := clampf(_elapsed / 360.0, 0.0, 1.6)
	values = DEFAULTS.merged({"heat": 1.0 + 0.6 * k, "strobe": clampf(k * 0.8, 0.0, 1.0),
		"sway": clampf((k - 0.5) * 0.5, 0.0, 0.6), "quake": clampf(k - 0.7, 0.0, 1.0),
		"speed_floor": 0.0 if k < 0.6 else 44.0}, true)


## Spawns due at the ship's distance; `elapsed` is survived time.
func next_spawns(player_s: float, elapsed: float) -> Array[Dictionary]:
	_elapsed = elapsed
	var out: Array[Dictionary] = []
	if elapsed >= _next_elite:
		_next_elite += ELITE_EVERY
		out.append_array(_tag(WavePlan.pattern("elite", player_s + 120.0, _rng)))
	if player_s + 150.0 < _next_s:
		return out
	var patterns: Dictionary = STAGES[stage_at(elapsed)].patterns
	out.append_array(_tag(WavePlan.pattern(WavePlan.pick(_rng, patterns), _next_s, _rng)))
	_next_s += _rng.randf_range(62.0, 96.0) / density_at(elapsed)
	return out


func _tag(list: Array[Dictionary]) -> Array[Dictionary]:
	_group += 1
	for spec in list:
		spec["group"] = _group
	return list
