class_name EnemyTypes
extends RefCounted
## Enemy catalogue. Each type has a unique shape AND colour so it is
## recognisable at a glance; the sector briefing lists them.

const TYPES := {
	"drone": {"name": "Drone", "desc": "Voa em grupo. Frágil: um tiro basta.",
		"color": Color(1.0, 0.28, 0.18), "hp": 1.0, "score": 100, "radius": 1.0},
	"weaver": {"name": "Vespa", "desc": "Rápida, ziguezagueia pelo túnel.",
		"color": Color(1.0, 0.85, 0.15), "hp": 2.0, "score": 150, "radius": 1.0},
	"gunner": {"name": "Atirador", "desc": "Para à sua frente e atira em você.",
		"color": Color(1.0, 0.5, 0.05), "hp": 5.0, "score": 300, "radius": 1.2},
	"mine": {"name": "Mina", "desc": "Parada no túnel. Explode ao contato.",
		"color": Color(1.0, 0.15, 0.6), "hp": 3.0, "score": 120, "radius": 1.1},
	"tank": {"name": "Couraçado", "desc": "Blindado, tiro em leque. Sempre solta upgrade.",
		"color": Color(0.75, 0.35, 1.0), "hp": 16.0, "score": 800, "radius": 1.8},
}

## Colours shared by gameplay feedback.
const PLAYER_COLOR := Color(0.3, 0.9, 1.0)
const BULLET_COLOR := Color(1.0, 0.18, 0.45)
const WEAPON_COLOR := Color(0.35, 1.0, 0.45)
const REPAIR_COLOR := Color(0.55, 0.75, 1.0)


static func get_type(kind: String) -> Dictionary:
	return TYPES[kind]
