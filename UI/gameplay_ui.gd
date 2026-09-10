extends CanvasLayer
var mouse_side : bool = false
var mouse_entered: bool = false
@export var camera_movement_rotation = 10
var cur_position : int = 1
#var edge_margin : float = 30
var current_position : int = 3
var camera : Camera3D

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

func moving_around(right : bool) -> void:
	if(right):
		if(current_position > 1):
			var new_position = camera.position.x + 3
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(camera,"position:x",new_position,0.15)
			current_position -= 1
	else:
		if(current_position < 3):
			var new_position = camera.position.x - 3
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(camera,"position:x",new_position,0.15)
			current_position += 1
#what anti anaing: sample rate under
func mouse_screen() -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)	
	while(mouse_entered):
		if(!mouse_side):
			var new_position = camera.rotation_degrees.y - camera_movement_rotation
			new_position = clamp(new_position, -camera_movement_rotation, camera_movement_rotation)
			if(new_position < camera_movement_rotation):
				tween.tween_property(camera,"rotation_degrees:y", new_position,0.15)
			else:
				camera.rotation_degrees.y = camera_movement_rotation
			return
		else:
			var new_position = camera.rotation_degrees.y + camera_movement_rotation
			new_position = clamp(new_position, -camera_movement_rotation, camera_movement_rotation)
			if(new_position > -camera_movement_rotation):
				tween.tween_property(camera,"rotation_degrees:y", new_position,0.15)
			else:
				camera.rotation_degrees.y = -camera_movement_rotation
			return;
	
	tween.tween_property(camera,"rotation_degrees:y", 0,0.15)

func _on_left_button_mouse_entered() -> void:
	mouse_side = true
	mouse_entered = true
	mouse_screen()

func _on_right_button_mouse_entered() -> void:
	mouse_side = false
	mouse_entered = true
	mouse_screen()

func _on_mouse_exited() -> void:
	mouse_entered = false
	mouse_screen()

func _on_left_button_pressed() -> void:
	moving_around(false)


func _on_right_button_pressed() -> void:
	moving_around(true)
