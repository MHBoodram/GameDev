# Scene root
# Initialize gamestate
extends Node3D

const PAUSE_MENU_SCENE := preload("res://UI/Gameplay_ui/PauseMenu.tscn")

@onready var player: Node3D = $Player
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $WorldEnvironment/Sun
@onready var night_timer: Timer = $Night_Time
@onready var counter: Node3D = $Coutner
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var debug_menu: CanvasLayer = $DebugMenu

func _ready() -> void:
	GameState.register_subsystems(self, player, night_timer, world_environment, sun, counter)
	add_child(PAUSE_MENU_SCENE.instantiate())
	PlayerStats.money = PlayerStats.previous_money
	animation_player.play("opening")
	await animation_player.animation_finished
	
	GameState.start_night()

func toggle_debug_menu() -> void:
	if not debug_menu:
		return
	if debug_menu.visible:
		debug_menu.visible = false
	elif not get_tree().paused:
		debug_menu.visible = true
