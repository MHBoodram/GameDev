extends CanvasLayer
var mouse_side : bool = false
var mouse_entered: bool = false
@export var camera_movement_rotation = 10
@export var player : Node3D
var current_position : int = 3
var match_position_counter : Dictionary ={1 : 5.8,2:2.8,3: -0.2}
var camera : Camera3D
var down : bool = false
var up_down_checks : bool = false

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	$FishEye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.gameplay_ui = self
	#print(camera.global_position.y)

func bendover() -> void:
	if(down):
		$Left_Button.disabled = false
		$Right_Button.disabled = false
		$Up_button.disabled = false
		_look_forward()
	else:
		$Left_Button.disabled = true
		$Right_Button.disabled = true
		$Up_button.disabled = false
		_look_behind()
	down = !down

func _look_behind() -> void:
	var marker_counter = get_tree().get_nodes_in_group("counter_mark")
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var marker_position = marker_counter[0].global_position
	marker_position.y = camera.global_position.y
	tween.tween_property(camera,"rotation_degrees:y",180,0.5)
	tween.tween_property(camera,"global_position",marker_position,0.5)
	tween.tween_property(camera,"rotation_degrees:x",-55.3,0.15 )
	
func _look_forward() -> void:
	up_down_checks = false

	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var new_position = Vector3(match_position_counter[current_position],camera.global_position.y,1.5)
	tween.tween_property(camera,"rotation_degrees:y",0,0.5)
	tween.tween_property(camera,"global_position",new_position,0.5)
	tween.tween_property(camera,"rotation_degrees:x", -16.3,0.15)

func moving_around(right : bool) -> void:
	if(right):
		if(current_position > 1):
			current_position -= 1
			var new_position = match_position_counter[current_position]
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(player,"position:x",new_position,0.15)
			
	else:
		if(current_position < 3):
			current_position += 1
			var new_position = match_position_counter[current_position]
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(player,"position:x",new_position,0.15)
#what anti anaing: sample rate under


func mouse_screen(looking: String) -> void:
	if(!down):
		GameState.player._update_hand("interact")
		match looking:
			"left":
				#print(camera_movement_rotation)
				var new_position = camera.rotation_degrees.y + camera_movement_rotation
				new_position = clamp(new_position, -camera_movement_rotation, camera_movement_rotation)
				if(new_position > -camera_movement_rotation):
					var tween = get_tree().create_tween()
					tween.set_trans(Tween.TRANS_SINE)
					tween.set_ease(Tween.EASE_OUT)
					tween.tween_property(camera,"rotation_degrees:y", new_position,0.15)
				else:
					camera.rotation_degrees.y = -camera_movement_rotation
				return;
				
			"right":
				var new_position = camera.rotation_degrees.y - camera_movement_rotation
				new_position = clamp(new_position, -camera_movement_rotation, camera_movement_rotation)
				if(new_position < camera_movement_rotation):
					var tween = get_tree().create_tween()
					tween.set_trans(Tween.TRANS_SINE)
					tween.set_ease(Tween.EASE_OUT)
					tween.tween_property(camera,"rotation_degrees:y", new_position,0.15)
				else:
					camera.rotation_degrees.y = camera_movement_rotation
				return
			"down":
				GameState.player._update_hand("interact")

			
			_:
				GameState.player._update_hand("idle")
				var tween = get_tree().create_tween()
				tween.set_trans(Tween.TRANS_SINE)
				tween.set_ease(Tween.EASE_OUT)
				tween.tween_property(camera,"rotation_degrees:y", 0,0.15)
				#tween.tween_property(camera,"rotation_degrees:x", -55.3,0.15)
				return;
	else:
		GameState.player._update_hand("interact")
		match looking:
			"up":
				up_down_checks = true
				while(up_down_checks):
					var new_rotation = camera.rotation_degrees.x + 5
					new_rotation = clamp(new_rotation, -camera_movement_rotation -45, camera_movement_rotation)
					var tween = get_tree().create_tween()
					tween.set_trans(Tween.TRANS_SINE)
					tween.set_ease(Tween.EASE_OUT)
					tween.tween_property(camera,"rotation_degrees:x", new_rotation,0.15)
					await get_tree().process_frame
				up_down_checks = false
				return;
			"down":
				up_down_checks = true
				while(up_down_checks):
					#print("something Check")
					var new_position = camera.rotation_degrees.x - 5
					new_position = clamp(new_position, -camera_movement_rotation - 45, camera_movement_rotation + 16.3)	
					var tween = get_tree().create_tween()
					tween.set_trans(Tween.TRANS_SINE)
					tween.set_ease(Tween.EASE_OUT)
					tween.tween_property(camera,"rotation_degrees:x", new_position,0.15)
					await get_tree().process_frame
				up_down_checks = false
				return;
			_:
				GameState.player._update_hand("idle")
				up_down_checks = false

			#tween.tween_property(camera,"rotation_degrees:x", -16.3,0.15)
			#else:
			#tween.tween_property(camera,"rotation_degrees:x",-55.3,0.15 )
		

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

