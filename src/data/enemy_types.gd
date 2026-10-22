class_name EnemyTypes
extends RefCounted
## Enemy catalogue. Each type has a unique shape AND colour so it is
## recognisable at a glance; the sector briefing lists them.

const TYPES := {
	"drone": {"name": "Dardo", "shape": "Tetraedro", "desc": "Voa em grupo. Frágil: um tiro basta.",
		"color": Color(1.0, 0.22, 0.42), "hp": 1.0, "score": 100, "radius": 1.0},
	"weaver": {"name": "Cata-vento", "shape": "Hélice", "desc": "Rápido, ziguezagueia pelo túnel.",
		"color": Color(0.72, 0.38, 1.0), "hp": 3.0, "score": 200, "radius": 1.0},
	"gunner": {"name": "Cubo", "shape": "Cubo", "desc": "Para à sua frente e atira em você.",
		"color": Color(1.0, 0.45, 0.1), "hp": 10.0, "score": 500, "radius": 1.2},
	"mine": {"name": "Mina", "shape": "Estrela", "desc": "Parada no túnel. Explode ao contato.",
		"color": Color(1.0, 0.2, 0.85), "hp": 6.0, "score": 250, "radius": 1.1},
	"seeker": {"name": "Esfera", "shape": "Orbe de energia", "desc": "Bola de energia que mergulha direto em você.",
		"color": Color(0.45, 0.65, 1.0), "hp": 4.0, "score": 300, "radius": 1.1},
	"swarm": {"name": "Enxame", "shape": "Estrela", "desc": "Faíscas em espiral que vêm na sua direção.",
		"color": Color(1.0, 0.3, 0.35), "hp": 1.0, "score": 60, "radius": 0.8},
	"phantom": {"name": "Espectro", "shape": "Losango fantasma", "desc": "Some e reaparece. O tiro carregado o revela.",
		"color": Color(0.7, 0.85, 1.0), "hp": 5.0, "score": 400, "radius": 1.1},
	"splitter": {"name": "Divisor", "shape": "Cubo duplo", "desc": "Ao morrer, divide-se em dois menores.",
		"color": Color(0.3, 1.0, 0.75), "hp": 6.0, "score": 250, "radius": 1.2},
	"warden": {"name": "Escudeiro", "shape": "Hexágono", "desc": "Protege inimigos próximos. Mate-o primeiro.",
		"color": Color(0.3, 0.6, 1.0), "hp": 8.0, "score": 600, "radius": 1.3},
	"laser": {"name": "Torre laser", "shape": "Torre", "desc": "Avisa com uma linha e dispara um feixe na faixa.",
		"color": Color(1.0, 0.25, 0.25), "hp": 8.0, "score": 500, "radius": 1.1},
	"serpent": {"name": "Serpente", "shape": "Corrente", "desc": "Só a cabeça leva dano; o corpo bloqueia tiros.",
		"color": Color(0.6, 1.0, 0.2), "hp": 14.0, "score": 1200, "radius": 1.3},
	"serpent_body": {"name": "Corpo da serpente", "shape": "Elo", "desc": "", "color": Color(0.45, 0.8, 0.15),
		"hp": 1.0, "score": 0, "radius": 0.9, "invulnerable": true, "hidden": true},
	"decoy": {"name": "Clone", "shape": "Clone", "desc": "", "color": Color(1.0, 0.35, 0.25),
		"hp": 2.0, "score": 150, "radius": 1.2, "hidden": true},
	"drifter": {"name": "Nave perdida", "shape": "Nave", "desc": "Inofensiva e foge quando atingida. Vale muitos pontos e solta power-up.",
		"color": Color(1.0, 0.78, 0.25), "hp": 8.0, "score": 3000, "radius": 1.4, "bonus": true},
	"tank": {"name": "Couraçado", "shape": "Icosaedro", "desc": "Blindado, tiro em leque. Sempre solta upgrade.",
		"color": Color(1.0, 0.82, 0.2), "hp": 28.0, "score": 1500, "radius": 1.8},
	"barrier": {"name": "Muralha", "shape": "Barreira", "desc": "INDESTRUTÍVEL. Passe pela abertura.",
		"color": Color(1.0, 0.85, 0.35), "hp": 1.0, "score": 0, "radius": 1.0, "invulnerable": true},
	"rotor": {"name": "Varredor", "shape": "Lâminas", "desc": "INDESTRUTÍVEL. Passe entre as lâminas.",
		"color": Color(1.0, 0.4, 0.3), "hp": 1.0, "score": 0, "radius": 1.0, "invulnerable": true},
	"pulse_ring": {"name": "Anel pulsante", "shape": "Anel", "desc": "INDESTRUTÍVEL. Fica letal no pulso: passe no intervalo.",
		"color": Color(1.0, 0.2, 0.5), "hp": 1.0, "score": 0, "radius": 1.0, "invulnerable": true},
	"spike": {"name": "Espinho", "shape": "Estrela fixa", "desc": "INDESTRUTÍVEL. Campo fixo: use os corredores.",
		"color": Color(1.0, 0.55, 0.2), "hp": 1.0, "score": 0, "radius": 1.0, "invulnerable": true},
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
	"missile": {"letter": "M", "name": "MÍSSEIS", "color": Color(1.0, 0.5, 0.2)},
	"slow": {"letter": "T", "name": "TEMPO", "color": Color(0.5, 0.9, 1.0)},
	"magnet": {"letter": "I", "name": "ÍMÃ", "color": Color(0.4, 1.0, 0.6)},
	"laser": {"letter": "L", "name": "LASER", "color": Color(0.7, 1.0, 1.0)},
}


static func powerup(kind: String) -> Dictionary:
	return POWERUPS[kind]


static func get_type(kind: String) -> Dictionary:
	return TYPES[kind]
