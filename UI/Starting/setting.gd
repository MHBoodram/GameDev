extends CanvasLayer
@export var menu_parent : Node3D
var waiting_keybind := false
var action_to_rebind : String
func _ready() -> void:
	$AnimationPlayer.speed_scale = 0.4

func _setting_dictionary_start() -> void:
	$CenterContainer/VBoxContainer/Audio_Container/Master/Master_slider.value = SettingState.setting_dic["Audio"]["Master_value"]
	$CenterContainer/VBoxContainer/Audio_Container/UI/UI_slider.value = SettingState.setting_dic["Audio"]["UI_value"]
	$CenterContainer/VBoxContainer/Audio_Container/Music/Music_slider.value = SettingState.setting_dic["Audio"]["Music_value"]
	$CenterContainer/VBoxContainer/Video/Full_Screen.button_pressed = SettingState.setting_dic["Video"]["FullScreen"]
	if $CenterContainer/VBoxContainer/Video/Full_Screen.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _moving(move : bool = true) -> void:
	if(move):
		$AnimationPlayer.play("Moving")
	else:
		$AnimationPlayer.play_backwards("Moving")

func _on_save_quit_pressed() -> void:
	if(menu_parent):
		menu_parent._moving_2d_to_3d()
		SettingState._saving_setting()

func _on_master_slider_value_changed(value: float) -> void:
	UIAudio._change_bus_volume("Master",value)
	SettingState.setting_dic["Audio"]["Master_value"] = value

func _on_music_slider_value_changed(value: float) -> void:
	UIAudio._change_bus_volume("Music",value)
	SettingState.setting_dic["Audio"]["Music_value"] = value

func _on_sound_effect_slider_value_changed(value: float) -> void:
	UIAudio._change_bus_volume("UI",value)
	SettingState.setting_dic["Audio"]["UI_value"] = value

func _on_full_screen_pressed() -> void:
	if $CenterContainer/VBoxContainer/Video/Full_Screen.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	SettingState.setting_dic["Video"]["FullScreen"] = $CenterContainer/VBoxContainer/Video/Full_Screen.button_pressed


func _on_master_slider_mouse_entered() -> void:
	menu_parent._update_hand("interact")


func _on_master_slider_mouse_exited() -> void:
	menu_parent._update_hand("idle")


func _on_audio_reset_pressed() -> void:
	UIAudio._change_bus_volume("Master",0)
	UIAudio._change_bus_volume("Music",0)
	UIAudio._change_bus_volume("UI",0)
	SettingState.setting_dic["Audio"]["Master_value"] = 0
	SettingState.setting_dic["Audio"]["Music_value"] = 0
	SettingState.setting_dic["Audio"]["UI_value"] = 0
	$CenterContainer/VBoxContainer/Audio_Container/SFX/SFX_slider.value = 0
	$CenterContainer/VBoxContainer/Audio_Container/Music/Music_slider.value = 0
	$CenterContainer/VBoxContainer/Audio_Container/Master/Master_slider.value = 0
	$CenterContainer/VBoxContainer/Audio_Container/UI/UI_slider.value = 0

func _input(event):
	if not waiting_keybind:
		return

	if event is InputEventKey and event.pressed:
	# Escape cancels
		if event.physical_keycode == KEY_ESCAPE:
			waiting_keybind = false
			$Label.text = "Cancelled"
			return

		rebind_action(action_to_rebind, event)
		waiting_keybind = false
		get_viewport().set_input_as_handled()

func rebind_action(action: String, new_key: Key):
	InputMap.action_erase_events(action)
	var ev = InputEventKey.new()
	ev.physical_keycode = new_key
	InputMap.action_add_event(action, ev)

func _on_change_up_pressed() -> void:
	action_to_rebind = "Up"
	waiting_keybind = true

func _on_change_down_pressed() -> void:
	action_to_rebind = "Down"
	waiting_keybind = true

func _on_change_left_pressed() -> void:
	action_to_rebind = "Left"
	waiting_keybind = true


func _on_change_right_pressed() -> void:
	action_to_rebind = "Right"
	waiting_keybind = true
