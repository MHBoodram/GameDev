extends CanvasLayer
@export var menu_parent : Node3D

func _ready() -> void:
	$AnimationPlayer.speed_scale = 0.4

func _collect_keybind_buttons() -> Dictionary:
	var list := $CenterContainer/VBoxContainer/Controls/VBoxContainer/KeybindsScroll/KeybindsList
	var control_buttons: Dictionary = {}
	var reset_buttons: Dictionary = {}
	var delete_buttons: Dictionary = {}
	for def in SettingState.CONTROL_KEYBIND_DEFS:
		var action_name := str(def["action"])
		var row := list.get_node_or_null(action_name + "Row")
		if row == null:
			continue
		var bind_btn := row.get_node_or_null(action_name) as Button
		var reset_btn := row.get_node_or_null(action_name + "_Reset") as Button
		var delete_btn := row.get_node_or_null(action_name + "_Delete") as Button
		if bind_btn:
			control_buttons[action_name] = bind_btn
		if reset_btn:
			reset_buttons[action_name] = reset_btn
		if delete_btn:
			delete_buttons[action_name] = delete_btn
	return {
		"control_buttons": control_buttons,
		"reset_buttons": reset_buttons,
		"delete_buttons": delete_buttons,
	}

func _get_control_buttons() -> Dictionary:
	return _collect_keybind_buttons()["control_buttons"]

func _setting_dictionary_start() -> void:
	var keybind_maps := _collect_keybind_buttons()
	SettingState.bind_settings_panel({
		"master_slider": $CenterContainer/VBoxContainer/Audio_Container/Master/Master_slider,
		"ui_slider": $CenterContainer/VBoxContainer/Audio_Container/UI/UI_slider,
		"music_slider": $CenterContainer/VBoxContainer/Audio_Container/Music/Music_slider,
		"sfx_slider": $CenterContainer/VBoxContainer/Audio_Container/SFX/SFX_slider,
		"audio_reset_btn": $CenterContainer/VBoxContainer/Audio_Container/Audio_reset,
		"fullscreen_btn": $CenterContainer/VBoxContainer/Video/HBoxContainer/Full_Screen,
		"world_env_btn": $CenterContainer/VBoxContainer/Video/HBoxContainer/World_Environment,
		"shaken_receipt_btn": $CenterContainer/VBoxContainer/Video/HBoxContainer/Shaken_Receipt,
		"control_buttons": keybind_maps["control_buttons"],
		"reset_buttons": keybind_maps["reset_buttons"],
		"delete_buttons": keybind_maps["delete_buttons"],
		"on_hover_enter": _on_master_slider_mouse_entered,
		"on_hover_exit": _on_master_slider_mouse_exited,
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