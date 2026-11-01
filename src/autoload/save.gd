extends Node
## Persistent settings + campaign progress. Also applies display settings.

signal settings_changed

const SAVE_PATH := "user://turbo_thruster.json"
## Automated tests and screenshot runs use their own file so they never
## touch the player's progress.
const TEST_SAVE_PATH := "user://turbo_thruster_test.json"
const SAVE_VERSION := 3
const MIN_WINDOW := Vector2i(960, 540)
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440),
]
const DEFAULT_SETTINGS := {
	"display_mode": 0,
	"window_size": 0,
	"vsync": true,
	"music": 0.6,
	"sfx": 0.8,
	"glow": 1.0,
	"shake": true,
	"autofire": false,
	"audio_style": 0,
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var unlocked := 1
var best: Dictionary = {}
var medals: Dictionary = {}
var arcade_top: Array = []

const ARCADE_SLOTS := 5
const MEDAL_IDS := ["untouched", "exterminator", "multiplier"]


var save_path := SAVE_PATH


func _ready() -> void:
	if _is_automated():
		save_path = TEST_SAVE_PATH
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register()
	load_data()
	# Browsers only allow fullscreen after a click or key press, so the web build starts in the page.
	if OS.has_feature("web"):
		settings.display_mode = 0
	# In the browser the page sizes the canvas; a minimum would render past its edges.
	if not OS.has_feature("web"):
		get_window().min_size = MIN_WINDOW
	apply_display()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F11:
		set_setting("display_mode", 0 if settings.display_mode == 1 else 1)
		get_viewport().set_input_as_handled()


func _is_automated() -> bool:
	var args := OS.get_cmdline_args()
	if "-s" in args or "--script" in args:
		return true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot"):
			return true
	return false


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	if key in ["display_mode", "window_size", "vsync"]:
		apply_display()
	save_data()
	settings_changed.emit()


func apply_display() -> void:
	var win := get_window()
	# On the web the page sizes the canvas and the browser paces frames.
	if OS.has_feature("web"):
		win.mode = Window.MODE_FULLSCREEN if settings.display_mode == 1 else Window.MODE_WINDOWED
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	if settings.display_mode == 1:
		win.mode = Window.MODE_FULLSCREEN
		return
	win.mode = Window.MODE_WINDOWED
	var screen := DisplayServer.screen_get_usable_rect(win.current_screen)
	var wanted: Vector2i = WINDOW_SIZES[clampi(int(settings.window_size), 0, WINDOW_SIZES.size() - 1)]
	var size := Vector2i(mini(wanted.x, screen.size.x), mini(wanted.y, screen.size.y))
	win.size = size
	win.position = screen.position + (screen.size - size) / 2


func is_unlocked(level: int) -> bool:
	return level < unlocked


func best_for(level: int) -> Dictionary:
	return best.get(str(level), {})


## Stores a finished sector. Returns true when it is a new best score.
func medals_for(level: int) -> Array:
	return medals.get(str(level), [])


## Stores newly earned medals; returns the ones earned for the first time.
func record_medals(level: int, earned: Array) -> Array:
	var key := str(level)
	var have: Array = medals.get(key, [])
	var fresh := earned.filter(func(m: String) -> bool: return not (m in have))
	medals[key] = have + fresh
	save_data()
	return fresh


func arcade_qualifies(score: int) -> bool:
	return score > 0 and (arcade_top.size() < ARCADE_SLOTS or score > int(arcade_top[-1].score))


func arcade_best() -> int:
	return 0 if arcade_top.is_empty() else int(arcade_top[0].score)


## Inserts a run into the top 5; returns its position (0-based) or -1.
func record_arcade(name: String, score: int, seconds: int) -> int:
	if not arcade_qualifies(score):
		return -1
	var entry := {"name": name.substr(0, 3).to_upper(), "score": score, "time": seconds,
		"date": Time.get_date_string_from_system()}
	var pos := 0
	while pos < arcade_top.size() and int(arcade_top[pos].score) >= score:
		pos += 1
	var list := arcade_top.duplicate()
	list.insert(pos, entry)
	arcade_top = list.slice(0, ARCADE_SLOTS)
	save_data()
	return pos if pos < ARCADE_SLOTS else -1


## Cheat: unlock every campaign sector. Returns false if all were open.
func unlock_all() -> bool:
	if unlocked >= Levels.count():
		return false
	unlocked = Levels.count()
	save_data()
	return true


func record_result(level: int, score: int, rank: String) -> bool:
	var key := str(level)
	var prev: Dictionary = best.get(key, {})
	var is_best := score > int(prev.get("score", -1))
	if is_best:
		best[key] = {"score": score, "rank": rank}
	unlocked = maxi(unlocked, mini(level + 2, Levels.count()))
	save_data()
	return is_best


func load_data() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is corrupt; using defaults.")
		return
	var data: Dictionary = parsed
	var raw_settings: Variant = data.get("settings", {})
	var loaded: Dictionary = raw_settings if typeof(raw_settings) == TYPE_DICTIONARY else {}
	for key: String in DEFAULT_SETTINGS:
		settings[key] = _coerce(loaded.get(key), DEFAULT_SETTINGS[key])
	# v3 added the Hyperdrive audio style and made it the default.
	if _num(data.get("version", 1), 1) < 3:
		settings.audio_style = 0
	if _num(data.get("version", 1), 1) < 2:
		settings.autofire = false
	unlocked = clampi(_num(data.get("unlocked", 1), 1), 1, Levels.count())
	var loaded_medals: Variant = data.get("medals", {})
	if typeof(loaded_medals) == TYPE_DICTIONARY:
		for key: Variant in loaded_medals:
			var list: Variant = loaded_medals[key]
			if typeof(list) == TYPE_ARRAY:
				medals[str(key)] = (list as Array).filter(func(m: Variant) -> bool: return str(m) in MEDAL_IDS)
	var loaded_top: Variant = data.get("arcade_top", [])
	if typeof(loaded_top) == TYPE_ARRAY:
		for entry: Variant in loaded_top:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("score") and entry.has("name"):
				arcade_top.append({"name": str(entry.name).substr(0, 3), "score": _num(entry.score),
					"time": _num(entry.get("time", 0)), "date": str(entry.get("date", ""))})
		arcade_top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
		arcade_top = arcade_top.slice(0, ARCADE_SLOTS)
	var loaded_best: Variant = data.get("best", {})
	if typeof(loaded_best) == TYPE_DICTIONARY:
		for key: Variant in loaded_best:
			var entry: Variant = loaded_best[key]
			if typeof(entry) == TYPE_DICTIONARY and entry.has("score") and entry.has("rank"):
				best[str(key)] = {"score": _num(entry.score), "rank": str(entry.rank)}


## Safe number read from untrusted JSON.
func _num(value: Variant, fallback := 0) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback


## JSON stores every number as float; convert back to the default's type.
func _coerce(value: Variant, fallback: Variant) -> Variant:
	match typeof(fallback):
		TYPE_BOOL:
			return value if typeof(value) == TYPE_BOOL else fallback
		TYPE_INT:
			return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback
		TYPE_FLOAT:
			return clampf(float(value), 0.0, 1.0) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback
	return fallback


func save_data() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "settings": settings, "unlocked": unlocked, "best": best,
		"medals": medals, "arcade_top": arcade_top}, "\t"))
