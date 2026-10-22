class_name RunEnd
extends RefCounted
## End-of-run screens: sector results with rank and medals, campaign game
## over, and the arcade flow (summary → initials if top 5 → leaderboard).

const MEDALS := {
	"untouched": ["Intocável", "sem levar dano"],
	"exterminator": ["Exterminador", "95% dos abates"],
	"multiplier": ["Multiplicador", "chegar a x50"],
}

var g: Game
var _survival_acc := 0.0


func _init(game: Game) -> void:
	g = game


## Arcade survival bonus: +100/s, doubling every minute.
func add_survival_score(dt: float) -> void:
	_survival_acc += dt
	if _survival_acc >= 1.0:
		_survival_acc -= 1.0
		g.score += 100 * int(pow(2.0, minf(floorf(g.elapsed / 60.0), 20.0)))


func rank(kill_ratio: float) -> String:
	if kill_ratio >= 0.85 and g.hits_taken == 0:
		return "S"
	if kill_ratio >= 0.7 and g.hits_taken <= 1:
		return "A"
	if kill_ratio >= 0.45:
		return "B"
	return "C"


func earned_medals(kill_ratio: float) -> Array:
	var out: Array = []
	if g.hits_taken == 0:
		out.append("untouched")
	if kill_ratio >= 0.95:
		out.append("exterminator")
	if g.max_multiplier >= 50:
		out.append("multiplier")
	return out


func show_results() -> void:
	var kill_ratio := minf(1.0, g.plan_kills / float(maxi(g.plan_total, 1)))
	var hull_bonus := g.player.hull * 1500
	var par_time: float = g.level.length / Player.BASE_SPEED + 60.0
	var time_bonus := int(maxf(0.0, par_time - g.elapsed) * 60.0)
	var total := g.score + hull_bonus + time_bonus
	var r := rank(kill_ratio)
	var is_best := Save.record_result(g.level_index, total, r)
	var fresh := Save.record_medals(g.level_index, earned_medals(kill_ratio))
	var rows := [
		["Pontos", Hud.format_int(g.score)],
		["Abates", "%d / %d" % [g.plan_kills, g.plan_total]],
		["Maior multiplicador · raspões", "x%d · %d" % [g.max_multiplier, g.grazes]],
		["Ondas limpas", str(g.waves_cleared)],
		["Bônus de casco + tempo", "+" + Hud.format_int(hull_bonus + time_bonus)],
		["Total", Hud.format_int(total), UiStyle.TEXT],
		["Classificação", r, UiStyle.rank_color(r), true],
	]
	for m: String in earned_medals(kill_ratio):
		rows.append(["Medalha: " + MEDALS[m][0], "NOVA!" if m in fresh else "✔", UiStyle.GOLD])
	var last := Levels.is_last(g.level_index)
	var buttons: Array = []
	if not last:
		buttons.append(["Próximo setor  ▸", func() -> void: g.leave(g.level_index + 1)])
	buttons.append(["Repetir setor", func() -> void: g.leave(g.level_index)])
	buttons.append(["Menu principal", func() -> void: g.leave(-1)])
	var heading := "CAMPANHA CONCLUÍDA" if last else "SETOR CONCLUÍDO"
	var sub := ("NOVO RECORDE!  " if is_best else "") + "Setor %d · %s" % [g.level_index + 1, g.level.name]
	g.show_overlay(Overlay.create(heading, sub, rows, buttons, UiStyle.GOOD))


func show_game_over() -> void:
	if g.is_arcade():
		_arcade_over()
		return
	var rows := [
		["Pontos", Hud.format_int(g.score)],
		["Distância", "%d%%" % int(clampf(g.player.s / g.level.length, 0.0, 1.0) * 100.0)],
		["Abates", str(g.kills)],
	]
	var buttons := [
		["Tentar de novo", func() -> void: g.leave(g.level_index)],
		["Menu principal", func() -> void: g.leave(-1)],
	]
	g.show_overlay(Overlay.create("NAVE DESTRUÍDA", "Setor %d · %s" % [g.level_index + 1, g.level.name],
		rows, buttons, UiStyle.DANGER))


func _time_text(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


func _arcade_over() -> void:
	var seconds := int(g.elapsed)
	if Save.arcade_qualifies(g.score):
		var entry := InitialsEntry.create(g.score, _time_text(seconds), func(name: String) -> void:
			_show_leaderboard(Save.record_arcade(name, g.score, seconds)))
		g.show_overlay(entry)
		return
	_show_leaderboard(-1)


func _show_leaderboard(highlight: int) -> void:
	var rows: Array = [
		["Sua partida", "%s pts · %s" % [Hud.format_int(g.score), _time_text(int(g.elapsed))], UiStyle.TEXT],
		["Abates · maior mult.", "%d · x%d" % [g.kills, g.max_multiplier]],
	]
	for i in Save.ARCADE_SLOTS:
		if i < Save.arcade_top.size():
			var e: Dictionary = Save.arcade_top[i]
			var color := UiStyle.GOLD if i == highlight else (UiStyle.TEXT if i == 0 else UiStyle.DIM)
			rows.append(["%d.  %s   %s" % [i + 1, e.name, _time_text(int(e.time))], Hud.format_int(int(e.score)), color])
		else:
			rows.append(["%d.  ---" % (i + 1), "—", UiStyle.DIM])
	var buttons := [
		["Jogar de novo", func() -> void: g.leave(-2)],
		["Menu principal", func() -> void: g.leave(-1)],
	]
	var sub := "NOVO RECORDE NO TOP 5!" if highlight >= 0 else "Top 5 do Modo Arcade"
	g.show_overlay(Overlay.create("FIM DE JOGO", sub, rows, buttons, UiStyle.DANGER))
