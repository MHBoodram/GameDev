class_name GlassStreamsVfx
extends Node

# spilling, impact splash particle effect

const OVERFLOW_STREAM_HOLD_TIME: float = 0.075
const POUR_SPLASH_HOLD_TIME: float = 0.075

var _pour_out_stream: PourStreamVisual = null
var _pour_splash_stream: PourStreamVisual = null
var _pour_splash_timer: float = 0.0
var _pour_splash_flow_rate: float = 0.0
var _pour_splash_color: Color = Color.WHITE
var _pour_splash_entry_u: float = 0.5

var _overflow_stream_left: PourStreamVisual = null
var _overflow_stream_right: PourStreamVisual = null
var _overflow_timer: float = 0.0
var _overflow_flow_rate: float = 0.0
var _overflow_color: Color = Color.WHITE

func _ready() -> void:
	ensure_streams()

func ensure_streams() -> void:
	if not is_instance_valid(_pour_out_stream):
		_pour_out_stream = PourStreamVisual.new()
		add_child(_pour_out_stream)
	if not is_instance_valid(_pour_splash_stream):
		_pour_splash_stream = PourStreamVisual.new()
		add_child(_pour_splash_stream)
	if not is_instance_valid(_overflow_stream_left):
		_overflow_stream_left = PourStreamVisual.new()
		add_child(_overflow_stream_left)
	if not is_instance_valid(_overflow_stream_right):
		_overflow_stream_right = PourStreamVisual.new()
		add_child(_overflow_stream_right)

func stop_pour_out() -> void:
	if is_instance_valid(_pour_out_stream):
		_pour_out_stream.set_stream_active(false)

func stop_pour_splash() -> void:
	_pour_splash_timer = 0.0
	_pour_splash_flow_rate = 0.0
	if is_instance_valid(_pour_splash_stream):
		_pour_splash_stream.set_splash_active(false)

func stop_overflow_streams() -> void:
	_overflow_timer = 0.0
	_overflow_flow_rate = 0.0
	if is_instance_valid(_overflow_stream_left):
		_overflow_stream_left.set_stream_active(false)
	if is_instance_valid(_overflow_stream_right):
		_overflow_stream_right.set_stream_active(false)

func stop_all() -> void:
	stop_pour_out()
	stop_pour_splash()
	stop_overflow_streams()

func trigger_pour_splash(splash_color: Color, liquids_num: float, pour_info: Dictionary) -> void:
	_pour_splash_color = splash_color
	_pour_splash_entry_u = clampf(float(pour_info.get("entry_u", 0.5)), 0.15, 0.85)
	var target_flow := clampf(liquids_num / 0.0825, 0.25, 1.8)
	_pour_splash_flow_rate = lerpf(_pour_splash_flow_rate, target_flow, 0.5) if _pour_splash_timer > 0.0 else target_flow
	_pour_splash_timer = POUR_SPLASH_HOLD_TIME

func trigger_overflow_spilling(overflow_color: Color, overflow: float) -> void:
	_overflow_color = overflow_color
	var tick_rate := overflow / 0.033
	var target_flow := clampf(tick_rate / 2.5, 0.28, 1.35)
	_overflow_flow_rate = lerpf(_overflow_flow_rate, target_flow, 0.5) if _overflow_timer > 0.0 else target_flow
	_overflow_timer = OVERFLOW_STREAM_HOLD_TIME

func update_all(delta: float, glass: Glasses, sp: Sprite3D, camera: Camera3D) -> void:
	ensure_streams()
	_update_pour_out_stream(glass, sp)
	_update_pour_splash(delta, glass, sp, camera)
	_update_overflow_streams(delta, glass, sp, camera)

func _update_pour_out_stream(glass: Glasses, sp: Sprite3D) -> void:
	if glass.is_pouring_out and glass._is_actively_pouring_out and glass.can_pour_out_from_mouth():
		var spout_pos := glass.get_pour_spout_world_position()
		var outward_x := Vector3.RIGHT
		if is_instance_valid(sp):
			var sign_dir := -1.0 if glass.pour_tilt_degrees >= 0.0 else 1.0
			outward_x = (sp.global_transform.basis.x * sign_dir).normalized()
		var eject_dir := (outward_x * 0.35 + Vector3(0.0, -0.92, 0.0)).normalized()
		var end_pos := Vector3(spout_pos.x, spout_pos.y - 2.2, spout_pos.z)
		var flow_rate := clampf(absf(glass.pour_tilt_degrees) / 65.0, 0.25, 1.8)
		_pour_out_stream.set_stream_active(true, spout_pos, end_pos, glass.get_top_liquid_color(), flow_rate, eject_dir, false, false)
	else:
		_pour_out_stream.set_stream_active(false)

