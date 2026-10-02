extends Glasses
class_name Drinks
var pouring_into : Node3D
@export var type_drink : String = "beer"


#func ready() -> void:
	#$Outside.material_overlay = $Outside.material_override.duplicate(true)
	#$Outside.material_override = $Outside.material_overlay
	#var material_overlay_x = $Outside.material_override
	#var gradient_tex = material_overlay_x.get_shader_parameter("gradient_texture")
	#gradient_tex.fill_to.x = 1

func _on_interact_area_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		pouring_into = area.get_parent()
		pouring_into.in_game = true
		in_game = true
		GameState.player._perfect_pour(self,area.get_parent())
		$Interact/CollisionShape3D.disabled = true
		await get_tree().create_timer(0.2).timeout
		$Interact/CollisionShape3D.disabled = false
		is_balls_dragging = false
		
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
				is_balls_dragging = false
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

func _in_game():
	in_game = true

func _out_of_game():
	in_game = false
