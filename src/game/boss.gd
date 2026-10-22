class_name Boss
extends Node3D
## Sector boss: hovers ahead of the player and cycles bullet patterns.

const PATTERNS := ["fan", "ring", "spiral", "burst"]
const DEATH_TIME := 1.8

var title := ""
var color := Color.RED
var s := 0.0
var th := 0.0
var h := 2.4
var hp := 100.0
var max_hp := 100.0
var radius := 2.6
var alive := true
var dying := false
var done := false

var _t := 0.0
var _difficulty := 1.0
var _pattern := 0
var _pattern_t := 0.0
var _shots_left := 0
var _cooldown := 2.0
var _shot_cd := 0.0
var _flash := 0.0
var _death_t := 0.0
var _escort_cd := 6.0
var _model: Node3D
var _ring_a: Node3D
var _ring_b: Node3D
var _core: Node3D
var _geometry: Array[GeometryInstance3D] = []


func setup(level: Dictionary, index: int, p_s: float, p_th: float) -> void:
	title = level.boss
	color = level.boss_color
	max_hp = level.boss_hp
	hp = max_hp
	s = p_s
	th = p_th
	_difficulty = 1.0 + index * 0.1
	_model = Meshes.boss(color)
	add_child(_model)
	_ring_a = _model.get_node("RingA")
	_ring_b = _model.get_node("RingB")
	_core = _model.get_node("Core")
	_geometry = Meshes.geometry_of(_model)


func health_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func step(dt: float, game: Game) -> void:
	_t += dt
	_flash = maxf(0.0, _flash - dt * 6.0)
	_ring_a.rotation.z += dt * (1.4 if hp > max_hp * 0.5 else 2.6)
	_ring_b.rotation.y += dt * 0.9
	_ring_b.rotation.x += dt * 0.5
	_core.rotation += Vector3(0.4, 0.7, 0.0) * dt
	for g in _geometry:
		g.set_instance_shader_parameter("hit", _flash)
	s = lerpf(s, game.player.s + 52.0, minf(1.0, dt * 1.1))
	if dying:
		_step_dying(dt, game)
		return
	th = lerp_angle(th, game.player.th + sin(_t * 0.7) * 0.9, dt * 0.9)
	if _t > 1.5:
		_step_attack(dt, game)


func damage(amount: float) -> bool:
	if not alive:
		return false
	hp -= amount
	_flash = 0.45
	if hp <= 0.0:
		alive = false
		dying = true
		return true
	return false


func _rage() -> float:
	return 1.45 if hp < max_hp * 0.5 else 1.0


func _step_attack(dt: float, game: Game) -> void:
	var speed_k := _difficulty * _rage()
	if _shots_left <= 0:
		_cooldown -= dt * speed_k
		if _cooldown <= 0.0:
			_start_pattern()
	else:
		_shot_cd -= dt * speed_k
		_pattern_t += dt
		if _shot_cd <= 0.0:
			_fire(game)
	if _rage() > 1.0:
		_escort_cd -= dt
		if _escort_cd <= 0.0:
			_escort_cd = 7.0
			game.spawn_enemy("drone", s - 6.0, th + 0.6, 0.0)
			game.spawn_enemy("drone", s - 6.0, th - 0.6, 1.0)


func _start_pattern() -> void:
	_pattern_t = 0.0
	_shot_cd = 0.0
	match PATTERNS[_pattern]:
		"fan": _shots_left = 3
		"ring": _shots_left = 3
		"spiral": _shots_left = 36
		"burst": _shots_left = 6


func _fire(game: Game) -> void:
	_shots_left -= 1
	match PATTERNS[_pattern]:
		"fan":
			game.fire_aimed(s, th, h, 22.0, 7, 0.13)
			_shot_cd = 0.75
		"ring":
			game.fire_ring(s, h, 22, game.player.th + randf_range(-1.2, 1.2), 3, 17.0)
			_shot_cd = 1.0
		"spiral":
			var a := th + _pattern_t * 3.2
			game.fire_bullet(s, a, h, 20.0, 0.0)
			game.fire_bullet(s, a + PI, h, 20.0, 0.0)
			_shot_cd = 0.07
		"burst":
			game.fire_aimed(s, th, h, 34.0, 1, 0.0)
			_shot_cd = 0.2
	if _shots_left <= 0:
		_pattern = (_pattern + 1) % PATTERNS.size()
		_cooldown = 1.3


func _step_dying(dt: float, game: Game) -> void:
	_death_t += dt
	_model.rotation.z += dt * 3.0
	if randf() < 0.3:
		var offset := Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-2, 2))
		game.fx.explosion(global_position + offset, color if randf() < 0.7 else Color(1, 0.85, 0.5), 0.9)
		Sfx.play("middle", -4.0, randf_range(0.8, 1.2))
	if _death_t >= DEATH_TIME:
		game.fx.explosion(global_position, color, 3.5)
		game.fx.explosion(global_position, Color(1, 0.9, 0.6), 2.5)
		game.fx.shake = 1.0
		Sfx.play("boss")
		_model.visible = false
		done = true
