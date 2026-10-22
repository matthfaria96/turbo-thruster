class_name Levels
extends RefCounted
## Campaign sectors. Tunnel tints are dim on purpose: enemies are bright and
## warm, the player is cyan. Length and enemy roster come from the sector's
## script (SectorScripts).

const DATA := [
	{"name": "Aurora", "boss": "Sentinela", "curve": 0.45, "tint": Color(0.3, 0.5, 1.0),
		"boss_hp": 110.0, "boss_color": Color(1.0, 0.3, 0.2), "music": "sector_a"},
	{"name": "Corrente", "boss": "Hidra", "curve": 0.55, "tint": Color(0.2, 0.8, 0.8),
		"boss_hp": 150.0, "boss_color": Color(1.0, 0.55, 0.1), "music": "sector_a"},
	{"name": "Abismo", "boss": "Leviatã", "curve": 0.6, "tint": Color(0.45, 0.4, 1.0),
		"boss_hp": 190.0, "boss_color": Color(1.0, 0.2, 0.55), "music": "sector_b"},
	{"name": "Prisma", "boss": "Colosso", "curve": 0.7, "tint": Color(0.3, 0.9, 0.55),
		"boss_hp": 230.0, "boss_color": Color(1.0, 0.8, 0.15), "music": "sector_b"},
	{"name": "Vórtice", "boss": "Ciclone", "curve": 0.8, "tint": Color(0.4, 0.6, 0.95),
		"boss_hp": 270.0, "boss_color": Color(0.8, 0.3, 1.0), "music": "sector_c"},
	{"name": "Nebulosa", "boss": "Espectro-Rei", "curve": 0.85, "tint": Color(0.6, 0.45, 1.0),
		"boss_hp": 320.0, "boss_color": Color(1.0, 0.35, 0.25), "music": "sector_c"},
	{"name": "Fratura", "boss": "Quimera", "curve": 0.95, "tint": Color(0.25, 0.7, 1.0),
		"boss_hp": 370.0, "boss_color": Color(1.0, 0.6, 0.1), "music": "sector_d"},
	{"name": "Forja", "boss": "Fornalha", "curve": 0.95, "tint": Color(0.75, 0.4, 0.55),
		"boss_hp": 420.0, "boss_color": Color(1.0, 0.75, 0.2), "music": "sector_d"},
	{"name": "Eclipse", "boss": "Gêmeos", "curve": 1.0, "tint": Color(0.5, 0.55, 0.75),
		"boss_hp": 470.0, "boss_color": Color(0.9, 0.35, 1.0), "music": "sector_e"},
	{"name": "Núcleo", "boss": "Coração do Toro", "curve": 1.05, "tint": Color(0.75, 0.8, 1.0),
		"boss_hp": 540.0, "boss_color": Color(1.0, 0.15, 0.3), "music": "sector_e"},
]


static func count() -> int:
	return DATA.size()


## Sector data plus derived "length", "acts" and "kinds".
static func get_level(index: int) -> Dictionary:
	var i := clampi(index, 0, DATA.size() - 1)
	var acts := SectorScripts.script_for(i)
	return (DATA[i] as Dictionary).merged({
		"length": SectorScripts.length_of(i),
		"acts": acts,
		"kinds": WavePlan.kinds_in(acts),
	})


## Synthetic endless "level" used by the arcade mode.
static func arcade_level() -> Dictionary:
	return {"name": "Arcade", "boss": "", "curve": 0.85, "tint": Color(0.45, 0.5, 1.0),
		"boss_hp": 0.0, "boss_color": Color(1, 0.2, 0.3), "music": "sector_a",
		"length": 1.0e9, "acts": [], "kinds": []}


static func is_last(index: int) -> bool:
	return index >= DATA.size() - 1
