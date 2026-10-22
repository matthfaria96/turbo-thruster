class_name EnemyTypes
extends RefCounted
## Enemy catalogue. Each type has a unique shape AND colour so it is
## recognisable at a glance; the sector briefing lists them.

const TYPES := {
	"drone": {"name": "Dardo", "shape": "Tetraedro", "desc": "Voa em grupo. Frágil: um tiro basta.",
		"color": Color(1.0, 0.22, 0.42), "hp": 1.0, "score": 100, "radius": 1.0},
	"weaver": {"name": "Cata-vento", "shape": "Hélice", "desc": "Rápido, ziguezagueia pelo túnel.",
		"color": Color(0.72, 0.38, 1.0), "hp": 2.0, "score": 150, "radius": 1.0},
	"gunner": {"name": "Cubo", "shape": "Cubo", "desc": "Para à sua frente e atira em você.",
		"color": Color(1.0, 0.45, 0.1), "hp": 5.0, "score": 300, "radius": 1.2},
	"mine": {"name": "Mina", "shape": "Estrela", "desc": "Parada no túnel. Explode ao contato.",
		"color": Color(1.0, 0.2, 0.85), "hp": 3.0, "score": 120, "radius": 1.1},
	"seeker": {"name": "Esfera", "shape": "Orbe de energia", "desc": "Bola de energia que mergulha direto em você.",
		"color": Color(0.45, 0.65, 1.0), "hp": 2.0, "score": 180, "radius": 1.1},
	"swarm": {"name": "Enxame", "shape": "Estrela", "desc": "Faíscas em espiral que vêm na sua direção.",
		"color": Color(1.0, 0.3, 0.35), "hp": 1.0, "score": 60, "radius": 0.8},
	"tank": {"name": "Couraçado", "shape": "Icosaedro", "desc": "Blindado, tiro em leque. Sempre solta upgrade.",
		"color": Color(1.0, 0.82, 0.2), "hp": 16.0, "score": 800, "radius": 1.8},
}

## Colours shared by gameplay feedback.
const PLAYER_COLOR := Color(0.3, 0.9, 1.0)
const BULLET_COLOR := Color(1.0, 0.3, 0.12)
const SHOT_COLOR := Color(1.0, 0.85, 0.3)
const WEAPON_COLOR := Color(0.35, 1.0, 0.45)
const REPAIR_COLOR := Color(0.85, 0.95, 1.0)
const GEOM_COLOR := Color(0.4, 1.0, 0.5)


## Power-ups that drop during a sector (they never carry over).
const POWERUPS := {
	"weapon": {"letter": "P", "name": "ARMA +1", "color": Color(0.35, 1.0, 0.45)},
	"repair": {"letter": "+", "name": "REPARO", "color": Color(0.85, 0.95, 1.0)},
	"shield": {"letter": "E", "name": "ESCUDO", "color": Color(0.35, 0.8, 1.0)},
	"rapid": {"letter": "R", "name": "RAJADA", "color": Color(1.0, 0.6, 0.15)},
	"bomb": {"letter": "B", "name": "BOMBA", "color": Color(1.0, 0.35, 0.9)},
}


static func powerup(kind: String) -> Dictionary:
	return POWERUPS[kind]


static func get_type(kind: String) -> Dictionary:
	return TYPES[kind]
