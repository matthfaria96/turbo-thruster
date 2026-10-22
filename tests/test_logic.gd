extends SceneTree
## Headless logic tests: godot --headless -s tests/test_logic.gd

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_track_frames()
	_test_angle_helpers()
	_test_wave_plans()
	_test_levels()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


func _test_track_frames() -> void:
	var track := Track.new(1.0, 1234)
	for s in [0.0, 50.0, 400.0, 2500.0, 9000.0]:
		var fr := track.frame(s)
		_check(absf(fr.basis.x.length() - 1.0) < 1e-3, "frame x unit at %s" % s)
		_check(absf(fr.basis.x.dot(fr.basis.y)) < 1e-3, "frame orthogonal at %s" % s)
		var wall := track.point(s, 0.7, 0.0)
		_check(absf(wall.distance_to(fr.origin) - Track.RADIUS) < 1e-3, "wall on radius at %s" % s)
		var pose := track.pose(s, -1.2, 1.0)
		_check(pose.basis.y.dot(fr.origin - pose.origin) > 0.0, "pose up points to axis at %s" % s)
	_check(track.center(0.0).distance_to(Vector3.ZERO) < 1e-4, "track starts straight at origin")
	var right := track.point(10.0, 0.3, 0.0) - track.point(10.0, 0.0, 0.0)
	_check(right.dot(track.frame(10.0).basis.x) > 0.0, "positive angle is screen right")


func _test_angle_helpers() -> void:
	_check(is_equal_approx(Track.angle_diff(PI - 0.1, -PI + 0.1), -0.2), "angle diff wraps")
	_check(Track.distance(10.0, 0.0, 1.0, 10.0, 0.0, 1.0) < 1e-5, "zero distance")
	_check(absf(Track.distance(10.0, 0.0, 1.0, 13.0, 0.0, 1.0) - 3.0) < 1e-4, "distance along s")


func _test_wave_plans() -> void:
	for i in Levels.count():
		var level := Levels.get_level(i)
		var a := WavePlan.build(level, i)
		var b := WavePlan.build(level, i)
		_check(a.size() > 10, "level %d has waves" % i)
		_check(a == b, "level %d plan deterministic" % i)
		var sorted := true
		for k in range(1, a.size()):
			sorted = sorted and a[k - 1].s <= a[k].s
		_check(sorted, "level %d plan sorted" % i)
		for spawn in a:
			_check(spawn.kind in level.kinds, "level %d spawns only its kinds (%s)" % [i, spawn.kind])
			_check(spawn.s < level.length, "level %d spawns before boss" % i)


func _test_levels() -> void:
	_check(Levels.count() == 8, "eight sectors")
	_check(Levels.is_last(Levels.count() - 1), "last sector detected")
	var prev_hp := 0.0
	for i in Levels.count():
		var level := Levels.get_level(i)
		_check(level.boss_hp > prev_hp, "boss hp increases at %d" % i)
		prev_hp = level.boss_hp
		for kind: String in level.kinds:
			_check(EnemyTypes.TYPES.has(kind), "known enemy kind %s" % kind)