func _update_pour_splash(delta: float, glass: Glasses, sp: Sprite3D, camera: Camera3D) -> void:
	if _pour_splash_timer <= 0.0 or glass.is_consumed or glass.is_pouring_out:
		_pour_splash_timer = 0.0
		_pour_splash_stream.set_splash_active(false)
		return

	_pour_splash_timer = maxf(0.0, _pour_splash_timer - delta)
	if not is_instance_valid(sp):
		_pour_splash_stream.set_splash_active(false)
		return

	var fill_ratio := clampf(glass.total_liquids / maxf(glass.size, 0.001), 0.05, 0.96)
	var impact_pos := SpriteSpoutUtils.get_sprite_surface_world_position(sp, fill_ratio, _pour_splash_entry_u)
	var active_cam := camera if is_instance_valid(camera) else glass.get_viewport().get_camera_3d()
	var cam_dir := (active_cam.global_position - impact_pos).normalized() if is_instance_valid(active_cam) else -sp.global_transform.basis.z.normalized()
	var spawn_pos := impact_pos + cam_dir * 0.008
	_pour_splash_stream.set_splash_active(true, spawn_pos, _pour_splash_color, _pour_splash_flow_rate, impact_pos.y)

func _compute_edge_outward_dir(edge_pos: Vector3, center_pos: Vector3, up_axis: Vector3, fallback: Vector3) -> Vector3:
	var outward := edge_pos - center_pos
	outward -= up_axis * outward.dot(up_axis)
	outward.y = 0.0
	if outward.length_squared() > 0.000001:
		return outward.normalized()
	var flat_fallback := Vector3(fallback.x, 0.0, fallback.z)
	if flat_fallback.length_squared() > 0.000001:
		return flat_fallback.normalized()
	return Vector3.RIGHT

func _update_overflow_streams(delta: float, glass: Glasses, sp: Sprite3D, camera: Camera3D) -> void:
	if _overflow_timer <= 0.0 or glass.is_consumed or glass.is_pouring_out or glass.total_liquids <= 0.001:
		_overflow_timer = 0.0
		_overflow_stream_left.set_stream_active(false)
		_overflow_stream_right.set_stream_active(false)
		return

	_overflow_timer = maxf(0.0, _overflow_timer - delta)
	if not is_instance_valid(sp):
		_overflow_stream_left.set_stream_active(false)
		_overflow_stream_right.set_stream_active(false)
		return

	var edges := SpriteSpoutUtils.get_sprite_rim_edges_world_positions(sp)
	var center_pos: Vector3 = edges["center"]
	var left_edge: Vector3 = edges["left"]
	var right_edge: Vector3 = edges["right"]

	var is_on_counter := not glass.in_game and absf(glass.global_position.y - glass.get_working_area_surface_y()) <= 0.08
	var floor_y := left_edge.y - 2.2
	if is_on_counter:
		var bounds = WorkingAreaService.get_working_area_bounds(glass)
		floor_y = ((bounds as AABB).end.y + 0.002) if (bounds is AABB) else SpriteSpoutUtils.get_sprite_surface_world_position(sp, 0.0).y

	var basis_x := sp.global_transform.basis.x.normalized()
	var basis_y := sp.global_transform.basis.y.normalized()
	var active_cam := camera if is_instance_valid(camera) else glass.get_viewport().get_camera_3d()
	var cam_dir := (active_cam.global_position - center_pos).normalized() if is_instance_valid(active_cam) else -sp.global_transform.basis.z.normalized()

	var left_outward := _compute_edge_outward_dir(left_edge, center_pos, basis_y, -basis_x)
	var right_outward := _compute_edge_outward_dir(right_edge, center_pos, basis_y, basis_x)

	var left_spawn := left_edge + left_outward * 0.003 + cam_dir * 0.004
	var right_spawn := right_edge + right_outward * 0.003 + cam_dir * 0.004

	var left_end := Vector3(left_spawn.x, floor_y if is_on_counter else (left_spawn.y - 2.2), left_spawn.z)
	var right_end := Vector3(right_spawn.x, floor_y if is_on_counter else (right_spawn.y - 2.2), right_spawn.z)

	var left_dir := (left_outward * 0.48 + Vector3.DOWN * 0.88).normalized()
	var right_dir := (right_outward * 0.48 + Vector3.DOWN * 0.88).normalized()

	_overflow_stream_left.set_stream_active(true, left_spawn, left_end, _overflow_color, _overflow_flow_rate, left_dir, false, false)
	_overflow_stream_right.set_stream_active(true, right_spawn, right_end, _overflow_color, _overflow_flow_rate, right_dir, false, false)