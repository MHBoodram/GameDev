extends CanvasLayer

const START_MENU_SCENE := "res://UI/Starting/Starting_screen.tscn"

@onready var resume_button: Button = $Border/Dim/CenterContainer/VBox2/ResumeButton
@onready var setting_button: Button = $Border/Dim/CenterContainer/VBox2/SettingButton
@onready var menu_button: Button = $Border/Dim/CenterContainer/VBox2/MainMenuButton
@onready var quit_button: Button = $Border/Dim/CenterContainer/VBox2/QuitButton
var which_menu = "Resume"
var action_to_rebind = "Up"
var waiting_keybind = false

func _ready() -> void:
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# The rest of ht egame stops when the tree is paused; this menu must keep running.
	_load_settings()
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	UIAudio.hook_buttons(self)
	resume_button.pressed.connect(resume)
	setting_button.pressed.connect(settings)
	menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	if OS.has_feature("web"):
		quit_button.hide()

func _get_control_buttons() -> Dictionary:
	return {
		"Right": $Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Right/Right,
		"Left": $Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Left/Left,
		"Down": $Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Down/Down,
		"Up": $Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Up/Up,
	}

func _begin_rebind(action_name: String) -> void:
	var btn := _get_control_buttons().get(action_name) as Button
	if btn:
		btn.text = "awaiting"
	action_to_rebind = action_name
	waiting_keybind = true

func _load_settings() -> void:
	SettingState.apply_settings_to_ui(
		$Inside_paper/Left_color/Left_Page/Audio_Container/Master/Master_slider,
		$Inside_paper/Left_color/Left_Page/Audio_Container/UI/UI_slider,
		$Inside_paper/Left_color/Left_Page/Audio_Container/Music/Music_slider,
		$Inside_paper/Left_color/Left_Page/Video/Full_Screen,
		$Inside_paper/Left_color/Left_Page/Video/World_Environment,
		_get_control_buttons()
	)

func _input(event: InputEvent) -> void:
	if not waiting_keybind:
		return
	var btn := _get_control_buttons().get(action_to_rebind) as Button
	waiting_keybind = SettingState.handle_rebind_input(event, action_to_rebind, btn)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		UIAudio.play_pause()
		if get_tree().paused && which_menu == "Resume":
			$AnimationPlayer.play_backwards("open_up_pause")
			resume()
		elif which_menu == "Resume":
			$AnimationPlayer.play("open_up_pause")
			pause()
		if get_tree().paused && which_menu == "Setting":
			_on_save_quit_setting_pressed()
		get_viewport().set_input_as_handled()

func pause() -> void:
	get_tree().paused = true
	show()
	$Hand.show()
	resume_button.grab_focus()

func resume() -> void:
	get_tree().paused = false
	$Hand.hide()
	hide()

func settings() -> void:
	if(which_menu=="Resume"):
		$AnimationPlayer.play("open_settings")
		which_menu = "Setting"
	else:
		$AnimationPlayer.play_backwards("open_settings")
		which_menu = "Resume"

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(START_MENU_SCENE)

func _on_quit_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _on_save_quit_setting_pressed() -> void:
	settings()
	SettingState._saving_setting()


func _on_full_screen_pressed() -> void:
	SettingState.set_fullscreen($Inside_paper/Left_color/Left_Page/Video/Full_Screen.button_pressed)

func _on_world_environment_pressed() -> void:
	SettingState.set_world_environment($Inside_paper/Left_color/Left_Page/Video/World_Environment.button_pressed)

func _on_up_pressed() -> void:
	_begin_rebind("Up")


func _on_down_pressed() -> void:
	_begin_rebind("Down")


func _on_left_pressed() -> void:
	_begin_rebind("Left")


func _on_right_pressed() -> void:
	_begin_rebind("Right")


func _on_master_slider_value_changed(value: float) -> void:
	SettingState.set_audio_setting("Master_value", ["Master"], value)

func _on_ui_slider_value_changed(value: float) -> void:
	SettingState.set_audio_setting("UI_value", ["UI", "SFX"], value)


func _on_music_slider_value_changed(value: float) -> void:
	SettingState.set_audio_setting("Music_value", ["Music"], value)


func _on_audio_reset_pressed() -> void:
	SettingState.reset_audio_settings([
		$Inside_paper/Left_color/Left_Page/Audio_Container/SFX/SFX_slider,
		$Inside_paper/Left_color/Left_Page/Audio_Container/Music/Music_slider,
		$Inside_paper/Left_color/Left_Page/Audio_Container/Master/Master_slider,
		$Inside_paper/Left_color/Left_Page/Audio_Container/UI/UI_slider,
	])


func _on_control_reset_pressed() -> void:
	SettingState.reset_controls_to_ui(_get_control_buttons())