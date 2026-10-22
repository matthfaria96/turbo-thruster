class_name SectorScripts
extends RefCounted
## Each sector is a script of ACTS. An act has a title (announced on entry),
## a length in track units, a spawn density, weighted wave patterns, one-off
## events at a fraction of the act, and modifiers that change how it feels:
##   speed_floor  forced minimum speed ("zona turbo")
##   spawn_ahead  how far ahead enemies appear (low = they burst out of the dark)
##   brightness   tunnel brightness (low = darkness)
##   strobe       tunnel pulsing to the beat, 0..1
##   sway         camera roll amplitude in radians (disorienting)
##   quake        periodic tunnel shock waves, 0..1
##   heat         enemy fire-rate multiplier

const BONUS := {"drone_ring": 1.0}


static func act(title: String, length: float, density: float, patterns: Dictionary,
		mods := {}, events := []) -> Dictionary:
	return {"title": title, "length": length, "density": density, "patterns": patterns,
		"mods": mods, "events": events}


static func respite(title := "Respiro") -> Dictionary:
	return act(title, 650.0, 0.5, BONUS, {"brightness": 1.1}, [[0.15, "bonus"], [0.6, "bonus"]])


static func script_for(index: int) -> Array[Dictionary]:
	match index:
		0: return _aurora()
		1: return _corrente()
		2: return _abismo()
		3: return _prisma()
		4: return _vortice()
		5: return _nebulosa()
		6: return _fratura()
		7: return _forja()
		8: return _eclipse()
	return _nucleo()


static func length_of(index: int) -> float:
	var total := 0.0
	for a in script_for(index):
		total += a.length
	return total


static func _aurora() -> Array[Dictionary]:
	return [
		act("Decolagem", 900.0, 0.8, {"drone_line": 3.0, "drone_v": 2.0}),
		act("Primeiro enxame", 1000.0, 0.9, {"swarm_spiral": 3.0, "drone_line": 1.0}),
		act("Portões", 900.0, 0.9, {"barrier_gate": 3.0, "drone_v": 1.0}),
		respite(),
		act("Corrida final", 1400.0, 1.1, {"drone_line": 2.0, "swarm_spiral": 2.0, "weaver_snake": 2.0,
			"barrier_gate": 1.0}, {"speed_floor": 44.0, "strobe": 0.3}),
	]


static func _corrente() -> Array[Dictionary]:
	return [
		act("Correnteza", 1000.0, 0.9, {"weaver_snake": 3.0, "drone_v": 2.0}),
		act("Fogo cruzado", 1100.0, 1.0, {"gunner_pair": 3.0, "drone_line": 2.0}, {"heat": 1.1}),
		act("Lâminas", 1000.0, 1.0, {"rotor": 2.0, "barrier_gate": 2.0, "double_gate": 1.0, "swarm_spiral": 1.0}, {"sway": 0.15}),
		respite(),
		act("Maré alta", 1500.0, 1.2, {"weaver_snake": 2.0, "seeker_dive": 2.0, "gunner_pair": 2.0, "storm": 1.0},
			{"strobe": 0.4}, [[0.5, "elite"]]),
	]


static func _abismo() -> Array[Dictionary]:
	return [
		act("Descida", 1000.0, 1.0, {"drone_ring": 2.0, "minefield": 2.0, "swarm_spiral": 1.0}),
		act("Escuridão", 1300.0, 1.0, {"seeker_dive": 3.0, "swarm_spiral": 2.0, "minefield": 1.0, "phantom_pack": 1.0},
			{"brightness": 0.35, "spawn_ahead": 80.0}),
		act("Campo minado", 1100.0, 1.1, {"mine_ring": 3.0, "minefield": 2.0, "rotor": 1.0}),
		respite(),
		act("Olhos no escuro", 1700.0, 1.25, {"seeker_rain": 2.0, "gunner_pair": 2.0, "storm": 1.0},
			{"brightness": 0.3, "spawn_ahead": 75.0, "strobe": 0.5}, [[0.6, "elite"]]),
	]


