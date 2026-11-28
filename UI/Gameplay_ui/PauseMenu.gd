extends CanvasLayer

const START_MENU_SCENE := "res://UI/Starting/Starting_screen.tscn"

@onready var resume_button: Button = $Border/Dim/CenterContainer/VBox2/ResumeButton
@onready var setting_button: Button = $Border/Dim/CenterContainer/VBox2/SettingButton
@onready var menu_button: Button = $Border/Dim/CenterContainer/VBox2/MainMenuButton
@onready var quit_button: Button = $Border/Dim/CenterContainer/VBox2/QuitButton
var which_menu = "Resume"

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

func _collect_keybind_buttons() -> Dictionary:
	var scroll := $Inside_paper/Right_Color/Right_Page/Controls/KeybindsScroll as KeybindsScroll
	if is_instance_valid(scroll):
		return scroll.get_keybind_bindings()
	return {
		"control_buttons": {},
		"reset_buttons": {},
		"delete_buttons": {},
	}

func _get_control_buttons() -> Dictionary:
	return _collect_keybind_buttons()["control_buttons"]

func _load_settings() -> void:
	var keybind_maps := _collect_keybind_buttons()
	SettingState.bind_settings_panel({
		"master_slider": $Inside_paper/Left_color/Left_Page/Audio_Container/Master/Master_slider,
		"ui_slider": $Inside_paper/Left_color/Left_Page/Audio_Container/UI/UI_slider,
		"music_slider": $Inside_paper/Left_color/Left_Page/Audio_Container/Music/Music_slider,
		"sfx_slider": $Inside_paper/Left_color/Left_Page/Audio_Container/SFX/SFX_slider,
		"audio_reset_btn": $Inside_paper/Left_color/Left_Page/Audio_Container/Audio_reset,
		"fullscreen_btn": $Inside_paper/Left_color/Left_Page/Video/Full_Screen,
		"world_env_btn": $Inside_paper/Left_color/Left_Page/Video/World_Environment,
		"shaken_receipt_btn": $Inside_paper/Left_color/Left_Page/Video/Shaken_Receipt,
		"control_buttons": keybind_maps["control_buttons"],
		"reset_buttons": keybind_maps["reset_buttons"],
		"delete_buttons": keybind_maps["delete_buttons"],
		"control_reset_btn": $Inside_paper/Right_Color/Right_Page/Controls/Control_reset,
		"invert_pour_btn": $Inside_paper/Right_Color/Right_Page/Controls/Invert_Pour,
	})

func _is_escape_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE
	return false

func _input(event: InputEvent) -> void:
	if SettingState.waiting_keybind:
		return
	if _is_escape_pressed(event):
		UIAudio.play_pause()
		if not visible:
			which_menu = "Resume"
			$Inside_paper.hide()
			$Border.show()
			$AnimationPlayer.play("RESET")
			$AnimationPlayer.play("open_up_pause")
			pause()
		elif which_menu == "Setting":
			_on_save_quit_setting_pressed()
		else:
			$AnimationPlayer.play_backwards("open_up_pause")
			resume()
		get_viewport().set_input_as_handled()

func pause() -> void:
	_load_settings()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().paused = true
	show()
	$Hand.show()
	resume_button.grab_focus()

func resume() -> void:
	SettingState.cancel_rebind()
	get_tree().paused = false
	$Hand.hide()
	hide()

func close_menu() -> void:
	if which_menu == "Setting" or ($AnimationPlayer.is_playing() and $AnimationPlayer.current_animation == "open_settings"):
		which_menu = "Resume"
		$Inside_paper.hide()
		$Border.show()
		$AnimationPlayer.play("RESET")
	resume()

func settings() -> void:
	var anim_player: AnimationPlayer = $AnimationPlayer
	if which_menu == "Resume":
		_load_settings()
		which_menu = "Setting"
		if anim_player.is_playing() and anim_player.current_animation == "open_settings":
			var cur_pos: float = anim_player.current_animation_position
			anim_player.play("open_settings", -1, 1.0, false)
			anim_player.seek(cur_pos, true)
		else:
			anim_player.play("open_settings")
	else:
		which_menu = "Resume"
		if anim_player.is_playing() and anim_player.current_animation == "open_settings":
			var cur_pos: float = anim_player.current_animation_position
			anim_player.play("open_settings", -1, -1.0, false)
			anim_player.seek(cur_pos, true)
		else:
			anim_player.play_backwards("open_settings")

func _on_main_menu_pressed() -> void:
	close_menu()
	GameState.reset_game()
	get_tree().change_scene_to_file(START_MENU_SCENE)

func _on_quit_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _on_save_quit_setting_pressed() -> void:
	SettingState.cancel_rebind()
	settings()
	SettingState._saving_setting()