extends Node3D
@onready var shot_glass = preload("res://Player/Drink/shot_cup.tscn")
var summoning : bool = false
var icup_spawn : String = "shot_glass"

func get_mouse_world_position(camera: Camera3D, plane_y: float) -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, plane_y)
	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		return hit
	return global_position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and summoning:
		summoning = false

		match icup_spawn:
			"shot_glass":
				icup_spawn = ""
				var new_projection = get_mouse_world_position($Camera3D, 1.2)
				new_projection.x = clamp(
					new_projection.x+0.3,
					-1 + $Coutner/Lower_counter.global_position.x,
					1.184 + $Coutner/Lower_counter.global_position.x
				)
				new_projection.z = max(new_projection.z, 0.28)

				var new_instance = shot_glass.instantiate()
				new_instance.scale = Vector3(0.2, 0.2, 0.2)
				new_instance._instiate($Coutner/Lower_counter)
				new_instance.position = new_projection
				add_child(new_instance)
			_:
				pass

func _on_area_3d_2_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		icup_spawn = "shot_glass"
		await get_tree().create_timer(0.2).timeout
		summoning = true


func _on_beer_keg_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var glass_array : Array = []
		var areas = $Coutner/CHUGCHUGBEER/BeerKeg.get_overlapping_areas()
		while(Input.get_action_strength("Left_click")):
			for x in areas:
				print(x.is_in_group("glass"))
				if(x.is_in_group("glass")):
					glass_array.append(x)
			
			for glasses in glass_array:
				glasses.get_parent()._pouring("beer", 0.01)
			await get_tree().create_timer(0.1).timeout
		
