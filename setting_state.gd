extends Node
const SAVE_PATH = "user://setting_state.dat"
const DEFAULT_SETTING = {
	"Video" :
		{
		"FullScreen" : false,
		"Resolution" : false,
		"WorldEnvironment" : true
		},
	"Control" :
		{
		"Up" : "W",
		"Down" : "S",
		"Left" : "A",
		"Right" : "D",
		},
	"Audio" :
		{
		"Master_value" : 0,
		"UI_value" : 0,
		"SFX_value" : 0,
		"Music_value" : 0
		}
}

var setting_dic = {
	"Video" :
		{
		"FullScreen" : false,
		"Resolution" : false,
		"WorldEnvironment" : true
		},
	"Control" :
		{
		"Up" : "w",
		"Down" : "s",
		"Left" : "a",
		"Right" : "d",
		},
	"Audio" :
		{
		"Master_value" : 0,
		"UI_value" : 0,
		"SFX_value" : 0,
		"Music_value" : 0
		}
}

func _saving_setting():
	var file = FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file:
		file.store_var(setting_dic)
		file.close()
	else:
		DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())

func _loading_setting():
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save data found.")
		apply_world_environment()
		apply_audio_settings()
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	print(SAVE_PATH)
	if file:
		var loaded_data = file.get_var()
		file.close()
		for main_key in setting_dic:
			if not loaded_data.has(main_key):
				loaded_data[main_key] = DEFAULT_SETTING[main_key].duplicate(true)
			for default_key in DEFAULT_SETTING[main_key]:
				if not loaded_data[main_key].has(default_key):
					loaded_data[main_key][default_key] = DEFAULT_SETTING[main_key][default_key]
			for sub_key in loaded_data[main_key]:
				var file_key = loaded_data[main_key][sub_key]
				if(file_key):
					setting_dic[main_key][sub_key] = file_key
					print(main_key + " " + sub_key + ": " + str(file_key))
				else:
					match main_key:
						"Video":
							setting_dic[main_key][sub_key] = false
						"Control":
							setting_dic[main_key][sub_key] = "_"
						"Audio":
							setting_dic[main_key][sub_key] = 0
		apply_world_environment()
		apply_audio_settings()

func set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, value)
		AudioServer.set_bus_mute(bus_index, value <= -24.0)

# applies loaded slider decibel levels to AudioServer buses on load
func apply_audio_settings() -> void:
	set_bus_volume("Master", setting_dic["Audio"]["Master_value"])
	set_bus_volume("UI", setting_dic["Audio"]["UI_value"])
	set_bus_volume("SFX", setting_dic["Audio"].get("SFX_value", setting_dic["Audio"]["UI_value"]))
	set_bus_volume("Music", setting_dic["Audio"]["Music_value"])

func apply_world_environment():
	var enabled = setting_dic["Video"].get("WorldEnvironment", true)
	var tree = get_tree()
	if not tree or not tree.root:
		return
	var env_nodes = tree.root.find_children("*", "WorldEnvironment", true, false)
	for env in env_nodes:
		if not env.has_meta("original_env"):
			if env.environment != null:
				env.set_meta("original_env", env.environment)
		if enabled:
			if env.has_meta("original_env"):
				env.environment = env.get_meta("original_env")
		else:
			env.environment = null

func _key_to_string(control: String) -> String:
	var value = SettingState.setting_dic["Control"][control]
	var temp : String
	if value is InputEventKey:
		temp = value.as_text_physical_keycode()
	elif value is int:
		temp = OS.get_keycode_string(value)
	else:
		temp = str(value)   # already a string, print as is
	return temp

func to_physical_event(event: InputEventKey) -> InputEventKey:
	var new_event := InputEventKey.new()
	new_event.physical_keycode = event.physical_keycode
	return new_event

func rebind_action(action: String, new_key):
	var phys := to_physical_event(new_key)
	setting_dic["Control"][action] = phys.physical_keycode
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, phys)
	get_viewport().set_input_as_handled()

func _reset_to_default_controls():
	for key in setting_dic["Control"]:
		if(DEFAULT_SETTING["Control"].has(key)):
			setting_dic["Control"][key] = DEFAULT_SETTING["Control"][key]
		else:
			setting_dic["Control"].erase(key)

func set_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	setting_dic["Video"]["FullScreen"] = enabled

func set_world_environment(enabled: bool) -> void:
	setting_dic["Video"]["WorldEnvironment"] = enabled
	apply_world_environment()

func set_audio_setting(key: String, buses: Array, value: float) -> void:
	for bus_name in buses:
		set_bus_volume(str(bus_name), value)
	setting_dic["Audio"][key] = value
	if key == "UI_value":
		setting_dic["Audio"]["SFX_value"] = value

func reset_audio_settings(sliders: Array = []) -> void:
	for bus_name in ["Master", "Music", "UI", "SFX"]:
		set_bus_volume(bus_name, 0.0)
	setting_dic["Audio"]["Master_value"] = 0
	setting_dic["Audio"]["Music_value"] = 0
	setting_dic["Audio"]["UI_value"] = 0
	setting_dic["Audio"]["SFX_value"] = 0
	for slider in sliders:
		if is_instance_valid(slider):
			slider.value = 0

func apply_settings_to_ui(
	master_slider: Range,
	ui_slider: Range,
	music_slider: Range,
	fullscreen_btn: BaseButton,
	world_env_btn: BaseButton,
	control_buttons: Dictionary
) -> void:
	if is_instance_valid(master_slider):
		master_slider.value = setting_dic["Audio"]["Master_value"]
	if is_instance_valid(ui_slider):
		ui_slider.value = setting_dic["Audio"]["UI_value"]
	if is_instance_valid(music_slider):
		music_slider.value = setting_dic["Audio"]["Music_value"]

	var fullscreen_enabled: bool = bool(setting_dic["Video"]["FullScreen"])
	if is_instance_valid(fullscreen_btn):
		fullscreen_btn.button_pressed = fullscreen_enabled
	set_fullscreen(fullscreen_enabled)

	var world_env_enabled: bool = bool(setting_dic["Video"].get("WorldEnvironment", true))
	if is_instance_valid(world_env_btn):
		world_env_btn.button_pressed = world_env_enabled
	apply_world_environment()

	for action_name in control_buttons:
		var btn := control_buttons[action_name] as Button
		if is_instance_valid(btn):
			btn.text = _key_to_string(str(action_name))

func handle_rebind_input(event: InputEvent, action_name: String, target_button: Button) -> bool:
	if not (event is InputEventKey and event.pressed):
		return true
	if event.physical_keycode == KEY_ESCAPE:
		if is_instance_valid(target_button):
			target_button.text = _key_to_string(action_name)
		return false
	rebind_action(action_name, event)
	if is_instance_valid(target_button):
		target_button.text = event.as_text()
	return false

func reset_controls_to_ui(control_buttons: Dictionary) -> void:
	_reset_to_default_controls()
	for action_name in control_buttons:
		var btn := control_buttons[action_name] as Button
		if is_instance_valid(btn):
			btn.text = str(DEFAULT_SETTING["Control"].get(str(action_name), _key_to_string(str(action_name))))