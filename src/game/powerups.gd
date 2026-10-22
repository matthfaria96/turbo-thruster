class_name PowerUps
extends Node
## Power-ups of the current run: drops/pickups and the timed effects
## (shield and rapid live on the Player; missiles, slow motion, magnet and
## laser live here). Nothing carries over to the next run.

const MISSILE_TIME := 10.0
const SLOW_TIME := 4.0
const MAGNET_TIME := 8.0
const LASER_TIME := 6.0
const SLOW_SCALE := 0.35
const LASER_RANGE := 95.0
const LASER_WIDTH := 0.15
const LASER_DPS := 26.0

var game: Game
var missile_t := 0.0
var slow_t := 0.0
var magnet_t := 0.0
var laser_t := 0.0
var _missile_cd := 0.0
var _laser_sound := 0.0


func spawn_pickup(kind: String, s: float, th: float) -> void:
	var p := Pickup.new()
	p.setup(kind, s, th)
	game.add_child(p)
	game.pickups.append(p)


## Weighted toward what the player needs right now; repairs get rarer in
## long arcade runs.
func random_kind() -> String:
	var p := game.player
	var repair_w := (3.0 if p.hull < Player.MAX_HULL else 0.3) / (1.0 + game.elapsed / 120.0 if game.is_arcade() else 1.0)
	var table := {"weapon": 4.0 if p.weapon < Player.MAX_WEAPON else 0.0, "repair": repair_w,
		"shield": 2.0, "rapid": 2.0, "bomb": 1.2, "missile": 1.6, "slow": 1.2, "magnet": 1.4, "laser": 1.3}
	var total := 0.0
	for k: String in table:
		total += table[k]
	var roll := randf() * total
	for k: String in table:
		roll -= table[k]
		if roll <= 0.0:
			return k
	return "rapid"


func laser_active() -> bool:
	return laser_t > 0.0


## Short label for the HUD of the strongest active timed power-up.
func active_label() -> String:
	if laser_t > 0.0: return "LASER %d" % ceili(laser_t)
	if missile_t > 0.0: return "MÍSSEIS %d" % ceili(missile_t)
	if slow_t > 0.0: return "TEMPO %d" % ceili(slow_t)
	if magnet_t > 0.0: return "ÍMÃ %d" % ceili(magnet_t)
	return ""


func collect(p: Pickup) -> void:
	var color := p.color()
	Sfx.play("pickup", -2.0)
	game.fx.sparks(p.global_position, color, 30, 16.0, 1.0, 0.4)
	game.fx.shockwave(p.global_position, color, 3.0)
	var player := game.player
	var text := ""
	match p.kind:
		"shield":
			player.shield_t = 10.0
			text = "ESCUDO ATIVO"
		"rapid":
			player.rapid_t = 9.0
			text = "RAJADA!"
		"bomb":
			if player.specials < Player.MAX_SPECIALS:
				player.specials += 1
				text = "BOMBA +1  (ESPAÇO)"
			else:
				_bonus(p, 3000)
		"missile":
			missile_t = MISSILE_TIME
			text = "MÍSSEIS TELEGUIADOS"
		"slow":
			slow_t = SLOW_TIME
			text = "CÂMERA LENTA"
		"magnet":
			magnet_t = MAGNET_TIME
			text = "ÍMÃ DE GEOMS"
		"laser":
			laser_t = LASER_TIME
			text = "LASER!"
		"weapon":
			if player.upgrade_weapon():
				text = "ARMA NÍVEL %d" % player.weapon
			else:
				_bonus(p, 2000)
		"repair":
			if player.repair():
				text = "CASCO REPARADO"
			else:
				_bonus(p, 1000)
	if text != "":
		game.hud.announce("", text, 1.0, color)


## Debug/test helper: starts a timed power-up for `seconds`.
func grant(kind: String, seconds: float) -> void:
	match kind:
		"missile": missile_t = seconds
		"slow": slow_t = seconds
		"magnet": magnet_t = seconds
		"laser": laser_t = seconds
		"shield": game.player.shield_t = seconds
		"rapid": game.player.rapid_t = seconds


func _bonus(p: Pickup, points: int) -> void:
	game.score += points
	game.fx.popup(p.global_position, "+%d" % points, p.color())


func update(dt: float) -> void:
	missile_t = maxf(0.0, missile_t - dt)
	slow_t = maxf(0.0, slow_t - dt)
	magnet_t = maxf(0.0, magnet_t - dt)
	laser_t = maxf(0.0, laser_t - dt)
	game.time_scale = move_toward(game.time_scale, SLOW_SCALE if slow_t > 0.0 else 1.0, dt * 3.0)
	game.geoms.magnet_boost = magnet_t > 0.0
	_update_missiles(dt)


