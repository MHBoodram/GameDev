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
	tween.tween_property($Point_001,"light_energy",0.087,0.5)
	tween.tween_property($Point_003,"light_energy",0.087,0.5)
	tween.tween_property($Point_004,"light_energy",0.087,0.5)
	tween.tween_property($Point_005,"light_energy",0.087,0.5)
	await tween.finished
	#$Spot_003.light_energy = 

func _close_light() -> void:
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property($Spot,"light_energy",0,0.5)
	tween.tween_property($shelf_spot,"light_energy",0,0.5)
	tween.tween_property($shelf_spot2,"light_energy",0,0.5)
	tween.tween_property($Spot_001,"light_energy",0,0.5)
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
	var tween = get_tree().create_tween().set_parallel(true)
	$Spot_003.light_color = Color(1.0, 1.0, 1.0, 1.0)
	tween.tween_property($Spot_003,"light_energy",4,0.5)
	tween.tween_property($shelf_spot,"light_energy",4,0.5)
	tween.tween_property($shelf_spot2,"light_energy",4,0.5)
	tween.tween_property($Spot,"light_energy",4,0.5)
	$Spot.show()
	$Spot_002.show()

func _get_marker(id: int) -> Marker3D:
	var string_node = str("Marker",id)
	var marker3d_node = get_node_or_null(string_node) as Marker3D
	return marker3d_node