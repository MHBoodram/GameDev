@tool
extends Node3D

func _ready() -> void:
	_clear_pixel_shader()
	if not Engine.is_editor_hint():
		WorkingAreaService.setup_drag_collisions(self)
		(func():
			if is_instance_valid(self):
				WorkingAreaService.setup_working_area_walls(self)
		).call_deferred()

func _clear_pixel_shader() -> void:
	for mesh in find_children("*", "GeometryInstance3D"):
		if mesh is GeometryInstance3D and mesh.material_overlay != null:
			mesh.material_overlay = null

func _spotlight_dim() -> void:
	for spotlight in 7:
		var name_spotlight = "SpotLight3D" + str(spotlight+1)
		var spotlight_node = get_node(name_spotlight)
		var tween = get_tree().create_tween()
		tween.tween_property(spotlight_node,"light_energy",0,0.5)