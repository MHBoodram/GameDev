extends CanvasLayer
var mouse_side : bool = false
var mouse_entered: bool = false
@export var camera_movement_rotation = 10
@export var player : Node3D
var cur_position : int = 1
var current_position : int = 3
var camera : Camera3D
var down : bool = false
func _ready() -> void:
	camera = get_viewport().get_camera_3d()

func bendover() -> void:
	
	if(down):
		$Left_Button.disabled = false
		$Right_Button.disabled = false
		$Up_button.disabled = true
		_camera_down_tween()
	else:
		$Left_Button.disabled = true
		$Right_Button.disabled = true
		$Up_button.disabled = false
		_camera_up_tween()
	down = !down

func _camera_down_tween() -> void:
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(camera,"position:y",2.7,0.15)
	tween.tween_property(camera,"position:z",1.5,0.15)
	tween.tween_property(camera,"rotation_degrees:x",-16.3,0.15)

func _camera_up_tween() -> void:
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(camera,"position:y",1.9,0.15)
	tween.tween_property(camera,"position:z",1.3,0.15)
	tween.tween_property(camera,"rotation_degrees:x",-55.3,0.15)

func moving_around(right : bool) -> void:
	if(right):
		if(current_position > 1):
			var new_position = player.position.x + 3
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(player,"position:x",new_position,0.15)
			current_position -= 1
	else:
		if(current_position < 3):
			var new_position = player.position.x - 3
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(player,"position:x",new_position,0.15)
			current_position += 1
#what anti anaing: sample rate under


func mouse_screen(looking: String) -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	match looking:
		"left":
			var new_position = camera.rotation_degrees.y + camera_movement_rotation
			new_position = clamp(new_position, -camera_movement_rotation, camera_movement_rotation)
			if(new_position > -camera_movement_rotation):
				tween.tween_property(camera,"rotation_degrees:y", new_position,0.15)
			else:
				camera.rotation_degrees.y = -camera_movement_rotation
			return;
			
		"right":
			var new_position = camera.rotation_degrees.y - camera_movement_rotation
			new_position = clamp(new_position, -camera_movement_rotation, camera_movement_rotation)
			if(new_position < camera_movement_rotation):
				tween.tween_property(camera,"rotation_degrees:y", new_position,0.15)
			else:
				camera.rotation_degrees.y = camera_movement_rotation
			return
		"down":
			if(!down):
				var new_position = camera.rotation_degrees.x - camera_movement_rotation
				new_position = clamp(new_position, -camera_movement_rotation - 16.3, camera_movement_rotation + 16.3)	
				tween.tween_property(camera,"rotation_degrees:x", new_position,0.15)
			return;
		"up":
			return;
		_:
			tween.tween_property(camera,"rotation_degrees:y", 0,0.15)
			if(!down):
				tween.tween_property(camera,"rotation_degrees:x", -16.3,0.15)
			return;

func _on_left_button_mouse_entered() -> void:
	mouse_side = true
	mouse_screen("left")

func _on_right_button_mouse_entered() -> void:
	mouse_side = false
	mouse_screen("right")

func _on_mouse_exited() -> void:
	mouse_screen("none")

func _on_left_button_pressed() -> void:
	moving_around(false)


func _on_right_button_pressed() -> void:
	moving_around(true)


func _on_bottom_button_pressed() -> void:
	bendover()

func _on_up_button_pressed() -> void:
	bendover()


func _on_bottom_button_mouse_entered() -> void:
	mouse_screen("down")
