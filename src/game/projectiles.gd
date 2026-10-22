class_name Projectiles
extends Node3D
## Player shots and enemy bullets, simulated in track space and drawn with
## two MultiMeshes (one draw call each).

const MAX_SHOTS := 300
const MAX_BULLETS := 600
const BULLET_SIZE := 1.25
const BULLET_RADIUS := 0.55

var track: Track
var shots: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var _shot_mm: MultiMesh
var _bullet_mm: MultiMesh


func setup(p_track: Track) -> void:
	track = p_track
	_shot_mm = _make_multimesh(MAX_SHOTS, Meshes.streak(3.2, 0.75))
	_bullet_mm = _make_multimesh(MAX_BULLETS, Meshes.additive(3.0, 0.35, 0.9))


func add_shot(shot: Dictionary) -> void:
	if shots.size() < MAX_SHOTS:
		shots.append(shot)


func add_bullet(s: float, th: float, h: float, vs: float, vth: float) -> void:
	if bullets.size() < MAX_BULLETS:
		bullets.append({"s": s, "th": th, "h": h, "vs": vs, "vth": vth, "age": 0.0, "dead": false})


func update(dt: float, player_s: float) -> void:
	for shot in shots:
		shot.ps = shot.s
		shot.s += shot.vs * dt
		shot.th = wrapf(shot.th + shot.vth * dt, -PI, PI)
		shot.life -= dt
	for b in bullets:
		b.s += b.vs * dt
		b.th = wrapf(b.th + b.vth * dt, -PI, PI)
		b.h = move_toward(b.h, Player.H, 2.5 * dt)
		b.age += dt
	shots = shots.filter(func(x: Dictionary) -> bool: return x.life > 0.0 and not x.get("dead", false))
	bullets = bullets.filter(func(b: Dictionary) -> bool:
		return not b.dead and b.age < 9.0 and b.s > player_s - 8.0)


## Removes bullets near a lane (used by the charge shot and finale).
func clear_bullets(where: Callable) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	for b in bullets:
		if not b.dead and where.call(b):
			b.dead = true
			removed.append(b)
	return removed


func render() -> void:
	_shot_mm.visible_instance_count = shots.size()
	for i in shots.size():
		var shot: Dictionary = shots[i]
		var fr := track.frame(shot.s)
		var pos: Vector3 = fr.origin + Track.radial(fr, shot.th) * (Track.RADIUS - shot.h)
		var length: float = 6.0 if shot.pierce else 2.8
		var basis := Basis(fr.basis.x * shot.size * 0.55, -fr.basis.z * length, fr.basis.y)
		_shot_mm.set_instance_transform(i, Transform3D(basis, pos))
		_shot_mm.set_instance_color(i, Color(0.75, 1.0, 1.0) if shot.pierce else EnemyTypes.SHOT_COLOR)
	_bullet_mm.visible_instance_count = bullets.size()
	for i in bullets.size():
		var b: Dictionary = bullets[i]
		var pulse := 1.1 + 0.18 * sin(b.age * 18.0)
		_bullet_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * BULLET_SIZE * pulse),
			track.point(b.s, b.th, b.h)))
		_bullet_mm.set_instance_color(i, EnemyTypes.BULLET_COLOR)


func _make_multimesh(count: int, mat: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm
