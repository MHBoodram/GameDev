extends Node
signal shaken_receipt_mode_changed(mode: String)

const SAVE_PATH = "user://setting_state.dat"
const SHAKEN_MODE_SPLIT = "split"
const SHAKEN_MODE_AVERAGED = "averaged"

const CONTROL_KEYBIND_DEFS: Array[Dictionary] = [
	{"action": "Up", "label": "Up"},
	{"action": "Down", "label": "Down"},
	{"action": "Left", "label": "Left"},
	{"action": "Right", "label": "Right"},
	{"action": "PourUp", "label": "Pour Up"},
	{"action": "PourDown", "label": "Pour Down"},
	{"action": "Hand", "label": "Hand"},
	{"action": "Knife", "label": "Knife"},
	{"action": "Mag", "label": "Mag"},
	{"action": "Fishing_Rod", "label": "Fishing Rod"},
	{"action": "InteractCustomer", "label": "Interact Customer"},
	{"action": "ContinueDialog", "label": "Continue Dialog"},
	{"action": "FastForward", "label": "Fast Forward"},
]

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
		"PourUp" : "Up",
		"PourDown" : "Down",
		"Hand" : "1",
		"Knife" : "2",
		"Mag" : "3",
		"Fishing_Rod" : "4",
		"InteractCustomer" : "Space",
		"ContinueDialog" : "Space",
		"FastForward" : "F",
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

static var _reset_arrow_icon: Texture2D = null
static var _delete_x_icon: Texture2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loading_setting()
	apply_all_controls_to_input_map()

func _input(event: InputEvent) -> void:
	if not waiting_keybind:
		return
	var btn := _active_control_buttons.get(action_to_rebind) as Button
	waiting_keybind = handle_rebind_input(event, action_to_rebind, btn)

func begin_rebind(action_name: String, control_buttons: Dictionary = {}) -> void:
	if not control_buttons.is_empty():
		_active_control_buttons = control_buttons
	if waiting_keybind and action_to_rebind != action_name:
		var prev_btn := _active_control_buttons.get(action_to_rebind) as Button
		if is_instance_valid(prev_btn):
			prev_btn.text = _key_to_string(action_to_rebind)
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

static func get_reset_arrow_icon() -> Texture2D:
	if _reset_arrow_icon != null:
		return _reset_arrow_icon
	if ResourceLoader.exists("res://Assets/UI/keybind_reset.png"): # NEED ICON
		_reset_arrow_icon = load("res://Assets/UI/keybind_reset.png") as Texture2D
		if _reset_arrow_icon != null:
			return _reset_arrow_icon
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(11.5, 11.5)
	var radius := 7.2
	var half_thick := 1.45
	var col := Color(0.1, 0.1, 0.1, 1.0)
	var start_ang := deg_to_rad(-35.0)
	var sweep_ang := deg_to_rad(305.0)

	for y in size:
		for x in size:
			var p := Vector2(float(x), float(y)) - center
			var r := p.length()
			if absf(r - radius) <= half_thick:
				var ang := fposmod(atan2(p.y, p.x) - start_ang, TAU)
				if ang <= sweep_ang:
					img.set_pixel(x, y, col)

	var tip_ang := start_ang + sweep_ang
	var tip_pos := center + Vector2.from_angle(tip_ang) * radius
	var tangent := Vector2(-sin(tip_ang), cos(tip_ang)).normalized()
	var radial := Vector2(cos(tip_ang), sin(tip_ang)).normalized()
	var a := tip_pos + tangent * 3.8
	var b := tip_pos - tangent * 1.4 + radial * 3.4
	var c := tip_pos - tangent * 1.4 - radial * 3.4
	_raster_triangle(img, a, b, c, col)

	_reset_arrow_icon = ImageTexture.create_from_image(img)
	return _reset_arrow_icon

static func get_delete_x_icon() -> Texture2D:
	if _delete_x_icon != null:
		return _delete_x_icon
	if ResourceLoader.exists("res://Assets/UI/keybind_delete.png"): # NEED ICON
		_delete_x_icon = load("res://Assets/UI/keybind_delete.png") as Texture2D
		if _delete_x_icon != null:
			return _delete_x_icon
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(0.75, 0.12, 0.12, 1.0)
	var p0 := Vector2(6.0, 6.0)
	var p1 := Vector2(17.0, 17.0)
	var p2 := Vector2(17.0, 6.0)
	var p3 := Vector2(6.0, 17.0)
	for y in size:
		for x in size:
			var pt := Vector2(float(x), float(y))
			var d1 := Geometry2D.get_closest_point_to_segment(pt, p0, p1).distance_to(pt)
			var d2 := Geometry2D.get_closest_point_to_segment(pt, p2, p3).distance_to(pt)
			if d1 <= 1.55 or d2 <= 1.55:
				img.set_pixel(x, y, col)

	_delete_x_icon = ImageTexture.create_from_image(img)
	return _delete_x_icon

