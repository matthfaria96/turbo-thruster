class_name BossPatterns
extends RefCounted
## Bullet patterns shared by bosses. `start` returns how many shots a
## pattern volley has; `fire` emits one shot of it and returns the delay
## until the next one.


static func shots_in(pattern: String) -> int:
	match pattern:
		"fan": return 3
		"ring": return 3
		"spiral": return 36
		"galaxy": return 40
		"burst": return 6
		"ring_wave": return 6
		"cross": return 30
		"rain": return 26
	return 1


static func fire(pattern: String, boss: Boss, game: Game, t: float) -> float:
	var s := boss.s
	var th := boss.th
	var h := boss.h
	match pattern:
		"fan":
			game.fire_aimed(s, th, h, 22.0, 7, 0.13)
			return 0.75
		"ring":
			game.fire_ring(s, h, 22, game.player.th + randf_range(-1.2, 1.2), 3, 17.0)
			return 1.0
		"spiral":
			var a := th + t * 3.2
			game.fire_bullet(s, a, h, 20.0, 0.0)
			game.fire_bullet(s, a + PI, h, 20.0, 0.0)
			return 0.07
		"galaxy":
			for arm in 4:
				game.fire_bullet(s, th + arm * TAU / 4.0 + t * 2.4, h, 15.0, 0.55)
			return 0.11
		"burst":
			game.fire_aimed(s, th, h, 34.0, 1, 0.0)
			return 0.2
		"ring_wave":
			# Consecutive rings whose gap rotates: the player must follow it.
			game.fire_ring(s, h, 26, th + t * 1.6, 4, 16.0)
			return 0.42
		"cross":
			var c := th + t * 1.3
			for arm in 4:
				game.fire_bullet(s, c + arm * PI / 2.0, h, 19.0, 0.0)
			return 0.09
		"rain":
			game.fire_bullet(s, randf_range(-PI, PI), randf_range(0.6, 3.0), randf_range(14.0, 22.0), 0.0)
			game.fire_bullet(s, randf_range(-PI, PI), randf_range(0.6, 3.0), randf_range(14.0, 22.0), 0.0)
			return 0.06
	return 0.5
