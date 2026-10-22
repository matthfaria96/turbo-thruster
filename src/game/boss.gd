class_name Boss
extends Node3D
## Sector boss driven by BossSpecs: phases of bullet patterns, optional
## destructible orbiting parts (heads/armour plates), pull, cloak with
## decoys, colour morphing between phases, and a long death sequence.

const DEATH_TIME := 1.8
const MORPH_COLORS := [Color(1.0, 0.2, 0.3), Color(1.0, 0.6, 0.1), Color(0.8, 0.3, 1.0), Color(1.0, 0.9, 0.2)]

var title := ""
var color := Color.RED
var spec: Dictionary
var s := 0.0
var th := 0.0
var h := 2.4
var hp := 100.0
var max_hp := 100.0
var radius := 2.6
var alive := true
var dying := false
var done := false
var cloaked := false
var parts: Array[Dictionary] = []

var _t := 0.0
var _difficulty := 1.0
var _phase := 0
var _pattern := 0
var _pattern_t := 0.0
var _shots_left := 0
var _cooldown := 2.0
var _shot_cd := 0.0
var _flash := 0.0
var _death_t := 0.0
var _escort_cd := 6.0
var _cloak_t := 0.0
var _offset_th := 0.0
var _rel := INF
var _model: Node3D
var _parts_root: Node3D
var _geometry: Array[GeometryInstance3D] = []


func setup(level: Dictionary, index: int, p_s: float, p_th: float, hp_share := 1.0, offset_th := 0.0) -> void:
	spec = BossSpecs.for_level(index)
	title = level.boss
	color = level.boss_color
	max_hp = float(level.boss_hp) * hp_share
	hp = max_hp
	s = p_s
	th = p_th
	_offset_th = offset_th
	_difficulty = 1.0 + index * 0.08
	_build_model()
	_build_parts(index)


func _build_model() -> void:
	if _model:
		_model.queue_free()
	_model = Meshes.boss(color)
	add_child(_model)
	_geometry = Meshes.geometry_of(_model)


func _build_parts(index: int) -> void:
	var p: Dictionary = spec.get("parts", {})
	if p.is_empty():
		return
	_parts_root = Node3D.new()
	add_child(_parts_root)
	var count: int = p.count
	for i in count:
		var node := Meshes.boss_part(String(p.shape), color.lightened(0.25))
		var angle := TAU * i / count
		node.position = Vector3(cos(angle), sin(angle), 0.0) * float(p.radius)
		_parts_root.add_child(node)
		parts.append({"node": node, "hp": float(p.hp) * (1.0 + index * 0.05), "alive": true,
			"geo": Meshes.geometry_of(node), "flash": 0.0})


func health_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func parts_alive() -> int:
	return parts.filter(func(p: Dictionary) -> bool: return p.alive).size()


func core_hittable() -> bool:
	return alive and not cloaked


func step(dt: float, game: Game) -> void:
	_t += dt
	_animate(dt)
	_rel = lerpf(s - game.player.s if _rel == INF else _rel, 52.0, minf(1.0, dt * 1.1))
	s = game.player.s + _rel
	if dying:
		_step_dying(dt, game)
		return
	var target := game.player.th + _offset_th + sin(_t * 0.7) * 0.9
	th = lerp_angle(th, target, dt * 0.9)
	_update_phase()
	_update_cloak(dt, game)
	var pull: float = spec.get("pull", 0.0)
	game.player.external_drift = signf(Track.angle_diff(th, game.player.th)) * pull if pull > 0.0 else 0.0
	if _t > 1.5:
		_step_attack(dt, game)


func _animate(dt: float) -> void:
	_flash = maxf(0.0, _flash - dt * 6.0)
	var rage := 2.6 if hp < max_hp * 0.5 else 1.4
	_model.get_node("RingA").rotation.z += dt * rage
	var ring_b: Node3D = _model.get_node("RingB")
	ring_b.rotation.y += dt * 0.9
	ring_b.rotation.x += dt * 0.5
	_model.get_node("Core").rotation += Vector3(0.4, 0.7, 0.0) * dt
	var fade := 0.18 if cloaked else 1.0
	for g in _geometry:
		g.set_instance_shader_parameter("hit", _flash)
		g.set_instance_shader_parameter("fade", fade)
	if _parts_root:
		_parts_root.rotation.z += dt * 0.8
		for p in parts:
			p.flash = maxf(0.0, float(p.flash) - dt * 8.0)
			for g: GeometryInstance3D in p.geo:
				g.set_instance_shader_parameter("hit", p.flash)
				g.set_instance_shader_parameter("fade", fade)


