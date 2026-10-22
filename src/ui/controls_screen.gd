class_name ControlsScreen
extends Screen


func _init(p_main: Node) -> void:
	super(p_main)
	var col := centered_column(820)
	col.add_child(UiStyle.title("CONTROLES", 54))
	var panel := PanelContainer.new()
	col.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 14)
	panel.add_child(grid)
	for header in ["AÇÃO", "TECLADO", "CONTROLE"]:
		grid.add_child(UiStyle.label(header, 16, UiStyle.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, true))
	for row: Array in InputSetup.HELP:
		grid.add_child(UiStyle.label(row[0], 20, UiStyle.TEXT))
		grid.add_child(UiStyle.label(row[1], 20, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
		grid.add_child(UiStyle.label(row[2], 20, UiStyle.DIM))
	var tip := "Dica: acelerar dá mais pontos; frear deixa as balas inimigas mais lentas.\n" \
		+ "O tiro carregado atravessa inimigos e apaga as balas no caminho."
	var tip_label := UiStyle.label(tip, 18, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(tip_label)
	var back := UiStyle.button("Voltar", _back_pressed, 300)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(back)
	add_child(UiStyle.hint_bar("Enter  Confirmar      Esc  Voltar"))
	focus_later(back)


func _back_pressed() -> void:
	main.show_main_menu()


func _go_back() -> bool:
	main.show_main_menu()
	return true
