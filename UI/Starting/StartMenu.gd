extends Control

const GAME_SCENE := "res://Main3D.tscn"

@onready var play_button: Button = $Paper/CenterContainer/VBox/PlayButton
@onready var setting_button: Button = $Paper/CenterContainer/VBox/SettingButton
@onready var quit_button: Button = $Paper/CenterContainer/VBox/QuitButton

func _ready() -> void:
	#$CenterContainer/VBox/Button.grab_focus()
	MusicPlayer.play_menu() # new menu song should be labeled "Piano Solo 1"
	get_tree().paused = false #in case we come here from the pause menu
	_apply_ink_paper_theme()
	UIAudio.hook_buttons(self)
	#SFXAudio.hook(self)
	#SFXAudio.play_entranto()
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	#play_button.grab_focus()
	if OS.has_feature("web"): #this is lowk only if this is on the web, shoudln't be much of an issue with us
		quit_button.hide()

func _apply_ink_paper_theme() -> void:
	theme = InkTheme.get_theme()
	InkTheme.apply_panel_variant($Paper, "cream", false, Vector4(12.0, 12.0, 12.0, 12.0))
	InkTheme.apply_button_variant(play_button, "primary", false, 40)
	InkTheme.apply_button_variant(setting_button, "paper", false, 40)
	InkTheme.apply_button_variant(quit_button, "muted", false, 40)

func _on_play_pressed() -> void:
	MusicPlayer.play_game()
	GameState.reset_game()
	Transition._changing_scene(GAME_SCENE)

func _change_hover(n_name: String = "Setting") -> void:
	var getting_node = get_node("Paper/CenterContainer/VBox/" + n_name + "Button")
	if(!getting_node):
		push_warning("Can't find node: " + n_name)
		return
	if getting_node is BaseButton:
		InkTheme.set_button_forced_hover(getting_node as BaseButton, true)
	getting_node.modulate = Color(1.0, 0.94, 0.65, 1.0)

func _remove_hover(n_name: String = "Setting") -> void:
	var getting_node = get_node("Paper/CenterContainer/VBox/" + n_name + "Button")
	if(!getting_node):
		push_warning("Can't find node: " + n_name)
		return
	if getting_node is BaseButton:
		InkTheme.set_button_forced_hover(getting_node as BaseButton, false)
	getting_node.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _setting() -> void:
	pass

func _on_quit_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()