class_name Game
extends Node3D
## One run. Campaign: intro → scripted acts → boss → portal → finale →
## results. Arcade: endless, difficulty rises with time until the ship dies.
## Everything (weapon level, hull, score) lives here and dies with the run.
## Collisions live in Combat, power-ups in PowerUps, end screens in RunEnd.

signal request_menu
signal request_level(index: int)
signal request_arcade

enum State { INTRO, PLAY, BOSS, PORTAL, FINALE, RESULTS, DEAD, OVER }

const INTRO_TIME := 2.0
const FINALE_TIME := 2.2
const MAX_MULTIPLIER := 99
const ACTIVE_STATES := [State.INTRO, State.PLAY, State.BOSS, State.PORTAL]
const SCORCH_LIMIT := 3.2

var mode := "campaign"
var level_index := 0
var level: Dictionary
var track: Track
var state := State.INTRO
var state_t := 0.0
var score := 0
var kills := 0
var plan_kills := 0
var plan_total := 0
var multiplier := 1
var max_multiplier := 1
var hits_taken := 0
var grazes := 0
var waves_cleared := 0
var elapsed := 0.0
var time_scale := 1.0
## Real seconds minus world seconds this frame (see Enemy.step).
var slow_carry := 0.0

var player: Player
var bosses: Array[Boss] = []
var fx: Fx
var projectiles: Projectiles
var tunnel: Tunnel
var lines: TrackLines
var hud: Hud
var camera: Camera3D
var enemies: Array[Enemy] = []
var pickups: Array[Pickup] = []
var geoms: Geoms
var backdrop: SpaceBackdrop
var director: ActDirector
var combat: Combat
var powerups: PowerUps
var run_end: RunEnd

var _plan: Array[Dictionary] = []
var _cam_th := 0.0
var _cam_roll := 0.0
var _portal: Node3D
var _portal_s := 0.0
var _overlay: Control
var _autoplay := false
var _leaving := false
var _start_s := 0.0
var _gallery := false
var _scorch_t := 0.0
var _scorch_th := 0.0
var _lane_t := 0.0


## Debug: freezes the ship and lines up every enemy type ahead of it.
func enable_gallery() -> void:
	_gallery = true


func setup(index: int, autoplay := false, start_s := 0.0, run_mode := "campaign") -> void:
	mode = run_mode
	level_index = index
	level = Levels.arcade_level() if is_arcade() else Levels.get_level(index)
	_autoplay = autoplay
	_start_s = start_s


func is_arcade() -> bool:
	return mode == "arcade"


func _ready() -> void:
	track = Track.new(level.curve, 1000 + level_index * 77)
	_build_world()
	combat = Combat.new(self)
	powerups = PowerUps.new()
	powerups.game = self
	add_child(powerups)
	run_end = RunEnd.new(self)
	hud = Hud.new()
	add_child(hud)
	hud.build(level_index, level, is_arcade())
	player.s = _start_s
	if is_arcade():
		director = ArcadeDirector.new()
	else:
		_plan = WavePlan.build(level, level_index).filter(func(p: Dictionary) -> bool: return p.s > _start_s)
		plan_total = _plan.filter(Combat.is_killable_spawn).size()
		combat.set_group_sizes(_plan)
		director = ActDirector.new(level.acts)
		hud.setup_route(track, level.length, _plan, WavePlan.act_starts(level.acts))
	director.act_started.connect(_on_act_started)
	if _gallery:
		_spawn_gallery()
	Sfx.play_music(level.music)
	var heading := "MODO ARCADE" if is_arcade() else "SETOR %d" % (level_index + 1)
	var sub := "Sobreviva" if is_arcade() else String(level.name).to_upper()
	hud.announce(heading, sub, INTRO_TIME - 0.4)
	_sync_transforms(0.0)


