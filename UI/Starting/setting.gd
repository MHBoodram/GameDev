extends CanvasLayer
@export var menu_parent : Node3D
var waiting_keybind := false
var action_to_rebind : String

func _ready() -> void:
	$AnimationPlayer.speed_scale = 0.4

func _get_control_buttons() -> Dictionary:
	return {
		"Right": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Right/Right,
		"Left": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Left/Left,
		"Down": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Down/Down,
		"Up": $CenterContainer/VBoxContainer/Controls/VBoxContainer/Up/Up,
	}

func _begin_rebind(action_name: String) -> void:
	var btn := _get_control_buttons().get(action_name) as Button
	if btn:
		btn.text = "awaiting"
	action_to_rebind = action_name
	waiting_keybind = true

func _setting_dictionary_start() -> void:
	SettingState.apply_settings_to_ui(
		$CenterContainer/VBoxContainer/Audio_Container/Master/Master_slider,
		$CenterContainer/VBoxContainer/Audio_Container/UI/UI_slider,
		$CenterContainer/VBoxContainer/Audio_Container/Music/Music_slider,
		$CenterContainer/VBoxContainer/Video/HBoxContainer/Full_Screen,
		$CenterContainer/VBoxContainer/Video/HBoxContainer/World_Environment,
		_get_control_buttons()
	)

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
	SettingState.set_audio_setting("Master_value", ["Master"], value)

func _on_music_slider_value_changed(value: float) -> void:
	SettingState.set_audio_setting("Music_value", ["Music"], value)

func _on_sound_effect_slider_value_changed(value: float) -> void:
	SettingState.set_audio_setting("UI_value", ["UI", "SFX"], value)

func _on_full_screen_pressed() -> void:
	SettingState.set_fullscreen($CenterContainer/VBoxContainer/Video/HBoxContainer/Full_Screen.button_pressed)

func _on_world_environment_pressed() -> void:
	SettingState.set_world_environment($CenterContainer/VBoxContainer/Video/HBoxContainer/World_Environment.button_pressed)

func _on_master_slider_mouse_entered() -> void:
	menu_parent._update_hand("interact")


func _on_master_slider_mouse_exited() -> void:
	menu_parent._update_hand("idle")


func _on_audio_reset_pressed() -> void:
	SettingState.reset_audio_settings([
		$CenterContainer/VBoxContainer/Audio_Container/SFX/SFX_slider,
		$CenterContainer/VBoxContainer/Audio_Container/Music/Music_slider,
		$CenterContainer/VBoxContainer/Audio_Container/Master/Master_slider,
		$CenterContainer/VBoxContainer/Audio_Container/UI/UI_slider,
	])

func _input(event):
	if not waiting_keybind:
		return
	var btn := _get_control_buttons().get(action_to_rebind) as Button
	waiting_keybind = SettingState.handle_rebind_input(event, action_to_rebind, btn)

func _on_change_up_pressed() -> void:
	_begin_rebind("Up")

func _on_change_down_pressed() -> void:
	_begin_rebind("Down")

func _on_change_left_pressed() -> void:
	_begin_rebind("Left")

func _on_change_right_pressed() -> void:
	_begin_rebind("Right")

func _on_control_reset_pressed() -> void:
	SettingState.reset_controls_to_ui(_get_control_buttons())