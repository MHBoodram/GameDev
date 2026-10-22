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
		"W" : "W in chat"
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
		"W" : "W in chat"
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
	if file:
		var loaded_data = file.get_var()
		file.close()
		for main_key in setting_dic:
			var main_key_temp = loaded_data[main_key]
			if(!main_key_temp):
				loaded_data[main_key] = DEFAULT_SETTING[main_key]
			for sub_key in loaded_data[main_key]:
				var file_key = loaded_data[main_key][sub_key]
				if(file_key):
					setting_dic[main_key][sub_key] = file_key
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
		