static func _raster_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var min_x := maxi(0, int(floorf(minf(a.x, minf(b.x, c.x)))) - 1)
	var max_x := mini(img.get_width() - 1, int(ceilf(maxf(a.x, maxf(b.x, c.x)))) + 1)
	var min_y := maxi(0, int(floorf(minf(a.y, minf(b.y, c.y)))) - 1)
	var max_y := mini(img.get_height() - 1, int(ceilf(maxf(a.y, maxf(b.y, c.y)))) + 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			if Geometry2D.point_is_inside_triangle(p, a, b, c):
				img.set_pixel(x, y, col)

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
	var hover_enter_cb: Callable = config.get("on_hover_enter", Callable())
	var hover_exit_cb: Callable = config.get("on_hover_exit", Callable())
	var control_buttons: Dictionary = config.get("control_buttons", {})
	var reset_buttons: Dictionary = config.get("reset_buttons", {})
	var delete_buttons: Dictionary = config.get("delete_buttons", {})

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
				if has_node("/root/UIAudio"):
					get_node("/root/UIAudio").call("play_click")
				begin_rebind(action_str, control_buttons)
			)
			if hover_enter_cb.is_valid() and hover_exit_cb.is_valid():
				btn.mouse_entered.connect(hover_enter_cb)
				btn.mouse_exited.connect(hover_exit_cb)

	for action_name in reset_buttons:
		var rbtn := reset_buttons[action_name] as Button
		if is_instance_valid(rbtn):
			if rbtn.icon == null:
				rbtn.icon = get_reset_arrow_icon()
			if not rbtn.get_meta("_setting_state_bound", false):
				rbtn.set_meta("_setting_state_bound", true)
				var action_str := str(action_name)
				rbtn.pressed.connect(func() -> void:
					if has_node("/root/UIAudio"):
						get_node("/root/UIAudio").call("play_click")
					reset_single_keybind(action_str, control_buttons.get(action_str) as Button)
				)
				if hover_enter_cb.is_valid() and hover_exit_cb.is_valid():
					rbtn.mouse_entered.connect(hover_enter_cb)
					rbtn.mouse_exited.connect(hover_exit_cb)

	for action_name in delete_buttons:
		var dbtn := delete_buttons[action_name] as Button
		if is_instance_valid(dbtn):
			if dbtn.icon == null:
				dbtn.icon = get_delete_x_icon()
			if not dbtn.get_meta("_setting_state_bound", false):
				dbtn.set_meta("_setting_state_bound", true)
				var action_str := str(action_name)
				dbtn.pressed.connect(func() -> void:
					if has_node("/root/UIAudio"):
						get_node("/root/UIAudio").call("play_click")
					clear_keybind(action_str, control_buttons.get(action_str) as Button)
				)
				if hover_enter_cb.is_valid() and hover_exit_cb.is_valid():
					dbtn.mouse_entered.connect(hover_enter_cb)
					dbtn.mouse_exited.connect(hover_exit_cb)

	if is_instance_valid(control_reset_btn) and not control_reset_btn.get_meta("_setting_state_bound", false):
		control_reset_btn.set_meta("_setting_state_bound", true)
		if control_reset_btn is Button:
			(control_reset_btn as Button).text = "Reset All Keybinds"
		control_reset_btn.pressed.connect(func() -> void:
			if has_node("/root/UIAudio"):
				get_node("/root/UIAudio").call("play_click")
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
		apply_all_controls_to_input_map()
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	print(SAVE_PATH)
	if file:
		var loaded_data = file.get_var()
		file.close()
		if not (loaded_data is Dictionary):
			apply_world_environment()
			apply_audio_settings()
			apply_all_controls_to_input_map()
			return
		for main_key in setting_dic:
			if not loaded_data.has(main_key):
				loaded_data[main_key] = DEFAULT_SETTING[main_key].duplicate(true)
			for default_key in DEFAULT_SETTING[main_key]:
				if not loaded_data[main_key].has(default_key):
					loaded_data[main_key][default_key] = DEFAULT_SETTING[main_key][default_key]
			for sub_key in loaded_data[main_key]:
				if not DEFAULT_SETTING[main_key].has(sub_key):
					continue
				var file_key = loaded_data[main_key][sub_key]
				if DEFAULT_SETTING.get(main_key, {}).get(sub_key) is bool:
					setting_dic[main_key][sub_key] = bool(file_key)
				elif main_key == "Control" and file_key is String and (file_key == "" or file_key == "_"):
					setting_dic[main_key][sub_key] = ""
				elif(file_key):
					setting_dic[main_key][sub_key] = file_key
					print(main_key + " " + sub_key + ": " + str(file_key))
				else:
					match main_key:
						"Video":
							setting_dic[main_key][sub_key] = false
						"Control":
							setting_dic[main_key][sub_key] = ""
						"Audio":
							setting_dic[main_key][sub_key] = 0
		if setting_dic.has("Video"):
			setting_dic["Video"]["ShakenReceiptMode"] = get_shaken_receipt_mode()
		apply_world_environment()
		apply_audio_settings()
		apply_all_controls_to_input_map()

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

func _resolve_keycode(value: Variant) -> Key:
	if value is InputEventKey:
		return (value as InputEventKey).physical_keycode
	if value is int:
		return (value as int) as Key
	if value is float:
		return int(value) as Key
	var s := str(value).strip_edges()
	if s == "" or s == "_" or s.to_lower() == "none":
		return KEY_NONE
	return OS.find_keycode_from_string(s)

func apply_action_to_input_map(action_name: String) -> void:
	if DEFAULT_SETTING["Control"].get(action_name) is bool:
		return
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	var keycode := _resolve_keycode(setting_dic["Control"].get(action_name, ""))
	if keycode != KEY_NONE and keycode != 0:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action_name, ev)

