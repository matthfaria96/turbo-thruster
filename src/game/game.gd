class_name Game
extends Node3D
## One sector run: intro → enemies → boss → portal → finale → results.
## Everything (weapon level, hull, score) lives here and dies with the sector.

signal request_menu
signal request_level(index: int)

enum State { INTRO, PLAY, BOSS, PORTAL, FINALE, RESULTS, DEAD, OVER }

const INTRO_TIME := 2.0
const SPAWN_AHEAD := 150.0
const FINALE_TIME := 2.2
const COMBO_WINDOW := 1.6
const ACTIVE_STATES := [State.INTRO, State.PLAY, State.BOSS, State.PORTAL]

var level_index := 0
var level: Dictionary
var track: Track
var state := State.INTRO
var state_t := 0.0
var score := 0
var kills := 0
var plan_kills := 0
var combo := 0
var max_combo := 0
var hits_taken := 0
var elapsed := 0.0

var player: Player
var boss: Boss
var fx: Fx
var projectiles: Projectiles
var tunnel: Tunnel
var hud: Hud
var camera: Camera3D
var enemies: Array[Enemy] = []
var pickups: Array[Pickup] = []

var _plan: Array[Dictionary] = []
var _plan_total := 0
var _combo_t := 0.0
var _cam_th := 0.0
var _kills_since_drop := 0
var _portal: Node3D
var _portal_s := 0.0
var _overlay: Control
var _autoplay := false
var _leaving := false
var _start_s := 0.0


func setup(index: int, autoplay := false, start_s := 0.0) -> void:
	level_index = index
	level = Levels.get_level(index)
	_autoplay = autoplay
	_start_s = start_s


