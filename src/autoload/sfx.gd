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
const MUSIC := [
	"res://assets/sounds/musics/tt1.ogg",
	"res://assets/sounds/musics/tt2.ogg",
	"res://assets/sounds/musics/tt3.ogg",
	"res://assets/sounds/musics/tt4.ogg",
]
const POOL_SIZE := 14
const MIN_REPEAT_MS := 45

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _last_play: Dictionary = {}
var _music: AudioStreamPlayer
var _music_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in SOUNDS:
		_streams[key] = load(SOUNDS[key])
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
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


func play_music(index: int) -> void:
	var wrapped := posmod(index, MUSIC.size())
	if wrapped == _music_index and _music.playing:
		return
	_music_index = wrapped
	var stream: AudioStream = load(MUSIC[wrapped])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()
	_music_index = -1


func _apply_music_volume() -> void:
	_music.volume_db = _to_db(float(Save.settings.music)) - 4.0


func _to_db(linear: float) -> float:
	return linear_to_db(maxf(linear, 0.0001))
