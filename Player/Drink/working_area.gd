class_name WorkingAreaService
extends RefCounted

# handles finding the counter working area bounds

const MARGIN_RATIO_X := 0.05
const MARGIN_RATIO_Z := 0.10
const BAR_COLLISION_TARGETS := ["leftshelf", "rightshelf", "pillar009"]

static var _cached_working_node: Node3D = null
static var _cached_working_xf: Transform3D = Transform3D.IDENTITY
static var _cached_working_bounds: AABB = AABB()
static var _has_cached_bounds: bool = false
static var _sprite_opaque_cache: Dictionary = {}

static var _cached_tree: SceneTree = null
static var _obstacle_meshes: Array[MeshInstance3D] = []
static var _obstacle_xfs: Array[Transform3D] = []
static var _obstacle_obbs: Array[Dictionary] = []

# literally searches for the working area node
static func find_working_area_node(search_root: Node) -> Node3D:
	if not is_instance_valid(search_root):
		return null
	var direct := search_root.find_child("Working area", true, false)
	if direct is Node3D:
		return direct
	for child in search_root.find_children("*", "Node3D", true, false):
		var n: String = child.name.to_lower().replace("_", " ").strip_edges()
		if n == "working area" or n.begins_with("working area"):
			return child
	return null

# calculates bounding box
static func compute_node_world_bounds(target_node: Node3D) -> Variant:
	var init: bool = false
	var out_bounds := AABB()
	var meshes: Array[Node] = []
	if target_node is MeshInstance3D:
		meshes.append(target_node)
	meshes.append_array(target_node.find_children("*", "MeshInstance3D", true, false))

	for m in meshes:
		var mesh_inst := m as MeshInstance3D
		if mesh_inst and mesh_inst.mesh:
			var local_box: AABB = mesh_inst.mesh.get_aabb()
			var xf: Transform3D = mesh_inst.global_transform
			for i in 8:
				var pt: Vector3 = xf * local_box.get_endpoint(i)
				if not init:
					out_bounds = AABB(pt, Vector3.ZERO)
					init = true
				else:
					out_bounds = out_bounds.expand(pt)

	if init:
		return out_bounds

	if target_node is VisualInstance3D:
		var vis_box: AABB = (target_node as VisualInstance3D).get_aabb()
		if vis_box.size != Vector3.ZERO:
			var xf: Transform3D = target_node.global_transform
			for i in 8:
				var pt: Vector3 = xf * vis_box.get_endpoint(i)
				if not init:
					out_bounds = AABB(pt, Vector3.ZERO)
					init = true
				else:
					out_bounds = out_bounds.expand(pt)

	return out_bounds if init else null

# gets the raw bounding box for the counter top surface
static func get_working_area_bounds(context: Node) -> Variant:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	if not tree:
		return null

	if not is_instance_valid(_cached_working_node) or not _cached_working_node.is_inside_tree() or _cached_working_node.get_tree() != tree:
		_cached_working_node = null
		_has_cached_bounds = false
		var roots: Array[Node] = [tree.current_scene, tree.root]
		for r in roots:
			if is_instance_valid(r):
				_cached_working_node = find_working_area_node(r)
				if _cached_working_node:
					break

	if not is_instance_valid(_cached_working_node):
		return null

	if _has_cached_bounds and _cached_working_node.global_transform == _cached_working_xf:
		return _cached_working_bounds

	var recalculated = compute_node_world_bounds(_cached_working_node)
	if recalculated is AABB:
		_cached_working_xf = _cached_working_node.global_transform
		_cached_working_bounds = recalculated
		_has_cached_bounds = true
		return _cached_working_bounds

	return null

# checks if camera or player counter mark is positioned along negative Z relative to counter center
static func is_near_side_min_z(context: Node, box: AABB) -> bool:
	if is_instance_valid(context) and context.is_inside_tree():
		var tree := context.get_tree()
		if tree:
			var counter_mark := tree.get_first_node_in_group("counter_mark") as Node3D
			if is_instance_valid(counter_mark):
				return counter_mark.global_position.z <= box.get_center().z
			var cam := tree.root.get_viewport().get_camera_3d()
			if is_instance_valid(cam):
				return cam.global_position.z <= box.get_center().z
	return true

