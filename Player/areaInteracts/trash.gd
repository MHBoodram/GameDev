@tool
extends Area3D

@export var indicator_path: NodePath = NodePath("TrashIndicator")
@export var collision_shape_path: NodePath = NodePath("CollisionShape3D")
@export var min_collision_height: float = 0.25

func _ready() -> void:
	sync_bounds_from_indicator()

func sync_bounds_from_indicator() -> void:
	var indicator := get_node_or_null(indicator_path) as Node3D
	var col := get_node_or_null(collision_shape_path) as CollisionShape3D
	if not is_instance_valid(indicator) or not is_instance_valid(col):
		return

	var local_aabb := _get_indicator_local_aabb(indicator)
	if local_aabb.size == Vector3.ZERO:
		return

	var xf: Transform3D = indicator.transform if indicator.get_parent() == self else (global_transform.affine_inverse() * indicator.global_transform)
	var sx: float = xf.basis.x.length()
	var sy: float = xf.basis.y.length()
	var sz: float = xf.basis.z.length()

	var rot_basis := Basis(
		xf.basis.x / sx if sx > 0.0001 else Vector3.RIGHT,
		xf.basis.y / sy if sy > 0.0001 else Vector3.UP,
		xf.basis.z / sz if sz > 0.0001 else Vector3.BACK
	).orthonormalized()

	col.transform = Transform3D(rot_basis, xf * local_aabb.get_center())

	var box := col.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
	elif not Engine.is_editor_hint():
		box = box.duplicate() as BoxShape3D
	box.size = Vector3(
		maxf(local_aabb.size.x * sx, 0.01),
		maxf(local_aabb.size.y * sy, min_collision_height),
		maxf(local_aabb.size.z * sz, 0.01)
	)
	col.shape = box

func _get_indicator_local_aabb(indicator: Node3D) -> AABB:
	if indicator is MeshInstance3D and (indicator as MeshInstance3D).mesh:
		var mesh_aabb: AABB = (indicator as MeshInstance3D).mesh.get_aabb()
		if mesh_aabb.size != Vector3.ZERO:
			return mesh_aabb
	if indicator is VisualInstance3D:
		var direct_aabb: AABB = (indicator as VisualInstance3D).get_aabb()
		if direct_aabb.size != Vector3.ZERO:
			return direct_aabb

	var bounds := AABB()
	var has_bounds := false
	var inv_xf: Transform3D = indicator.global_transform.affine_inverse() if indicator.is_inside_tree() else Transform3D.IDENTITY
	for child in indicator.find_children("*", "VisualInstance3D", true, false):
		var vis := child as VisualInstance3D
		var vis_aabb: AABB = (vis as MeshInstance3D).mesh.get_aabb() if (vis is MeshInstance3D and (vis as MeshInstance3D).mesh) else vis.get_aabb()
		if vis_aabb.size == Vector3.ZERO:
			continue
		var rel_xf: Transform3D = inv_xf * vis.global_transform if indicator.is_inside_tree() else vis.transform
		for i in 8:
			var pt: Vector3 = rel_xf * vis_aabb.get_endpoint(i)
			if not has_bounds:
				bounds = AABB(pt, Vector3.ZERO)
				has_bounds = true
			else:
				bounds = bounds.expand(pt)
	return bounds if has_bounds else AABB()