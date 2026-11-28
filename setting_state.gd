extends Node
signal shaken_receipt_mode_changed(mode: String)

const SAVE_PATH = "user://setting_state.dat"
const SHAKEN_MODE_SPLIT = "split"
const SHAKEN_MODE_AVERAGED = "averaged"

const DEFAULT_SETTING = {
	"Video" :
		{
		"FullScreen" : false,
		"Resolution" : false,
		"WorldEnvironment" : true,
		"ShakenReceiptMode" : SHAKEN_MODE_SPLIT
		},
	"Control" :
		{
		"Up" : "W",
		"Down" : "S",
		"Left" : "A",
		"Right" : "D",
		"InvertPouringAngle" : false,
		},
	"Audio" :
		{
		"Master_value" : 0,
		"UI_value" : 0,
		"SFX_value" : 0,
		"Music_value" : 0
		}
}

var setting_dic: Dictionary = DEFAULT_SETTING.duplicate(true)
var waiting_keybind: bool = false
var action_to_rebind: String = "Up"
var _active_control_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not waiting_keybind:
		return
	var btn := _active_control_buttons.get(action_to_rebind) as Button
	waiting_keybind = handle_rebind_input(event, action_to_rebind, btn)

func begin_rebind(action_name: String, control_buttons: Dictionary = {}) -> void:
	if not control_buttons.is_empty():
		_active_control_buttons = control_buttons
	var btn := _active_control_buttons.get(action_name) as Button
	if is_instance_valid(btn):
		btn.text = "awaiting"
	action_to_rebind = action_name
	waiting_keybind = true

func cancel_rebind() -> void:
	if waiting_keybind:
		var btn := _active_control_buttons.get(action_to_rebind) as Button
		if is_instance_valid(btn):
			btn.text = _key_to_string(action_to_rebind)
		waiting_keybind = false

func bind_settings_panel(config: Dictionary) -> void:
	cancel_rebind()
	var master_slider := config.get("master_slider") as Range
	var ui_slider := config.get("ui_slider") as Range
	var music_slider := config.get("music_slider") as Range
	var sfx_slider := config.get("sfx_slider") as Range
	var fullscreen_btn := config.get("fullscreen_btn") as BaseButton
	var world_env_btn := config.get("world_env_btn") as BaseButton
	var shaken_receipt_btn := config.get("shaken_receipt_btn") as BaseButton
	var audio_reset_btn := config.get("audio_reset_btn") as BaseButton
	var control_reset_btn := config.get("control_reset_btn") as BaseButton
	var invert_pour_btn := config.get("invert_pour_btn") as BaseButton
	var control_buttons: Dictionary = config.get("control_buttons", {})

	_active_control_buttons = control_buttons
	apply_settings_to_ui(master_slider, ui_slider, music_slider, fullscreen_btn, world_env_btn, control_buttons, invert_pour_btn, shaken_receipt_btn)

	if is_instance_valid(master_slider) and not master_slider.get_meta("_setting_state_bound", false):
		master_slider.set_meta("_setting_state_bound", true)
		master_slider.value_changed.connect(func(v: float) -> void:
			set_audio_setting("Master_value", ["Master"], v)
		)

	if is_instance_valid(ui_slider) and not ui_slider.get_meta("_setting_state_bound", false):
		ui_slider.set_meta("_setting_state_bound", true)
		ui_slider.value_changed.connect(func(v: float) -> void:
			set_audio_setting("UI_value", ["UI", "SFX"], v)
		)

	if is_instance_valid(music_slider) and not music_slider.get_meta("_setting_state_bound", false):
		music_slider.set_meta("_setting_state_bound", true)
		music_slider.value_changed.connect(func(v: float) -> void:
			set_audio_setting("Music_value", ["Music"], v)
		)

	if is_instance_valid(audio_reset_btn) and not audio_reset_btn.get_meta("_setting_state_bound", false):
		audio_reset_btn.set_meta("_setting_state_bound", true)
		var sliders: Array = [sfx_slider, music_slider, master_slider, ui_slider]
		audio_reset_btn.pressed.connect(func() -> void:
			reset_audio_settings(sliders)
		)

	if is_instance_valid(fullscreen_btn) and not fullscreen_btn.get_meta("_setting_state_bound", false):
		fullscreen_btn.set_meta("_setting_state_bound", true)
		fullscreen_btn.pressed.connect(func() -> void:
			set_fullscreen(fullscreen_btn.button_pressed)
		)

	if is_instance_valid(world_env_btn) and not world_env_btn.get_meta("_setting_state_bound", false):
		world_env_btn.set_meta("_setting_state_bound", true)
		world_env_btn.pressed.connect(func() -> void:
			set_world_environment(world_env_btn.button_pressed)
		)

	if is_instance_valid(shaken_receipt_btn) and not shaken_receipt_btn.get_meta("_setting_state_bound", false):
		shaken_receipt_btn.set_meta("_setting_state_bound", true)
		shaken_receipt_btn.pressed.connect(func() -> void:
			toggle_shaken_receipt_mode()
			shaken_receipt_btn.text = get_shaken_receipt_mode_label()
		)

	if is_instance_valid(invert_pour_btn) and not invert_pour_btn.get_meta("_setting_state_bound", false):
		invert_pour_btn.set_meta("_setting_state_bound", true)
		invert_pour_btn.pressed.connect(func() -> void:
			set_invert_pouring_angle(invert_pour_btn.button_pressed)
		)

	for action_name in control_buttons:
		var btn := control_buttons[action_name] as Button
		if is_instance_valid(btn) and not btn.get_meta("_setting_state_bound", false):
			btn.set_meta("_setting_state_bound", true)
			var action_str := str(action_name)
			btn.pressed.connect(func() -> void:
				begin_rebind(action_str, control_buttons)
			)

	if is_instance_valid(control_reset_btn) and not control_reset_btn.get_meta("_setting_state_bound", false):
		control_reset_btn.set_meta("_setting_state_bound", true)
		control_reset_btn.pressed.connect(func() -> void:
			reset_controls_to_ui(control_buttons, invert_pour_btn)
		)

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
		if not (loaded_data is Dictionary):
			apply_world_environment()
			apply_audio_settings()
			return
		for main_key in setting_dic:
			if not loaded_data.has(main_key):
				loaded_data[main_key] = DEFAULT_SETTING[main_key].duplicate(true)
			for default_key in DEFAULT_SETTING[main_key]:
				if not loaded_data[main_key].has(default_key):
					loaded_data[main_key][default_key] = DEFAULT_SETTING[main_key][default_key]
			for sub_key in loaded_data[main_key]:
				var file_key = loaded_data[main_key][sub_key]
				if DEFAULT_SETTING.get(main_key, {}).get(sub_key) is bool:
					setting_dic[main_key][sub_key] = bool(file_key)
				elif(file_key):
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
		if setting_dic.has("Video"):
			setting_dic["Video"]["ShakenReceiptMode"] = get_shaken_receipt_mode()
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

