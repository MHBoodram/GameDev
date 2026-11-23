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

var in_pour_zone: Glasses = null
var _glasses_in_area: Array[Glasses] = []
var _is_pouring: bool = false
var _active_pouring_glass: Glasses = null
var _last_sfx_ms: int = 0

func _ready() -> void:
	sync_bounds_from_indicator()
	if Engine.is_editor_hint():
		return
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

func _get_pour_height_ratio() -> float:
	var viewport := get_viewport()
	if not viewport:
		return 0.5
	var vp_height: float = viewport.get_visible_rect().size.y
	if vp_height <= 1.0:
		return 0.5
	var mouse_y: float = viewport.get_mouse_position().y
	var raw_height: float = 1.0 - clampf(mouse_y / vp_height, 0.0, 1.0)
	return clampf((raw_height - 0.1) / 0.8, 0.0, 1.0)

func _get_pour_rate_multiplier() -> float:
	return _get_pour_height_ratio() * 2.0

func _get_pour_tilt_degrees() -> float:
	return _get_pour_height_ratio() * MAX_POUR_TILT_DEGREES

func _snap_target() -> Node3D:
	var indicator := get_node_or_null(indicator_path) as Node3D
	if is_instance_valid(indicator):
		return indicator
	var col := get_node_or_null(collision_shape_path) as Node3D
	if is_instance_valid(col):
		return col
	return self

func _get_camera_rig() -> Camera3D:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam and cam.has_method("focus_on_marker") and cam.has_method("return_from_marker"):
		return cam
	return null

func _get_sink_camera_marker() -> Node3D:
	var scene_root := get_tree().current_scene
	if is_instance_valid(scene_root):
		var marker := scene_root.get_node_or_null("sink_camera_marker") as Node3D
		if marker:
			return marker
	if is_instance_valid(GameState.main_node):
		return GameState.main_node.get_node_or_null("sink_camera_marker") as Node3D
	return null

func _is_pour_button_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.get_action_strength("Left_click") > 0.0

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
	_glasses_in_area.erase(glass)
	if in_pour_zone == glass:
		in_pour_zone = null
	if glass.has_method("set_active_trash"):
		glass.set_active_trash(null)
	glass._remove_displaying_list()
	if glass.has_method("return_to_previous_location"):
		glass.return_to_previous_location()
	if not in_pour_zone:
		for g in _glasses_in_area:
			if is_instance_valid(g):
				_set_active_glass(g)
				break

func start_pour() -> void:
	if _is_pouring:
		return
	if not in_pour_zone or not is_instance_valid(in_pour_zone) or in_pour_zone.total_liquids <= 0.0:
		return

	_is_pouring = true
	var active_glass := in_pour_zone
	_active_pouring_glass = active_glass
	var cam_rig: Camera3D = _get_camera_rig()
	var marker := _get_sink_camera_marker()
	if cam_rig and marker:
		if GameState.gameplay_ui and GameState.gameplay_ui.has_method("_in_down_minigame"):
			GameState.gameplay_ui._in_down_minigame()
		cam_rig.call("focus_on_marker", marker, 0.55)

	if active_glass.has_method("start_pour_out"):
		active_glass.start_pour_out(_get_pour_tilt_degrees())

	while _is_pour_button_held() and is_inside_tree():
		if is_instance_valid(active_glass) and active_glass.total_liquids > 0.0 and active_glass.can_pour_out_from_mouth():
			var rate_mult: float = clampf(absf(active_glass.pour_tilt_degrees) / (MAX_POUR_TILT_DEGREES * 0.5), 0.15, 2.0)
			active_glass._pour_out(pour_out_amount * (POUR_INTERVAL / 0.1) * rate_mult)
			var now_ms := Time.get_ticks_msec()
			if now_ms - _last_sfx_ms >= SFX_INTERVAL_MS:
				_last_sfx_ms = now_ms
				SFXAudio.play_liquidpour()
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

	if cam_rig and marker:
		cam_rig.call("return_from_marker", 0.55)
		if cam_rig.has_signal("marker_returned"):
			await cam_rig.marker_returned
		if not is_inside_tree():
			_is_pouring = false
			return
		if GameState.gameplay_ui and GameState.gameplay_ui.has_method("_out_down_minigame"):
			GameState.gameplay_ui._out_down_minigame()
	_is_pouring = false

func _on_area_entered(area: Area3D) -> void:
	if not (area is Glasses) or not area.is_in_group("glass"):
		return
	var glass := area as Glasses
	if not _glasses_in_area.has(glass):
		_glasses_in_area.append(glass)
	if not in_pour_zone:
		_set_active_glass(glass)

func _on_area_exited(area: Area3D) -> void:
	if _glasses_in_area.size() > 0:
		_glasses_in_area.erase(area)
	if area == in_pour_zone:
		if is_instance_valid(area):
			area.exit_snap_zone(_snap_target())
			if area.has_method("set_active_trash"):
				area.set_active_trash(null)
			area._remove_displaying_list()
		in_pour_zone = null
		for g in _glasses_in_area:
			if is_instance_valid(g):
				_set_active_glass(g)
				break

func _set_active_glass(glass: Glasses) -> void:
	in_pour_zone = glass
	if glass.has_method("set_active_trash"):
		glass.set_active_trash(self)
	glass.enter_snap_zone(_snap_target(), snap_pull_speed, snap_release_speed, snap_break_distance)

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