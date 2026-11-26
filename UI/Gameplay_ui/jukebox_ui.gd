extends Control

@onready var toggle_button: Button = %JukeboxToggleButton
@onready var panel: PanelContainer = %JukeboxPanel
@onready var close_button: Button = %CloseButton
@onready var easy_button: Button = %EasyListeningButton
@onready var upbeat_button: Button = %UpbeatButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	panel.hide()
	toggle_button.pressed.connect(_toggle_panel)
	close_button.pressed.connect(_close_panel)
	easy_button.pressed.connect(_on_easy_pressed)
	upbeat_button.pressed.connect(_on_upbeat_pressed)

func _toggle_panel() -> void:
	panel.visible = not panel.visible

func _close_panel() -> void:
	panel.hide()

func _on_easy_pressed() -> void:
	if not is_instance_valid(GameState.jukebox_manager):
		status_label.text = "Jukebox Unavailable"
		return
	_show_result(GameState.jukebox_manager.activate_easy_listening())

func _on_upbeat_pressed() -> void:
	if not is_instance_valid(GameState.jukebox_manager):
		status_label.text = "Jukebox Unavailable"
		return
	_show_result(GameState.jukebox_manager.activate_upbeat())

func _show_result(result: String) -> void:
	match result:
		"activated":
			status_label.text = "Playing... Effects last 30 seconds"
		"cooldown":
			status_label.text = "Jukebox currently not available"
		"insufficient_funds":
			status_label.text = "You need at least 30 {coin} to use the jukebox"