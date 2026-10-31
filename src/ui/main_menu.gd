class_name MainMenu
extends Screen


func _init(p_main: Node) -> void:
	super(p_main)
	var col := centered_column(420)
	col.add_child(ArcadeTitle.make("TURBO THRUSTER", 76))
	var tagline := UiStyle.label("CORRIDA ARCADE NEON", 20, Color(1.0, 0.45, 0.85), HORIZONTAL_ALIGNMENT_CENTER, true)
	tagline.label_settings.outline_size = 6
	tagline.label_settings.outline_color = Color(0.35, 0.0, 0.3)
	col.add_child(tagline)
	col.add_child(spacer(36))
	var play := UiStyle.button("Campanha", main.show_level_select)
	var arcade := UiStyle.button("Modo Arcade", main.start_arcade)
	var buttons := [play, arcade,
			UiStyle.button("Configurações", main.show_settings),
			UiStyle.button("Controles", main.show_controls)]
	# A browser tab cannot be closed by the game.
	if not OS.has_feature("web"):
		buttons.append(UiStyle.button("Sair", main.quit))
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(b)
	var progress := "Setores liberados: %d / %d" % [Save.unlocked, Levels.count()]
	col.add_child(spacer(10))
	col.add_child(UiStyle.label(progress, 18, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UiStyle.hint_bar("↑ ↓  Navegar      Enter  Confirmar      F11  Tela cheia"))
	var version := UiStyle.label("v" + str(ProjectSettings.get_setting("application/config/version")), 15, Color(UiStyle.DIM, 0.6))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -90
	version.offset_top = -44
	add_child(version)
	add_child(_leaderboard())
	focus_later(play)


## Arcade top 5, shown beside the menu.
func _leaderboard() -> PanelContainer:
	var panel := PanelContainer.new()
	# Anchored to the right edge, vertically centred beside the buttons.
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_right = -36.0
	panel.offset_top = -40.0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(UiStyle.label("RECORDES ARCADE", 18, Color(1.0, 0.45, 0.85), HORIZONTAL_ALIGNMENT_CENTER, true))
	if Save.arcade_top.is_empty():
		var empty := UiStyle.label("Nenhum recorde ainda.\nJogue o Modo Arcade!", 16, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		vb.add_child(empty)
	for i in Save.arcade_top.size():
		var e: Dictionary = Save.arcade_top[i]
		var row := HBoxContainer.new()
		var color := UiStyle.GOLD if i == 0 else UiStyle.TEXT
		row.add_child(UiStyle.label("%d." % (i + 1), 16, UiStyle.DIM))
		row.add_child(UiStyle.label(String(e.name), 18, color, HORIZONTAL_ALIGNMENT_LEFT, true))
		var score := UiStyle.label(Hud.format_int(int(e.score)), 18, color, HORIZONTAL_ALIGNMENT_RIGHT, true)
		score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(score)
		var secs := int(e.time)
		row.add_child(UiStyle.label("%d:%02d" % [secs / 60, secs % 60], 14, UiStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT))
		vb.add_child(row)
	return panel
