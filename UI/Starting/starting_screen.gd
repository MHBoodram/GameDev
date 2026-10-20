extends Node3D
@export var sub_viewport: SubViewport
@onready var start_menu = get_node("Menu2/Menu3/Viewport/SubViewport/StartMenu")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	await SettingState._loading_setting()
	$Node2D/Setting._setting_dictionary_start()
	$AnimationPlayer.speed_scale = 0.4
	$AnimationPlayer.play("movement")
	$Menu_animation.play("menu_close")

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	$Node2D/Setting/Hand.global_position = get_viewport().get_mouse_position()

func _moving_3d_to_2d():
	$AnimationPlayer.play("move_setting")
	$Node2D/Setting._moving(false)
	await $AnimationPlayer.animation_finished
	#$Node2D/Camera2D.make_current()

func _update_hand(change: String) -> void:
	match change:
		"interact":
			if(!$Node2D/Setting/Hand/AnimationPlayer.current_animation == "interact"):
				$Node2D/Setting/Hand/AnimationPlayer.play("interact")
			return
		"holding":
			if(!$Node2D/Setting/Hand/AnimationPlayer.current_animation == "hold"):
				$Node2D/Setting/Hand/AnimationPlayer.play("hold")
			return
		_:
			if(!$Node2D/Setting/Hand/AnimationPlayer.current_animation == "idle"):
				$Node2D/Setting/Hand/AnimationPlayer.play("idle")
			return

func _moving_2d_to_3d():
	$AnimationPlayer.play_backwards("move_setting")
	$Node2D/Setting._moving(true)
	await $AnimationPlayer.animation_finished
	

@warning_ignore("unused_parameter")
func _on_area_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		$Menu2/Menu3/Viewport/SubViewport/StartMenu._on_play_pressed()

func _on_play_mouse_entered() -> void:
	_update_hand("interact")
	start_menu._change_hover("Play")

func _on_setting_mouse_entered() -> void:
	_update_hand("interact")
	start_menu._change_hover("Setting")

func _on_play_mouse_exited() -> void:
	_update_hand("idle")
	
	start_menu._remove_hover("Play")

func _on_setting_mouse_exited() -> void:
	_update_hand("idle")
	
	start_menu._remove_hover("Setting")


@warning_ignore("unused_parameter")
func _on_setting_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_moving_3d_to_2d()

@warning_ignore("unused_parameter")
func _on_quit_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		start_menu._on_quit_pressed()

func _on_quit_mouse_entered() -> void:
	_update_hand("interact")
	start_menu._change_hover("Quit")

func _on_quit_mouse_exited() -> void:
	_update_hand("idle")
	start_menu._remove_hover("Quit")
