# All audio sound effects
extends Node

const UI_AUDIO_SCRIPT := preload("res://UI/Audio/UIAudio.gd")

@export var knifedraw_stream: AudioStream
@export var knifestab_stream: AudioStream
# @export var knifeslice_stream: AudioStream
@export var entranto_stream: AudioStream
@export var liquidpour_stream: AudioStream
@export var shakerrattle_stream: AudioStream
@export var mugpickup_stream: AudioStream
@export var slime_stream: AudioStream
@export var bus_name: StringName = &"SFX"

var _players: Dictionary = {}

static func _resolve_stream(current: AudioStream, primary_path: String, fallback_path: String) -> AudioStream:
	if current != null:
		return current
	if ResourceLoader.exists(primary_path):
		return load(primary_path) as AudioStream
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path) as AudioStream
	return null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	knifedraw_stream = _resolve_stream(knifedraw_stream, "res://Audio/SFX/Knifesheaf.wav", "res://Assets/Audio/SFX/Knifesheaf.wav")
	knifestab_stream = _resolve_stream(knifestab_stream, "res://Audio/SFX/KnifeStab.wav", "res://Assets/Audio/SFX/KnifeStab.wav")
	# knifeslice_stream = _resolve_stream(knifeslice_stream, "res://Audio/SFX/KnifeSlice.wav", "res://Assets/Audio/SFX/KnifeSlice.wav")
	entranto_stream = _resolve_stream(entranto_stream, "res://Audio/SFX/842380__mihacappy__entrance_open1.wav", "res://Assets/Audio/SFX/842380__mihacappy__entrance_open1.wav")
	liquidpour_stream = _resolve_stream(liquidpour_stream, "res://Audio/SFX/liquidpour.wav", "res://Audio/SFX/liquidpour.wav")
	shakerrattle_stream = _resolve_stream(shakerrattle_stream, "res://Audio/SFX/Shaker1.mp3", "res://Audio/SFX/Shaker1.mp3")
	mugpickup_stream = _resolve_stream(mugpickup_stream, "res://Audio/SFX/Pickupglass.wav", "res://Audio/SFX/Pickupglass.wav")
	slime_stream = _resolve_stream(slime_stream, "res://Audio/SFX/Slime.wav", "res://Audio/SFX/Slime.wav")

	var streams := {
		&"draw": knifedraw_stream,
		&"stab": knifestab_stream,
		# &"slice": knifeslice_stream,
		&"entranto": entranto_stream,
		&"liquidpour": liquidpour_stream,
		&"shakerrattle": shakerrattle_stream,
		&"mugpickup": mugpickup_stream,
		&"slime": slime_stream,
	}
	for key in streams:
		_players[key] = UI_AUDIO_SCRIPT.create_bus_player(self, streams[key], bus_name, &"SFXAudio")

func _play_key(key: StringName) -> void:
	UI_AUDIO_SCRIPT.play_player(_players.get(key) as AudioStreamPlayer)

func play_draw() -> void:
	_play_key(&"draw")

func play_stab() -> void:
	_play_key(&"stab")

# func play_slice() -> void:
# 	_play_key(&"slice")

func play_entranto() -> void:
	_play_key(&"entranto")

func play_liquidpour() -> void:
	_play_key(&"liquidpour")

func play_shakerrattle() -> void:
	_play_key(&"shakerrattle")

func play_mugpickup() -> void:
	_play_key(&"mugpickup")

func play_slime() -> void:
	_play_key(&"slime")