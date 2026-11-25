# All audio sound effects
extends Node

@export var knifedraw_stream: AudioStream = preload("res://Assets/Audio/SFX/Knifesheaf.wav")
@export var knifestab_stream: AudioStream = preload("res://Assets/Audio/SFX/KnifeStab.wav")
@export var entranto_stream: AudioStream = preload("res://Assets/Audio/SFX/842380__mihacappy__entrance_open1.wav")
@export var liquidpour_stream: AudioStream = preload("res://Assets/Audio/SFX/liquidpour.wav")
@export var shakerrattle_stream: AudioStream = preload("res://Assets/Audio/SFX/Shaker1.mp3")
@export var mugpickup_stream: AudioStream = preload("res://Assets/Audio/SFX/Pickupglass.wav")
@export var bus_name: StringName = &"SFX"

var knifedraw: AudioStreamPlayer
var knifestab: AudioStreamPlayer
var entranto: AudioStreamPlayer
var liquidpour: AudioStreamPlayer
var shakerrattle: AudioStreamPlayer
var mugpickup: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	knifedraw = _make_player(knifedraw_stream)
	knifestab = _make_player(knifestab_stream)
	entranto = _make_player(entranto_stream)
	liquidpour = _make_player(liquidpour_stream)
	shakerrattle = _make_player(shakerrattle_stream)
	mugpickup = _make_player(mugpickup_stream)
	call_deferred("_connect_game_events")

func _connect_game_events() -> void:
	if not GameEvents.sfx_requested.is_connected(_on_sfx_requested):
		GameEvents.sfx_requested.connect(_on_sfx_requested)

func _on_sfx_requested(sfx_id: String) -> void:
	match sfx_id:
		"draw", "knifedraw", "play_draw":
			play_draw()
		"stab", "knifestab", "play_stab":
			play_stab()
		"entranto", "play_entranto":
			play_entranto()
		"pour", "liquidpour", "play_liquidpour":
			play_liquidpour()
		"shaker", "shakerrattle", "play_shakerrattle":
			play_shakerrattle()
		"mugpickup", "play_mugpickup":
			play_mugpickup()

func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	if AudioServer.get_bus_index(bus_name) != -1:
		player.bus = bus_name
	else:
		push_warning("SFXAudio: bus '%s' not found, falling back to Master." % bus_name)
		player.bus = &"Master"
	add_child(player)
	return player

func _change_bus_volume(n_bus: String, value: float) -> void:
	SettingState.set_bus_volume(n_bus, value)

func play_draw() -> void:
	_play(knifedraw)

func play_stab() -> void:
	_play(knifestab)

func play_entranto() -> void:
	_play(entranto)

func play_liquidpour() -> void:
	_play(liquidpour)

func play_shakerrattle() -> void:
	_play(shakerrattle)

func play_mugpickup() -> void:
	_play(mugpickup)

func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()