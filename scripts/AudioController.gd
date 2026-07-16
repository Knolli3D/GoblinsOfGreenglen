extends Node

const SFX_FILES := {
	"jump": "res://assets/audio/jump.wav",
	"double_jump": "res://assets/audio/double_jump.wav",
	"coin": "res://assets/audio/coin.wav",
	"stomp": "res://assets/audio/stomp.wav",
	"hit": "res://assets/audio/hit.wav",
	"death": "res://assets/audio/death.wav",
	"level_clear": "res://assets/audio/level_clear.wav",
	"win": "res://assets/audio/win.wav",
	"click": "res://assets/audio/click.wav",
}

const MUSIC_FILE := "res://assets/audio/music.wav"
const SFX_VOICES := 8
const MUSIC_NORMAL_DB := 0.0
const MUSIC_PAUSED_DB := -14.0

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var sfx_next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_players()


func play_sfx(sfx_name: String, pitch_jitter := 0.0) -> void:
	var stream: AudioStream = sfx_streams.get(sfx_name)
	if stream == null or sfx_players.is_empty():
		return
	var player := sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.stream = stream
	player.play()


func start_music() -> void:
	if music_player != null and not music_player.playing:
		music_player.play()


func stop_music() -> void:
	if music_player != null:
		music_player.stop()


func is_music_playing() -> bool:
	return music_player != null and music_player.playing


func set_music_ducked(ducked: bool) -> void:
	if music_player != null:
		music_player.volume_db = MUSIC_PAUSED_DB if ducked else MUSIC_NORMAL_DB


func _build_players() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(MUSIC_FILE):
		var music: AudioStreamWAV = load(MUSIC_FILE)
		music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.loop_begin = 0
		music.loop_end = int(music.get_length() * music.mix_rate)
		music_player.stream = music
	add_child(music_player)

	for i in range(SFX_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "SFXVoice%d" % (i + 1)
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		sfx_players.append(player)

	for key: String in SFX_FILES:
		if ResourceLoader.exists(SFX_FILES[key]):
			sfx_streams[key] = load(SFX_FILES[key])
