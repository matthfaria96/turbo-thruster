extends Node
## Sound effects pool + music player.

## Two audio styles chosen in Settings ("audio_style"):
##   0 = Metal (default): tools/music/synth_metal.py + sfx_metal.py
##   1 = Classical: the first synthesized techno set + original Torus Trooper SFX
const STYLES := ["metal", "classical"]
const SFX_FILES := {
	"shot": "shot", "charge": "charge", "nova": "charge_shot", "hit": "hit",
	"small": "small_dest", "middle": "middle_dest", "boss": "boss_dest", "ship": "myship_dest",
	"pickup": "extend", "alert": "timeup_beep", "ui_move": "ui_move", "ui_confirm": "ui_confirm",
}
const SFX_DIRS := {"metal": "res://assets/sfx_metal/", "classical": "res://assets/sounds/chunks/"}
const MUSIC_DIRS := {"metal": "res://assets/music_metal/", "classical": "res://assets/music/"}
## Classical has no dedicated UI sounds: reuse gentle ones.
const CLASSICAL_UI := {"ui_move": ["shot", 1.6, -14.0], "ui_confirm": ["pickup", 1.4, -10.0]}
const TRACKS := ["menu", "sector_a", "sector_b", "sector_c", "sector_d", "sector_e", "boss"]
## Last-resort music: the original Torus Trooper tracks.
const FALLBACK := {
	"menu": "res://assets/sounds/musics/tt1.ogg", "sector_a": "res://assets/sounds/musics/tt1.ogg",
	"sector_b": "res://assets/sounds/musics/tt2.ogg", "sector_c": "res://assets/sounds/musics/tt3.ogg",
	"sector_d": "res://assets/sounds/musics/tt4.ogg", "sector_e": "res://assets/sounds/musics/tt4.ogg",
	"boss": "res://assets/sounds/musics/tt3.ogg",
}
const CROSSFADE := 0.8
const POOL_SIZE := 14
const MIN_REPEAT_MS := 45

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _last_play: Dictionary = {}
var _music: AudioStreamPlayer
var _music_name := ""
var _fade: Tween
var _style := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = _make_music_bus()
	add_child(_music)
	Save.settings_changed.connect(_on_settings_changed)
	_on_settings_changed()


func style() -> String:
	return STYLES[clampi(int(Save.settings.get("audio_style", 0)), 0, STYLES.size() - 1)]


func _on_settings_changed() -> void:
	_apply_music_volume()
	if style() == _style:
		return
	_style = style()
	_load_sfx()
	if _music_name != "":
		var current := _music_name
		_music_name = ""
		play_music(current)


func _load_sfx() -> void:
	_streams.clear()
	for key: String in SFX_FILES:
		var path: String = SFX_DIRS[_style] + SFX_FILES[key] + ".wav"
		if not ResourceLoader.exists(path):
			path = SFX_DIRS.classical + SFX_FILES[key] + ".wav"
		if ResourceLoader.exists(path):
			_streams[key] = load(path)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound) and CLASSICAL_UI.has(sound):
		var alias: Array = CLASSICAL_UI[sound]
		sound = alias[0]
		pitch = alias[1]
		volume_db += alias[2]
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sound, -1000)) < MIN_REPEAT_MS:
		return
	_last_play[sound] = now
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db + _to_db(float(Save.settings.sfx))
			player.pitch_scale = pitch
			player.play()
			return


func play_music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	var path: String = MUSIC_DIRS[_style] + track + ".ogg"
	if not ResourceLoader.exists(path):
		path = MUSIC_DIRS.classical + track + ".ogg"
	if not ResourceLoader.exists(path):
		path = FALLBACK.get(track, FALLBACK.menu)
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("Music not found: %s" % track)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	if _fade:
		_fade.kill()
	if not _music.playing:
		_start_stream(stream)
		return
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", -40.0, CROSSFADE * 0.5)
	_fade.tween_callback(_start_stream.bind(stream))


func _start_stream(stream: AudioStream) -> void:
	_music.stream = stream
	_music.volume_db = _music_db() - 30.0
	_music.play()
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", _music_db(), CROSSFADE * 0.5)


func stop_music() -> void:
	_music.stop()
	_music_name = ""


func _music_db() -> float:
	return _to_db(float(Save.settings.music)) - 4.0


const FILTER_CLOSED_HZ := 900.0
const FILTER_OPEN_HZ := 20000.0

var _lowpass: AudioEffectLowPassFilter
var _intensity := 1.0


## Music bus with a low-pass filter: calm moments sound muffled, intense
## ones open up fully ("adaptive" layering without separate stems).
func _make_music_bus() -> StringName:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Music")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = FILTER_OPEN_HZ
	AudioServer.add_bus_effect(idx, _lowpass)
	return &"Music"


## 0 = calm (filtered), 1 = full intensity.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	var target := lerpf(4000.0, FILTER_OPEN_HZ, sqrt(_intensity)) if _intensity < 0.99 else FILTER_OPEN_HZ
	_lowpass.cutoff_hz = lerpf(_lowpass.cutoff_hz, target, minf(1.0, delta * 2.0))


func _apply_music_volume() -> void:
	_music.volume_db = _music_db()


func _to_db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.0001))
