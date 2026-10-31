extends Node
const SAVE_PATH = "user://setting_state.dat"
const DEFAULT_SETTING = {
	"Video" :
		{
		"FullScreen" : false,
		"Resolution" : false
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
		"Resolution" : false
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
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	print(SAVE_PATH)
	if file:
		var loaded_data = file.get_var()
		file.close()
		for main_key in setting_dic:
			if not loaded_data.has(main_key):
				loaded_data[main_key] = DEFAULT_SETTING[main_key].duplicate(true)
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
		#print("Setting_dic: " + str(setting_dic))
		#print("loaded_data: " + str(loaded_data))

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