func _build_world() -> void:
	var env := WorldEnv.new()
	env.tint = level.tint
	add_child(env)
	backdrop = SpaceBackdrop.new()
	add_child(backdrop)
	backdrop.setup(level.tint)
	tunnel = Tunnel.new()
	tunnel.setup(track, level.tint)
	add_child(tunnel)
	fx = Fx.new()
	add_child(fx)
	fx.ripple.connect(tunnel.add_ripple)
	lines = TrackLines.new()
	add_child(lines)
	lines.setup(track)
	geoms = Geoms.new()
	add_child(geoms)
	geoms.setup(track)
	geoms.collected.connect(_on_geom)
	projectiles = Projectiles.new()
	add_child(projectiles)
	projectiles.setup(track)
	player = Player.new()
	add_child(player)
	player.nova_fired.connect(_on_nova)
	player.lane_bump.connect(_on_lane_bump)
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.near = 0.1
	camera.far = 420.0
	add_child(camera)
	camera.current = true


func _spawn_gallery() -> void:
	_plan.clear()
	player.frozen = true
	var kinds := ["gunner", "tank", "seeker", "phantom", "splitter", "warden", "laser", "serpent", "drone", "swarm"]
	for i in kinds.size():
		spawn_enemy(kinds[i], _start_s + 14.0 + i * 6.0, -1.3 + i * 0.3, 0.0)
	spawn_enemy("rotor", _start_s + 80.0, 0.0, 1.0)
	spawn_enemy("pulse_ring", _start_s + 95.0, 0.0, 0.0)
	spawn_enemy("barrier", _start_s + 110.0, PI * 0.6, 1.4)
	for e in enemies:
		e.age = 5.0
		e.damage(e.max_hp * 0.6)


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
	var playing := state in ACTIVE_STATES and not get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if playing else Input.MOUSE_MODE_VISIBLE
	var world_dt := dt * time_scale
	slow_carry = dt - world_dt
	state_t += dt
	_step_state(dt)
	director.update(player.s, dt)
	_apply_act_mods(dt)
	var shots := player.step(dt, _read_input())
	if not powerups.laser_active():
		for shot in shots:
			projectiles.add_shot(shot)
	if state in ACTIVE_STATES and not _gallery:
		_spawn_next()
	_step_entities(world_dt)
	powerups.update(dt)
	projectiles.update(dt, time_scale, player.s, player.speed)
	geoms.update(dt, player)
	if state in [State.PLAY, State.BOSS, State.PORTAL] and not _gallery:
		combat.resolve(dt)
	_sync_transforms(dt)
	_draw_lines()
	projectiles.render()
	geoms.render()
	tunnel.update_view(player.s)
	backdrop.follow(camera, dt)
	hud.refresh(_hud_state(), dt)


func _hud_state() -> Dictionary:
	return {"score": score, "multiplier": multiplier, "weapon": player.weapon,
		"hull": maxi(player.hull, 0), "speed": player.speed, "shield": player.shield_t,
		"rapid": player.rapid_t, "distance": player.s, "charge": player.charge,
		"kills": plan_kills if not is_arcade() else kills, "total": plan_total, "length": level.length,
		"act": director.index, "acts": director.count, "act_title": director.title,
		"reticle": _reticle_screen_pos(), "bank": player.bank_amount(), "hazard": _hazard_ahead(),
		"elapsed": elapsed, "arcade": is_arcade(), "boss_ratio": boss_ratio(),
		"slow": time_scale < 0.99, "power": powerups.active_label()}


# --------------------------------------------------------------- state flow