# shrinks working area bounds inward a margin
static func get_working_area_usable_bounds(context: Node) -> Variant:
	var raw_bounds = get_working_area_bounds(context)
	if not (raw_bounds is AABB):
		return null

	var box: AABB = raw_bounds
	var margin_x: float = box.size.x * MARGIN_RATIO_X
	var margin_z: float = box.size.z * MARGIN_RATIO_Z
	var near_is_min: bool = is_near_side_min_z(context, box)

	var min_x: float = box.position.x + margin_x
	var max_x: float = box.end.x - margin_x
	var min_z: float = box.position.z if near_is_min else (box.position.z + margin_z)
	var max_z: float = (box.end.z - margin_z) if near_is_min else box.end.z

	return AABB(Vector3(min_x, box.position.y, min_z), Vector3(maxf(max_x - min_x, 0.01), box.size.y, maxf(max_z - min_z, 0.01)))

# collision with pillars or shelf
static func get_bar_obstacle_obbs(context: Node) -> Array[Dictionary]:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return []
	var tree := context.get_tree()
	if not tree:
		return []

	var needs_reload: bool = (_cached_tree != tree) or _obstacle_meshes.is_empty()
	if not needs_reload:
		for m in _obstacle_meshes:
			if not is_instance_valid(m) or not m.is_inside_tree():
				needs_reload = true
				break

	if needs_reload:
		_cached_tree = tree
		_obstacle_meshes.clear()
		_obstacle_xfs.clear()
		_obstacle_obbs.clear()
		var candidate_roots: Array[Node] = [tree.current_scene, tree.root]
		for root_node in candidate_roots:
			if not is_instance_valid(root_node):
				continue
			for child in root_node.find_children("*", "Node3D", true, false):
				var compact := child.name.to_lower().replace("_", "").replace(".", "").replace(" ", "")
				if not BAR_COLLISION_TARGETS.has(compact):
					continue
				if child is MeshInstance3D and child.mesh and not _obstacle_meshes.has(child):
					_obstacle_meshes.append(child)
				for sub in child.find_children("*", "MeshInstance3D", true, false):
					if sub is MeshInstance3D and sub.mesh and not _obstacle_meshes.has(sub):
						_obstacle_meshes.append(sub)
			if not _obstacle_meshes.is_empty():
				break

	var xfs_changed: bool = _obstacle_obbs.size() != _obstacle_meshes.size()
	if not xfs_changed:
		for i in _obstacle_meshes.size():
			if _obstacle_meshes[i].global_transform != _obstacle_xfs[i]:
				xfs_changed = true
				break

	if xfs_changed:
		_obstacle_xfs.clear()
		_obstacle_obbs.clear()
		for mesh_inst in _obstacle_meshes:
			var xf: Transform3D = mesh_inst.global_transform
			_obstacle_xfs.append(xf)
			var local_aabb: AABB = mesh_inst.mesh.get_aabb()
			var col0 := xf.basis.x * (local_aabb.size.x * 0.5)
			var col1 := xf.basis.y * (local_aabb.size.y * 0.5)
			var col2 := xf.basis.z * (local_aabb.size.z * 0.5)
			var half := Vector3(col0.length(), col1.length(), col2.length())
			var axes: Array[Vector3] = [
				col0 / half.x if half.x > 0.00001 else Vector3.RIGHT,
				col1 / half.y if half.y > 0.00001 else Vector3.UP,
				col2 / half.z if half.z > 0.00001 else Vector3.BACK,
			]
			_obstacle_obbs.append({"center": xf * local_aabb.get_center(), "axes": axes, "half": half})

	return _obstacle_obbs