static func _prisma() -> Array[Dictionary]:
	return [
		act("Refração", 1100.0, 1.0, {"drone_v": 2.0, "weaver_snake": 2.0, "barrier_gate": 2.0}),
		act("Corredor de lâminas", 1300.0, 1.0, {"gauntlet": 3.0, "rotor": 2.0}, {"sway": 0.2}),
		act("Couraçados", 1200.0, 1.1, {"tank_escort": 2.0, "gunner_pair": 2.0, "splitter_pack": 2.0}, {"heat": 1.15}, [[0.5, "elite"]]),
		respite(),
		act("Caleidoscópio", 1700.0, 1.3, {"storm": 2.0, "gauntlet": 2.0, "seeker_dive": 2.0, "gunner_wall": 1.0},
			{"strobe": 0.7, "sway": 0.3, "heat": 1.2}),
	]


static func _vortice() -> Array[Dictionary]:
	return [
		act("Redemoinho", 1200.0, 1.1, {"swarm_spiral": 3.0, "weaver_snake": 2.0}, {"sway": 0.4}),
		act("Olho do furacão", 1200.0, 1.2, {"storm": 2.0, "pulse_gate": 2.0, "splitter_pack": 1.0},
			{"sway": 0.5, "speed_floor": 46.0, "lane": 1.6}),
		respite(),
		act("Tempestade", 1500.0, 1.3, {"seeker_rain": 2.0, "gunner_wall": 2.0, "drone_flood": 2.0},
			{"sway": 0.5, "strobe": 0.5, "heat": 1.2}, [[0.4, "elite"], [0.8, "elite"]]),
		act("Turbo", 1500.0, 1.4, {"gauntlet": 2.0, "drone_flood": 2.0, "storm": 1.0, "pulse_gate": 1.0},
			{"speed_floor": 52.0, "sway": 0.3, "strobe": 0.6, "lane": 2.0}),
	]


static func _nebulosa() -> Array[Dictionary]:
	return [
		act("Névoa", 1300.0, 1.1, {"phantom_pack": 3.0, "seeker_dive": 2.0, "weaver_snake": 1.0},
			{"brightness": 0.4, "spawn_ahead": 70.0}),
		act("Ecos", 1300.0, 1.2, {"storm": 2.0, "warden_guard": 2.0, "barrier_gate": 2.0}, {"quake": 0.5}),
		act("Cegueira", 1200.0, 1.2, {"seeker_rain": 2.0, "phantom_pack": 2.0, "mine_ring": 1.0},
			{"brightness": 0.2, "spawn_ahead": 60.0, "strobe": 0.4}),
		respite("Clareira"),
		act("Supernova", 1900.0, 1.45, {"drone_flood": 2.0, "gunner_wall": 2.0, "gauntlet": 1.0, "storm": 2.0},
			{"strobe": 0.8, "quake": 0.6, "heat": 1.3}, [[0.3, "elite"], [0.75, "elite"]]),
	]


static func _fratura() -> Array[Dictionary]:
	return [
		act("Rachaduras", 1300.0, 1.2, {"barrier_gate": 2.0, "splitter_pack": 2.0, "drone_line": 2.0},
			{"quake": 0.7, "lane": 1.6, "lane_pulse": 0.5}),
		act("Terremoto", 1400.0, 1.3, {"serpent": 2.0, "tank_escort": 1.0, "swarm_spiral": 2.0},
			{"quake": 1.0, "sway": 0.25, "lane": 1.2, "lane_pulse": 0.4}),
		act("Estilhaços", 1300.0, 1.3, {"storm": 2.0, "seeker_rain": 2.0}, {"strobe": 0.5, "heat": 1.25}),
		respite(),
		act("Colapso", 2000.0, 1.5, {"gauntlet": 2.0, "gunner_wall": 2.0, "drone_flood": 2.0, "mine_ring": 1.0},
			{"quake": 1.0, "sway": 0.35, "speed_floor": 48.0, "heat": 1.35, "lane": 1.5, "lane_pulse": 0.6}, [[0.5, "elite"]]),
	]