func apply_all_controls_to_input_map() -> void:
	for key in setting_dic["Control"].keys():
		apply_action_to_input_map(str(key))

func _key_to_string(control: String) -> String:
	var value = SettingState.setting_dic["Control"].get(control, "")
	var temp: String
	if value is InputEventKey:
		temp = value.as_text_physical_keycode()
	elif value is int or value is float:
		var code := int(value)
		temp = OS.get_keycode_string(code) if code > 0 else "None"
	else:
		temp = str(value)
	if temp == "" or temp == "_":
		return "None"
	return temp

func to_physical_event(event: InputEventKey) -> InputEventKey:
	var new_event := InputEventKey.new()
	new_event.physical_keycode = event.physical_keycode
	return new_event

func rebind_action(action: String, new_key):
	var phys := to_physical_event(new_key)
	setting_dic["Control"][action] = phys.physical_keycode
	apply_action_to_input_map(action)
	if get_viewport():
		get_viewport().set_input_as_handled()

func clear_keybind(action: String, target_button: Button = null) -> void:
	if waiting_keybind and action_to_rebind == action:
		waiting_keybind = false
	setting_dic["Control"][action] = ""
	apply_action_to_input_map(action)
	var btn := target_button if is_instance_valid(target_button) else (_active_control_buttons.get(action) as Button)
	if is_instance_valid(btn):
		btn.text = _key_to_string(action)

func reset_single_keybind(action: String, target_button: Button = null) -> void:
	if waiting_keybind and action_to_rebind == action:
		waiting_keybind = false
	if DEFAULT_SETTING["Control"].has(action):
		setting_dic["Control"][action] = DEFAULT_SETTING["Control"][action]
	apply_action_to_input_map(action)
	var btn := target_button if is_instance_valid(target_button) else (_active_control_buttons.get(action) as Button)
	if is_instance_valid(btn):
		btn.text = _key_to_string(action)

func _reset_to_default_controls():
	for key in setting_dic["Control"].keys():
		if(DEFAULT_SETTING["Control"].has(key)):
			setting_dic["Control"][key] = DEFAULT_SETTING["Control"][key]
		else:
			setting_dic["Control"].erase(key)
	for default_key in DEFAULT_SETTING["Control"].keys():
		if not setting_dic["Control"].has(default_key):
			setting_dic["Control"][default_key] = DEFAULT_SETTING["Control"][default_key]
	apply_all_controls_to_input_map()

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
	if not (event is InputEventKey and event.pressed and not event.echo):
		return true
	if event.physical_keycode == KEY_ESCAPE:
		if is_instance_valid(target_button):
			target_button.text = _key_to_string(action_name)
			target_button.release_focus()
		if get_viewport():
			get_viewport().set_input_as_handled()
		return false
	rebind_action(action_name, event)
	if is_instance_valid(target_button):
		target_button.text = _key_to_string(action_name)
		target_button.release_focus()
	return false

func reset_controls_to_ui(control_buttons: Dictionary, invert_pour_btn: BaseButton = null) -> void:
	waiting_keybind = false
	_reset_to_default_controls()
	for action_name in control_buttons:
		var btn := control_buttons[action_name] as Button
		if is_instance_valid(btn):
			btn.text = _key_to_string(str(action_name))
	var invert_enabled: bool = is_invert_pouring_angle()
	if is_instance_valid(invert_pour_btn):
		invert_pour_btn.button_pressed = invert_enabled