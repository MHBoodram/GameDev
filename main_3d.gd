# Scene root
# Initialize gamestate
extends Node3D

const OPENING_FF_SCOPE := "opening_cutscene"

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
	FastForward.begin_scope(OPENING_FF_SCOPE, {
		"duration": 0.25,
		"priority": 30,
	})
	animation_player.play("opening")
	FastForward.track_animation(animation_player, OPENING_FF_SCOPE)
	await animation_player.animation_finished
	FastForward.end_scope(OPENING_FF_SCOPE)
	
	GameState.start_night()

func _exit_tree() -> void:
	FastForward.end_scope(OPENING_FF_SCOPE)

func toggle_debug_menu() -> void:
	GameState.toggle_debug_menu()
