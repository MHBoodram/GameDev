extends Node
## Autoload that plays menu sound effects on the "UI" audio bus.
## Assign the two WAV files in the Inspector on UIAudio.tscn

@export var click_stream: AudioStream # button clicks
@export var pause_stream: AudioStream # pressing Esc to pause / unpause
@export var bus_name: StringName = &"UI"

var _click_player: AudioStreamPlayer
var _pause_player: AudioStreamPlayer

func _ready() -> void:
	# AudioStreamPlayers stop when the tree is paused unless they can process
	# while paused, so this node (and all it's children nodes) must always process
	_click_player = _make_player(click_stream)
	_pause_player = _make_player(pause_stream)

func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	if AudioServer.get_bus_index(bus_name) != -1:
		player.bus = bus_name
	else:
		push_warning("UIAudio: bus '%s' not found, falling back to Master." % bus_name)
		player.bus = &"Master"
	add_child(player)
	return player

func play_click() -> void:
	_play(_click_player)

func play_pause() -> void:
	_play(_pause_player)

func _play(player : AudioStreamPlayer) -> void:
	if player.stream:
		player.play()


func hook_buttons(root: Node) -> void:
	for node in root.find_children("*","BaseButton",true,false):
		var button := node as BaseButton
		if not button.pressed.is_connected(play_click):
			button.pressed.connect(play_click)