func _update_missiles(dt: float) -> void:
	var p := game.player
	if missile_t > 0.0 and p.alive and game.state in [Game.State.PLAY, Game.State.BOSS]:
		_missile_cd -= dt
		if _missile_cd <= 0.0:
			_missile_cd = 0.55
			for side in [-1.0, 1.0]:
				game.projectiles.add_shot({"s": p.s + 1.0, "ps": p.s + 1.0, "th": p.th + side * 0.25, "h": Player.H + 0.3,
					"vs": p.speed + 70.0, "vth": side * 1.5, "dmg": 3.0, "pierce": false, "size": 0.8, "life": 1.6,
					"homing": true, "color": Color(1.0, 0.5, 0.2)})
			Sfx.play("shot", -10.0, 0.7)
	for shot in game.projectiles.shots:
		if shot.get("homing", false):
			_steer(shot, dt)


func _steer(shot: Dictionary, dt: float) -> void:
	var best: Node3D = null
	var best_d := 80.0
	var best_th := 0.0
	for e in game.enemies:
		var ahead: float = e.s - shot.s
		if e.alive and not e.invulnerable and not e.hidden and ahead > 0.0 and ahead < best_d:
			best = e
			best_d = ahead
			best_th = e.th
	for b in game.bosses:
		if b.core_hittable() and b.s - shot.s > 0.0 and b.s - shot.s < best_d:
			best = b
			best_th = b.th
	if best == null:
		return
	var want := clampf(Track.angle_diff(best_th, shot.th) * 5.0, -5.0, 5.0)
	shot.vth = lerpf(shot.vth, want, minf(1.0, dt * 6.0))


## Continuous beam: damages everything in the ship's lane ahead.
func apply_laser(dt: float) -> void:
	if laser_t <= 0.0 or not game.player.alive:
		return
	var p := game.player
	var dmg := LASER_DPS * dt * (1.0 + p.weapon * 0.2)
	for e in game.enemies:
		var ahead: float = e.s - p.s
		if e.alive and ahead > 0.0 and ahead < LASER_RANGE and absf(Track.angle_diff(e.th, p.th)) < LASER_WIDTH + 0.1:
			if e.uses_frame() or e.invulnerable:
				continue
			game.combat.hit_enemy(e, dmg)
	for b in game.bosses:
		var beam_at_boss := game.track.point(b.s, p.th, Player.H)
		for i in b.parts.size():
			if b.parts[i].alive and b.part_position(i).distance_to(beam_at_boss) < 1.8 and b.damage_part(i, dmg):
				game.fx.explosion(b.part_position(i), b.color, 1.6)
				game.score += 800 * game.multiplier
		if b.core_hittable() and absf(Track.angle_diff(b.th, p.th)) < 0.3 and b.damage(dmg):
			game.on_boss_killed(b)
	_laser_sound -= dt
	if _laser_sound <= 0.0:
		_laser_sound = 0.12
		Sfx.play("shot", -14.0, 0.5)


func draw_laser() -> void:
	if laser_t <= 0.0 or not game.player.alive:
		return
	var p := game.player
	# Two fixed widths (not random) so only two materials are ever cached.
	var flicker := 1.0 if fmod(Time.get_ticks_msec() / 50.0, 2.0) < 1.0 else 0.85
	game.lines.line("plaser", Color(0.6, 1.0, 1.0), p.s + 1.0, p.s + LASER_RANGE, p.th, Player.H, 0.45 * flicker, 3.2)
	game.lines.line("plaser_core", Color(1, 1, 1), p.s + 1.0, p.s + LASER_RANGE, p.th, Player.H, 0.14, 4.0)


## Space: spend one stocked special.
func use_special() -> bool:
	var p := game.player
	if p.specials <= 0 or not p.alive:
		Sfx.play("hit", -8.0, 0.5)
		return false
	p.specials -= 1
	_bomb()
	return true


## Clears every bullet and heavily damages everything ahead.
func _bomb() -> void:
	game.hud.announce("BOMBA", "", 0.8, EnemyTypes.powerup("bomb").color)
	game.post.kick(1.0)
	game.post.pulse(EnemyTypes.powerup("bomb").color, 0.9)
	Sfx.play("boss", -4.0, 1.3)
	game.fx.shake = 0.8
	var at := game.track.point(game.player.s + 6.0, game.player.th, 3.0)
	game.fx.shockwave(at, Color(1, 0.6, 1), 7.0)
	game.fx.sparks(at, Color(1, 0.6, 1), 80, 40.0, 2.0, 0.6)
	game.tunnel.add_ripple(at, 2.5)
	game.hud.set_flash(0.35)
	create_tween().tween_method(game.hud.set_flash, 0.35, 0.0, 0.4)
	game.combat.explode_all_bullets()
	for e in game.enemies:
		if e.alive and e.s < game.player.s + 110.0 and e.damage(10.0):
			game.combat.on_enemy_killed(e)
	game.enemies = game.enemies.filter(func(e: Enemy) -> bool: return e.alive)
	for b in game.bosses:
		if b.core_hittable() and b.damage(b.max_hp * 0.06):
			game.on_boss_killed(b)
