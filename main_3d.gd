# Scene root
# Initialize gamestate
extends Node3D

@onready var player: Node3D = $Player
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $WorldEnvironment/Sun
@onready var night_timer: Timer = $Night_Time
@onready var counter: Node3D = $Coutner
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var debug_menu: CanvasLayer = get_node_or_null("DebugMenu")

func _ready() -> void:
	if is_instance_valid(debug_menu):
		debug_menu.queue_free()
		debug_menu = null
	GameState.register_subsystems(self, player, night_timer, world_environment, sun, counter)
	PlayerStats.money = PlayerStats.previous_money
	animation_player.play("opening")
	await animation_player.animation_finished
	
	GameState.start_night()

func toggle_debug_menu() -> void:
	GameState.toggle_debug_menu()
