extends Node
## Sound effects pool + music player.

const SOUNDS := {
	"shot": "res://assets/sounds/chunks/shot.wav",
	"charge": "res://assets/sounds/chunks/charge.wav",
	"nova": "res://assets/sounds/chunks/charge_shot.wav",
	"hit": "res://assets/sounds/chunks/hit.wav",
	"small": "res://assets/sounds/chunks/small_dest.wav",
	"middle": "res://assets/sounds/chunks/middle_dest.wav",
	"boss": "res://assets/sounds/chunks/boss_dest.wav",
	"ship": "res://assets/sounds/chunks/myship_dest.wav",
	"pickup": "res://assets/sounds/chunks/extend.wav",
	"alert": "res://assets/sounds/chunks/timeup_beep.wav",
}
## Synthesized soundtrack (tools/music/synth.py). Missing files fall back to
## the original Torus Trooper tracks.
const MUSIC := {
	"menu": "res://assets/music/menu.ogg",
	"sector_a": "res://assets/music/sector_a.ogg",
	"sector_b": "res://assets/music/sector_b.ogg",
	"sector_c": "res://assets/music/sector_c.ogg",
	"sector_d": "res://assets/music/sector_d.ogg",
	"sector_e": "res://assets/music/sector_e.ogg",
	"boss": "res://assets/music/boss.ogg",
}
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in SOUNDS:
		_streams[key] = load(SOUNDS[key])
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = _make_music_bus()
	add_child(_music)
	Save.settings_changed.connect(_apply_music_volume)
	_apply_music_volume()


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
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
	var path: String = MUSIC.get(track, "")
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
