class_name Enemy
extends Node3D
## Regular enemy. Behaviour depends on `kind` (see EnemyTypes).

var kind := ""
var spec: Dictionary
var s := 0.0
var th := 0.0
var h := 1.1
var hp := 1.0
var alive := true
var age := 0.0
var from_plan := false

var _base_th := 0.0
var _phase := 0.0
var _fire_cd := 0.0
var _flash := 0.0
var _difficulty := 1.0
var _model: Node3D
var _spin: Node3D
var _orbit: Node3D
var _geometry: Array[GeometryInstance3D] = []


func setup(p_kind: String, p_s: float, p_th: float, phase: float, difficulty: float) -> void:
	kind = p_kind
	spec = EnemyTypes.get_type(kind)
	s = p_s
	th = p_th
	_base_th = p_th
	_phase = phase
	_difficulty = difficulty
	hp = spec.hp
	h = 1.6 if kind == "tank" else 1.1
	_fire_cd = randf_range(0.6, 1.4)
	_model = Meshes.enemy(kind)
	add_child(_model)
	_spin = _model.get_node_or_null("Spin")
	_orbit = _model.get_node_or_null("Orbit")
	_geometry = Meshes.geometry_of(_model)
	_model.scale = Vector3.ONE * 0.01
	if kind in ["drone", "weaver", "tank", "seeker", "swarm"]:
		var trail := Fx.make_trail(spec.color, 18, 0.25, 0.5 if kind == "tank" else 0.3)
		trail.position = Vector3(0, 0, -0.6)
		add_child(trail)
		trail.emitting = true


func step(dt: float, game: Game) -> void:
	age += dt
	_flash = maxf(0.0, _flash - dt * 10.0)
	var ahead := s - game.player.s
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
	_animate(dt)


func _hold_ahead(dt: float, game: Game, distance: float, hold_time: float) -> void:
	if age < hold_time:
		s = lerpf(s, game.player.s + distance, minf(1.0, dt * 1.4))
	else:
		s += 6.0 * dt


func _try_fire(dt: float, game: Game, ahead: float, interval: float, fire: Callable) -> void:
	_fire_cd -= dt * _difficulty
	if _fire_cd > 0.0 or ahead < 12.0 or ahead > 80.0 or not game.enemies_may_fire():
		return
	_fire_cd = interval
	fire.call()


## Returns true when this hit destroys the enemy.
func damage(amount: float) -> bool:
	if not alive:
		return false
	hp -= amount
	_flash = 0.7
	if hp <= 0.0:
		alive = false
		return true
	return false


func _animate(dt: float) -> void:
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
	if _orbit:
		_orbit.rotation.z -= dt * 2.2
	# Spawn: spiral in from nothing, then a gentle breathing pulse.
	var grow := ease(minf(1.0, age / 0.45), 0.35)
	var breathe := 1.0 + sin(age * 5.0 + _phase) * 0.07
	_model.scale = Vector3.ONE * 1.25 * grow * breathe
	_model.rotation.z = (1.0 - grow) * TAU
	var pulse := 0.5 + 0.5 * sin(age * 6.0 + _phase)
	for g in _geometry:
		g.set_instance_shader_parameter("hit", _flash)
		g.set_instance_shader_parameter("pulse", pulse)
