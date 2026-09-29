extends Ingredients
class_name Glasses
@export var liquids : Array = []
@export var size : float = 1.0 
var total_liquids : float = 0
var current_position = 0
var base_y_position = 1.2

func _delete():
	queue_free()

func _process(_delta: float) -> void:
	if is_balls_dragging:
		var mouse_pos = get_viewport().get_mouse_position()
		var new_projection = camera.project_position(mouse_pos, drag_z_depth)
		
		new_projection.x = clamp(new_projection.x, -1 + counter_origin.global_position.x,1.184+ counter_origin.global_position.x)
		new_projection.z = max(new_projection.z, -0.3)
		if(new_projection.z < 0.28):
			new_projection.y = base_y_position + 0.2
		else:
			new_projection.y = base_y_position
		global_position = new_projection
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
