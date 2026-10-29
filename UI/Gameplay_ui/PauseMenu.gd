extends CanvasLayer

const START_MENU_SCENE := "res://UI/Starting/Starting_screen.tscn"

@onready var resume_button: Button = $Border/Dim/CenterContainer/VBox2/ResumeButton
@onready var setting_button: Button = $Border/Dim/CenterContainer/VBox2/SettingButton
@onready var menu_button: Button = $Border/Dim/CenterContainer/VBox2/MainMenuButton
@onready var quit_button: Button = $Border/Dim/CenterContainer/VBox2/QuitButton
var which_menu = "Resume"
var action_to_rebind = "Up"
var waiting_keybind = true

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

func _load_settings() -> void:
	$Inside_paper/Left_color/Left_Page/Audio_Container/Master/Master_slider.value = SettingState.setting_dic["Audio"]["Master_value"]
	$Inside_paper/Left_color/Left_Page/Audio_Container/UI/UI_slider.value = SettingState.setting_dic["Audio"]["UI_value"]
	$Inside_paper/Left_color/Left_Page/Audio_Container/Music/Music_slider.value = SettingState.setting_dic["Audio"]["Music_value"]
	$Inside_paper/Left_color/Left_Page/Video/Full_Screen.button_pressed = SettingState.setting_dic["Video"]["FullScreen"]
	if $Inside_paper/Left_color/Left_Page/Video/Full_Screen.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Right/Right.text = SettingState._key_to_string("Right")
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Left/Left.text = SettingState._key_to_string("Left")
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Down/Down.text = SettingState._key_to_string("Down")
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Up/Up.text = SettingState._key_to_string("Up")

func _input(event: InputEvent) -> void:
	if not waiting_keybind:
		return
	if event is InputEventKey and event.pressed:
		var node_search = get_node("Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/" + action_to_rebind + "/" + action_to_rebind)
		var previous_text = node_search.text
		if event.physical_keycode == KEY_ESCAPE:
			waiting_keybind = false
			node_search.text = previous_text
			return
		
		SettingState.rebind_action(action_to_rebind, event)
		node_search.text = event.as_text()
		waiting_keybind = false
		get_viewport().set_input_as_handled()

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
	if $Inside_paper/Left_color/Left_Page/Video/Full_Screen.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	SettingState.setting_dic["Video"]["FullScreen"] = $Inside_paper/Left_color/Left_Page/Video/Full_Screen.button_pressed


func _on_up_pressed() -> void:
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Up/Up.text = "awaiting"
	action_to_rebind = "Up"
	waiting_keybind = true


func _on_down_pressed() -> void:
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Down/Down.text = "awaiting"
	action_to_rebind = "Down"
	waiting_keybind = true


func _on_left_pressed() -> void:
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Left/Left.text = "awaiting"
	action_to_rebind = "Left"
	waiting_keybind = true


func _on_right_pressed() -> void:
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Right/Right.text = "awaiting"
	action_to_rebind = "Right"
	waiting_keybind = true


func _on_master_slider_value_changed(value: float) -> void:
	UIAudio._change_bus_volume("Master",value)
	SettingState.setting_dic["Audio"]["Master_value"] = value

func _on_ui_slider_value_changed(value: float) -> void:
	UIAudio._change_bus_volume("UI",value)
	SettingState.setting_dic["Audio"]["UI_value"] = value


func _on_music_slider_value_changed(value: float) -> void:
	UIAudio._change_bus_volume("Music",value)
	SettingState.setting_dic["Audio"]["Music_value"] = value


func _on_audio_reset_pressed() -> void:
	UIAudio._change_bus_volume("Master",0)
	UIAudio._change_bus_volume("Music",0)
	UIAudio._change_bus_volume("UI",0)
	SettingState.setting_dic["Audio"]["Master_value"] = 0
	SettingState.setting_dic["Audio"]["Music_value"] = 0
	SettingState.setting_dic["Audio"]["UI_value"] = 0
	$Inside_paper/Left_color/Left_Page/Audio_Container/SFX/SFX_slider.value = 0
	$Inside_paper/Left_color/Left_Page/Audio_Container/Music/Music_slider.value = 0
	$Inside_paper/Left_color/Left_Page/Audio_Container/Master/Master_slider.value = 0
	$Inside_paper/Left_color/Left_Page/Audio_Container/UI/UI_slider.value = 0


func _on_control_reset_pressed() -> void:
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Right/Right.text = "D"
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Left/Left.text = "A"
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Down/Down.text = "S"
	$Inside_paper/Right_Color/Right_Page/Controls/Controls/VBoxContainer/Up/Up.text = "W"
	SettingState._reset_to_default_controls()