## Damage to the core, reduced while protective parts survive.
func damage(amount: float) -> bool:
	if not core_hittable():
		return false
	var mult: float = spec.get("parts", {}).get("core_mult", 1.0) if parts_alive() > 0 else 1.0
	hp -= amount * mult
	_flash = 0.45 if mult > 0.0 else 0.1
	if hp <= 0.0:
		alive = false
		dying = true
		return true
	return false


func core_shielded() -> bool:
	return parts_alive() > 0 and float(spec.get("parts", {}).get("core_mult", 1.0)) < 0.5


func part_position(i: int) -> Vector3:
	return (parts[i].node as Node3D).global_position


## Returns true when the part is destroyed by this hit.
func damage_part(i: int, amount: float) -> bool:
	var p := parts[i]
	if not p.alive:
		return false
	p.hp = float(p.hp) - amount
	p.flash = 0.8
	if float(p.hp) <= 0.0:
		p.alive = false
		(p.node as Node3D).visible = false
		return true
	return false


func _update_phase() -> void:
	var phases: Array = spec.phases
	var next := _phase
	for i in phases.size():
		if health_ratio() <= float(phases[i].at):
			next = i
	if next == _phase:
		return
	_phase = next
	_pattern = 0
	_shots_left = 0
	_cooldown = 0.8
	if spec.get("morph", false):
		color = MORPH_COLORS[_phase % MORPH_COLORS.size()]
		_build_model()
		_flash = 1.0


func _update_cloak(dt: float, game: Game) -> void:
	var cycle: Array = spec.get("cloak", [])
	if cycle.is_empty():
		return
	_cloak_t += dt
	var limit: float = cycle[1] if cloaked else cycle[0]
	if _cloak_t < limit:
		return
	_cloak_t = 0.0
	cloaked = not cloaked
	if cloaked:
		for k in 3:
			game.spawn_enemy("decoy", s - 4.0, th + (k - 1) * 1.4, float(k))
	else:
		th = wrapf(game.player.th + randf_range(-1.5, 1.5), -PI, PI)
		_flash = 1.0


func _step_attack(dt: float, game: Game) -> void:
	var phase: Dictionary = spec.phases[_phase]
	var speed_k := _difficulty * float(phase.speed)
	if _shots_left <= 0:
		_cooldown -= dt * speed_k
		if _cooldown <= 0.0:
			_pattern_t = 0.0
			_shot_cd = 0.0
			_shots_left = BossPatterns.shots_in(_current_pattern())
	else:
		_shot_cd -= dt * speed_k
		_pattern_t += dt
		if _shot_cd <= 0.0 and not cloaked and game.enemies_may_fire():
			_shots_left -= 1
			_shot_cd = BossPatterns.fire(_current_pattern(), self, game, _pattern_t)
			if _shots_left <= 0:
				_pattern = (_pattern + 1) % (phase.patterns as Array).size()
				_cooldown = 1.2
	_step_escort(dt, game)


func _current_pattern() -> String:
	var list: Array = spec.phases[_phase].patterns
	return list[_pattern % list.size()]


func _step_escort(dt: float, game: Game) -> void:
	var kind: String = spec.get("escort", "")
	if kind == "" or hp > max_hp * 0.6:
		return
	_escort_cd -= dt
	if _escort_cd <= 0.0:
		_escort_cd = 7.0
		game.spawn_enemy(kind, s - 6.0, th + 0.6, 0.0)
		game.spawn_enemy(kind, s - 6.0, th - 0.6, 1.0)


func _step_dying(dt: float, game: Game) -> void:
	_death_t += dt
	cloaked = false
	game.player.external_drift = 0.0
	_model.rotation.z += dt * 3.0
	if randf() < 0.3:
		var offset := Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-2, 2))
		game.fx.explosion(global_position + offset, color if randf() < 0.7 else Color(1, 0.85, 0.5), 0.9)
		Sfx.play("middle", -4.0, randf_range(0.8, 1.2))
	if _death_t >= DEATH_TIME:
		game.post.kick(1.0)
		game.post.pulse(color, 1.0)
		game.hitstop_t = 0.25
		game.fx.explosion(global_position, color, 3.5)
		game.fx.explosion(global_position, Color(1, 0.9, 0.6), 2.5)
		game.fx.shake = 1.0
		Sfx.play("boss")
		visible = false
		done = true
