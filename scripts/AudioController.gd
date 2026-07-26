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

const MAIN_MENU_MUSIC_FILE := "res://assets/audio/music/grand_project-wonders-of-the-earth-550792.mp3"
const GAMEPLAY_MUSIC_FILE := "res://assets/audio/music/viacheslavstarostin-game-gaming-video-game-music-471936.mp3"
# Compatibility alias for older resource checks. New code should choose an explicit track.
const MUSIC_FILE := GAMEPLAY_MUSIC_FILE
const SFX_VOICES := 8
const MUSIC_NORMAL_DB := 0.0
const MUSIC_PAUSED_DB := -14.0

enum MusicTrack { NONE, MAIN_MENU, GAMEPLAY }

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var sfx_next := 0
var current_music_track := MusicTrack.NONE


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


func play_main_menu_music() -> void:
	_play_music_track(MusicTrack.MAIN_MENU, MAIN_MENU_MUSIC_FILE)


func play_gameplay_music() -> void:
	_play_music_track(MusicTrack.GAMEPLAY, GAMEPLAY_MUSIC_FILE)


# Compatibility wrapper for callers that predate separate menu/gameplay tracks.
func start_music() -> void:
	play_gameplay_music()


func stop_music() -> void:
	if music_player != null:
		music_player.stop()
	current_music_track = MusicTrack.NONE


func is_music_playing() -> bool:
	return music_player != null and music_player.playing


func is_playing_music_track(track: MusicTrack) -> bool:
	return current_music_track == track and is_music_playing()


func set_music_ducked(ducked: bool) -> void:
	if music_player != null:
		music_player.volume_db = MUSIC_PAUSED_DB if ducked else MUSIC_NORMAL_DB


func _build_players() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
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


func _play_music_track(track: MusicTrack, path: String) -> void:
	if music_player == null:
		return
	if current_music_track == track and music_player.playing:
		return
	if not ResourceLoader.exists(path):
		push_warning("Music track is missing: %s" % path)
		return
	var music := load(path) as AudioStream
	if music == null:
		push_warning("Music track could not be loaded: %s" % path)
		return
	if music is AudioStreamMP3:
		(music as AudioStreamMP3).loop = true
	music_player.stream = music
	music_player.play()
	current_music_track = track
