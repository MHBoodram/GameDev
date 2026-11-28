extends CanvasLayer
@export var menu_parent : Node3D

func _ready() -> void:
	$AnimationPlayer.speed_scale = 0.4
	_apply_ink_paper_theme()

func _apply_ink_paper_theme() -> void:
	var center := $CenterContainer as Control
	var panel := $CenterContainer/PanelContainer as PanelContainer
	var left_col := $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Columns/LeftColumn
	var right_col := $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Columns/RightColumn
	if is_instance_valid(center):
		center.theme = InkTheme.get_theme()
	if is_instance_valid(panel):
		InkTheme.apply_panel_variant(panel, "cream", false, Vector4(10.0, 8.0, 10.0, 2.0))

	for div_node in [
		$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TopDivider,
		left_col.get_node_or_null("Video_Divider"),
		left_col.get_node_or_null("Audio_Divider"),
		right_col.get_node_or_null("Control_Divider"),
	]:
		if div_node is Control:
			InkTheme.style_divider(div_node as Control, false)
	var col_div := $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Columns/ColumnDivider as Control
	if is_instance_valid(col_div):
		InkTheme.style_divider(col_div, true)

	for cb in [
		left_col.get_node_or_null("Video/Full_Screen"),
		left_col.get_node_or_null("Video/World_Environment"),
		right_col.get_node_or_null("Controls/Invert_Pour"),
	]:
		if cb is CheckButton:
			InkTheme.apply_check_button(cb as CheckButton, 26)

	var shaken_opt := left_col.get_node_or_null("Video/Shaken_Receipt/Shaken_Receipt_Option")
	if shaken_opt is OptionButton:
		InkTheme.apply_button_variant(shaken_opt as OptionButton, "paper", false, 24)

	for btn in [
		left_col.get_node_or_null("Audio_Container/Audio_reset"),
		right_col.get_node_or_null("Controls/Control_reset"),
	]:
		if btn is Button:
			InkTheme.apply_button_variant(btn as Button, "paper", false, 26)

	for slider in [
		left_col.get_node_or_null("Audio_Container/Master/Master_slider"),
		left_col.get_node_or_null("Audio_Container/UI/UI_slider"),
		left_col.get_node_or_null("Audio_Container/SFX/SFX_slider"),
		left_col.get_node_or_null("Audio_Container/Music/Music_slider"),
	]:
		if slider is HSlider:
			InkTheme.apply_dithered_beer_slider(slider as HSlider)

	var save_btn := $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SaveQuit as Button
	if is_instance_valid(save_btn):
		InkTheme.apply_button_variant(save_btn, "primary", false, 28)

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
		"shaken_receipt_option": left_col.get_node("Video/Shaken_Receipt/Shaken_Receipt_Option"),
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