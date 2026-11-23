extends Node3D

func _ready() -> void:
	if not Engine.is_editor_hint():
		WorkingAreaService.setup_drag_collisions(self)
		(func():
			if is_instance_valid(self):
				WorkingAreaService.setup_working_area_walls(self)
		).call_deferred()

func _open_light() -> void:
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property($Spot_003,"light_energy",2.503,0.5)
	tween.tween_property($Point_001,"light_energy",0.087,0.5)
	#tween.tween_property($Point_002,"light_energy",0.087,0.5)
	tween.tween_property($Point_003,"light_energy",0.087,0.5)
	tween.tween_property($Point_004,"light_energy",0.087,0.5)
	tween.tween_property($Point_005,"light_energy",0.087,0.5)
	await tween.finished
	#$Spot_003.light_energy = 

func _close_light() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property($Spot_003,"light_energy",0,0.5)
	tween.tween_property($Point_001,"light_energy",0,0.5)
	#tween.tween_property($Point_002,"light_energy",0,0.5)
	tween.tween_property($Point_003,"light_energy",0,0.5)
	tween.tween_property($Point_004,"light_energy",0,0.5)
	tween.tween_property($Point_005,"light_energy",0,0.5)
	await tween.finished
	

func _setup_shop_scene() -> void:
	$Shop.play("default")
	await $Shop.animation_finished
	#$Spot_003.light_color = Color("80fd00")
	$Spot.show()
	$Spot_002.show()

func _get_marker(id: int) -> Marker3D:
	var string_node = str("Marker",id)
	var marker3d_node = get_node(string_node)
	return marker3d_node