extends Glasses
class_name Drinks
var pouring_into : Node3D
@export var type_drink : String = "beer"
var original_position : Marker3D

#func ready() -> void:
	#$Outside.material_overlay = $Outside.material_override.duplicate(true)
	#$Outside.material_override = $Outside.material_overlay
	#var material_overlay_x = $Outside.material_override
	#var gradient_tex = material_overlay_x.get_shader_parameter("gradient_texture")
	#gradient_tex.fill_to.x = 1

func setup(og_position: Marker3D,Counter: Node3D) -> void:
	original_position = og_position
	counter_origin = Counter
	global_position = og_position.global_position
	rotation_degrees = Vector3.ZERO
	
func _process(_delta: float) -> void:
	if is_balls_dragging:
		var mouse_pos = get_viewport().get_mouse_position()
		var new_projection = camera.project_position(mouse_pos, drag_z_depth)
		new_projection.x = clamp(new_projection.x, -1.2 + counter_origin.global_position.x,1.4+ counter_origin.global_position.x)
		new_projection.z = clamp(new_projection.z, counter_origin.global_position.z - 0.4,counter_origin.global_position.z + 0.4)
		if(new_projection.z < 0.28):
			new_projection.y = base_y_position + 0.2
		else:
			new_projection.y = base_y_position
		global_position = new_projection
		if(Input.is_action_just_released("Left_click")):
			is_balls_dragging = false
			_return_original()
		else:
			look_at(camera.global_position)

@warning_ignore("shadowed_variable", "unused_parameter", "shadowed_variable_base_class")
func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if !in_game:
			if event.pressed:
				is_balls_dragging = true
				var to_object = global_position - camera.global_position
				var forward = -camera.global_transform.basis.z
				drag_z_depth = to_object.dot(forward)
			else:
				print("returning original")
				is_balls_dragging = false
				if(pouring_into):
					_pouring_game()
				else:
					_return_original()
		else:
			if event.pressed:
				rotation_degrees.z = 80
				if(pouring_into):
					while(Input.get_action_strength("Left_click")):
						pouring_into._pouring(type_drink, 0.25)
						await get_tree().create_timer(0.1).timeout
			else:
				
				#for glasses in glass_array:
					#glasses.get_parent()._pouring("beer", 0.05)
				await get_tree().create_timer(0.1).timeout
				rotation_degrees.z = 0

func _return_original():
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"global_position",original_position.global_position,0.5)
	tween.tween_property(self,"global_position",original_position.global_position,0.5)
	rotation_degrees = Vector3.ZERO
	
func _in_game():
	in_game = true
	pouring_into._on_hover(false)

func _out_of_game():
	in_game = false
	_return_original()
	pouring_into = null
	

func _pouring_game() -> void:
	pouring_into.in_game = true
	in_game = true
	GameState.player._perfect_pour(self,pouring_into)
	$Interact/CollisionShape3D.disabled = true
	await get_tree().create_timer(0.2).timeout
	$Interact/CollisionShape3D.disabled = false
	is_balls_dragging = false

func _on_interact_area_entered(area: Area3D) -> void:
	if(area.is_in_group("glass") && is_balls_dragging && pouring_into == null):
		pouring_into = area.get_parent()
		area.get_parent()._on_hover(true)
		

func _on_interact_area_exited(area: Area3D) -> void:
	if(area.is_in_group("glass") && is_balls_dragging):
		if(area.get_parent() == pouring_into):
			pouring_into = null
			area.get_parent()._on_hover(false)
