extends AudioStreamPlayer
# Autoload "MusicPlayer" (MusicPlayer.tscn) Keeps playing across scene changes

const MENU_MUSIC = preload("res://Assets/Audio/Music/Piano Solo 1.ogg")
const GAME_MUSIC = preload("res://Assets/Audio/Music/Piano Saxophone.ogg")

const SILENT_DB := -60.0 # volume_db at the bottom of the fade (low taper fade is still massive 0.0 )
const FADE_OUT := 0.5 # seconds to fade out the old song
const FADE_IN := 1.15 # secongs to fade in new song

var _target: AudioStream # track we're going into/out of
var _tween: Tween

func play_menu() -> void:
	_play(MENU_MUSIC)

func play_game() -> void:
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