func _step_state(dt: float) -> void:
	match state:
		State.INTRO:
			if state_t >= INTRO_TIME:
				_set_state(State.PLAY)
				hud.announce("VAI!", "", 0.6)
		State.PLAY:
			elapsed += dt
			if is_arcade():
				run_end.add_survival_score(dt)
			elif player.s >= level.length:
				_start_boss()
		State.BOSS:
			elapsed += dt
			if bosses.all(func(b: Boss) -> bool: return b.done):
				_open_portal()
		State.PORTAL:
			elapsed += dt
			_portal.get_node("Ring").rotation.z += dt * 1.5
			_portal.get_node("Inner").rotation.z -= dt * 2.5
			if player.s >= _portal_s:
				_start_finale()
		State.FINALE:
			_step_finale(dt)
		State.RESULTS:
			hud.set_flash(1.0 - minf(1.0, state_t / 0.8))
			tunnel.set_flash(maxf(0.0, 0.35 - state_t * 0.4))
		State.DEAD:
			if state_t >= 1.6:
				_set_state(State.OVER)
				run_end.show_game_over()


func set_state(next: State) -> void:
	_set_state(next)


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
	var live := bosses.filter(func(b: Boss) -> bool: return b.alive)
	if not live.is_empty():
		target = (live[0] as Boss).th
	elif not enemies.is_empty():
		target = enemies[0].th
	var x := clampf(Track.angle_diff(target, player.th) * 3.0, -1.0, 1.0)
	if player.invert_x:
		x = -x
	return {"x": x, "y": 0.6, "fire": state != State.INTRO, "charge": false}


func enemies_may_fire() -> bool:
	return state in [State.PLAY, State.BOSS]


func boss_active() -> bool:
	return not bosses.is_empty()


func boss_ratio() -> float:
	if bosses.is_empty():
		return -1.0
	var hp := 0.0
	var total := 0.0
	for b in bosses:
		hp += maxf(b.hp, 0.0)
		total += b.max_hp
	return clampf(hp / maxf(total, 1.0), 0.0, 1.0)


# ----------------------------------------------------------------- spawning

func _spawn_next() -> void:
	if is_arcade():
		if state == State.PLAY:
			var batch := (director as ArcadeDirector).next_spawns(player.s, elapsed)
			combat.set_group_sizes(batch)
			for spec in batch:
				_spawn_spec(spec, spec.s)
		return
	var ahead := director.get_value("spawn_ahead")
	while not _plan.is_empty() and _plan[0].s <= player.s + ahead:
		var spec: Dictionary = _plan.pop_front()
		_spawn_spec(spec, maxf(spec.s, player.s + minf(60.0, ahead * 0.7)))


func _spawn_spec(spec: Dictionary, at: float) -> void:
	var kind := String(spec.kind)
	if kind.begins_with("pickup_"):
		powerups.spawn_pickup(kind.trim_prefix("pickup_"), at, spec.th)
		return
	var e := spawn_enemy(kind, at, spec.th, spec.phase, true)
	combat.register_group(e, int(spec.get("group", -1)))
	if spec.get("elite", false):
		e.make_elite()
	if kind == "serpent":
		for k in int(spec.get("segments", 8)):
			var body := spawn_enemy("serpent_body", at + (k + 1) * 2.0, spec.th, 0.0)
			body.leader = e
			body.slot = k + 1


func spawn_enemy(kind: String, s: float, th: float, phase: float, from_plan := false) -> Enemy:
	var e := Enemy.new()
	var heat := director.get_value("heat") if director else 1.0
	e.setup(kind, s, th, phase, (1.0 + maxi(level_index, 0) * 0.08) * heat)
	e.from_plan = from_plan
	add_child(e)
	enemies.append(e)
	return e


func _step_entities(dt: float) -> void:
	for e in enemies:
		e.step(dt, self)
	var gone := enemies.filter(func(e: Enemy) -> bool: return e.s < player.s - 10.0 or not e.alive)
	for e: Enemy in gone:
		if e.alive:
			combat.on_escaped(e)
		elif e.kind == "serpent_body":
			fx.explosion(e.global_position, e.spec.color, 0.8)
		e.queue_free()
	enemies = enemies.filter(func(e: Enemy) -> bool: return not (e in gone))
	for p in pickups:
		p.step(dt, player)
	for b in bosses:
		b.step(dt, self)


# ------------------------------------------------------------------- acts

