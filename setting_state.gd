extends Node
const SAVE_PATH = "user://setting_state.dat"

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
		setting_dic["Video"]["FullScreen"] = loaded_data["Video"]["FullScreen"]
		setting_dic["Audio"]["Master_value"] = loaded_data["Audio"]["Master_value"]
		setting_dic["Audio"]["UI_value"] = loaded_data["Audio"]["UI_value"]
		print("Setting_dic: " + str(setting_dic))
		print("loaded_data: " + str(loaded_data))
		