func get_shaken_receipt_mode() -> String:
	var raw := str(setting_dic.get("Video", {}).get("ShakenReceiptMode", SHAKEN_MODE_SPLIT)).to_lower().strip_edges()
	if raw == SHAKEN_MODE_AVERAGED:
		return SHAKEN_MODE_AVERAGED
	return SHAKEN_MODE_SPLIT

func set_shaken_receipt_mode(mode: String) -> void:
	var clean := SHAKEN_MODE_AVERAGED if mode.to_lower().strip_edges() == SHAKEN_MODE_AVERAGED else SHAKEN_MODE_SPLIT
	if not setting_dic.has("Video"):
		setting_dic["Video"] = {}
	var changed: bool = str(setting_dic["Video"].get("ShakenReceiptMode", "")) != clean
	setting_dic["Video"]["ShakenReceiptMode"] = clean
	if changed:
		shaken_receipt_mode_changed.emit(clean)

func toggle_shaken_receipt_mode() -> String:
	var next_mode := SHAKEN_MODE_AVERAGED if get_shaken_receipt_mode() == SHAKEN_MODE_SPLIT else SHAKEN_MODE_SPLIT
	set_shaken_receipt_mode(next_mode)
	return next_mode

func get_shaken_receipt_mode_label(mode: String = "") -> String:
	var target_mode := get_shaken_receipt_mode() if mode == "" else mode.to_lower().strip_edges()
	if target_mode == SHAKEN_MODE_AVERAGED:
		return "Shaken Receipt: Averaged Color"
	return "Shaken Receipt: Vertical Split"

func set_invert_pouring_angle(enabled: bool) -> void:
	setting_dic["Control"]["InvertPouringAngle"] = enabled

func is_invert_pouring_angle() -> bool:
	return bool(setting_dic["Control"].get("InvertPouringAngle", false))

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
	control_buttons: Dictionary,
	invert_pour_btn: BaseButton = null,
	shaken_receipt_btn: BaseButton = null
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

	if is_instance_valid(shaken_receipt_btn):
		shaken_receipt_btn.text = get_shaken_receipt_mode_label()

	for action_name in control_buttons:
		var btn := control_buttons[action_name] as Button
		if is_instance_valid(btn):
			btn.text = _key_to_string(str(action_name))

	var invert_enabled: bool = is_invert_pouring_angle()
	if is_instance_valid(invert_pour_btn):
		invert_pour_btn.button_pressed = invert_enabled

func handle_rebind_input(event: InputEvent, action_name: String, target_button: Button) -> bool:
	if not (event is InputEventKey and event.pressed):
		return true
	if event.physical_keycode == KEY_ESCAPE:
		if is_instance_valid(target_button):
			target_button.text = _key_to_string(action_name)
		get_viewport().set_input_as_handled()
		return false
	rebind_action(action_name, event)
	if is_instance_valid(target_button):
		target_button.text = event.as_text()
	return false

func reset_controls_to_ui(control_buttons: Dictionary, invert_pour_btn: BaseButton = null) -> void:
	waiting_keybind = false
	_reset_to_default_controls()
	for action_name in control_buttons:
		var btn := control_buttons[action_name] as Button
		if is_instance_valid(btn):
			btn.text = str(DEFAULT_SETTING["Control"].get(str(action_name), _key_to_string(str(action_name))))
	var invert_enabled: bool = is_invert_pouring_angle()
	if is_instance_valid(invert_pour_btn):
		invert_pour_btn.button_pressed = invert_enabled