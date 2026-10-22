class_name Enemy
extends Node3D
## Enemy or obstacle. Behaviour depends on `kind` (see EnemyTypes).
## Tough enemies take many hits and show it: hit punch + jitter, sparks,
## a health bar, and smoke/flicker when nearly dead. Obstacles ("barrier",
## "rotor") are indestructible and must be dodged.

const HP_BAR_CELLS := 8

var kind := ""
var spec: Dictionary
var s := 0.0
var th := 0.0
var h := 1.1
var hp := 1.0
var max_hp := 1.0
var alive := true
var age := 0.0
var from_plan := false
var invulnerable := false
var half_width := 0.0

var _base_th := 0.0
var _phase := 0.0
var _fire_cd := 0.0
var _flash := 0.0
var _punch := 0.0
var _smoke_cd := 0.0
var _difficulty := 1.0
var _prev_rel := INF
var _crossed := false
var _hold_rel := INF
var spark_cd := 0.0
const TRAIL_STEP := 0.5
const BODY_GAP := 4
var _hit_written := 0.0
var _elite_scale := 1.0
## Splitter generation (0 = full size); serpent body leader and slot.
var generation := 0
var leader: Enemy
var slot := 0
var trail: Array[Vector2] = []
var shielded := false
var hidden := false
var beam_state := 0
var _cycle := 0.0
var _fade_written := 1.0
var _model: Node3D
var _spin: Node3D
var _orbit: Node3D
var _hp_label: Label3D
var _geometry: Array[GeometryInstance3D] = []


func setup(p_kind: String, p_s: float, p_th: float, phase: float, difficulty: float) -> void:
	kind = p_kind
	spec = EnemyTypes.get_type(kind)
	s = p_s
	th = p_th
	_base_th = p_th
	_phase = phase
	_difficulty = difficulty
	invulnerable = spec.get("invulnerable", false)
	max_hp = spec.hp
	hp = max_hp
	h = 1.6 if kind == "tank" else 1.1
	_fire_cd = randf_range(0.6, 1.4)
	if kind == "barrier":
		half_width = clampf(phase, 0.7, 2.2)
		_model = Meshes.barrier(half_width)
	else:
		_model = Meshes.enemy(kind)
	add_child(_model)
	_spin = _model.get_node_or_null("Spin")
	_orbit = _model.get_node_or_null("Orbit")
	_geometry = Meshes.geometry_of(_model)
	for g in _geometry:
		g.set_instance_shader_parameter("phase", _phase * 3.0)
	_model.scale = Vector3.ONE * 0.01
	if kind in ["drone", "weaver", "tank", "seeker", "swarm"]:
		var trail := Fx.make_trail(spec.color, 18, 0.25, 0.5 if kind == "tank" else 0.3)
		trail.position = Vector3(0, 0, -0.6)
		add_child(trail)
		trail.emitting = true
	if max_hp >= 4.0 and not invulnerable:
		_hp_label = _make_hp_label()
		add_child(_hp_label)


## Obstacles are placed in the tunnel's cross-section frame, not on the wall.
func uses_frame() -> bool:
	return kind in ["barrier", "rotor", "pulse_ring"]


## World angle the cross-section model is rotated to (frame mode only).
func frame_angle() -> float:
	return th


func step(dt: float, game: Game) -> void:
	age += dt
	spark_cd = maxf(0.0, spark_cd - dt)
	# Slow motion slows the world *relative to the ship*: carry the enemy
	# along with the ship for the part of the frame the world skipped.
	s += game.player.speed * game.slow_carry
	var ahead := s - game.player.s
	# Crossing detection runs every frame so it never goes stale while the
	# ship is invulnerable.
	_crossed = (_prev_rel > 0.0 and ahead <= 0.0 and ahead > -4.0) or absf(ahead) < 0.9
	_prev_rel = ahead
	match kind:
		"drone":
			s += 9.0 * dt
			th = _base_th + sin(age * 1.4 + _phase) * 0.22
		"weaver":
			s += 13.0 * dt
			th = _base_th + sin(age * 2.6 + _phase) * 1.0
		"gunner":
			_hold_ahead(dt, game, 36.0, 7.0)
			th = lerp_angle(th, game.player.th, dt * 0.35)
			_try_fire(dt, game, ahead, 1.5, func(): game.fire_aimed(s, th, h, 24.0, 3 if _difficulty > 1.3 else 1, 0.12))
		"seeker":
			if age > 0.6:
				s -= 20.0 * dt
				th = lerp_angle(th, game.player.th, dt * 1.3)
			h = 1.1 + sin(age * 4.0 + _phase) * 0.25
		"swarm":
			s -= 12.0 * dt
			th = wrapf(_base_th + age * 1.9, -PI, PI)
			h = 1.0 + sin(age * 6.0 + _phase) * 0.4
		"tank":
			_hold_ahead(dt, game, 44.0, 9.0)
			th = lerp_angle(th, game.player.th, dt * 0.25)
			_try_fire(dt, game, ahead, 2.1, func(): game.fire_aimed(s, th, h, 20.0, 5, 0.16))
		"barrier":
			th = _base_th + sin(age * 0.6 + _phase) * 0.25
		"rotor":
			pass
		_:
			_step_special(dt, game)
	_animate(dt, game)