func _on_act_started(index: int, title: String) -> void:
	if state != State.PLAY or (index == 0 and not is_arcade()):
		return
	var heading := "NÍVEL %d" % (index + 1) if is_arcade() else "ATO %d" % (index + 1)
	hud.announce(heading, title.to_upper(), 1.8, UiStyle.GOLD)
	Sfx.play("alert", -10.0, 1.3)
	if is_arcade():
		Sfx.play_music((director as ArcadeDirector).music_for_stage())


func _apply_act_mods(dt: float) -> void:
	if state == State.PLAY:
		player.min_speed_override = director.get_value("speed_floor")
	tunnel.set_brightness(director.get_value("brightness"))
	Sfx.set_intensity(1.0 if boss_active() or is_arcade() else director.intensity())
	if state in [State.INTRO, State.PLAY, State.BOSS]:
		tunnel.set_flash(director.strobe_pulse() * 0.08)
	_update_lane(dt)
	if state != State.PLAY:
		return
	if director.quake_due(dt):
		var at := track.point(player.s + randf_range(20.0, 60.0), randf_range(-PI, PI), 0.0)
		tunnel.add_ripple(at, 2.2)
		fx.shake = maxf(fx.shake, 0.35)
		Sfx.play("middle", -14.0, 0.5)
	_update_scorch(dt)


func _update_lane(dt: float) -> void:
	_lane_t += dt
	# Lane walls only exist during the scripted acts, never in boss fights.
	var lane := director.get_value("lane") if state == State.PLAY else PI
	var half := lane + sin(_lane_t * 0.9) * (director.get_value("lane_pulse") if state == State.PLAY else 0.0)
	player.lane_half = clampf(half, 0.45, PI)
	if player.lane_half < PI - 0.01:
		player.lane_center = wrapf(sin(_lane_t * 0.21) * 1.4, -PI, PI)


## "Scorch" acts punish standing still: move or the hull burns.
func _update_scorch(dt: float) -> void:
	if director.get_value("scorch") < 0.5:
		_scorch_t = 0.0
		return
	if absf(Track.angle_diff(player.th, _scorch_th)) > 0.35:
		_scorch_th = player.th
		_scorch_t = 0.0
		return
	_scorch_t += dt
	if _scorch_t > SCORCH_LIMIT * 0.55 and fmod(_scorch_t, 0.5) < dt:
		hud.announce("", "CALOR! MOVA-SE!", 0.5, UiStyle.DANGER)
	if _scorch_t > SCORCH_LIMIT:
		_scorch_t = 0.0
		combat.hurt_player(player.global_position)


func _on_lane_bump() -> void:
	if fmod(elapsed, 0.15) < 0.05:
		fx.sparks(player.global_position, level.tint.lightened(0.4), 6, 10.0, 0.6, 0.2)
	fx.shake = maxf(fx.shake, 0.08)


func _draw_lines() -> void:
	if player.lane_half < PI - 0.01:
		var wall: Color = (level.tint as Color).lightened(0.35)
		for side in [-1.0, 1.0]:
			var a: float = player.lane_center + side * (player.lane_half + 0.08)
			lines.line("lane", wall, player.s + 4.0, player.s + 170.0, a, 0.05, 0.12, 1.5)
	for e in enemies:
		if e.kind == "laser" and e.beam_state > 0:
			var firing := e.beam_state == 2
			lines.line("beam_fire" if firing else "beam_warn", Color(1, 0.2, 0.2) if firing else Color(1, 0.4, 0.4),
				player.s + 1.0, e.s, e.th, Player.H, 0.55 if firing else 0.05, 3.0 if firing else 1.5)
	powerups.draw_laser()
	lines.flush()


## Screen position of the aim point straight ahead of the ship.
func _reticle_screen_pos() -> Vector2:
	var aim := track.point(player.s + 28.0, player.th, Player.H)
	if camera.is_position_behind(aim):
		return Vector2(-1000, -1000)
	return camera.unproject_position(aim)


