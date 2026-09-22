extends Area3D
@onready var keg_sprite = get_node("CHUGCHUGBEER")
@onready var keg_water_particle = get_node("CPUParticles3D")
@onready var pour_zone = get_node("PourArea/PourZone")
var in_pour_zone : Area3D

@warning_ignore("unused_parameter")
func _on_beer_keg_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		#var glass_array : Array = []
		keg_sprite.rotation_degrees.x = -64.5
		#var areas = $Coutner/PourArea.get_overlapping_areas()
		keg_water_particle.emitting = true
		while(Input.get_action_strength("Left_click")):
			
			#for x in areas:
				#print(x.is_in_group("glass"))
				#if(x.is_in_group("glass")):
					#glass_array.append(x)
			if(in_pour_zone):
				in_pour_zone.get_parent()._pouring("beer", 0.25)
			#for glasses in glass_array:
				#glasses.get_parent()._pouring("beer", 0.05)
			await get_tree().create_timer(0.1).timeout
		keg_sprite.rotation_degrees.x = -131.5
		keg_water_particle.emitting = false

func _on_pour_area_area_entered(area: Area3D) -> void:
	if(area.is_in_group("glass") && !in_pour_zone):
		in_pour_zone = area
		pour_zone.modulate = Color(1, 0, 0)


func _on_pour_area_area_exited(area: Area3D) -> void:
	if(area == in_pour_zone):
		in_pour_zone = null
		pour_zone.modulate = Color(1.0, 1.0, 1.0, 1.0)
