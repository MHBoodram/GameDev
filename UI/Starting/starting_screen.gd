extends Node3D

func _ready() -> void:
	$AnimationPlayer.speed_scale = 0.4
	$AnimationPlayer.play("movement")
	$Menu_animation.play("menu_close")

@export var sub_viewport: SubViewport


func _on_area_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		$Menu2/Menu3/Viewport/SubViewport/StartMenu._on_play_pressed()
