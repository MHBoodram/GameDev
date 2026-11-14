extends Control

const GAME_SCENE := "res://Main3D.tscn"

@onready var play_button: Button = $Paper/CenterContainer/VBox/PlayButton
@onready var quit_button: Button = $Paper/CenterContainer/VBox/QuitButton

func _ready() -> void:
	#$CenterContainer/VBox/Button.grab_focus()
	
	MusicPlayer.play_menu() # new menu song should be labeled "Piano Solo 1"
	get_tree().paused = false #in case we come here from the pause menu
	UIAudio.hook_buttons(self)
	#SFXAudio.hook(self)
	#SFXAudio.play_entranto()
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	#play_button.grab_focus()
	if OS.has_feature("web"): #this is lowk only if this is on the web, shoudln't be much of an issue with us
		quit_button.hide()

func _on_play_pressed() -> void:
	MusicPlayer.play_game()
	GameState.seat1_order = []
	GameState.seat2_order = []
	GameState.seat3_order = []
	Transition._changing_scene(GAME_SCENE)

func _change_hover(n_name: String = "Setting") -> void:
	var getting_node = get_node("Paper/CenterContainer/VBox/" + n_name + "Button")
	if(!getting_node):
		push_warning("Can't find node: " + n_name)
		return
	getting_node.modulate = Color(0.898, 0.831, 0.0, 0.624)

func _remove_hover(n_name: String = "Setting") -> void:
	var getting_node = get_node("Paper/CenterContainer/VBox/" + n_name + "Button")
	if(!getting_node):
		push_warning("Can't find node: " + n_name)
		return
	getting_node.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _setting() -> void:
	pass


func _on_quit_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
