# All audio sound effects
extends Node

const UI_AUDIO_SCRIPT := preload("res://UI/Audio/UIAudio.gd")

@export var knifedraw_stream: AudioStream = preload("res://Assets/Audio/SFX/Knifesheaf.wav")
@export var knifestab_stream: AudioStream = preload("res://Assets/Audio/SFX/KnifeStab.wav")
@export var entranto_stream: AudioStream = preload("res://Assets/Audio/SFX/842380__mihacappy__entrance_open1.wav")
@export var liquidpour_stream: AudioStream = preload("res://Assets/Audio/SFX/liquidpour.wav")
@export var shakerrattle_stream: AudioStream = preload("res://Assets/Audio/SFX/Shaker1.mp3")
@export var mugpickup_stream: AudioStream = preload("res://Assets/Audio/SFX/Pickupglass.wav")
@export var slime_stream: AudioStream = preload("res://Assets/Audio/SFX/Slime.wav")
@export var bus_name: StringName = &"SFX"

var _players: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var streams := {
		&"draw": knifedraw_stream,
		&"stab": knifestab_stream,
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