# collision
static func compute_aabb_obb_push(aabb_center: Vector3, aabb_half: Vector3, obb: Dictionary, horizontal_only: bool) -> Vector3:
	var b_center: Vector3 = obb["center"]
	var b_axes: Array[Vector3] = obb["axes"]
	var b_half: Vector3 = obb["half"]
	var d := aabb_center - b_center

	var max_r := aabb_half.length() + b_half.length()
	if d.length_squared() > max_r * max_r:
		return Vector3.ZERO

	var a_axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var test_axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK, b_axes[0], b_axes[1], b_axes[2]]
	for i in 3:
		for j in 3:
			var cross_axis: Vector3 = a_axes[i].cross(b_axes[j])
			if cross_axis.length_squared() > 0.0001:
				test_axes.append(cross_axis.normalized())

	var min_overlap: float = INF
	var best_axis: Vector3 = Vector3.ZERO
	var min_horiz_overlap: float = INF
	var best_horiz_axis: Vector3 = Vector3.ZERO

	for axis in test_axes:
		var dist := d.dot(axis)
		var r_a := aabb_half.x * absf(axis.x) + aabb_half.y * absf(axis.y) + aabb_half.z * absf(axis.z)
		var r_b := b_half.x * absf(b_axes[0].dot(axis)) + b_half.y * absf(b_axes[1].dot(axis)) + b_half.z * absf(b_axes[2].dot(axis))
		var overlap := (r_a + r_b) - absf(dist)
		if overlap <= 0.0:
			return Vector3.ZERO

		var signed_axis := axis if dist >= 0.0 else -axis
		if overlap < min_overlap:
			min_overlap = overlap
			best_axis = signed_axis

		if horizontal_only and absf(axis.y) < 0.05:
			if overlap < min_horiz_overlap:
				min_horiz_overlap = overlap
				best_horiz_axis = signed_axis

	if horizontal_only:
		if best_horiz_axis != Vector3.ZERO:
			best_horiz_axis.y = 0.0
			if best_horiz_axis.length_squared() > 0.00001:
				return best_horiz_axis.normalized() * min_horiz_overlap
		var flat_push := Vector3(best_axis.x, 0.0, best_axis.z)
		if flat_push.length_squared() > 0.00001:
			return flat_push.normalized() * min_overlap
		return Vector3.ZERO

	return best_axis * min_overlap

# pushes an item out of all nearby shelves and pillars
static func resolve_bar_collisions(item_bounds: AABB, context: Node) -> Vector3:
	var obbs := get_bar_obstacle_obbs(context)
	if obbs.is_empty():
		return Vector3.ZERO

	var item_center: Vector3 = item_bounds.get_center()
	var item_half: Vector3 = item_bounds.size * 0.5
	item_half.x = maxf(item_half.x, 0.03)
	item_half.y = maxf(item_half.y, 0.03)
	item_half.z = maxf(item_half.z, 0.03)

	var total_push: Vector3 = Vector3.ZERO
	for _pass in 2:
		var moved: bool = false
		for obb in obbs:
			var push := compute_aabb_obb_push(item_center + total_push, item_half, obb, true)
			if push.length_squared() > 0.0000001:
				total_push += push
				moved = true
		if not moved:
			break

	return total_push

# bounds sprite to counter boundaries
static func clamp_to_counter(target_position: Vector3, half_extents: Vector2, context: Node, counter_origin: Node3D) -> Vector3:
	var surface_bounds = get_working_area_usable_bounds(context)
	if surface_bounds is AABB:
		var boundary: AABB = surface_bounds
		var margin_x: float = minf(half_extents.x, boundary.size.x * 0.45)
		var margin_z: float = minf(maxf(half_extents.y, 0.02), boundary.size.z * 0.45)
		target_position.x = clampf(target_position.x, boundary.position.x + margin_x, boundary.end.x - margin_x)
		target_position.z = clampf(target_position.z, boundary.position.z + margin_z, boundary.end.z - margin_z)
		return target_position

	if counter_origin:
		var raw_min_x: float = counter_origin.global_position.x - 1.15
		var raw_max_x: float = counter_origin.global_position.x + 1.82
		var raw_min_z: float = counter_origin.global_position.z - 0.35
		var raw_max_z: float = counter_origin.global_position.z + 0.38
		var inset_x: float = (raw_max_x - raw_min_x) * MARGIN_RATIO_X
		var inset_z: float = (raw_max_z - raw_min_z) * MARGIN_RATIO_Z
		target_position.x = clampf(target_position.x, raw_min_x + inset_x, raw_max_x - inset_x)
		target_position.z = clampf(target_position.z, raw_min_z, raw_max_z - inset_z)
	return target_position

