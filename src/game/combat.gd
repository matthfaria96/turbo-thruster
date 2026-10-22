class_name Combat
extends RefCounted
## Collisions and their consequences: player shots vs enemies/boss parts,
## enemy bullets/bodies/beams vs the ship, grazes (near misses), kills,
## drops, splitter children, warden shields and "wave cleared" bonuses.

const GRAZE_RADIUS := 1.9
const GRAZES_PER_MULT := 3
const WAVE_BONUS := 1000
const WAVE_BONUS_PER_MULT := 50

var g: Game
var _groups: Dictionary = {}
var _kills_since_drop := 0


func _init(game: Game) -> void:
	g = game


static func is_killable_spawn(p: Dictionary) -> bool:
	var kind := String(p.kind)
	return not kind.begins_with("pickup_") and not EnemyTypes.get_type(kind).get("invulnerable", false)


func resolve(dt: float) -> void:
	_update_shields()
	for shot in g.projectiles.shots:
		_shot_vs_enemies(shot)
		_shot_vs_bosses(shot)
	if nova_active():
		_nova_clears_bullets()
	_bullets_vs_player()
	_enemies_vs_player()
	_pickups_vs_player()
	g.powerups.apply_laser(dt)
	g.enemies = g.enemies.filter(func(e: Enemy) -> bool: return e.alive)


func nova_active() -> bool:
	return g.projectiles.shots.any(func(s: Dictionary) -> bool: return s.pierce)


# ------------------------------------------------------------- player shots

func _shot_vs_enemies(shot: Dictionary) -> void:
	for e in g.enemies:
		if not e.alive or shot.get("dead", false) or e.hidden:
			continue
		if e.uses_frame():
			if e.blocks_shot(shot.th) and e.s >= shot.ps - 0.5 and e.s <= shot.s + 0.5:
				g.fx.sparks(g.track.point(e.s, shot.th, shot.h), e.spec.color, 4, 10.0, 0.6, 0.2)
				shot.dead = true
			continue
		if not swept_hit(shot, e.s, e.th, e.h, e.spec.radius):
			continue
		hit_enemy(e, shot.dmg)
		if not shot.pierce:
			shot.dead = true


func hit_enemy(e: Enemy, amount: float) -> void:
	if e.damage(amount):
		on_enemy_killed(e)
		return
	if e.spark_cd > 0.0:
		return
	e.spark_cd = 0.08
	var blocked := e.invulnerable or e.shielded
	g.fx.sparks(e.global_position, Color(0.5, 0.8, 1.0) if blocked else e.spec.color, 6 if blocked else 8, 14.0, 0.8, 0.25)
	Sfx.play("hit", -14.0 if blocked else -10.0, 1.6 if blocked else 1.0)


func _shot_vs_bosses(shot: Dictionary) -> void:
	for b in g.bosses:
		if shot.get("dead", false) or not b.alive:
			continue
		var a := g.track.point(shot.ps, shot.th, shot.h)
		var z := g.track.point(shot.s, shot.th, shot.h)
		for i in b.parts.size():
			var part_key := "hit_part_%d_%d" % [b.get_instance_id(), i]
			if b.parts[i].alive and not shot.has(part_key) and _segment_hits(a, z, b.part_position(i), 1.3 + shot.size * 0.5):
				if shot.pierce:
					shot[part_key] = true
				if b.damage_part(i, shot.dmg):
					g.fx.explosion(b.part_position(i), b.color, 1.6)
					g.post.kick(0.5)
					g.post.pulse(b.color, 0.5)
					g.hitstop_t = 0.1
					g.score += 800 * g.multiplier
					Sfx.play("middle", -2.0)
					g.hud.announce("", "PARTE DESTRUÍDA", 0.8, UiStyle.GOLD)
				else:
					g.fx.sparks(b.part_position(i), b.color, 6, 12.0, 0.7, 0.2)
				if not shot.pierce:
					shot.dead = true
					return
		if not b.core_hittable() or not swept_hit(shot, b.s, b.th, b.h, b.radius):
			continue
		if shot.pierce and shot.has("hit_boss_%d" % b.get_instance_id()):
			continue
		shot["hit_boss_%d" % b.get_instance_id()] = true
		var shielded := b.core_shielded()
		if b.damage(shot.dmg):
			g.on_boss_killed(b)
		g.fx.sparks(g.track.point(b.s - 2.5, shot.th, shot.h), Color(0.6, 0.8, 1.0) if shielded else b.color, 8, 16.0, 0.9, 0.25)
		Sfx.play("hit", -10.0, 1.6 if shielded else 1.0)
		if not shot.pierce:
			shot.dead = true


