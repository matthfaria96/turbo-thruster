class_name BossSpecs
extends RefCounted
## One distinct boss per sector. Fields:
##   phases     [{at: hp ratio where the phase starts, patterns: [...], speed}]
##   parts      orbiting destructible pieces: {count, hp, radius, core_mult, shape}
##              core_mult = damage the core takes while any part survives
##   pull       angular pull on the ship toward the boss (rad/s)
##   cloak      seconds visible/invisible cycle; decoys spawned while hidden
##   twins      true = two bosses sharing the health pool
##   escort     enemy kind spawned in rage, "" for none

## Every bullet pattern BossPatterns knows how to fire.
const PATTERNS := ["fan", "ring", "spiral", "galaxy", "burst", "ring_wave", "cross", "rain"]

const SPECS := [
	{"phases": [{"at": 1.0, "patterns": ["fan", "ring"], "speed": 1.0},
			{"at": 0.5, "patterns": ["fan", "ring", "burst"], "speed": 1.3}],
		"escort": "drone"},
	{"phases": [{"at": 1.0, "patterns": ["fan", "burst"], "speed": 1.0},
			{"at": 0.4, "patterns": ["spiral", "fan"], "speed": 1.35}],
		"parts": {"count": 3, "hp": 28.0, "radius": 4.2, "core_mult": 0.0, "shape": "head"},
		"escort": "weaver"},
	{"phases": [{"at": 1.0, "patterns": ["galaxy", "fan"], "speed": 1.0},
			{"at": 0.5, "patterns": ["galaxy", "spiral", "burst"], "speed": 1.3}],
		"escort": "seeker"},
	{"phases": [{"at": 1.0, "patterns": ["ring", "burst"], "speed": 1.0},
			{"at": 0.5, "patterns": ["ring_wave", "fan"], "speed": 1.3}],
		"parts": {"count": 6, "hp": 22.0, "radius": 3.3, "core_mult": 0.2, "shape": "plate"},
		"escort": "gunner"},
	{"phases": [{"at": 1.0, "patterns": ["cross", "spiral"], "speed": 1.0},
			{"at": 0.5, "patterns": ["cross", "galaxy", "ring"], "speed": 1.4}],
		"pull": 0.55, "escort": "swarm"},
	{"phases": [{"at": 1.0, "patterns": ["fan", "rain"], "speed": 1.0},
			{"at": 0.5, "patterns": ["rain", "galaxy", "burst"], "speed": 1.35}],
		"cloak": [3.2, 2.2], "escort": "phantom"},
	{"phases": [{"at": 1.0, "patterns": ["fan", "ring"], "speed": 1.0},
			{"at": 0.75, "patterns": ["spiral", "burst"], "speed": 1.15},
			{"at": 0.5, "patterns": ["cross", "rain"], "speed": 1.3},
			{"at": 0.25, "patterns": ["galaxy", "ring_wave", "burst"], "speed": 1.5}],
		"escort": "splitter", "morph": true},
	{"phases": [{"at": 1.0, "patterns": ["ring_wave", "fan"], "speed": 1.0},
			{"at": 0.5, "patterns": ["ring_wave", "rain", "cross"], "speed": 1.4}],
		"parts": {"count": 4, "hp": 40.0, "radius": 3.6, "core_mult": 0.3, "shape": "plate"},
		"escort": "gunner"},
	{"phases": [{"at": 1.0, "patterns": ["fan", "spiral"], "speed": 1.0},
			{"at": 0.5, "patterns": ["galaxy", "cross", "burst"], "speed": 1.4}],
		"twins": true, "escort": "seeker"},
	{"phases": [{"at": 1.0, "patterns": ["fan", "ring", "burst"], "speed": 1.0},
			{"at": 0.66, "patterns": ["galaxy", "ring_wave", "cross"], "speed": 1.3},
			{"at": 0.33, "patterns": ["rain", "spiral", "galaxy", "ring_wave"], "speed": 1.6}],
		"parts": {"count": 5, "hp": 45.0, "radius": 4.0, "core_mult": 0.0, "shape": "head"},
		"pull": 0.3, "escort": "splitter", "morph": true},
]


static func for_level(index: int) -> Dictionary:
	return SPECS[clampi(index, 0, SPECS.size() - 1)]
