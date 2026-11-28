extends CanvasLayer
@export var menu_parent : Node3D

func _ready() -> void:
	$AnimationPlayer.speed_scale = 0.4

func _collect_keybind_buttons() -> Dictionary:
	var scroll := $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Columns/RightColumn/Controls/KeybindsScroll as KeybindsScroll
	if is_instance_valid(scroll):
		return scroll.get_keybind_bindings()
	return {
		"control_buttons": {},
		"reset_buttons": {},
		"delete_buttons": {},
	}

func _get_control_buttons() -> Dictionary:
	return _collect_keybind_buttons()["control_buttons"]

func _setting_dictionary_start() -> void:
	var keybind_maps := _collect_keybind_buttons()
	var left_col := $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Columns/LeftColumn
	var right_col := $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Columns/RightColumn
	SettingState.bind_settings_panel({
		"master_slider": left_col.get_node("Audio_Container/Master/Master_slider"),
		"ui_slider": left_col.get_node("Audio_Container/UI/UI_slider"),
		"music_slider": left_col.get_node("Audio_Container/Music/Music_slider"),
		"sfx_slider": left_col.get_node("Audio_Container/SFX/SFX_slider"),
		"audio_reset_btn": left_col.get_node("Audio_Container/Audio_reset"),
		"fullscreen_btn": left_col.get_node("Video/Full_Screen"),
		"world_env_btn": left_col.get_node("Video/World_Environment"),
		"shaken_receipt_btn": left_col.get_node("Video/Shaken_Receipt"),
		"control_buttons": keybind_maps["control_buttons"],
		"reset_buttons": keybind_maps["reset_buttons"],
		"delete_buttons": keybind_maps["delete_buttons"],
		"on_hover_enter": _on_master_slider_mouse_entered,
		"on_hover_exit": _on_master_slider_mouse_exited,
		"control_reset_btn": right_col.get_node("Controls/Control_reset"),
		"invert_pour_btn": right_col.get_node("Controls/Invert_Pour"),
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