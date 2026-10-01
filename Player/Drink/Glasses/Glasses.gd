extends Ingredients
class_name Glasses
@export var liquids : Array = []
@export var size : float = 1.0 
var total_liquids : float = 0
var current_position = 0

func _delete():
	queue_free()

func _process(_delta: float) -> void:
	if is_balls_dragging:
		if(raycast.is_colliding()):
			print("Raycast Collision position: " + str(raycast.get_collision_point()))
			#var normal_offset := 0.5
			
			var collision_point = raycast.get_collision_point() 
			#collision_point.x = clamp(collision_point.x, -1 + counter_origin.global_position.x,1.184+ counter_origin.global_position.x)
			#collision_point.z = max(collision_point.z, -0.3)
			#
			#if(collision_point.z < 0.28):
				#collision_point.y = base_y_position + 0.2
			#else:
				#collision_point.y = base_y_position
			global_position = collision_point
			print("Global position: " + str(global_position))
			
		if(Input.is_action_just_released("Left_click")):
			is_balls_dragging = false
		look_at(camera.global_position)

func _pouring(id : String, liquids_num : float) -> void:
	if(len(liquids) != 0):
		var top_drink = liquids[len(liquids)-1]
		#print(top_drink==)
		
		if(top_drink[0] == id):
			top_drink[1] += liquids_num
			_visuals_change(liquids_num)
		else:
			var temp_liquid = [id,liquids_num]
			liquids.push_back(temp_liquid)
			_visuals_change(liquids_num)

	else:
		var temp_liquid = [id,liquids_num]
		liquids.push_back(temp_liquid)
		_visuals_change(liquids_num)

func _pushing_glass(other_glass : Area3D) -> void:
	var push_dir = (global_position - other_glass.global_position)
	push_dir.y = 0 
	if push_dir.length() < 0.001:
		push_dir = Vector3(1, 0, 0) 
	push_dir = push_dir.normalized()
	var push_strength = 0.03 
	global_position += push_dir * push_strength
	look_at(camera.global_position)
	

func _visuals_change(liquids_num: float) -> void:
	print(liquids_num)

func _dranked() -> void:
	queue_free()

func _return_drink() -> Array:
	return liquids
