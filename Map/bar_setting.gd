@tool
extends Node3D

const DRAG_COLLISION_LAYER := 1 << 7
const DRAG_COLLISION_TARGETS := ["leftshelf", "rightshelf", "pillar009"]

@export var pixel_size: int = 3:
	set(value):
		pixel_size = value
		_apply_pixel_shader()

func _ready() -> void:
	_apply_pixel_shader()
	if not Engine.is_editor_hint():
		_setup_drag_collisions()

func _apply_pixel_shader() -> void:
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://Shader/per_object_pixel_shader.gdshader")
	mat.set_shader_parameter("pixel_size", pixel_size)
	mat.render_priority = -1

	for mesh in find_children("*", "GeometryInstance3D"):
		mesh.material_overlay = mat

func _setup_drag_collisions() -> void:
	for node in find_children("*", "Node3D", true, false):
		var compact_name: String = node.name.to_lower().replace("_", "").replace(".", "").replace(" ", "")
		if not DRAG_COLLISION_TARGETS.has(compact_name):
			continue
		node.add_to_group("bar_drag_obstacle")

		var meshes: Array[MeshInstance3D] = []
		if node is MeshInstance3D:
			meshes.append(node)
		for child in node.find_children("*", "MeshInstance3D", true, false):
			if child is MeshInstance3D and not meshes.has(child):
				meshes.append(child)

		for mesh_inst in meshes:
			if not mesh_inst.mesh or mesh_inst.get_node_or_null("DragCollisionBody") != null:
				continue
			var body := StaticBody3D.new()
			body.name = "DragCollisionBody"
			body.input_ray_pickable = false
			body.collision_layer = DRAG_COLLISION_LAYER
			body.collision_mask = 0

			var col := CollisionShape3D.new()
			var shape: Shape3D = mesh_inst.mesh.create_convex_shape(true, false)
			if shape == null:
				var aabb: AABB = mesh_inst.mesh.get_aabb()
				var box := BoxShape3D.new()
				box.size = aabb.size
				col.position = aabb.get_center()
				shape = box
			col.shape = shape
			body.add_child(col)
			mesh_inst.add_child(body)

func _spotlight_dim() -> void:
	for spotlight in 7:
		var name_spotlight = "SpotLight3D" + str(spotlight+1)
		var spotlight_node = get_node(name_spotlight)
		var tween = get_tree().create_tween()
		tween.tween_property(spotlight_node,"light_energy",0,0.5)
		
