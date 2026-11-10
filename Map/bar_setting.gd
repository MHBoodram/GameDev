@tool
extends Node3D

@export var pixel_size: int = 3:
	set(value):
		pixel_size = value
		_apply_pixel_shader()

func _ready() -> void:
	_apply_pixel_shader()

func _apply_pixel_shader() -> void:
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://Shader/per_object_pixel_shader.gdshader")
	mat.set_shader_parameter("pixel_size", pixel_size)
	mat.render_priority = -1

	for mesh in find_children("*", "GeometryInstance3D"):
		mesh.material_overlay = mat

func _spotlight_dim() -> void:
	for spotlight in 7:
		var name_spotlight = "SpotLight3D" + str(spotlight+1)
		var spotlight_node = get_node(name_spotlight)
		var tween = get_tree().create_tween()
		tween.tween_property(spotlight_node,"light_energy",0,0.5)
		