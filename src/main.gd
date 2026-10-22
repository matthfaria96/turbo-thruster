extends Node
## Scene router: menus (over an animated tunnel) and game sessions.
## Command-line (after "--"): --shot=PATH --screen=menu|levels|settings|controls|game
##   --level=N --delay=SECONDS --autoplay --skip=DISTANCE --size=WxH  → saves a screenshot and quits (tests).

var _ui: CanvasLayer
var _backdrop: MenuBackdrop
var _screen: Control
var _game: Game
var _args: Dictionary = {}


func _ready() -> void:
	_args = _parse_args()
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	match String(_args.get("screen", "menu")):
		"levels": show_level_select()
		"settings": show_settings()
		"controls": show_controls()
		"game": start_level(int(_args.get("level", "0")))
		_: show_main_menu()
	if _args.has("size"):
		var dims := String(_args.size).split("x")
		get_window().size = Vector2i(int(dims[0]), int(dims[1]))
	if _args.has("shot"):
		_capture_later(String(_args.shot), float(_args.get("delay", "2.0")))


func show_main_menu() -> void:
	_show_screen(MainMenu.new(self))
	Sfx.play_music(0)


func show_level_select() -> void:
	_show_screen(LevelSelect.new(self))


func show_settings() -> void:
	_show_screen(SettingsScreen.new(self))


func show_controls() -> void:
	_show_screen(ControlsScreen.new(self))


func start_level(index: int) -> void:
	_clear_screen()
	_clear_game()
	if _backdrop:
		_backdrop.queue_free()
		_backdrop = null
	_game = Game.new()
	_game.setup(index, _args.has("autoplay"), float(_args.get("skip", "0")))
	_game.request_menu.connect(show_main_menu)
	_game.request_level.connect(start_level)
	add_child(_game)


func quit() -> void:
	get_tree().quit()


func _show_screen(screen: Control) -> void:
	_clear_game()
	_clear_screen()
	if _backdrop == null:
		_backdrop = MenuBackdrop.new()
		add_child(_backdrop)
	_screen = screen
	_ui.add_child(screen)


func _clear_screen() -> void:
	if _screen:
		_screen.queue_free()
		_screen = null


func _clear_game() -> void:
	if _game:
		_game.queue_free()
		_game = null
	get_tree().paused = false


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var clean := arg.trim_prefix("--")
		var parts := clean.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "1"
	return out


func _capture_later(path: String, delay: float) -> void:
	await get_tree().create_timer(delay, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	if err != OK:
		push_error("Screenshot failed: %s" % err)
	get_tree().quit()
