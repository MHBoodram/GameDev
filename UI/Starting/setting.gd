extends CanvasLayer
@export var menu_parent : Node3D

func _ready() -> void:
	$AnimationPlayer.speed_scale = 0.4

func _get_control_buttons() -> Dictionary:
	return {
		"Right": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Right/Right,
		"Left": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Left/Left,
		"Down": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Down/Down,
		"Up": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Up/Up,
	}

func _setting_dictionary_start() -> void:
	SettingState.bind_settings_panel({
		"master_slider": $CenterContainer/VBoxContainer/Audio_Container/Master/Master_slider,
		"ui_slider": $CenterContainer/VBoxContainer/Audio_Container/UI/UI_slider,
		"music_slider": $CenterContainer/VBoxContainer/Audio_Container/Music/Music_slider,
		"sfx_slider": $CenterContainer/VBoxContainer/Audio_Container/SFX/SFX_slider,
		"audio_reset_btn": $CenterContainer/VBoxContainer/Audio_Container/Audio_reset,
		"fullscreen_btn": $CenterContainer/VBoxContainer/Video/HBoxContainer/Full_Screen,
		"world_env_btn": $CenterContainer/VBoxContainer/Video/HBoxContainer/World_Environment,
		"control_buttons": _get_control_buttons(),
		"control_reset_btn": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Control_reset,
		"invert_pour_btn": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Invert_Pour,
	})

func _moving(move : bool = true) -> void:
	if(move):
		$AnimationPlayer.play("Moving")
	else:
		$AnimationPlayer.play_backwards("Moving")

func _on_save_quit_pressed() -> void:
	SettingState.cancel_rebind()
	if(menu_parent):
		menu_parent._moving_2d_to_3d()
		SettingState._saving_setting()

func _on_master_slider_mouse_entered() -> void:
	if menu_parent:
		menu_parent._update_hand("interact")

func _on_master_slider_mouse_exited() -> void:
	if menu_parent:
		menu_parent._update_hand("idle")