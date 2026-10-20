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

	for mesh in find_children("*", "GeometryInstance3D"):
		mesh.material_overlay = mat
