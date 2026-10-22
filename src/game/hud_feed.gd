class_name HudFeed
extends RefCounted
## Builds the data for the left panel (powers + things ahead) and the
## on-screen target markers from the current game state.

const SCAN_AHEAD := 150.0
const MAX_MARKERS := 26
const HIDDEN_KINDS := ["serpent_body"]


static func powers(g: Game) -> Array:
	var p := g.player
	var pu := g.powerups
	var bomb_color: Color = EnemyTypes.powerup("bomb").color
	var rows: Array = [
		{"icon": "pickup_bomb", "name": "Bomba", "key": "ESPAÇO", "color": bomb_color,
			"count": p.specials, "max": Player.MAX_SPECIALS, "ready": p.specials > 0},
		{"icon": "charge", "name": "Espiral elétrica", "key": "BOTÃO DIR.", "color": Color(0.75, 1.0, 1.0),
			"ratio": p.charge, "ready": p.charge >= 1.0, "label": "PRONTO!" if p.charge >= 1.0 else ""},
	]
	var timed := [["shield", p.shield_t, 10.0], ["rapid", p.rapid_t, 9.0], ["missile", pu.missile_t, PowerUps.MISSILE_TIME],
		["slow", pu.slow_t, PowerUps.SLOW_TIME], ["magnet", pu.magnet_t, PowerUps.MAGNET_TIME],
		["laser", pu.laser_t, PowerUps.LASER_TIME]]
	for t: Array in timed:
		if float(t[1]) > 0.0:
			var info := EnemyTypes.powerup(t[0])
			rows.append({"icon": "pickup_" + String(t[0]), "name": String(info.name).capitalize(), "color": info.color,
				"ratio": float(t[1]) / float(t[2]), "label": "%ds" % ceili(float(t[1]))})
	return rows


## Things ahead grouped by kind, nearest first, plus screen markers.
static func scan(g: Game) -> Dictionary:
	var groups: Dictionary = {}
	var markers: Array = []
	for e in g.enemies:
		var ahead := e.s - g.player.s
		if not e.alive or e.hidden or ahead < -2.0 or ahead > SCAN_AHEAD or e.kind in HIDDEN_KINDS:
			continue
		_add(groups, e.kind, ahead)
		markers.append({"kind": e.kind, "world": _anchor(g, e), "dist": ahead})
	for p in g.pickups:
		var ahead := p.s - g.player.s
		if ahead < -2.0 or ahead > SCAN_AHEAD:
			continue
		_add(groups, "pickup_" + p.kind, ahead)
		markers.append({"kind": "pickup_" + p.kind, "world": p.global_position, "dist": ahead})
	var area := groups.values()
	area.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.dist < b.dist)
	markers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.dist < b.dist)
	var screen: Array = []
	for m: Dictionary in markers.slice(0, MAX_MARKERS):
		if m.dist > 3.0 and not g.camera.is_position_behind(m.world):
			screen.append({"kind": m.kind, "pos": g.camera.unproject_position(m.world), "dist": m.dist})
	return {"area": area, "markers": screen}


static func _add(groups: Dictionary, kind: String, ahead: float) -> void:
	var entry: Dictionary = groups.get(kind, {"kind": kind, "count": 0, "dist": INF})
	entry.count += 1
	entry.dist = minf(entry.dist, maxf(ahead, 0.0))
	groups[kind] = entry


## Where to put the marker: obstacles are drawn across the tunnel.
static func _anchor(g: Game, e: Enemy) -> Vector3:
	match e.kind:
		"barrier":
			return g.track.point(e.s, e.th, 1.8)
		"rotor", "pulse_ring":
			return g.track.point(e.s, g.player.th, Track.RADIUS * 0.55)
	return e.global_position
