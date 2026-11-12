class_name ReceiptBoard
extends RefCounted

var search_root: Node
var _slots: Array = []
var _board_node: Node3D = null
var _cached_transform: Transform3D = Transform3D.IDENTITY
var _cached_data: Dictionary = {}

func _init(p_search_root: Node = null) -> void:
	search_root = p_search_root

func setup(p_search_root: Node) -> void:
	search_root = p_search_root
	_slots.clear()
	_board_node = null
	_cached_data.clear()

func mount_receipt(receipt: Node3D, duration: float = 0.5) -> bool:
	if not is_instance_valid(receipt):
		return false

	var board_data: Dictionary = get_board_data()
	if board_data.is_empty():
		return false

	var slot_index: int = allocate_slot(receipt)
	var r_size: Vector2 = Vector2(0.25, 0.35)
	if receipt.has_method("get_receipt_dimensions"):
		r_size = receipt.get_receipt_dimensions()

	var slot_xf: Dictionary = compute_slot_transform(board_data, slot_index, r_size)
	if receipt.has_method("_moving_to_board"):
		receipt._moving_to_board(slot_xf["position"], slot_xf["basis"], duration)
	else:
		receipt.global_position = slot_xf["position"]
		receipt.basis = slot_xf["basis"]
	return true

func release_receipt(receipt: Node3D) -> void:
	if not is_instance_valid(receipt):
		return
	for i in _slots.size():
		if _slots[i] == receipt:
			_slots[i] = null
	if receipt.has_method("clear_board_slot"):
		receipt.clear_board_slot()
	elif "ordered" in receipt:
		receipt.ordered = false

func allocate_slot(receipt: Node3D) -> int:
	for i in _slots.size():
		if _slots[i] == receipt:
			return i
	for i in _slots.size():
		if not is_instance_valid(_slots[i]):
			_slots[i] = receipt
			return i
	_slots.append(receipt)
	return _slots.size() - 1

func get_board_data() -> Dictionary:
	var board_node := _find_board_node()
	if not is_instance_valid(board_node):
		return {}

	if not _cached_data.is_empty() and board_node.global_transform == _cached_transform:
		return _cached_data

	var meshes: Array[MeshInstance3D] = []
	if board_node is MeshInstance3D:
		meshes.append(board_node)
	for child in board_node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			meshes.append(child)

	if meshes.is_empty():
		return {}

	var local_bounds := AABB()
	var bounds_init: bool = false
	if meshes.size() == 1 and meshes[0] == board_node and meshes[0].mesh:
		local_bounds = meshes[0].mesh.get_aabb()
		bounds_init = true
	else:
		var inv_ref: Transform3D = board_node.global_transform.affine_inverse()
		for m in meshes:
			if not m.mesh:
				continue
			var m_aabb: AABB = m.mesh.get_aabb()
			var to_ref: Transform3D = inv_ref * m.global_transform
			for i in 8:
				var pt: Vector3 = to_ref * m_aabb.get_endpoint(i)
				if not bounds_init:
					local_bounds = AABB(pt, Vector3.ZERO)
					bounds_init = true
				else:
					local_bounds = local_bounds.expand(pt)

	if not bounds_init or local_bounds.size == Vector3.ZERO:
		return {}

	var world_xf: Transform3D = board_node.global_transform
	var board_center: Vector3 = world_xf * local_bounds.get_center()
	var axes: Array[Vector3] = [
		world_xf.basis.x * local_bounds.size.x,
		world_xf.basis.y * local_bounds.size.y,
		world_xf.basis.z * local_bounds.size.z,
	]

	var up_idx: int = 0
	var best_up_dot: float = -1.0
	for i in 3:
		var len_i: float = axes[i].length()
		if len_i > 0.0001:
			var dot_up: float = absf(axes[i].normalized().dot(Vector3.UP))
			if dot_up > best_up_dot:
				best_up_dot = dot_up
				up_idx = i

	var vertical_axis: Vector3 = axes[up_idx]
	if vertical_axis.y < 0.0:
		vertical_axis = -vertical_axis
	var board_up: Vector3 = vertical_axis.normalized()
	var board_height: float = vertical_axis.length()

	var horiz_indices: Array[int] = []
	for i in 3:
		if i != up_idx:
			horiz_indices.append(i)

	var a0: Vector3 = axes[horiz_indices[0]]
	var a1: Vector3 = axes[horiz_indices[1]]
	var depth_axis: Vector3 = a0 if a0.length() <= a1.length() else a1
	var width_axis: Vector3 = a1 if a0.length() <= a1.length() else a0

	var board_thickness: float = depth_axis.length()
	var board_width: float = width_axis.length()

	var viewer_pos: Vector3 = Vector3.ZERO
	var has_viewer: bool = false
	if search_root and search_root.is_inside_tree():
		var counter_mark := search_root.get_tree().get_first_node_in_group("counter_mark") as Node3D
		if counter_mark:
			viewer_pos = counter_mark.global_position
			has_viewer = true
		else:
			var cam := search_root.get_viewport().get_camera_3d()
			if cam:
				viewer_pos = cam.global_position
				has_viewer = true

	if has_viewer and depth_axis.dot(viewer_pos - board_center) < 0.0:
		depth_axis = -depth_axis

	var board_normal: Vector3 = depth_axis.normalized()
	var board_right: Vector3 = board_up.cross(board_normal).normalized()
	board_up = board_normal.cross(board_right).normalized()

	var surface_offset: float = 0.015
	var front_center: Vector3 = board_center + board_normal * (board_thickness * 0.5 + surface_offset)
	var top_left: Vector3 = front_center - board_right * (board_width * 0.5) + board_up * (board_height * 0.5)

	_cached_transform = board_node.global_transform
	_cached_data = {
		"top_left": top_left,
		"right": board_right,
		"up": board_up,
		"normal": board_normal,
		"width": board_width,
		"height": board_height,
	}
	return _cached_data

