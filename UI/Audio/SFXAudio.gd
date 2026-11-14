extends Node
## Autoload that plays menu sound effects on the "SFX" audio bus.


@export var knifedraw_stream: AudioStream 
@export var knifestab_stream: AudioStream
@export var entranto_stream: AudioStream
@export var liquidpour_stream: AudioStream
@export var shakerrattle_stream: AudioStream
@export var mugpickup_stream: AudioStream
@export var bus_name: StringName = &"SFX"

var knifedraw: AudioStreamPlayer
var knifestab: AudioStreamPlayer
var entranto: AudioStreamPlayer
var liquidpour: AudioStreamPlayer
var shakerrattle: AudioStreamPlayer
var mugpickup: AudioStreamPlayer

func _ready() -> void:
	# AudioStreamPlayers stop when the tree is paused unless they can process
	# while paused, so this node (and all it's children nodes) must always process
	knifedraw = _make_player(knifedraw_stream)
	knifestab = _make_player(knifestab_stream)
	entranto = _make_player(entranto_stream)
	liquidpour = _make_player(liquidpour_stream)
	shakerrattle = _make_player(shakerrattle_stream)
	mugpickup = _make_player(mugpickup_stream)

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

func _change_bus_volume(n_bus: String,value : float): #Not working currently
	if AudioServer.get_bus_index(bus_name) != -1:
		var bus_index := AudioServer.get_bus_index(n_bus)
		AudioServer.set_bus_volume_db(bus_index,value)
		if(value <= -24):
			AudioServer.set_bus_mute(bus_index,true)
		else:
			AudioServer.set_bus_mute(bus_index,false)
			
	else:
		push_warning("SFXAudio: bus '%s' not found, falling back to Master." % bus_name)
		
	
	#if(value <= -24):
		#AudioServer.set_bus_mute(bus_index,true)
	#else:
		#AudioServer.set_bus_mute(bus_index,false)

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

func _play(player : AudioStreamPlayer) -> void:
	if player.stream:
		player.play()


#func hook(root: Node) -> void:
	#for node in root.find_children("*","BaseButton",true,false):
		#var button := node as BaseButton
		#if not button.pressed.is_connected(play_entranto):
			#button.pressed.connect(play_entranto)