func _out_down_minigame() -> void:
	$Bottom_button.disabled = false
	$Up_button.disabled = false
	$Bottom_button.mouse_filter = Control.MOUSE_FILTER_STOP
	$Up_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _in_down_minigame() -> void:
	$Bottom_button.disabled = true
	$Up_button.disabled = true
	$Bottom_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Up_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_bottom_button_mouse_entered() -> void:
	GameState.player._update_hand("interact")
	mouse_screen("down")

func _on_up_button_mouse_entered() -> void:
	mouse_screen("up")

func _night_title_popup()-> void:
	var hey_peter = randi_range(1,500)
	print(hey_peter)
	if(hey_peter == 67):
		$ColorRect3/Night/HeyPeter.show()
	else:
		$ColorRect3/Night/HeyPeter.hide()
	$ColorRect3/Night.text = "Night 1"
	$AnimationPlayer.play("Night_Animation")

func _night_title_finish()->void:
	var hey_peter = randi_range(1,500)
	print(hey_peter)
	if(hey_peter == 67):
		$ColorRect3/Night/HeyPeter.show()
	else:
		$ColorRect3/Night/HeyPeter.hide()
	$ColorRect3/Night.text = "Finish"
	$AnimationPlayer.play("Night_Animation")


func _change_money(new_value: float) -> void:
	var old_value = float($"Right Container/Money/Label".text)
	if(new_value < old_value):
		$"Right Container/Money/CPUParticles2D".color = Color(1.0, 0.0, 0.0, 1.0)
	else:
		$"Right Container/Money/CPUParticles2D".color = Color(1.0, 1.0, 1.0, 1.0)
	$"Right Container/Money/CPUParticles2D".emitting = true
	$"Right Container/Money/Label".text = str(new_value)
	await get_tree().create_timer(0.5).timeout
	$"Right Container/Money/CPUParticles2D".emitting = false

func _change_time(new_value:float) -> void:
	$"Left Container/Timer".value = new_value
	pass

#OLD CODE
#func _on_up_button_pressed() -> void:
	#bendover()


#func _camera_down_tween() -> void:
	#var tween = get_tree().create_tween().set_parallel(true)
	#tween.set_trans(Tween.TRANS_SINE)
	#tween.set_ease(Tween.EASE_OUT)
	#tween.tween_property(camera,"position:y",2.7,0.15)
	#tween.tween_property(camera,"position:z",1.5,0.15)
	#tween.tween_property(camera,"rotation_degrees:x",-16.3,0.15)
#
#func _camera_up_tween() -> void:
	#var tween = get_tree().create_tween().set_parallel(true)
	#tween.set_trans(Tween.TRANS_SINE)
	#tween.set_ease(Tween.EASE_OUT)
	#tween.tween_property(camera,"position:y",1.9,0.15)
	#tween.tween_property(camera,"position:z",1.3,0.15)
	#tween.tween_property(camera,"rotation_degrees:x",-55.3,0.15)
