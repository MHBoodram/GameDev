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
	_click_player = create_bus_player(self, click_stream, bus_name, &"UIAudio")
	_pause_player = create_bus_player(self, pause_stream, bus_name, &"UIAudio")

static func create_bus_player(parent: Node, stream: AudioStream, target_bus: StringName, owner_tag: StringName = &"Audio") -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	if AudioServer.get_bus_index(target_bus) != -1:
		player.bus = target_bus
	else:
		push_warning("%s: bus '%s' not found, falling back to Master." % [owner_tag, target_bus])
		player.bus = &"Master"
	if is_instance_valid(parent):
		parent.add_child(player)
	return player

static func play_player(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()

func play_click() -> void:
	play_player(_click_player)

func play_pause() -> void:
	play_player(_pause_player)

func hook_buttons(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if not button.pressed.is_connected(play_click):
			button.pressed.connect(play_click)