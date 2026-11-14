@tool
extends Node3D

const DRAG_COLLISION_LAYER := 1 << 7
const DRAG_COLLISION_TARGETS := ["leftshelf", "rightshelf", "pillar009"]
const WORKING_AREA_MARGIN_RATIO_X := 0.05
const WORKING_AREA_MARGIN_RATIO_Z := 0.10
const WORKING_AREA_WALL_HEIGHT := 1.0

@export var pixel_size: int = 3:
	set(value):
		pixel_size = value
		_apply_pixel_shader()

func _ready() -> void:
	_apply_pixel_shader()
	if not Engine.is_editor_hint():
		_setup_drag_collisions()
		call_deferred("_setup_working_area_walls")

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

func _setup_working_area_walls() -> void:
	if get_node_or_null("WorkingAreaInvisibleWalls") != null:
		return

	var working_area := _find_working_area_node()
	if not is_instance_valid(working_area):
		return

	var bounds := _compute_world_bounds(working_area)
	if bounds.size.x <= 0.001 or bounds.size.z <= 0.001:
		return

	var near_is_min_z: bool = true
	if is_inside_tree():
		var counter_mark := get_tree().get_first_node_in_group("counter_mark") as Node3D
		if is_instance_valid(counter_mark):
			near_is_min_z = counter_mark.global_position.z <= bounds.get_center().z

	var margin_x: float = bounds.size.x * WORKING_AREA_MARGIN_RATIO_X
	var margin_z: float = bounds.size.z * WORKING_AREA_MARGIN_RATIO_Z
	var wall_y: float = bounds.end.y + WORKING_AREA_WALL_HEIGHT * 0.5
	var center: Vector3 = bounds.get_center()

	var walls_root := Node3D.new()
	walls_root.name = "WorkingAreaInvisibleWalls"
	add_child(walls_root)

	_create_invisible_wall(
		walls_root,
		"LeftMarginWall",
		Vector3(bounds.position.x + margin_x * 0.5, wall_y, center.z),
		Vector3(margin_x, WORKING_AREA_WALL_HEIGHT, bounds.size.z)
	)
	_create_invisible_wall(
		walls_root,
		"RightMarginWall",
		Vector3(bounds.end.x - margin_x * 0.5, wall_y, center.z),
		Vector3(margin_x, WORKING_AREA_WALL_HEIGHT, bounds.size.z)
	)

	var far_wall_z: float = (bounds.end.z - margin_z * 0.5) if near_is_min_z else (bounds.position.z + margin_z * 0.5)
	_create_invisible_wall(
		walls_root,
		"FarMarginWall",
		Vector3(center.x, wall_y, far_wall_z),
		Vector3(bounds.size.x, WORKING_AREA_WALL_HEIGHT, margin_z)
	)

func _create_invisible_wall(parent_node: Node3D, wall_name: String, world_center: Vector3, box_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = wall_name
	body.input_ray_pickable = false
	body.collision_layer = DRAG_COLLISION_LAYER
	body.collision_mask = 0

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	col.shape = box
	body.add_child(col)
	parent_node.add_child(body)
	body.global_position = world_center

func _find_working_area_node() -> Node3D:
	for child in find_children("*", "Node3D", true, false):
		var normalized_name: String = child.name.to_lower().replace("_", " ").strip_edges()
		if normalized_name == "working area":
			return child
	for child in find_children("*", "Node3D", true, false):
		var normalized_name: String = child.name.to_lower().replace("_", " ").strip_edges()
		if normalized_name.begins_with("working area"):
			return child
	return null

func _compute_world_bounds(target_node: Node3D) -> AABB:
	var bounds_init: bool = false
	var world_bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if target_node is MeshInstance3D:
		meshes.append(target_node)
	for child in target_node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and not meshes.has(child):
			meshes.append(child)

	for mesh_inst in meshes:
		if not mesh_inst.mesh:
			continue
		var local_aabb: AABB = mesh_inst.mesh.get_aabb()
		var xf: Transform3D = mesh_inst.global_transform
		for i in 8:
			var pt: Vector3 = xf * local_aabb.get_endpoint(i)
			if not bounds_init:
				world_bounds = AABB(pt, Vector3.ZERO)
				bounds_init = true
			else:
				world_bounds = world_bounds.expand(pt)
	return world_bounds

func _spotlight_dim() -> void:
	for spotlight in 7:
		var name_spotlight = "SpotLight3D" + str(spotlight+1)
		var spotlight_node = get_node(name_spotlight)
		var tween = get_tree().create_tween()
		tween.tween_property(spotlight_node,"light_energy",0,0.5)
	