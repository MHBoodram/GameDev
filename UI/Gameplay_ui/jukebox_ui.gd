extends Control

@onready var toggle_button: Button = %JukeboxToggleButton
@onready var panel: PanelContainer = %JukeboxPanel
@onready var close_button: Button = %CloseButton
@onready var easy_button: Button = %EasyListeningButton
@onready var upbeat_button: Button = %UpbeatButton
@onready var status_label: Label = %StatusLabel

var _showing_live_status: bool = false

func _ready() -> void:
	panel.hide()
	toggle_button.pressed.connect(_toggle_panel)
	close_button.pressed.connect(_close_panel)
	easy_button.pressed.connect(_on_easy_pressed)
	upbeat_button.pressed.connect(_on_upbeat_pressed)

	CooldownManager.bind_button(easy_button, JukeboxManager.COOLDOWN_ID, {
		"disable_while_cooling": true,
		"show_progress_bar": true,
		"show_countdown": true,
	})
	CooldownManager.bind_button(upbeat_button, JukeboxManager.COOLDOWN_ID, {
		"disable_while_cooling": true,
		"show_progress_bar": true,
		"show_countdown": true,
	})
	CooldownManager.bind_button(toggle_button, JukeboxManager.COOLDOWN_ID, {
		"disable_while_cooling": false,
		"show_progress_bar": true,
		"show_countdown": true,
	})

func _process(_delta: float) -> void:
	if not panel.visible:
		return
	var jm := GameState.jukebox_manager
	if is_instance_valid(jm) and jm.effect_time_left > 0.0:
		status_label.text = "Playing... Effects last %ds" % ceili(jm.effect_time_left)
		_showing_live_status = true
	elif CooldownManager.is_on_cooldown(JukeboxManager.COOLDOWN_ID):
		status_label.text = "Cooldown: %ds" % ceili(CooldownManager.get_time_left(JukeboxManager.COOLDOWN_ID))
		_showing_live_status = true
	elif _showing_live_status:
		status_label.text = "Choose a track."
		_showing_live_status = false

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
			_showing_live_status = true
			status_label.text = "Playing... Effects last 30 seconds"
		"cooldown":
			_showing_live_status = true
			status_label.text = "Jukebox currently not available"
		"insufficient_funds":
			_showing_live_status = false
			status_label.text = "You need at least 30 {coin} to use the jukebox"