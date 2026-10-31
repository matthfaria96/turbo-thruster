class_name Donut
extends Node3D
## Charged release: a glowing energy ring that flies down the ship's lane,
## widening slightly. It damages at most MAX_HITS enemies (each once), erases
## enemy bullets it passes through, then bursts.

const MAX_HITS := 3
const DAMAGE := 9.0
const SPEED := 85.0
const LIFE := 1.0
const RADIUS_START := 0.9
const RADIUS_END := 2.5
const COLOR := Color(0.55, 0.9, 1.0)

var s := 0.0
var ps := 0.0
var th := 0.0
var age := 0.0
var done := false
var _hits: Array[Enemy] = []
var _boss_hit := false
var _game: Game
var _ring: Node3D
var _geo: Array[GeometryInstance3D] = []


func setup(game: Game, p_s: float, p_th: float) -> void:
	_game = game
	s = p_s
	ps = p_s
	th = p_th
	_ring = Node3D.new()
	_ring.add_child(NeonGeo.build("donut_outer", NeonGeo.ring(1.0, 32, 0.25), COLOR, 2.4, 0.18, 0.09))
	_ring.add_child(NeonGeo.build("donut_inner", NeonGeo.ring(0.72, 24), Color(1, 1, 1), 2.0, 0.0, 0.04))
	add_child(_ring)
	_geo = Meshes.geometry_of(_ring)


func radius() -> float:
	return lerpf(RADIUS_START, RADIUS_END, ease(minf(age / LIFE, 1.0), 0.5))


func step(dt: float) -> void:
	if done:
		return
	age += dt
	ps = s
	s += (_game.player.speed + SPEED) * dt
	_place()
	_hit_enemies()
	_hit_bosses()
	_clear_bullets()
	if age >= LIFE or _hits.size() >= MAX_HITS:
		_burst()


func _place() -> void:
	var fr := _game.track.frame(s)
	var center := fr.origin + Track.radial(fr, th) * (Track.RADIUS - Player.H - 0.3)
	global_transform = Transform3D(fr.basis, center)
	_ring.scale = Vector3.ONE * radius()
	_ring.rotation.z += 0.25
	var fade := 1.0 - smoothstep(0.75, 1.0, age / LIFE)
	for g in _geo:
		Meshes.set_param(g, "fade", fade)


func _inside(e_s: float, e_th: float, e_h: float, e_radius: float) -> bool:
	if e_s < ps - e_radius or e_s > s + e_radius:
		return false
	var arc := absf(Track.angle_diff(e_th, th)) * (Track.RADIUS - e_h)
	return arc < radius() + e_radius * 0.5


func _hit_enemies() -> void:
	for e in _game.enemies:
		if _hits.size() >= MAX_HITS:
			return
		if not e.alive or e.hidden or e.invulnerable or e in _hits:
			continue
		if _inside(e.s, e.th, e.h, e.spec.radius):
			_hits.append(e)
			_game.fx.sparks(e.global_position, COLOR, 14, 16.0, 0.9, 0.3)
			_game.combat.hit_enemy(e, DAMAGE)


func _hit_bosses() -> void:
	for b in _game.bosses:
		if not _boss_hit and b.core_hittable() and _inside(b.s, b.th, b.h, b.radius):
			_boss_hit = true
			_hits.append(null)
			if b.damage(DAMAGE * 1.5):
				_game.on_boss_killed(b)


func _clear_bullets() -> void:
	var removed := _game.projectiles.clear_bullets(func(b: Dictionary) -> bool:
		return b.s >= ps - 1.0 and b.s <= s + 1.0 and absf(Track.angle_diff(b.th, th)) * Track.RADIUS < radius())
	for b in removed.slice(0, 6):
		_game.fx.sparks(_game.track.point(b.s, b.th, b.h), EnemyTypes.BULLET_COLOR, 4, 8.0, 0.5, 0.2)


func _burst() -> void:
	done = true
	_game.fx.shockwave(global_position, COLOR, radius() * 1.6)
	_game.fx.sparks(global_position, COLOR, 20, 14.0, 0.8, 0.3)
	queue_free()
