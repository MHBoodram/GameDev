extends AudioStreamPlayer
# Autoload "MusicPlayer" (MusicPlayer.tscn) Keeps playing across scene changes

var MENU_MUSIC: AudioStream
var GAME_MUSIC: AudioStream

const SILENT_DB := -60.0 # volume_db at the bottom of the fade (low taper fade is still massive 0.0 )
const FADE_OUT := 0.5 # seconds to fade out the old song
const FADE_IN := 1.15 # secongs to fade in new song

var _target: AudioStream # track we're going into/out of
var _tween: Tween

func _ready() -> void:
	MENU_MUSIC = _load_audio("res://Audio/Music/Piano Solo 1.ogg", "res://Assets/Audio/Music/Piano Solo 1.ogg")
	GAME_MUSIC = _load_audio("res://Audio/Music/Piano Saxophone.ogg", "res://Assets/Audio/Music/Piano Saxophone.ogg")

static func _load_audio(primary_path: String, fallback_path: String) -> AudioStream:
	if ResourceLoader.exists(primary_path):
		return load(primary_path) as AudioStream
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path) as AudioStream
	return null

func play_menu() -> void:
	if MENU_MUSIC:
		_play(MENU_MUSIC)

func play_game() -> void:
	if GAME_MUSIC:
		_play(GAME_MUSIC)

func _play(track: AudioStream) -> void:
	if track == _target:
		return # alr playing into the right song
	_target = track

	if _tween:
		_tween.kill() #cancel song transition
	_tween = create_tween()

	if playing:
		_tween.tween_property(self, "volume_db", SILENT_DB, FADE_OUT)
	_tween.tween_callback(func():
		stream = track
		volume_db = SILENT_DB
		play())
	_tween.tween_property(self, "volume_db", 0.0, FADE_IN)