## Is an indestructible obstacle or a laser lane coming up for the ship?
func _hazard_ahead() -> bool:
	for e in enemies:
		var ahead := e.s - player.s
		if ahead < 0.0 or ahead > 70.0:
			continue
		if e.kind == "laser" and e.beam_state > 0 and absf(Track.angle_diff(player.th, e.th)) < 0.25:
			return true
		if e.invulnerable and (e.kind in ["rotor", "pulse_ring"] or e.blocks_shot(player.th)):
			return true
	return false


func _sync_transforms(dt: float) -> void:
	player.global_transform = track.pose(player.s, player.th, Player.H)
	for e in enemies:
		if e.uses_frame():
			var fr := track.frame(e.s)
			e.global_transform = Transform3D(fr.basis * Basis(Vector3.BACK, e.frame_angle()), fr.origin)
		else:
			e.global_transform = track.pose(e.s, e.th, e.h)
	for p in pickups:
		p.global_transform = track.pose(p.s, p.th, p.h)
	for b in bosses:
		b.global_transform = track.pose(b.s, b.th, b.h)
	_update_camera(dt)


func _update_camera(dt: float) -> void:
	_cam_th = lerp_angle(_cam_th, player.th, minf(1.0, 7.0 * dt)) if dt > 0.0 else player.th
	var eye := track.point(player.s - 7.0, _cam_th, Track.RADIUS - 3.0)
	var target := track.point(player.s + 26.0, _cam_th, Track.RADIUS - 3.4)
	var up := -Track.radial(track.frame(player.s), _cam_th)
	var flip := director.get_value("flip") if state == State.PLAY else 0.0
	var roll_target := director.roll() + flip * PI - player.bank_amount() * 0.12
	_cam_roll = lerpf(_cam_roll, roll_target, minf(1.0, dt * 3.0)) if dt > 0.0 else roll_target
	up = up.rotated((target - eye).normalized(), _cam_roll)
	camera.look_at_from_position(eye, target, up)
	# Upside down, steering is mirrored so it stays screen-relative; the
	# swap happens exactly when the camera passes 90°.
	player.invert_x = cos(_cam_roll - director.roll()) < 0.0
	camera.fov = lerpf(camera.fov, 78.0 + (player.speed - Player.BASE_SPEED) * 0.4, minf(1.0, dt * 4.0))
	var amount := fx.shake if bool(Save.settings.shake) else 0.0
	camera.h_offset = randf_range(-1.0, 1.0) * amount * 0.6
	camera.v_offset = randf_range(-1.0, 1.0) * amount * 0.6
	fx.shake = move_toward(fx.shake, 0.0, dt * 2.2)


# ------------------------------------------------------------------ firing

func fire_bullet(s: float, th: float, h: float, rel_speed: float, vth: float) -> void:
	var speed_k := director.get_value("heat") if director else 1.0
	projectiles.add_bullet(s, th, h, player.speed - rel_speed * sqrt(speed_k), vth)


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
	var at := track.point(s, th, Player.H)
	fx.sparks(at, Color(0.8, 1.0, 1.0), 40, 30.0, 1.6, 0.4)
	fx.shockwave(at, Color(0.8, 1.0, 1.0), 5.0)
	fx.shake = maxf(fx.shake, 0.25)
	Sfx.play("nova")


func _on_geom(pos: Vector3) -> void:
	multiplier = mini(MAX_MULTIPLIER, multiplier + 1)
	max_multiplier = maxi(max_multiplier, multiplier)
	fx.sparks(pos, EnemyTypes.GEOM_COLOR, 4, 8.0, 0.5, 0.2)
	Sfx.play("shot", -18.0, 2.2)


# --------------------------------------------------------- boss and portal