# computes sprite bounds ignoring transparent padding in the texture
static func get_sprite_world_bounds(target_sprite: Sprite3D) -> Variant:
	if not is_instance_valid(target_sprite) or target_sprite.texture == null:
		return null
	var dims: Rect2 = target_sprite.get_item_rect()
	if dims.size.x <= 0.0 or dims.size.y <= 0.0:
		return null

	var pad_left: float = 0.0
	var pad_right: float = 0.0
	var pad_bottom: float = 0.0
	var pad_top: float = 0.0

	if target_sprite.hframes == 1 and target_sprite.vframes == 1 and not target_sprite.region_enabled:
		var tex_id: int = target_sprite.texture.get_rid().get_id()
		var used_rect: Rect2i
		var tex_size: Vector2i
		if _sprite_opaque_cache.has(tex_id):
			var data: Dictionary = _sprite_opaque_cache[tex_id]
			used_rect = data["used"]
			tex_size = data["size"]
		else:
			var img: Image = target_sprite.texture.get_image()
			if img != null and not img.is_empty():
				used_rect = img.get_used_rect()
				tex_size = img.get_size()
			_sprite_opaque_cache[tex_id] = {"used": used_rect, "size": tex_size}

		if used_rect.size.x > 0 and used_rect.size.y > 0 and tex_size.x > 0 and tex_size.y > 0:
			var sx: float = dims.size.x / float(tex_size.x)
			var sy: float = dims.size.y / float(tex_size.y)
			pad_left = float(tex_size.x - used_rect.end.x if target_sprite.flip_h else used_rect.position.x) * sx
			pad_right = float(used_rect.position.x if target_sprite.flip_h else tex_size.x - used_rect.end.x) * sx
			pad_bottom = float(used_rect.position.y if target_sprite.flip_v else tex_size.y - used_rect.end.y) * sy
			pad_top = float(tex_size.y - used_rect.end.y if target_sprite.flip_v else used_rect.position.y) * sy

	var ps: float = target_sprite.pixel_size
	var min_lx := (dims.position.x + pad_left) * ps
	var max_lx := (dims.end.x - pad_right) * ps
	var min_ly := (dims.position.y + pad_bottom) * ps
	var max_ly := (dims.end.y - pad_top) * ps

	var pts: Array[Vector3] = [
		Vector3(min_lx, min_ly, 0.0),
		Vector3(max_lx, min_ly, 0.0),
		Vector3(min_lx, max_ly, 0.0),
		Vector3(max_lx, max_ly, 0.0)
	]
	var xf: Transform3D = target_sprite.global_transform
	var box := AABB(xf * pts[0], Vector3.ZERO)
	for i in range(1, pts.size()):
		box = box.expand(xf * pts[i])
	return box

# checks whether mouse ray cast onto the counter table falls within table bounds
static func is_pointer_over_working_area(camera: Camera3D, surface_y: float, context: Node, counter_origin: Node3D) -> bool:
	if not camera:
		return true

	var mouse_pos := camera.get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var forward := -camera.global_transform.basis.z

	var hit = Plane(Vector3.UP, surface_y).intersects_ray(from, dir)
	if hit == null:
		return false
	var to_hit: Vector3 = hit - from
	if to_hit.dot(forward) <= 0.0 or to_hit.length() > 5.0:
		return false

	var bounds = get_working_area_bounds(context)
	if bounds is AABB:
		var box: AABB = bounds
		return (hit.x >= box.position.x - 0.35 and hit.x <= box.end.x + 0.35 and hit.z <= box.end.z + 0.05)

	if counter_origin:
		return (hit.x >= counter_origin.global_position.x - 1.4 and hit.x <= counter_origin.global_position.x + 2.05 and hit.z <= counter_origin.global_position.z + 0.43)

	return true