func swept_hit(shot: Dictionary, s: float, th: float, h: float, radius: float) -> bool:
	var r: float = radius + shot.size * 0.5
	if s < shot.ps - r or s > shot.s + r:
		return false
	var arc := absf(Track.angle_diff(shot.th, th)) * (Track.RADIUS - h)
	return arc < r and absf(shot.h - h) < r + 0.6


static func _segment_hits(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return (a + ab * t).distance_to(c) < r


func _nova_clears_bullets() -> void:
	for nova: Dictionary in g.projectiles.shots.filter(func(s: Dictionary) -> bool: return s.pierce):
		var removed := g.projectiles.clear_bullets(func(b: Dictionary) -> bool:
			return absf(b.s - nova.s) < 6.0 and absf(Track.angle_diff(b.th, nova.th)) < 0.45)
		g.score += 10 * removed.size()
		_spark_bullets(removed)


const MAX_BURST_SPARKS := 30


func explode_all_bullets() -> void:
	_spark_bullets(g.projectiles.clear_bullets(func(_b: Dictionary) -> bool: return true))


## Sparks for removed bullets, capped so mass clears never spawn hundreds
## of particle nodes in one frame.
func _spark_bullets(removed: Array[Dictionary]) -> void:
	var step := maxi(1, ceili(removed.size() / float(MAX_BURST_SPARKS)))
	for i in range(0, removed.size(), step):
		var b := removed[i]
		g.fx.sparks(g.track.point(b.s, b.th, b.h), EnemyTypes.BULLET_COLOR, 5, 10.0, 0.6, 0.25)


# ------------------------------------------------------------ ship damage

func _bullets_vs_player() -> void:
	var p := g.player
	if not p.alive:
		return
	for b in g.projectiles.bullets:
		if b.dead:
			continue
		var d := Track.distance(b.s, b.th, b.h, p.s, p.th, Player.H)
		if d < Projectiles.BULLET_RADIUS + 0.35 and p.invuln <= 0.0:
			b.dead = true
			hurt_player(g.track.point(b.s, b.th, b.h))
			return
		# A graze pays only once the bullet has passed the ship without hitting.
		if d < GRAZE_RADIUS and p.invuln <= 0.0:
			b.near = true
		elif b.get("near", false) and not b.get("grazed", false) and b.s < p.s:
			b.grazed = true
			_graze(b)


func _graze(b: Dictionary) -> void:
	g.grazes += 1
	g.score += 50 * g.multiplier
	g.fx.sparks(g.track.point(b.s, b.th, b.h), Color(1, 1, 1), 5, 12.0, 0.5, 0.2)
	g.post.pulse(Color(1, 1, 1), 0.12)
	Sfx.play("shot", -12.0, 2.6)
	if g.grazes % GRAZES_PER_MULT == 0:
		g.multiplier = mini(Game.MAX_MULTIPLIER, g.multiplier + 1)
		g.max_multiplier = maxi(g.max_multiplier, g.multiplier)
		g.fx.popup(g.player.global_position + Vector3.UP * 1.2, "RASPÃO", Color(1, 1, 1))


func _enemies_vs_player() -> void:
	var p := g.player
	var vulnerable := p.invuln <= 0.0 and p.alive
	for e in g.enemies:
		if not e.alive or not vulnerable:
			continue
		if e.beam_hits(p) or e.touches(p):
			if e.invulnerable or e.kind == "laser":
				g.fx.sparks(p.global_position, e.spec.color, 20, 18.0, 1.0, 0.35)
			elif e.damage(4.0):
				on_enemy_killed(e)
			hurt_player(e.global_position)
			vulnerable = false


func _pickups_vs_player() -> void:
	var p := g.player
	if not p.alive:
		return
	var taken := g.pickups.filter(func(x: Pickup) -> bool:
		return Track.distance(x.s, x.th, x.h, p.s, p.th, Player.H) < Pickup.COLLECT_RADIUS)
	for x: Pickup in taken:
		g.powerups.collect(x)
		x.queue_free()
	var missed := g.pickups.filter(func(x: Pickup) -> bool: return x.s < p.s - 8.0)
	for x: Pickup in missed:
		x.queue_free()
	g.pickups = g.pickups.filter(func(x: Pickup) -> bool: return not (x in taken) and not (x in missed))


## `source` is the world position of what hit the ship (for the vignette side).
func hurt_player(source: Vector3) -> void:
	var p := g.player
	if p.invuln > 0.0 or not p.alive:
		return
	var hull_before := p.hull
	var died := p.take_hit()
	if p.hull == hull_before and not died:
		# Shield absorbed the hit: no damage, no penalties.
		g.fx.shockwave(p.global_position, Color(0.4, 0.8, 1.0), 3.0)
		Sfx.play("hit", -6.0, 1.5)
		return
	g.hits_taken += 1
	g.fx.explosion(p.global_position, EnemyTypes.PLAYER_COLOR, 0.8)
	g.fx.shake = 0.7
	g.post.kick(0.8)
	g.post.pulse(UiStyle.DANGER, 0.7)
	g.hitstop_t = 0.09
	var side := signf((source - p.global_position).dot(g.camera.global_transform.basis.x))
	g.hud.damage_pulse(side)
	g.multiplier = maxi(1, g.multiplier / 2)
	if died:
		g.on_player_died()
		return
	Sfx.play("hit", 0.0, 0.7)
	if p.invuln > 1.0:
		g.hud.announce("", "CASCO DANIFICADO — ARMA NV %d" % p.weapon, 0.8, UiStyle.DANGER)


# ------------------------------------------------------------ kills, drops

func _speed_mult() -> float:
	return 1.0 + maxf(0.0, g.player.speed - Player.BASE_SPEED) / 40.0


func on_enemy_killed(e: Enemy) -> void:
	g.kills += 1
	if e.from_plan:
		g.plan_kills += 1
	var points := int(e.spec.score * g.multiplier * _speed_mult())
	g.score += points
	var big := e.kind in ["tank", "serpent", "warden", "drifter"]
	g.fx.explosion(e.global_position, e.spec.color, 1.8 if big else 1.0)
	g.post.pulse(e.spec.color, 0.45 if big else 0.18)
	if big:
		g.post.kick(0.35)
		g.hitstop_t = 0.06
	if points > 0:
		g.fx.popup(e.global_position + Vector3.UP * 0.5, "+%d" % points, e.spec.color)
	Sfx.play("middle" if big else "small", -3.0, randf_range(0.9, 1.1))
	_maybe_drop(e)
	g.geoms.drop(e.s, e.th, e.h, 18 if e.kind == "drifter" else 2 + int(e.spec.hp / 3.0))
	if e.kind == "drifter":
		g.hud.announce("", "NAVE PERDIDA DESTRUÍDA  +%d" % points, 1.2, e.spec.color)
	_split(e)
	_count_group_kill(e)
	e.queue_free()


func _split(e: Enemy) -> void:
	if e.kind != "splitter" or e.generation >= 2:
		return
	for k in 2:
		var child := g.spawn_enemy("splitter", e.s + 3.0, e.th + (k - 0.5) * 0.6, randf() * TAU)
		child.set_generation(e.generation + 1)
		child.age = 0.3


func _maybe_drop(e: Enemy) -> void:
	_kills_since_drop += 1
	var kind := ""
	if e.kind in ["tank", "serpent", "warden", "drifter"]:
		kind = "weapon" if g.player.weapon < Player.MAX_WEAPON else g.powerups.random_kind()
	elif _kills_since_drop >= 9 or randf() < 0.03:
		kind = g.powerups.random_kind()
	if kind == "":
		return
	_kills_since_drop = 0
	g.powerups.spawn_pickup(kind, e.s, e.th)


# ------------------------------------------------------------ waves, shields

## Wave sizes are known up front (from the spawn plan), so a wave is only
## "clean" once every member has spawned and died.
func set_group_sizes(plan: Array) -> void:
	for spec: Dictionary in plan:
		var group := int(spec.get("group", -1))
		if group >= 0 and is_killable_spawn(spec):
			var info: Dictionary = _groups.get(group, {"left": 0, "size": 0, "spoiled": false})
			info.left += 1
			info.size += 1
			_groups[group] = info


func register_group(e: Enemy, group: int) -> void:
	if group < 0 or e.invulnerable or not _groups.has(group):
		return
	e.set_meta("group", group)


func on_escaped(e: Enemy) -> void:
	if e.has_meta("group") and _groups.has(e.get_meta("group")):
		_groups[e.get_meta("group")].spoiled = true


func _count_group_kill(e: Enemy) -> void:
	if not e.has_meta("group"):
		return
	var info: Dictionary = _groups.get(e.get_meta("group"), {})
	if info.is_empty():
		return
	info.left -= 1
	if info.left <= 0 and not info.spoiled and info.size >= 4:
		g.waves_cleared += 1
		var bonus := WAVE_BONUS + WAVE_BONUS_PER_MULT * g.multiplier
		g.score += bonus
		g.fx.popup(e.global_position + Vector3.UP * 1.5, "ONDA LIMPA +%d" % bonus, UiStyle.GOLD)
		Sfx.play("pickup", -6.0, 1.2)
		_groups.erase(e.get_meta("group"))


## Wardens protect enemies close to them along the tunnel.
func _update_shields() -> void:
	var wardens := g.enemies.filter(func(e: Enemy) -> bool: return e.kind == "warden" and e.alive)
	for e in g.enemies:
		var protected := false
		if e.kind != "warden" and not e.invulnerable:
			for w: Enemy in wardens:
				if absf(w.s - e.s) < 16.0 and absf(Track.angle_diff(w.th, e.th)) < 1.3:
					protected = true
					break
		e.shielded = protected