func _start_boss() -> void:
	_set_state(State.BOSS)
	player.min_speed_override = 0.0
	Sfx.play_music("boss")
	var spec := BossSpecs.for_level(level_index)
	var twins: bool = spec.get("twins", false)
	for i in (2 if twins else 1):
		var b := Boss.new()
		b.setup(level, level_index, player.s + 110.0 + i * 8.0, player.th + i * PI, 0.5 if twins else 1.0, i * PI)
		add_child(b)
		bosses.append(b)
	hud.show_boss(level.boss)
	hud.announce("ALERTA", "CHEFE: " + String(level.boss).to_upper(), 2.2, UiStyle.DANGER)
	Sfx.play("alert")


func on_boss_killed(_b: Boss) -> void:
	if bosses.any(func(b: Boss) -> bool: return b.alive):
		hud.announce("", "UM A MENOS!", 1.0, UiStyle.GOLD)
		return
	score += int(5000 * (1.0 + level_index * 0.25))
	fx.shake = 0.6
	combat.explode_all_bullets()
	for e in enemies:
		e.shielded = false
		e.hidden = false
		if e.alive and e.damage(999.0):
			combat.on_enemy_killed(e)
	enemies = enemies.filter(func(e: Enemy) -> bool: return e.alive)


func _open_portal() -> void:
	_set_state(State.PORTAL)
	hud.hide_boss()
	_portal_s = bosses[0].s + 40.0
	for b in bosses:
		b.queue_free()
	bosses.clear()
	player.external_drift = 0.0
	_portal = Meshes.portal()
	add_child(_portal)
	_portal.global_transform = track.pose(_portal_s, 0.0, Track.RADIUS)
	player.min_speed_override = 42.0
	hud.announce("CHEFE DERROTADO", "Entre no portal!", 2.0, UiStyle.GOOD)


func _start_finale() -> void:
	_set_state(State.FINALE)
	player.min_speed_override = 70.0
	Sfx.play("boss")
	combat.explode_all_bullets()
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
		_set_state(State.RESULTS)
		player.min_speed_override = 0.0
		run_end.show_results()


func on_player_died() -> void:
	_set_state(State.DEAD)
	Sfx.play("ship")
	fx.explosion(player.global_position, EnemyTypes.PLAYER_COLOR, 2.5)
	fx.explosion(player.global_position, Color(1, 1, 1), 1.5)
	fx.shake = 1.0
	player.min_speed_override = 0.0
	player.external_drift = 0.0


# --------------------------------------------------------- pause, overlays

func _pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var buttons: Array = [["Continuar", _resume]]
	if is_arcade():
		buttons.append(["Encerrar partida (conta pontos)", _end_arcade_run])
		buttons.append(["Recomeçar", func() -> void: leave(-2)])
	else:
		buttons.append(["Reiniciar setor", func() -> void: leave(level_index)])
	buttons.append(["Menu principal", func() -> void: leave(-1)])
	var sub := "Modo Arcade" if is_arcade() else "Setor %d · %s" % [level_index + 1, level.name]
	show_overlay(Overlay.create("PAUSADO", sub, [], buttons, UiStyle.ACCENT, _resume))


func _resume() -> void:
	get_tree().paused = false
	close_overlay()


func _end_arcade_run() -> void:
	get_tree().paused = false
	close_overlay()
	_set_state(State.OVER)
	player.alive = false
	run_end.show_game_over()


func show_overlay(overlay: Control) -> void:
	close_overlay()
	_overlay = overlay
	hud.add_overlay(overlay)


func close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.set_intensity(1.0)
	player.external_drift = 0.0


## next_level: -1 = menu, -2 = new arcade run, otherwise a sector index.
func leave(next_level: int) -> void:
	if _leaving:
		return
	_leaving = true
	process_mode = Node.PROCESS_MODE_DISABLED
	if next_level == -1:
		request_menu.emit.call_deferred()
	elif next_level == -2:
		request_arcade.emit.call_deferred()
	else:
		request_level.emit.call_deferred(next_level)
