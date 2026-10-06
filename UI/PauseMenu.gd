extends CanvasLayer

const START_MENU_SCENE := "res://UI/StartMenu.tscn"

@onready var resume_button: Button = $CenterContainer/VBox/ResumeButton
@onready var menu_button: Button = $CenterContainer/VBox/MainMenuButton
@onready var quit_button: Button = $CenterContainer/VBox/QuitButton

func _ready() -> void:
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# The rest of ht egame stops when the tree is paused; this menu must keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	UIAudio.hook_buttons(self)
	resume_button.pressed.connect(resume)
	menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	if OS.has_feature("web"):
		quit_button.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		UIAudio.play_pause()
		if get_tree().paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()

func pause() -> void:
	get_tree().paused = true
	show()
	resume_button.grab_focus()

func resume() -> void:
	get_tree().paused = false
	hide()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(START_MENU_SCENE)

func _on_quit_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
