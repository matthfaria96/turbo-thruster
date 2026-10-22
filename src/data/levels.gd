class_name Levels
extends RefCounted
## Campaign sectors. Tunnel tints are cool and dim on purpose: enemies are
## warm (red/orange/yellow/magenta/violet) and the player is cyan/white.

const DATA := [
	{"name": "Aurora", "boss": "Sentinela", "length": 1500.0, "curve": 0.45,
		"tint": Color(0.3, 0.5, 1.0), "kinds": ["drone", "weaver", "swarm"], "density": 0.9,
		"boss_hp": 90.0, "boss_color": Color(1.0, 0.3, 0.2), "music": 0},
	{"name": "Corrente", "boss": "Hidra", "length": 1700.0, "curve": 0.55,
		"tint": Color(0.2, 0.8, 0.8), "kinds": ["drone", "weaver", "gunner", "swarm", "seeker"], "density": 1.0,
		"boss_hp": 130.0, "boss_color": Color(1.0, 0.55, 0.1), "music": 1},
	{"name": "Abismo", "boss": "Leviatã", "length": 1850.0, "curve": 0.6,
		"tint": Color(0.45, 0.4, 1.0), "kinds": ["drone", "weaver", "gunner", "mine", "swarm", "seeker"], "density": 1.1,
		"boss_hp": 170.0, "boss_color": Color(1.0, 0.2, 0.55), "music": 2},
	{"name": "Prisma", "boss": "Colosso", "length": 2000.0, "curve": 0.7,
		"tint": Color(0.3, 0.9, 0.55), "kinds": ["drone", "weaver", "gunner", "mine", "tank", "swarm", "seeker"], "density": 1.15,
		"boss_hp": 210.0, "boss_color": Color(1.0, 0.8, 0.15), "music": 3},
	{"name": "Vórtice", "boss": "Ciclone", "length": 2150.0, "curve": 0.8,
		"tint": Color(0.4, 0.6, 0.95), "kinds": ["drone", "weaver", "gunner", "mine", "tank", "swarm", "seeker"], "density": 1.25,
		"boss_hp": 250.0, "boss_color": Color(0.8, 0.3, 1.0), "music": 0},
	{"name": "Nebulosa", "boss": "Espectro", "length": 2300.0, "curve": 0.85,
		"tint": Color(0.6, 0.45, 1.0), "kinds": ["drone", "weaver", "gunner", "mine", "tank", "swarm", "seeker"], "density": 1.35,
		"boss_hp": 290.0, "boss_color": Color(1.0, 0.35, 0.25), "music": 1},
	{"name": "Fratura", "boss": "Quimera", "length": 2450.0, "curve": 0.95,
		"tint": Color(0.25, 0.7, 1.0), "kinds": ["drone", "weaver", "gunner", "mine", "tank", "swarm", "seeker"], "density": 1.45,
		"boss_hp": 330.0, "boss_color": Color(1.0, 0.6, 0.1), "music": 2},
	{"name": "Núcleo", "boss": "Coração do Toro", "length": 2600.0, "curve": 1.0,
		"tint": Color(0.75, 0.8, 1.0), "kinds": ["drone", "weaver", "gunner", "mine", "tank", "swarm", "seeker"], "density": 1.6,
		"boss_hp": 420.0, "boss_color": Color(1.0, 0.15, 0.3), "music": 3},
]


static func count() -> int:
	return DATA.size()


static func get_level(index: int) -> Dictionary:
	return DATA[clampi(index, 0, DATA.size() - 1)]


static func is_last(index: int) -> bool:
	return index >= DATA.size() - 1
