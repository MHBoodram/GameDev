extends Control

const GAME_SCENE := "res://Main3D.tscn"

@onready var play_button: Button = $CenterContainer/VBox/PlayButton
@onready var quit_button: Button = $CenterContainer/VBox/QuitButton

func _ready() -> void:
	get_tree().paused = false #in case we come here from the pause menu
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()

	if OS.has_feature("web"): #this is lowk only if this is on the web, shoudln't be much of an issue with us
		quit_button.hide()

func _on_play_pressed() -> void:
	GameState.seat1_order = []
	GameState.seat2_order = []
	GameState.seat3_order = []
	get_tree().change_scene_to_file(GAME_SCENE)
	

func _on_quit_pressed() -> void:
	get_tree().quit()