const LASER_CYCLE := [1.4, 1.0, 0.9]
const PULSE_PERIOD := 2.4
const PULSE_ON := 0.7


func _step_special(dt: float, game: Game) -> void:
	_cycle += dt
	match kind:
		"phantom":
			s += 4.0 * dt
			th = lerp_angle(th, game.player.th, dt * 0.5)
			var phase_t := fmod(_cycle + _phase, 2.8)
			hidden = phase_t > 1.6 and not game.combat.nova_active()
		"splitter":
			s += 7.0 * dt
			th = _base_th + sin(age * 1.8 + _phase) * 0.5
		"warden":
			_hold_ahead(dt, game, 40.0, 8.0)
			th = lerp_angle(th, _base_th, dt)
		"laser":
			_hold_ahead(dt, game, 46.0, 9.0)
			var t := fmod(_cycle, LASER_CYCLE[0] + LASER_CYCLE[1] + LASER_CYCLE[2])
			beam_state = 0 if t < LASER_CYCLE[0] else (1 if t < LASER_CYCLE[0] + LASER_CYCLE[1] else 2)
			if not game.enemies_may_fire():
				beam_state = 0
		"serpent":
			s -= 5.0 * dt
			th = _base_th + sin(age * 1.2 + _phase) * 1.1
			# One trail point per fixed arc length, so body spacing does not
			# depend on frame rate or slow motion.
			var here := Vector2(s, th)
			if trail.is_empty() or Vector2(here.x - trail[-1].x, Track.angle_diff(here.y, trail[-1].y) * Track.RADIUS).length() >= TRAIL_STEP:
				trail.append(here)
			if trail.size() > 240:
				trail.pop_front()
		"serpent_body":
			if leader == null or not is_instance_valid(leader) or not leader.alive:
				alive = false
				return
			var idx := leader.trail.size() - 1 - slot * BODY_GAP
			if idx >= 0:
				s = leader.trail[idx].x
				th = leader.trail[idx].y
			else:
				s = leader.s + slot * 2.0
		"decoy":
			s += 3.0 * dt
			th = _base_th + sin(age * 2.2 + _phase) * 0.7
		"pulse_ring":
			beam_state = 2 if fmod(_cycle + _phase, PULSE_PERIOD) < PULSE_ON else (
				1 if fmod(_cycle + _phase, PULSE_PERIOD) > PULSE_PERIOD - 0.45 else 0)


## Laser lane check: is the ship inside the firing beam?
func beam_hits(player: Player) -> bool:
	return kind == "laser" and beam_state == 2 and s > player.s \
		and absf(Track.angle_diff(player.th, th)) < 0.16


## True when the player's ship collides with this enemy this frame.
func touches(player: Player) -> bool:
	var crossed := _crossed
	match kind:
		"barrier":
			return crossed and absf(Track.angle_diff(player.th, th)) < half_width + 0.06
		"pulse_ring":
			return crossed and beam_state == 2
		"rotor":
			if not crossed:
				return false
			var blade := th + _spin.rotation.z
			for k in 2:
				if absf(Track.angle_diff(player.th, blade + k * PI)) < 0.17:
					return true
			return false
	if hidden:
		return false
	return Track.distance(s, th, h, player.s, player.th, Player.H) < spec.radius + 0.5


## Does this enemy stop a player shot passing at angle `shot_th`?
func blocks_shot(shot_th: float) -> bool:
	return kind == "barrier" and absf(Track.angle_diff(shot_th, th)) < half_width


## Holds a fixed distance ahead of the ship (independent of ship speed and
## slow motion), then drifts back toward it once `hold_time` is over.
func _hold_ahead(dt: float, game: Game, distance: float, hold_time: float) -> void:
	if _hold_rel == INF:
		_hold_rel = s - game.player.s
	var target := distance if age < hold_time else -20.0
	_hold_rel = lerpf(_hold_rel, target, minf(1.0, dt * (1.4 if age < hold_time else 0.25)))
	s = game.player.s + _hold_rel


func _try_fire(dt: float, game: Game, ahead: float, interval: float, fire: Callable) -> void:
	_fire_cd -= dt * _difficulty
	if _fire_cd > 0.0 or ahead < 12.0 or ahead > 80.0 or not game.enemies_may_fire():
		return
	_fire_cd = interval
	fire.call()