func compute_slot_transform(board_data: Dictionary, slot_index: int, receipt_size: Vector2) -> Dictionary:
	var board_w: float = board_data["width"]
	var board_h: float = board_data["height"]
	var r_w: float = maxf(receipt_size.x, 0.01)
	var r_h: float = maxf(receipt_size.y, 0.01)

	var min_gap_x: float = minf(0.04, r_w * 0.12)
	var min_gap_y: float = minf(0.04, r_h * 0.12)

	var cols: int = maxi(1, int(floor((board_w - min_gap_x) / (r_w + min_gap_x))))
	var rows: int = maxi(1, int(floor((board_h - min_gap_y) / (r_h + min_gap_y))))

	var gap_x: float = (board_w - float(cols) * r_w) / float(cols + 1)
	var gap_y: float = (board_h - float(rows) * r_h) / float(rows + 1)

	var capacity: int = cols * rows
	var layer: int = slot_index / capacity
	var wrapped_index: int = slot_index % capacity
	var row: int = wrapped_index / cols
	var col: int = wrapped_index % cols

	var offset_x: float = board_w * 0.5 if gap_x < 0.0 else (gap_x + r_w * 0.5 + float(col) * (r_w + gap_x))
	var offset_y: float = board_h * 0.5 if gap_y < 0.0 else (gap_y + r_h * 0.5 + float(row) * (r_h + gap_y))

	var board_right: Vector3 = board_data["right"]
	var board_up: Vector3 = board_data["up"]
	var board_normal: Vector3 = board_data["normal"]
	var top_left: Vector3 = board_data["top_left"]

	var slot_pos: Vector3 = top_left + board_right * offset_x - board_up * offset_y + board_normal * (0.006 * float(layer))
	var slot_basis := Basis(-board_right, -board_normal, -board_up).orthonormalized()

	return {
		"position": slot_pos,
		"basis": slot_basis,
	}

func _find_board_node() -> Node3D:
	if is_instance_valid(_board_node) and _board_node.is_inside_tree():
		return _board_node
	if not is_instance_valid(search_root):
		return null
	for child in search_root.find_children("*", "Node3D", true, false):
		var normalized: String = child.name.to_lower().replace("_", " ").strip_edges()
		if normalized == "receipts board" or normalized.replace(" ", "") == "receiptsboard":
			_board_node = child
			return _board_node
	for child in search_root.find_children("*", "Node3D", true, false):
		var normalized: String = child.name.to_lower().replace("_", " ").strip_edges()
		if normalized.begins_with("receipts board") or normalized.begins_with("receipt board"):
			_board_node = child
			return _board_node
	return null