static func _forja() -> Array[Dictionary]:
	return [
		act("Fornalha", 1300.0, 1.25, {"laser_post": 3.0, "drone_flood": 2.0, "gunner_pair": 1.0},
			{"heat": 1.3, "strobe": 0.4, "scorch": 1.0}),
		act("Chuva de fogo", 1400.0, 1.35, {"gunner_wall": 3.0, "seeker_dive": 2.0}, {"heat": 1.5}),
		act("Esteira", 1400.0, 1.3, {"gauntlet": 2.0, "mine_grid": 2.0, "laser_post": 1.0}, {"speed_floor": 54.0, "sway": 0.3}),
		respite("Resfriamento"),
		act("Derretimento", 2100.0, 1.6, {"gunner_wall": 2.0, "tank_escort": 2.0, "storm": 2.0, "gauntlet": 1.0},
			{"heat": 1.6, "strobe": 0.8, "quake": 0.6, "scorch": 1.0}, [[0.25, "elite"], [0.55, "elite"], [0.85, "elite"]]),
	]


static func _eclipse() -> Array[Dictionary]:
	return [
		act("Penumbra", 1400.0, 1.3, {"seeker_rain": 2.0, "weaver_snake": 2.0, "rotor": 1.0},
			{"brightness": 0.35, "spawn_ahead": 75.0, "sway": 0.3}),
		act("Inversão", 1400.0, 1.35, {"storm": 2.0, "gauntlet": 2.0, "warden_guard": 1.0}, {"flip": 1.0, "sway": 0.3, "strobe": 0.5}),
		act("Totalidade", 1400.0, 1.4, {"drone_flood": 2.0, "serpent": 2.0, "phantom_pack": 2.0},
			{"brightness": 0.15, "spawn_ahead": 55.0, "quake": 0.6}),
		respite(),
		act("Coroa solar", 2200.0, 1.7, {"gunner_wall": 2.0, "storm": 2.0, "gauntlet": 2.0, "tank_escort": 1.0},
			{"strobe": 1.0, "sway": 0.5, "heat": 1.6, "speed_floor": 50.0}, [[0.4, "elite"], [0.8, "elite"]]),
	]


static func _nucleo() -> Array[Dictionary]:
	return [
		act("Aproximação", 1400.0, 1.4, {"drone_flood": 2.0, "storm": 2.0, "barrier_gate": 1.0}, {"strobe": 0.5}),
		act("Defesas", 1500.0, 1.5, {"gunner_wall": 2.0, "warden_guard": 2.0, "laser_post": 2.0, "gauntlet": 1.0},
			{"heat": 1.6, "quake": 0.5}, [[0.5, "elite"]]),
		act("Sobrecarga", 1500.0, 1.6, {"seeker_rain": 2.0, "serpent": 2.0, "pulse_gate": 2.0, "splitter_pack": 1.0},
			{"sway": 0.4, "strobe": 0.9, "speed_floor": 50.0, "lane": 1.8, "lane_pulse": 0.4}),
		respite("Calmaria"),
		act("Ponto sem retorno", 2400.0, 1.9, {"drone_flood": 2.0, "gunner_wall": 2.0, "gauntlet": 2.0,
			"seeker_rain": 2.0, "tank_escort": 1.0, "phantom_pack": 1.0, "mine_grid": 1.0},
			{"strobe": 1.0, "sway": 0.6, "quake": 1.0, "heat": 1.8, "scorch": 1.0,
			"brightness": 0.6}, [[0.2, "elite"], [0.5, "elite"], [0.8, "elite"]]),
	]
