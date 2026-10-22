class_name MainMenu
extends Screen


func _init(p_main: Node) -> void:
	super(p_main)
	var col := centered_column(420)
	col.add_child(UiStyle.title("TURBO THRUSTER", 84))
	col.add_child(UiStyle.label("Corrida arcade neon dentro do túnel", 22, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(spacer(36))
	var play := UiStyle.button("Campanha", main.show_level_select)
	var best := Save.arcade_best()
	var arcade_text := "Modo Arcade" + ("  ·  recorde %s" % Hud.format_int(best) if best > 0 else "")
	var arcade := UiStyle.button(arcade_text, main.start_arcade)
	for b in [play, arcade,
			UiStyle.button("Configurações", main.show_settings),
			UiStyle.button("Controles", main.show_controls),
			UiStyle.button("Sair", main.quit)]:
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
	focus_later(play)