## Smaller generation of a splitter.
func set_generation(gen: int) -> void:
	generation = gen
	max_hp = maxf(1.0, spec.hp / pow(2.0, gen))
	hp = max_hp
	_elite_scale = pow(0.7, gen)


## Elite variant: much tougher and bigger (mid-act mini-boss).
func make_elite() -> void:
	max_hp *= 2.5
	hp = max_hp
	_elite_scale = 1.45
	if _hp_label == null:
		_hp_label = _make_hp_label()
		add_child(_hp_label)
	_hp_label.visible = true
	_update_hp_label()


## Returns true when this hit destroys the enemy.
func damage(amount: float) -> bool:
	if not alive or invulnerable or hidden:
		return false
	if shielded:
		_flash = 0.3
		return false
	hp -= amount
	_flash = 0.8
	_punch = 1.0
	if _hp_label:
		_hp_label.visible = true
		_update_hp_label()
	if hp <= 0.0:
		alive = false
		return true
	return false


func health_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func _animate(dt: float, game: Game) -> void:
	if _spin:
		match kind:
			"drone":
				_spin.rotation += Vector3(1.3, 2.1, 0.0) * dt
			"weaver":
				_spin.rotation.z += dt * 7.0
			"gunner":
				_spin.rotation += Vector3(0.9, 1.4, 0.4) * dt
			"mine":
				_spin.rotation.z += dt * 2.4
				_spin.rotation.y += dt * 1.1
			"tank":
				_spin.rotation += Vector3(0.3, 0.6, 0.0) * dt
			"seeker":
				_spin.rotation += Vector3(2.0, 1.4, 0.8) * dt
			"swarm":
				_spin.rotation.z += dt * 9.0
			"phantom", "decoy":
				_spin.rotation.y += dt * 2.5
			"splitter", "serpent_body":
				_spin.rotation += Vector3(1.1, 1.7, 0.0) * dt
			"warden":
				_spin.rotation.z += dt * 1.2
			"laser":
				_spin.rotation.y += dt * (8.0 if beam_state > 0 else 1.5)
			"serpent":
				_spin.rotation.z += dt * 3.0
			"pulse_ring":
				_spin.rotation.z += dt * 0.6
			"spike":
				_spin.rotation.z += dt * 1.0
			"rotor":
				_spin.rotation.z += dt * (1.1 + _difficulty * 0.35) * (1.0 if _phase >= 0.0 else -1.0)
	if _orbit:
		_orbit.rotation.z -= dt * 2.2
	# Spawn: spiral in from nothing, then breathe. Hits punch and shake it.
	var grow := ease(minf(1.0, age / 0.45), 0.35)
	var breathe := 1.0 + sin(age * 5.0 + _phase) * 0.07
	var size := 1.0 if uses_frame() else 1.25 * _elite_scale
	_model.scale = Vector3.ONE * size * grow * (breathe + _punch * 0.25)
	_model.rotation.z = (1.0 - grow) * TAU if not uses_frame() else 0.0
	_model.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.22 * _punch
	_punch = maxf(0.0, _punch - dt * 7.0)
	var hurt := not invulnerable and max_hp >= 4.0 and health_ratio() < 0.4
	if hurt:
		_smoke_cd -= dt
		if _smoke_cd <= 0.0:
			_smoke_cd = 0.12
			game.fx.sparks(global_position, spec.color, 3, 6.0, 0.6, 0.35)
	var flicker := 0.35 if hurt and fmod(age, 0.18) < 0.06 else 0.0
	if kind in ["pulse_ring", "laser"]:
		flicker = [0.0, 0.25 if fmod(age, 0.12) < 0.06 else 0.0, 0.7][beam_state]
	if shielded:
		flicker = maxf(flicker, 0.15)
	var flash := maxf(_flash, flicker)
	var fade := 0.12 if hidden else (0.35 if kind == "pulse_ring" and beam_state == 0 else 1.0)
	if not is_equal_approx(fade, _fade_written):
		_fade_written = fade
		for g in _geometry:
			g.set_instance_shader_parameter("fade", fade)
	if not is_equal_approx(flash, _hit_written):
		_hit_written = flash
		for g in _geometry:
			g.set_instance_shader_parameter("hit", flash)
	_flash = maxf(0.0, _flash - dt * 9.0)


func _make_hp_label() -> Label3D:
	var label := Label3D.new()
	label.font = UiStyle.font()
	label.font_size = 30
	label.outline_size = 8
	label.pixel_size = 0.001
	label.fixed_size = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.modulate = spec.color.lightened(0.3)
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.position = Vector3(0, 2.4 if kind == "tank" else 1.8, 0)
	label.visible = false
	return label


func _update_hp_label() -> void:
	var filled := ceili(health_ratio() * HP_BAR_CELLS)
	_hp_label.text = "▰".repeat(filled) + "▱".repeat(HP_BAR_CELLS - filled)