func _ready() -> void:
	track = Track.new(level.curve, 1000 + level_index * 77)
	add_child(WorldEnv.new())
	tunnel = Tunnel.new()
	tunnel.setup(track, level.tint)
	tunnel.set_brightness(0.8)
	add_child(tunnel)
	fx = Fx.new()
	add_child(fx)
	projectiles = Projectiles.new()
	add_child(projectiles)
	projectiles.setup(track)
	player = Player.new()
	add_child(player)
	player.nova_fired.connect(_on_nova)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.1
	camera.far = 420.0
	add_child(camera)
	camera.current = true
	hud = Hud.new()
	add_child(hud)
	hud.build(level_index, level)
	_plan = WavePlan.build(level, level_index)
	player.s = _start_s
	_plan = _plan.filter(func(p: Dictionary) -> bool: return p.s > _start_s)
	_plan_total = _plan.size()
	Sfx.play_music(level.music)
	hud.announce("SETOR %d" % (level_index + 1), String(level.name).to_upper(), INTRO_TIME - 0.4)
	_sync_transforms(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state in ACTIVE_STATES \
			and not get_tree().paused and not _autoplay:
		_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state in ACTIVE_STATES and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_pause()


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	state_t += dt
	_step_state(dt)
	var shots := player.step(dt, _read_input())
	for shot in shots:
		projectiles.add_shot(shot)
	if state in ACTIVE_STATES:
		_spawn_from_plan()
	_step_entities(dt)
	projectiles.update(dt, player.s)
	if state in [State.PLAY, State.BOSS, State.PORTAL]:
		_resolve_hits()
	_combo_t -= dt
	if _combo_t <= 0.0:
		combo = 0
	_sync_transforms(dt)
	projectiles.render()
	tunnel.update_view(player.s)
	hud.refresh({"score": score, "combo": combo, "progress": clampf(player.s / level.length, 0.0, 1.0),
		"weapon": player.weapon, "hull": maxi(player.hull, 0), "speed": player.speed,
		"charge": player.charge}, dt)
	if boss:
		hud.set_boss_health(boss.health_ratio())


# --------------------------------------------------------------- state flow

func _step_state(dt: float) -> void:
	match state:
		State.INTRO:
			if state_t >= INTRO_TIME:
				_set_state(State.PLAY)
				hud.announce("VAI!", "", 0.6)
		State.PLAY:
			elapsed += dt
			if player.s >= level.length:
				_start_boss()
		State.BOSS:
			elapsed += dt
			if boss.done:
				_open_portal()
		State.PORTAL:
			elapsed += dt
			_portal.get_node("Ring").rotation.z += dt * 1.5
			if player.s >= _portal_s:
				_start_finale()
		State.FINALE:
			_step_finale(dt)
		State.RESULTS:
			hud.set_flash(1.0 - minf(1.0, state_t / 0.8))
			tunnel.set_flash(maxf(0.0, 0.35 - state_t * 0.4))
		State.DEAD:
			if state_t >= 1.6:
				_show_game_over()


func _set_state(next: State) -> void:
	state = next
	state_t = 0.0


func _read_input() -> Dictionary:
	if state in [State.FINALE, State.RESULTS, State.DEAD, State.OVER]:
		return {"x": 0.0, "y": 0.0, "fire": false, "charge": false}
	if _autoplay:
		return _autoplay_input()
	return {
		"x": Input.get_axis("move_left", "move_right"),
		"y": Input.get_axis("brake", "accelerate"),
		"fire": state != State.INTRO and (bool(Save.settings.autofire) or Input.is_action_pressed("fire")),
		"charge": state != State.INTRO and Input.is_action_pressed("charge"),
	}


## Simple bot used by the screenshot/smoke-test harness.
func _autoplay_input() -> Dictionary:
	var target := player.th
	if boss and boss.alive:
		target = boss.th
	elif not enemies.is_empty():
		target = enemies[0].th
	var x := clampf(Track.angle_diff(target, player.th) * 3.0, -1.0, 1.0)
	return {"x": x, "y": 0.6, "fire": state != State.INTRO, "charge": false}


func enemies_may_fire() -> bool:
	return state in [State.PLAY, State.BOSS]


# ----------------------------------------------------------------- spawning

func _spawn_from_plan() -> void:
	while not _plan.is_empty() and _plan[0].s <= player.s + SPAWN_AHEAD:
		var spec: Dictionary = _plan.pop_front()
		spawn_enemy(spec.kind, maxf(spec.s, player.s + 60.0), spec.th, spec.phase, true)


func spawn_enemy(kind: String, s: float, th: float, phase: float, from_plan := false) -> void:
	var e := Enemy.new()
	e.setup(kind, s, th, phase, 1.0 + level_index * 0.08)
	e.from_plan = from_plan
	add_child(e)
	enemies.append(e)


func _step_entities(dt: float) -> void:
	for e in enemies:
		e.step(dt, self)
	var passed := enemies.filter(func(e: Enemy) -> bool: return e.s < player.s - 10.0)
	for e: Enemy in passed:
		e.queue_free()
	enemies = enemies.filter(func(e: Enemy) -> bool: return e.alive and e.s >= player.s - 10.0)
	for p in pickups:
		p.step(dt, player)
	if boss:
		boss.step(dt, self)


func _sync_transforms(dt: float) -> void:
	player.global_transform = track.pose(player.s, player.th, Player.H)
	for e in enemies:
		e.global_transform = track.pose(e.s, e.th, e.h)
	for p in pickups:
		p.global_transform = track.pose(p.s, p.th, p.h)
	if boss:
		boss.global_transform = track.pose(boss.s, boss.th, boss.h)
	_update_camera(dt)


func _update_camera(dt: float) -> void:
	_cam_th = lerp_angle(_cam_th, player.th, minf(1.0, 7.0 * dt)) if dt > 0.0 else player.th
	var eye := track.point(player.s - 8.5, _cam_th, Track.RADIUS - 4.0)
	var target := track.point(player.s + 16.0, _cam_th, Track.RADIUS - 2.2)
	var up := -Track.radial(track.frame(player.s), _cam_th)
	camera.look_at_from_position(eye, target, up)
	camera.fov = lerpf(camera.fov, 70.0 + (player.speed - Player.BASE_SPEED) * 0.35, minf(1.0, dt * 4.0))
	var amount := fx.shake if bool(Save.settings.shake) else 0.0
	camera.h_offset = randf_range(-1.0, 1.0) * amount * 0.6
	camera.v_offset = randf_range(-1.0, 1.0) * amount * 0.6
	fx.shake = move_toward(fx.shake, 0.0, dt * 2.2)


# ------------------------------------------------------------------ firing

func fire_bullet(s: float, th: float, h: float, rel_speed: float, vth: float) -> void:
	projectiles.add_bullet(s, th, h, player.speed - rel_speed, vth)


## Shoots `count` bullets aimed at the player, spread by `spread` radians.
func fire_aimed(s: float, th: float, h: float, rel_speed: float, count: int, spread: float) -> void:
	var travel := maxf((s - player.s) / rel_speed, 0.4)
	var aim := Track.angle_diff(player.th, th) / travel
	for i in count:
		var offset := (i - (count - 1) * 0.5) * spread
		fire_bullet(s, th, h, rel_speed, aim + offset / travel)


## Full ring of bullets with a gap of `gap` bullets centred on `gap_th`.
func fire_ring(s: float, h: float, count: int, gap_th: float, gap: int, rel_speed: float) -> void:
	for i in count:
		var a := gap_th + TAU * (i + 0.5 + gap * 0.5) / count
		if i < count - gap:
			fire_bullet(s, wrapf(a, -PI, PI), h, rel_speed, 0.0)


func _on_nova(s: float, th: float) -> void:
	projectiles.add_shot(player.nova_shot(s, th))
	fx.burst(track.point(s, th, Player.H), Color(0.8, 1.0, 1.0), 30, 16.0, 0.5, 0.5)
	fx.shake = maxf(fx.shake, 0.25)
	Sfx.play("nova")


# --------------------------------------------------------------- collisions

func _resolve_hits() -> void:
	for shot in projectiles.shots:
		_shot_vs_targets(shot)
	if shot_nova_active():
		_nova_clears_bullets()
	_bullets_vs_player()
	_enemies_vs_player()
	_pickups_vs_player()
	enemies = enemies.filter(func(e: Enemy) -> bool: return e.alive)


func shot_nova_active() -> bool:
	return projectiles.shots.any(func(s: Dictionary) -> bool: return s.pierce)


func _shot_vs_targets(shot: Dictionary) -> void:
	for e in enemies:
		if not e.alive or shot.get("dead", false):
			continue
		if _swept_hit(shot, e.s, e.th, e.h, e.spec.radius):
			if e.damage(shot.dmg):
				_on_enemy_killed(e)
			else:
				fx.sparks(e.global_position, e.spec.color)
				Sfx.play("hit", -10.0)
			if not shot.pierce:
				shot.dead = true
	if boss and boss.alive and not shot.get("dead", false) and _swept_hit(shot, boss.s, boss.th, boss.h, boss.radius):
		if not shot.pierce or not shot.has("hit_boss"):
			if boss.damage(shot.dmg):
				_on_boss_killed()
			fx.sparks(track.point(boss.s - 2.5, shot.th, shot.h), boss.color)
			Sfx.play("hit", -10.0)
		shot["hit_boss"] = true
		if not shot.pierce:
			shot.dead = true


func _swept_hit(shot: Dictionary, s: float, th: float, h: float, radius: float) -> bool:
	var r: float = radius + shot.size * 0.5
	if s < shot.ps - r or s > shot.s + r:
		return false
	var arc := absf(Track.angle_diff(shot.th, th)) * (Track.RADIUS - h)
	return arc < r and absf(shot.h - h) < r + 0.6


func _nova_clears_bullets() -> void:
	var novas := projectiles.shots.filter(func(s: Dictionary) -> bool: return s.pierce)
	for nova: Dictionary in novas:
		var removed := projectiles.clear_bullets(func(b: Dictionary) -> bool:
			return absf(b.s - nova.s) < 6.0 and absf(Track.angle_diff(b.th, nova.th)) < 0.45)
		for b in removed:
			fx.sparks(track.point(b.s, b.th, b.h), EnemyTypes.BULLET_COLOR)
			score += 10


func _bullets_vs_player() -> void:
	if player.invuln > 0.0 or not player.alive:
		return
	for b in projectiles.bullets:
		if not b.dead and Track.distance(b.s, b.th, b.h, player.s, player.th, Player.H) < Projectiles.BULLET_RADIUS + 0.35:
			b.dead = true
			_hurt_player()
			return


func _enemies_vs_player() -> void:
	if player.invuln > 0.0 or not player.alive:
		return
	for e in enemies:
		if e.alive and Track.distance(e.s, e.th, e.h, player.s, player.th, Player.H) < e.spec.radius + 0.5:
			if e.damage(4.0):
				_on_enemy_killed(e)
			_hurt_player()
			return


func _pickups_vs_player() -> void:
	var taken := pickups.filter(func(p: Pickup) -> bool:
		return Track.distance(p.s, p.th, p.h, player.s, player.th, Player.H) < Pickup.COLLECT_RADIUS)
	for p: Pickup in taken:
		_collect(p)
		p.queue_free()
	var missed := pickups.filter(func(p: Pickup) -> bool: return p.s < player.s - 8.0)
	for p: Pickup in missed:
		p.queue_free()
	pickups = pickups.filter(func(p: Pickup) -> bool: return not (p in taken) and not (p in missed))


func _hurt_player() -> void:
	hits_taken += 1
	var died := player.take_hit()
	fx.explosion(player.global_position, EnemyTypes.PLAYER_COLOR, 0.8)
	fx.shake = 0.7
	hud.damage_pulse()
	combo = 0
	if died:
		_on_player_died()
		return
	Sfx.play("hit", 0.0, 0.7)
	hud.announce("", "CASCO DANIFICADO — ARMA NV %d" % player.weapon, 0.8, UiStyle.DANGER)


# ------------------------------------------------------------ kills, drops

func _speed_mult() -> float:
	return 1.0 + maxf(0.0, player.speed - Player.BASE_SPEED) / 40.0


func _on_enemy_killed(e: Enemy) -> void:
	kills += 1
	if e.from_plan:
		plan_kills += 1
	combo = combo + 1 if _combo_t > 0.0 else 1
	_combo_t = COMBO_WINDOW
	max_combo = maxi(max_combo, combo)
	var points := int(e.spec.score * mini(combo, 8) * _speed_mult())
	score += points
	var big := e.kind == "tank"
	fx.explosion(e.global_position, e.spec.color, 1.8 if big else 1.0)
	fx.popup(e.global_position + Vector3.UP * 0.5, "+%d" % points, e.spec.color)
	Sfx.play("middle" if big else "small", -3.0, randf_range(0.9, 1.1))
	_maybe_drop(e)
	e.queue_free()


func _maybe_drop(e: Enemy) -> void:
	_kills_since_drop += 1
	var kind := ""
	if e.kind == "tank" or _kills_since_drop >= 9:
		kind = "repair" if player.weapon >= Player.MAX_WEAPON and player.hull < Player.MAX_HULL else "weapon"
	elif player.hull < Player.MAX_HULL and randf() < 0.04:
		kind = "repair"
	if kind == "":
		return
	_kills_since_drop = 0
	var p := Pickup.new()
	p.setup(kind, e.s, e.th)
	add_child(p)
	pickups.append(p)


func _collect(p: Pickup) -> void:
	Sfx.play("pickup", -2.0)
	fx.burst(p.global_position, p.color(), 26, 10.0, 0.4, 0.6)
	if p.kind == "weapon":
		if player.upgrade_weapon():
			hud.announce("", "ARMA NÍVEL %d" % player.weapon, 1.0, UiStyle.GOOD)
		else:
			score += 2000
			fx.popup(p.global_position, "+2000", p.color())
	else:
		if player.repair():
			hud.announce("", "CASCO REPARADO", 1.0, UiStyle.ACCENT)
		else:
			score += 1000
			fx.popup(p.global_position, "+1000", p.color())


# --------------------------------------------------------- boss and portal

func _start_boss() -> void:
	_set_state(State.BOSS)
	boss = Boss.new()
	boss.setup(level, level_index, player.s + 110.0, player.th)
	add_child(boss)
	hud.show_boss(boss.title)
	hud.announce("ALERTA", "CHEFE: " + boss.title.to_upper(), 2.2, UiStyle.DANGER)
	Sfx.play("alert")


func _on_boss_killed() -> void:
	score += int(5000 * (1.0 + level_index * 0.25))
	fx.shake = 0.6
	_explode_all_bullets()
	for e in enemies:
		if e.alive and e.damage(999.0):
			_on_enemy_killed(e)
	enemies.clear()


func _open_portal() -> void:
	_set_state(State.PORTAL)
	hud.hide_boss()
	_portal_s = boss.s + 40.0
	boss.queue_free()
	boss = null
	_portal = Meshes.portal()
	add_child(_portal)
	_portal.global_transform = track.pose(_portal_s, 0.0, Track.RADIUS)
	player.min_speed_override = 42.0
	hud.announce("CHEFE DERROTADO", "Entre no portal!", 2.0, UiStyle.GOOD)


func _start_finale() -> void:
	_set_state(State.FINALE)
	player.min_speed_override = 70.0
	Sfx.play("boss")
	_explode_all_bullets()
	for e in enemies:
		fx.explosion(e.global_position, e.spec.color, 1.4)
		e.queue_free()
	enemies.clear()
	fx.explosion(_portal.global_position, Color(0.6, 0.95, 1.0), 4.0)
	_portal.queue_free()
	_portal = null


func _step_finale(dt: float) -> void:
	if state_t < 1.6 and randf() < 0.75:
		var s := player.s + randf_range(6.0, 70.0)
		var pos := track.point(s, randf_range(-PI, PI), randf_range(0.5, Track.RADIUS - 0.5))
		var palette := [Color(1, 0.3, 0.2), Color(1, 0.8, 0.2), Color(0.4, 0.9, 1), Color(1, 0.3, 0.7), Color(1, 1, 1)]
		fx.explosion(pos, palette[randi() % palette.size()], randf_range(1.2, 2.4))
		if randf() < 0.3:
			Sfx.play("middle", -6.0, randf_range(0.7, 1.3))
	fx.shake = maxf(fx.shake, 0.5 * (1.0 - state_t / FINALE_TIME))
	tunnel.set_flash(clampf(state_t * 0.25, 0.0, 0.35))
	hud.set_flash(clampf((state_t - 1.0) / 0.9, 0.0, 1.0))
	if state_t >= FINALE_TIME:
		_show_results()


func _explode_all_bullets() -> void:
	var removed := projectiles.clear_bullets(func(_b: Dictionary) -> bool: return true)
	for b in removed:
		fx.sparks(track.point(b.s, b.th, b.h), EnemyTypes.BULLET_COLOR)


# ---------------------------------------------------------------- results

func _rank(kill_ratio: float) -> String:
	if kill_ratio >= 0.85 and hits_taken == 0:
		return "S"
	if kill_ratio >= 0.7 and hits_taken <= 1:
		return "A"
	if kill_ratio >= 0.45:
		return "B"
	return "C"


func _show_results() -> void:
	_set_state(State.RESULTS)
	player.min_speed_override = 0.0
	var kill_ratio := minf(1.0, plan_kills / float(maxi(_plan_total, 1)))
	var hull_bonus := player.hull * 1500
	var par_time: float = level.length / Player.BASE_SPEED + 45.0
	var time_bonus := int(maxf(0.0, par_time - elapsed) * 60.0)
	var total := score + hull_bonus + time_bonus
	var rank := _rank(kill_ratio)
	var is_best := Save.record_result(level_index, total, rank)
	var last := Levels.is_last(level_index)
	var rows := [
		["Pontos", Hud._format_int(score)],
		["Abates", "%d / %d" % [plan_kills, _plan_total]],
		["Maior combo", "x%d" % max_combo],
		["Bônus de casco", "+" + Hud._format_int(hull_bonus)],
		["Bônus de tempo (%ds)" % int(elapsed), "+" + Hud._format_int(time_bonus)],
		["Total", Hud._format_int(total), UiStyle.TEXT],
		["Classificação", rank, UiStyle.rank_color(rank), true],
	]
	var buttons: Array = []
	if not last:
		buttons.append(["Próximo setor  ▸", func() -> void: _leave(level_index + 1)])
	buttons.append(["Repetir setor", func() -> void: _leave(level_index)])
	buttons.append(["Menu principal", func() -> void: _leave(-1)])
	var heading := "CAMPANHA CONCLUÍDA" if last else "SETOR CONCLUÍDO"
	var sub := ("NOVO RECORDE!  " if is_best else "") + "Setor %d · %s" % [level_index + 1, level.name]
	_show_overlay(Overlay.create(heading, sub, rows, buttons, UiStyle.GOOD))


func _on_player_died() -> void:
	_set_state(State.DEAD)
	Sfx.play("ship")
	fx.explosion(player.global_position, EnemyTypes.PLAYER_COLOR, 2.5)
	fx.explosion(player.global_position, Color(1, 1, 1), 1.5)
	fx.shake = 1.0
	player.min_speed_override = 0.0


func _show_game_over() -> void:
	_set_state(State.OVER)
	var rows := [
		["Pontos", Hud._format_int(score)],
		["Distância", "%d%%" % int(clampf(player.s / level.length, 0.0, 1.0) * 100.0)],
		["Abates", str(kills)],
	]
	var buttons := [
		["Tentar de novo", func() -> void: _leave(level_index)],
		["Menu principal", func() -> void: _leave(-1)],
	]
	_show_overlay(Overlay.create("NAVE DESTRUÍDA", "Setor %d · %s" % [level_index + 1, level.name],
		rows, buttons, UiStyle.DANGER))


func _pause() -> void:
	get_tree().paused = true
	var buttons := [
		["Continuar", _resume],
		["Reiniciar setor", func() -> void: _leave(level_index)],
		["Menu principal", func() -> void: _leave(-1)],
	]
	_show_overlay(Overlay.create("PAUSADO", "Setor %d · %s" % [level_index + 1, level.name], [], buttons,
		UiStyle.ACCENT, _resume))


func _resume() -> void:
	get_tree().paused = false
	_close_overlay()


func _show_overlay(overlay: Control) -> void:
	_close_overlay()
	_overlay = overlay
	hud.add_overlay(overlay)


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _leave(next_level: int) -> void:
	if _leaving:
		return
	_leaving = true
	process_mode = Node.PROCESS_MODE_DISABLED
	if next_level < 0:
		request_menu.emit.call_deferred()
	else:
		request_level.emit.call_deferred(next_level)
