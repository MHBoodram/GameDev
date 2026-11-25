@tool
extends Area3D

const MAX_POUR_TILT_DEGREES: float = 135.0
const POUR_INTERVAL: float = 0.033
const SFX_INTERVAL_MS: int = 100

@export var indicator_path: NodePath = NodePath("TrashIndicator")
@export var collision_shape_path: NodePath = NodePath("CollisionShape3D")
@export var min_collision_height: float = 0.25

@export_group("Glass Snapping")
@export var snap_pull_speed: float = 22.0
@export var snap_release_speed: float = 16.0
@export var snap_break_distance: float = 0.45

@export_group("Pouring")
@export var pour_out_amount: float = 0.35

var _snap_zone: PourStreamVisual.SnapZoneHelper = PourStreamVisual.SnapZoneHelper.new()
var in_pour_zone: Glasses:
	get:
		return _snap_zone.active_glass
var _is_pouring: bool = false
var _active_pouring_glass: Glasses = null
var _last_sfx_ms: int = -1

func _ready() -> void:
	sync_bounds_from_indicator()
	if Engine.is_editor_hint():
		return
	_snap_zone.on_glass_activated = func(glass: Glasses) -> void:
		if glass.has_method("set_active_trash"):
			glass.set_active_trash(self)
	_snap_zone.on_glass_deactivated = func(glass: Glasses) -> void:
		if is_instance_valid(glass) and glass.has_method("set_active_trash"):
			glass.set_active_trash(null)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)
	if not input_event.is_connected(_on_trash_input_event):
		input_event.connect(_on_trash_input_event)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _is_pouring and is_instance_valid(_active_pouring_glass):
		if _active_pouring_glass.has_method("set_pour_out_tilt"):
			_active_pouring_glass.set_pour_out_tilt(_get_pour_tilt_degrees())

func _get_pour_tilt_degrees() -> float:
	var ratio: float = PourStreamVisual.get_pour_height_ratio(get_viewport())
	if ratio <= 0.001:
		return 0.0
	return lerpf(42.0, MAX_POUR_TILT_DEGREES, ratio)

func _snap_target() -> Node3D:
	var indicator := get_node_or_null(indicator_path) as Node3D
	if is_instance_valid(indicator):
		return indicator
	var col := get_node_or_null(collision_shape_path) as Node3D
	if is_instance_valid(col):
		return col
	return self

func can_pour_glass(glass: Glasses) -> bool:
	if _is_pouring:
		return false
	if not is_instance_valid(glass) or glass != in_pour_zone:
		return false
	return glass.total_liquids > 0.0

@warning_ignore("unused_parameter")
func _on_trash_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _is_pouring:
		start_pour()

func _return_glass_to_previous_location(glass: Glasses) -> void:
	if not is_instance_valid(glass):
		return
	_snap_zone.release_glass(glass)
	if glass.has_method("return_to_previous_location"):
		glass.return_to_previous_location()
	if not is_instance_valid(in_pour_zone):
		_snap_zone.promote_next(_snap_target(), snap_pull_speed, snap_release_speed, snap_break_distance)

func start_pour() -> void:
	if _is_pouring:
		return
	if not in_pour_zone or not is_instance_valid(in_pour_zone) or in_pour_zone.total_liquids <= 0.0:
		return

	_is_pouring = true
	_last_sfx_ms = -1
	var active_glass := in_pour_zone
	_active_pouring_glass = active_glass
	var cam_rig: Camera3D = PourStreamVisual.focus_station_camera(self, "sink_camera_marker", 0.55)

	if active_glass.has_method("start_pour_out"):
		active_glass.start_pour_out(_get_pour_tilt_degrees())

	while PourStreamVisual.is_pour_button_held() and is_inside_tree() and is_instance_valid(active_glass) and active_glass.total_liquids > 0.0:
		if active_glass.can_pour_out_from_mouth():
			var rate_mult: float = clampf(absf(active_glass.pour_tilt_degrees) / (MAX_POUR_TILT_DEGREES * 0.5), 0.15, 2.0)
			active_glass._pour_out(pour_out_amount * (POUR_INTERVAL / 0.1) * rate_mult)
			_last_sfx_ms = PourStreamVisual.play_throttled_pour_sfx(_last_sfx_ms, SFX_INTERVAL_MS)
		await get_tree().create_timer(POUR_INTERVAL).timeout
		if not is_inside_tree():
			_is_pouring = false
			_active_pouring_glass = null
			return

	_active_pouring_glass = null
	if is_instance_valid(active_glass) and active_glass.has_method("stop_pour_out"):
		active_glass.stop_pour_out()

	await get_tree().create_timer(0.15).timeout
	if not is_inside_tree():
		_is_pouring = false
		return

	_return_glass_to_previous_location(active_glass)

	await PourStreamVisual.return_station_camera(self, cam_rig, 0.55)
	if not is_inside_tree():
		_is_pouring = false
		return
	_is_pouring = false

func _on_area_entered(area: Area3D) -> void:
	_snap_zone.handle_area_entered(area, _snap_target(), snap_pull_speed, snap_release_speed, snap_break_distance)

func _on_area_exited(area: Area3D) -> void:
	_snap_zone.handle_area_exited(area, _snap_target(), snap_pull_speed, snap_release_speed, snap_break_distance)

func _on_mouse_entered() -> void:
	if Ingredients.active_dragging_item != null:
		return
	if in_pour_zone and is_instance_valid(in_pour_zone) and in_pour_zone.total_liquids > 0.0:
		if GameState.player:
			GameState.player._update_hand("interact")

func _on_mouse_exited() -> void:
	if Ingredients.active_dragging_item != null:
		return
	if GameState.player:
		GameState.player._update_hand("idle")

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