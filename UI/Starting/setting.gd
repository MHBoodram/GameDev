extends CanvasLayer
@export var menu_parent : Node3D

func _ready() -> void:
	$AnimationPlayer.speed_scale = 0.4

func _setting_dictionary_start() -> void:
	$CenterContainer/VBoxContainer/Audio_Container/Master/Master_slider.value = SettingState.setting_dic["Audio"]["Master_value"]
	$CenterContainer/VBoxContainer/Audio_Container/Sound_effect/Sound_effect_slider.value = SettingState.setting_dic["Audio"]["UI_value"]
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
