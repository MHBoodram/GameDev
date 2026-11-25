@tool
class_name PourStreamVisual
extends Node3D
# Renders mid-pour liquid
const MAX_PIXELS := 280
const GRAVITY := 5.4

const POUR_SIZE_MIN_SHALLOW := 0.38
const POUR_SIZE_MAX_SHALLOW := 0.88
const POUR_SIZE_MIN_SHARP := 0.75
const POUR_SIZE_MAX_SHARP := 1.70
const POUR_PPS_SHALLOW := 24.0
const POUR_PPS_SHARP := 125.0
const POUR_SPREAD_SHALLOW := 0.0055
const POUR_SPREAD_SHARP := 0.0110

const SPILL_SIZE_MIN := 0.45
const SPILL_SIZE_MAX := 1.05
const SPILL_PPS := 55.0
const SPILL_SPREAD := 0.0050

const SPLASH_PIXELS_PER_SEC_MIN := 36.0
const SPLASH_PIXELS_PER_SEC_MAX := 85.0
const SPLASH_HORIZ_SPEED := 0.16
const SPLASH_UP_SPEED_MIN := 0.42
const SPLASH_UP_SPEED_MAX := 0.72
const SPLASH_DEPTH_SPEED := 0.0
const SPLASH_FLOW_SCALE_MIN := 0.75
const SPLASH_FLOW_SCALE_MAX := 1.15
const SPLASH_SIZE_MIN := 0.65
const SPLASH_SIZE_MAX := 1.00
const SPLASH_LIFE_MIN := 0.16
const SPLASH_LIFE_MAX := 0.28

class SnapZoneHelper extends RefCounted:
	var active_glass: Glasses = null
	var glasses_in_area: Array[Glasses] = []
	var on_glass_activated: Callable = Callable()
	var on_glass_deactivated: Callable = Callable()

	func _activate(glass: Glasses, snap_target: Node3D, pull_speed: float, release_speed: float, break_distance: float) -> void:
		active_glass = glass
		if on_glass_activated.is_valid():
			on_glass_activated.call(glass)
		glass.enter_snap_zone(snap_target, pull_speed, release_speed, break_distance)

	func _deactivate(glass: Glasses) -> void:
		if on_glass_deactivated.is_valid():
			on_glass_deactivated.call(glass)

	func promote_next(snap_target: Node3D, pull_speed: float, release_speed: float, break_distance: float) -> void:
		for g in glasses_in_area:
			if is_instance_valid(g):
				_activate(g, snap_target, pull_speed, release_speed, break_distance)
				break

	func _remove_area_entry(area: Area3D) -> void:
		for i in range(glasses_in_area.size() - 1, -1, -1):
			var g := glasses_in_area[i]
			if not is_instance_valid(g) or g == area:
				glasses_in_area.remove_at(i)

	func handle_area_entered(area: Area3D, snap_target: Node3D, pull_speed: float, release_speed: float, break_distance: float) -> void:
		if not (area is Glasses) or not area.is_in_group("glass"):
			return
		var glass := area as Glasses
		if not glasses_in_area.has(glass):
			glasses_in_area.append(glass)
		if not is_instance_valid(active_glass):
			_activate(glass, snap_target, pull_speed, release_speed, break_distance)

	func handle_area_exited(area: Area3D, snap_target: Node3D, pull_speed: float, release_speed: float, break_distance: float) -> void:
		if glasses_in_area.size() > 0:
			_remove_area_entry(area)
		if area == active_glass:
			if is_instance_valid(area):
				var glass := area as Glasses
				glass.exit_snap_zone(snap_target)
				_deactivate(glass)
				glass._remove_displaying_list()
			active_glass = null
			promote_next(snap_target, pull_speed, release_speed, break_distance)

	func release_glass(glass: Glasses) -> void:
		if not is_instance_valid(glass):
			return
		glasses_in_area.erase(glass)
		if active_glass == glass:
			active_glass = null
		_deactivate(glass)
		glass._remove_displaying_list()

static var _sprite_anchor_cache: Dictionary = {}
var _mm_instance: MultiMeshInstance3D = null
var _multi_mesh: MultiMesh = null
var _p_pos: PackedVector3Array = PackedVector3Array()
var _p_vel: PackedVector3Array = PackedVector3Array()
var _p_col: PackedColorArray = PackedColorArray()
var _p_size: PackedFloat32Array = PackedFloat32Array()
var _p_life: PackedFloat32Array = PackedFloat32Array()
var _p_max_life: PackedFloat32Array = PackedFloat32Array()
var _p_target_y: PackedFloat32Array = PackedFloat32Array()
var _p_rim_y: PackedFloat32Array = PackedFloat32Array()
var _p_is_splash: PackedByteArray = PackedByteArray()
var _p_is_snapped: PackedByteArray = PackedByteArray()
var _active_count: int = 0
var _active: bool = false
var _splash_mode: bool = false
var _is_spill: bool = false
var _start_pos: Vector3 = Vector3.ZERO
var _end_pos: Vector3 = Vector3.ZERO
var _rim_pos: Vector3 = Vector3.ZERO
var _has_rim_pos: bool = false
var _eject_dir: Vector3 = Vector3.DOWN
var _color: Color = Color.WHITE
var _flow_rate: float = 0.0
var _snap_to_target: bool = true
var _enable_splash: bool = true
var _splash_max_radius: float = -1.0
var _splash_max_top_y: float = 9999.0
var _arrival_vel: Vector3 = Vector3(0.0, -1.5, 0.0)
var _spawn_accum: float = 0.0
var _next_spawn_interval: float = 0.0

static func is_pour_button_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.get_action_strength("Left_click") > 0.0

static func get_pour_height_ratio(viewport: Viewport) -> float:
	if not viewport:
		return 0.5
	var vp_height: float = viewport.get_visible_rect().size.y
	if vp_height <= 1.0:
		return 0.5
	var mouse_y: float = viewport.get_mouse_position().y
	var raw_height: float = 1.0 - clampf(mouse_y / vp_height, 0.0, 1.0)
	var ratio: float = clampf((raw_height - 0.1) / 0.8, 0.0, 1.0)
	if not Engine.is_editor_hint():
		var tree := viewport.get_tree()
		var settings := tree.root.get_node_or_null("SettingState") if (tree and tree.root) else null
		if settings and settings.has_method("is_invert_pouring_angle") and settings.is_invert_pouring_angle():
			return 1.0 - ratio
	return ratio

static func get_pour_rate_multiplier(viewport: Viewport) -> float:
	return get_pour_height_ratio(viewport) * 2.0

static func get_camera_rig(viewport: Viewport) -> Camera3D:
	if not viewport:
		return null
	var cam: Camera3D = viewport.get_camera_3d()
	if cam and cam.has_method("focus_on_marker") and cam.has_method("return_from_marker"):
		return cam
	return null

static func find_scene_marker(context: Node, marker_name: String) -> Node3D:
	if is_instance_valid(context) and context.is_inside_tree():
		var scene_root := context.get_tree().current_scene
		if is_instance_valid(scene_root):
			var marker := scene_root.get_node_or_null(marker_name) as Node3D
			if marker:
				return marker
	if is_instance_valid(GameState.main_node):
		return GameState.main_node.get_node_or_null(marker_name) as Node3D
	return null

static func focus_station_camera(context: Node, marker_name: String, duration: float = 0.55) -> Camera3D:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return null
	var cam_rig: Camera3D = get_camera_rig(context.get_viewport())
	var marker := find_scene_marker(context, marker_name)
	if not cam_rig or not marker:
		return null
	if GameState.gameplay_ui and GameState.gameplay_ui.has_method("_in_down_minigame"):
		GameState.gameplay_ui._in_down_minigame()
	cam_rig.call("focus_on_marker", marker, duration)
	return cam_rig

static func return_station_camera(context: Node, cam_rig: Camera3D, duration: float = 0.55) -> void:
	if not is_instance_valid(cam_rig) or not is_instance_valid(context) or not context.is_inside_tree():
		return
	cam_rig.call("return_from_marker", duration)
	if cam_rig.has_signal("marker_returned"):
		await cam_rig.marker_returned
	if not is_instance_valid(context) or not context.is_inside_tree():
		return
	if GameState.gameplay_ui and GameState.gameplay_ui.has_method("_out_down_minigame"):
		GameState.gameplay_ui._out_down_minigame()

static func play_throttled_pour_sfx(last_sfx_ms: int, interval_ms: int = 100) -> int:
	var now_ms := Time.get_ticks_msec()
	if last_sfx_ms < 0 or now_ms - last_sfx_ms >= interval_ms:
		SFXAudio.play_liquidpour()
		return now_ms
	return last_sfx_ms

static func _get_texture_anchors(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {
			"top_v": 0.1,
			"bottom_v": 0.9,
			"top_center_u": 0.5,
			"top_min_u": 0.2,
			"top_max_u": 0.8,
			"top_min_v": 0.1,
			"top_max_v": 0.1,
		}
	var key := tex.get_rid().get_id()
	if _sprite_anchor_cache.has(key):
		return _sprite_anchor_cache[key]
	var result := {
		"top_v": 0.1,
		"bottom_v": 0.9,
		"top_center_u": 0.5,
		"top_min_u": 0.2,
		"top_max_u": 0.8,
		"top_min_v": 0.1,
		"top_max_v": 0.1,
	}
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		if w > 0 and h > 0:
			var top_y := h
			var bottom_y := -1
			for y in h:
				for x in w:
					if img.get_pixel(x, y).a > 0.1:
						top_y = mini(top_y, y)
						bottom_y = maxi(bottom_y, y)
						break
			if bottom_y >= top_y:
				var band_end := mini(top_y + maxi(2, int(float(h) * 0.08)), bottom_y)
				var min_x := w
				var max_x := -1
				var min_x_y := top_y
				var max_x_y := top_y
				var sum_x := 0.0
				var count_x := 0
				for y in range(top_y, band_end + 1):
					for x in w:
						if img.get_pixel(x, y).a > 0.1:
							if x < min_x:
								min_x = x
								min_x_y = y
							if x > max_x:
								max_x = x
								max_x_y = y
							sum_x += float(x)
							count_x += 1
				result["top_v"] = (float(top_y) + 0.5) / float(h)
				result["bottom_v"] = (float(bottom_y) + 0.5) / float(h)
				if count_x > 0 and max_x >= min_x:
					result["top_center_u"] = (sum_x / float(count_x) + 0.5) / float(w)
					result["top_min_u"] = (float(min_x) + 0.5) / float(w)
					result["top_max_u"] = (float(max_x) + 0.5) / float(w)
					result["top_min_v"] = (float(min_x_y) + 0.5) / float(h)
					result["top_max_v"] = (float(max_x_y) + 0.5) / float(h)
	_sprite_anchor_cache[key] = result
	return result

static func _uv_to_sprite_world(sprite: Sprite3D, u: float, v: float) -> Vector3:
	if not is_instance_valid(sprite):
		return Vector3.ZERO
	var dims: Rect2 = sprite.get_item_rect()
	if dims.size.x <= 0.0 or dims.size.y <= 0.0:
		return sprite.global_position
	var ps := sprite.pixel_size
	var eff_u := (1.0 - u) if sprite.flip_h else u
	var eff_v := (1.0 - v) if sprite.flip_v else v
	var lx := lerpf(dims.position.x, dims.end.x, eff_u) * ps
	var ly := lerpf(dims.end.y, dims.position.y, eff_v) * ps
	return sprite.global_transform * Vector3(lx, ly, 0.0)

static func get_sprite_top_spout_world_position(sprite: Sprite3D) -> Vector3:
	if not is_instance_valid(sprite):
		return Vector3.ZERO
	var anchors := _get_texture_anchors(sprite.texture)
	return _uv_to_sprite_world(sprite, float(anchors["top_center_u"]), float(anchors["top_v"]))

static func get_sprite_rim_spout_world_position(sprite: Sprite3D, tilt_degrees: float = 0.0) -> Vector3:
	if not is_instance_valid(sprite):
		return Vector3.ZERO
	var anchors := _get_texture_anchors(sprite.texture)
	var want_local_neg_x := tilt_degrees >= 0.0
	var u: float
	if want_local_neg_x:
		u = float(anchors["top_max_u"]) if sprite.flip_h else float(anchors["top_min_u"])
	else:
		u = float(anchors["top_min_u"]) if sprite.flip_h else float(anchors["top_max_u"])
	return _uv_to_sprite_world(sprite, u, float(anchors["top_v"]))

static func get_sprite_rim_edges_world_positions(sprite: Sprite3D) -> Dictionary:
	if not is_instance_valid(sprite):
		return {
			"center": Vector3.ZERO,
			"left": Vector3.ZERO,
			"right": Vector3.ZERO,
		}
	var anchors := _get_texture_anchors(sprite.texture)
	var center := _uv_to_sprite_world(sprite, float(anchors["top_center_u"]), float(anchors["top_v"]))
	var min_v := float(anchors.get("top_min_v", anchors["top_v"]))
	var max_v := float(anchors.get("top_max_v", anchors["top_v"]))
	var edge_min := _uv_to_sprite_world(sprite, float(anchors["top_min_u"]), min_v)
	var edge_max := _uv_to_sprite_world(sprite, float(anchors["top_max_u"]), max_v)
	return {
		"center": center,
		"left": edge_max if sprite.flip_h else edge_min,
		"right": edge_min if sprite.flip_h else edge_max,
	}

static func get_sprite_surface_world_position(sprite: Sprite3D, fill_ratio: float, u_override: float = -1.0) -> Vector3:
	if not is_instance_valid(sprite):
		return Vector3.ZERO
	var anchors := _get_texture_anchors(sprite.texture)
	var clamped_fill := clampf(fill_ratio, 0.05, 0.98)
	var v := lerpf(float(anchors["bottom_v"]), float(anchors["top_v"]), clamped_fill)
	var u := clampf(u_override, 0.05, 0.95) if u_override >= 0.0 else float(anchors["top_center_u"])
	return _uv_to_sprite_world(sprite, u, v)

static func world_pos_to_sprite_u(sprite: Sprite3D, world_pos: Vector3) -> float:
	if not is_instance_valid(sprite):
		return 0.5
	var dims: Rect2 = sprite.get_item_rect()
	var ps := sprite.pixel_size
	if dims.size.x <= 0.0 or ps <= 0.000001:
		return 0.5
	var local_p := sprite.global_transform.affine_inverse() * world_pos
	var px_x := local_p.x / ps
	var eff_u := inverse_lerp(dims.position.x, dims.end.x, px_x)
	var u := (1.0 - eff_u) if sprite.flip_h else eff_u
	return clampf(u, 0.0, 1.0)

static func world_vel_to_grid_vel(sprite: Sprite3D, world_vel: Vector3) -> Vector2:
	if not is_instance_valid(sprite) or not sprite.is_inside_tree():
		return Vector2(0.0, 36.0)
	var b := sprite.global_transform.basis
	var axis_x := b.x.normalized()
	var axis_y := b.y.normalized()
	if sprite.flip_h:
		axis_x = -axis_x
	if sprite.flip_v:
		axis_y = -axis_y
	var scale_vel := 18.0
	return Vector2(world_vel.dot(axis_x) * scale_vel, -world_vel.dot(axis_y) * scale_vel)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	top_level = true
	global_transform = Transform3D.IDENTITY
	_p_pos.resize(MAX_PIXELS)
	_p_vel.resize(MAX_PIXELS)
	_p_col.resize(MAX_PIXELS)
	_p_size.resize(MAX_PIXELS)
	_p_life.resize(MAX_PIXELS)
	_p_max_life.resize(MAX_PIXELS)
	_p_target_y.resize(MAX_PIXELS)
	_p_rim_y.resize(MAX_PIXELS)
	_p_is_splash.resize(MAX_PIXELS)
	_p_is_snapped.resize(MAX_PIXELS)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = mat
	_multi_mesh = MultiMesh.new()
	_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_multi_mesh.use_colors = true
	_multi_mesh.mesh = quad
	_multi_mesh.instance_count = MAX_PIXELS
	_multi_mesh.visible_instance_count = 0
	_mm_instance = MultiMeshInstance3D.new()
	_mm_instance.multimesh = _multi_mesh
	_mm_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm_instance.visible = false
	add_child(_mm_instance)

func set_stream_active(
	active: bool,
	start_pos: Vector3 = Vector3.ZERO,
	end_pos: Vector3 = Vector3.ZERO,
	color: Color = Color.WHITE,
	flow_rate: float = 1.0,
	eject_dir: Vector3 = Vector3.DOWN,
	snap_to_target: bool = true,
	enable_splash: bool = true,
	rim_pos: Variant = null,
	is_spill: bool = false
) -> void:
	_splash_mode = false
	_active = active and flow_rate > 0.01
	if active:
		_start_pos = start_pos
		_end_pos = end_pos
		_has_rim_pos = rim_pos is Vector3
		_rim_pos = (rim_pos as Vector3) if _has_rim_pos else end_pos
		_color = Color(color.r, color.g, color.b, 1.0)
		_flow_rate = clampf(flow_rate, 0.0, 2.0)
		_eject_dir = eject_dir.normalized() if eject_dir.length_squared() > 0.0001 else Vector3.DOWN
		_snap_to_target = snap_to_target
		_enable_splash = enable_splash
		_is_spill = is_spill
	if not _active:
		_spawn_accum = 0.0
		_next_spawn_interval = 0.0

func set_splash_active(
	active: bool,
	pos: Vector3 = Vector3.ZERO,
	color: Color = Color.WHITE,
	flow_rate: float = 1.0,
	surface_y: float = -9999.0,
	max_radius: float = -1.0,
	max_top_y: float = 9999.0
) -> void:
	_splash_mode = true
	_active = active and flow_rate > 0.01
	if active:
		_start_pos = pos
		_end_pos = Vector3(pos.x, surface_y if surface_y > -9000.0 else pos.y, pos.z)
		_has_rim_pos = false
		_rim_pos = _end_pos
		_color = Color(color.r, color.g, color.b, 1.0)
		_flow_rate = clampf(flow_rate, 0.0, 2.0)
		_splash_max_radius = max_radius
		_splash_max_top_y = max_top_y
	if not _active:
		_spawn_accum = 0.0
		_next_spawn_interval = 0.0

func get_arrival_velocity() -> Vector3:
	return _arrival_vel

func _compute_snapped_flight_time() -> float:
	var arc_len := maxf(_start_pos.distance_to(_end_pos), 0.04)
	var down_speed := 0.55 if _is_spill else lerpf(0.35, 0.85, clampf(_flow_rate * 0.5, 0.0, 1.0))
	var flight_time := (-down_speed + sqrt(down_speed * down_speed + 2.0 * GRAVITY * arc_len)) / GRAVITY
	return clampf(flight_time, 0.06, 0.45)

func _compute_launch_velocity() -> Vector3:
	if _snap_to_target:
		var flight_time := _compute_snapped_flight_time()
		var down_speed := 0.55 if _is_spill else lerpf(0.35, 0.85, clampf(_flow_rate * 0.5, 0.0, 1.0))
		var arrival_speed := down_speed + GRAVITY * flight_time
		_arrival_vel = Vector3(0.0, -arrival_speed, 0.0)
		return Vector3(0.0, -down_speed, 0.0)
	var eject_speed := lerpf(0.16, 0.42, clampf(_flow_rate * 0.5, 0.0, 1.0))
	var free_v := _eject_dir * eject_speed
	_arrival_vel = free_v + Vector3(0.0, -1.6, 0.0)
	return free_v

func _add_pixel(pos: Vector3, vel: Vector3, col: Color, size: float, max_life: float, target_y: float, rim_y: float, is_splash: bool, is_snapped: bool = false, initial_life: float = 0.0) -> void:
	if _active_count >= MAX_PIXELS:
		return
	var i := _active_count
	_p_pos[i] = pos
	_p_vel[i] = vel
	_p_col[i] = col
	_p_size[i] = size
	_p_life[i] = initial_life
	_p_max_life[i] = max_life
	_p_target_y[i] = target_y
	_p_rim_y[i] = rim_y
	_p_is_splash[i] = 1 if is_splash else 0
	_p_is_snapped[i] = 1 if is_snapped else 0
	_active_count += 1

func _remove_pixel(idx: int) -> void:
	var last := _active_count - 1
	if idx < last:
		_p_pos[idx] = _p_pos[last]
		_p_vel[idx] = _p_vel[last]
		_p_col[idx] = _p_col[last]
		_p_size[idx] = _p_size[last]
		_p_life[idx] = _p_life[last]
		_p_max_life[idx] = _p_max_life[last]
		_p_target_y[idx] = _p_target_y[last]
		_p_rim_y[idx] = _p_rim_y[last]
		_p_is_splash[idx] = _p_is_splash[last]
		_p_is_snapped[idx] = _p_is_snapped[last]
	_active_count = last

func _vary_pixel_color(base: Color) -> Color:
	var r := randf()
	if r < 0.18:
		return base.lightened(0.28)
	if r < 0.40:
		return base.darkened(0.14)
	return base

func _spawn_particles(dt: float, px_size: float) -> void:
	var flow_t := clampf(_flow_rate * 0.5, 0.0, 1.0)
	var cam_spawn := get_viewport().get_camera_3d()
	var cam_right := cam_spawn.global_transform.basis.x.normalized() if cam_spawn else Vector3.RIGHT
	var cam_fwd := cam_spawn.global_transform.basis.z.normalized() if cam_spawn else Vector3.BACK
	_spawn_accum += dt

	if _splash_mode:
		var pixels_per_sec := lerpf(SPLASH_PIXELS_PER_SEC_MIN, SPLASH_PIXELS_PER_SEC_MAX, flow_t)
		var avg_interval := 1.0 / maxf(pixels_per_sec, 1.0)
		var flow_scale := lerpf(SPLASH_FLOW_SCALE_MIN, SPLASH_FLOW_SCALE_MAX, flow_t)
		var surface_y := _end_pos.y
		while _spawn_accum >= _next_spawn_interval:
			_spawn_accum -= _next_spawn_interval
			var age := clampf(_spawn_accum, 0.0, dt)
			_next_spawn_interval = maxf(avg_interval * randf_range(0.35, 1.85), 0.001)
			if _active_count >= MAX_PIXELS:
				break
			var horiz_speed := randf_range(-SPLASH_HORIZ_SPEED, SPLASH_HORIZ_SPEED) * flow_scale
			var up_speed := randf_range(SPLASH_UP_SPEED_MIN, SPLASH_UP_SPEED_MAX) * flow_scale
			var depth_speed := randf_range(-SPLASH_DEPTH_SPEED, SPLASH_DEPTH_SPEED) * flow_scale
			var v := cam_right * horiz_speed + Vector3.UP * up_speed + cam_fwd * depth_speed
			var p := _start_pos + cam_right * randf_range(-0.004, 0.004) + Vector3.UP * randf_range(0.001, 0.004) + cam_fwd * 0.002 + v * (age - dt)
			_add_pixel(
				p,
				v,
				_vary_pixel_color(_color).lightened(0.16),
				px_size * randf_range(SPLASH_SIZE_MIN, SPLASH_SIZE_MAX),
				randf_range(SPLASH_LIFE_MIN, SPLASH_LIFE_MAX),
				surface_y,
				-9999.0,
				true,
				false,
				age - dt
			)
		return

	var angle_t := clampf((_flow_rate - 0.2) / 1.8, 0.0, 1.0)
	var stream_pixels_per_sec := SPILL_PPS if _is_spill else lerpf(POUR_PPS_SHALLOW, POUR_PPS_SHARP, angle_t)
	var stream_avg_interval := 1.0 / maxf(stream_pixels_per_sec, 1.0)
	var size_min := SPILL_SIZE_MIN if _is_spill else lerpf(POUR_SIZE_MIN_SHALLOW, POUR_SIZE_MIN_SHARP, angle_t)
	var size_max := SPILL_SIZE_MAX if _is_spill else lerpf(POUR_SIZE_MAX_SHALLOW, POUR_SIZE_MAX_SHARP, angle_t)
	var horiz_spread := SPILL_SPREAD if _is_spill else lerpf(POUR_SPREAD_SHALLOW, POUR_SPREAD_SHARP, angle_t)
	var vert_spread := 0.0020 if _is_spill else lerpf(0.0015, 0.0035, angle_t)
	var depth_spread := 0.0020

	if _snap_to_target:
		var flight_time := _compute_snapped_flight_time()
		var down_speed := 0.55 if _is_spill else lerpf(0.35, 0.85, flow_t)
		_arrival_vel = Vector3(0.0, -(down_speed + GRAVITY * flight_time), 0.0)
		var target_y := _end_pos.y
		var rim_y := _rim_pos.y if _has_rim_pos else target_y
		while _spawn_accum >= _next_spawn_interval:
			_spawn_accum -= _next_spawn_interval
			var age := clampf(_spawn_accum, 0.0, dt)
			_next_spawn_interval = maxf(stream_avg_interval * randf_range(0.25, 2.20), 0.001)
			if _active_count >= MAX_PIXELS:
				break
			var jitter_offset := (
				cam_right * randf_range(-horiz_spread, horiz_spread)
				+ Vector3.UP * randf_range(-vert_spread, vert_spread)
				+ cam_fwd * randf_range(-depth_spread, depth_spread)
			)
			var p_life := flight_time * randf_range(0.86, 1.16)
			var p_size := px_size * randf_range(size_min, size_max)
			_add_pixel(_start_pos + jitter_offset, jitter_offset, _vary_pixel_color(_color), p_size, p_life, target_y, rim_y, false, true, age - dt)
	else:
		var base_vel := _compute_launch_velocity()
		var use_end_y := _enable_splash or _end_pos != Vector3.ZERO
		var target_y := _end_pos.y if use_end_y else (_start_pos.y - 2.2)
		var rim_y := -9999.0
		while _spawn_accum >= _next_spawn_interval:
			_spawn_accum -= _next_spawn_interval
			var age := clampf(_spawn_accum, 0.0, dt)
			_next_spawn_interval = maxf(stream_avg_interval * randf_range(0.25, 2.20), 0.001)
			if _active_count >= MAX_PIXELS:
				break
			var jitter_pos := (
				cam_right * randf_range(-horiz_spread, horiz_spread)
				+ Vector3.UP * randf_range(-vert_spread, vert_spread)
				+ cam_fwd * randf_range(-depth_spread, depth_spread)
			)
			var jitter_vel := Vector3(
				randf_range(-0.025, 0.025),
				randf_range(-0.06, 0.06),
				randf_range(-0.012, 0.012)
			)
			var v := base_vel + jitter_vel
			var p := _start_pos + jitter_pos + v * (age - dt)
			var p_size := px_size * randf_range(size_min, size_max)
			_add_pixel(p, v, _vary_pixel_color(_color), p_size, 0.9, target_y, rim_y, false, false, age - dt)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_inside_tree():
		return
	var dt := minf(delta, 0.05)
	if _active:
		var px_size := 1.0 / LiquidVisualHelper.UNIFORM_PIXEL_DENSITY
		_spawn_particles(dt, px_size)

	var p0 := _start_pos
	var p3 := _end_pos
	var drop_h := maxf(p0.y - p3.y, 0.03)
	var end_handle := clampf(drop_h * 0.48, 0.025, 0.22)
	var start_drop := clampf(drop_h * 0.12, 0.006, 0.04)
	var p1 := Vector3(
		lerpf(p0.x, p3.x, 0.65),
		p0.y - start_drop,
		lerpf(p0.z, p3.z, 0.65)
	)
	var p2 := Vector3(p3.x, p3.y + end_handle, p3.z)

	var i := 0
	while i < _active_count:
		_p_life[i] += dt
		var splash := _p_is_splash[i] == 1
		if not splash and _p_is_snapped[i] == 1:
			if _p_life[i] >= _p_max_life[i]:
				if _enable_splash:
					_p_pos[i] = Vector3(p3.x + _p_vel[i].x * 0.5, p3.y + 0.002, p3.z + _p_vel[i].z * 0.5)
					_p_vel[i] = Vector3(randf_range(-SPLASH_HORIZ_SPEED, SPLASH_HORIZ_SPEED) * 0.55, randf_range(SPLASH_UP_SPEED_MIN, SPLASH_UP_SPEED_MAX) * 0.45, randf_range(-0.01, 0.01))
					_p_col[i] = _p_col[i].lightened(0.16)
					_p_size[i] = _p_size[i] * randf_range(0.65, 0.90)
					_p_life[i] = 0.0
					_p_max_life[i] = randf_range(0.08, 0.15)
					_p_target_y[i] = p3.y
					_p_is_splash[i] = 1
					_p_is_snapped[i] = 0
					i += 1
					continue
				_remove_pixel(i)
				continue
			var u := clampf(_p_life[i] / maxf(_p_max_life[i], 0.001), 0.0, 1.0)
			var s := lerpf(u, u * u, 0.40)
			var omt := 1.0 - s
			var b0 := omt * omt * omt
			var b1 := 3.0 * omt * omt * s
			var b2 := 3.0 * omt * s * s
			var b3 := s * s * s
			var curve_pos := p0 * b0 + p1 * b1 + p2 * b2 + p3 * b3
			_p_pos[i] = curve_pos + _p_vel[i] * lerpf(0.85, 0.70, s)
			i += 1
			continue

		var v := _p_vel[i]
		v.y -= GRAVITY * dt
		var p := _p_pos[i] + v * dt
		if splash:
			if _splash_max_radius > 0.0:
				var flat_off := Vector2(p.x - _start_pos.x, p.z - _start_pos.z)
				var flat_dist := flat_off.length()
				if flat_dist > _splash_max_radius and flat_dist > 0.0001:
					var clamped_flat := flat_off * (_splash_max_radius / flat_dist)
					p.x = _start_pos.x + clamped_flat.x
					p.z = _start_pos.z + clamped_flat.y
					v.x *= -0.25
					v.z *= -0.25
			var splash_ceiling := _splash_max_top_y + 0.012
			if p.y > splash_ceiling and v.y > 0.0:
				p.y = splash_ceiling
				v.y = 0.0
		_p_vel[i] = v
		_p_pos[i] = p
		if splash:
			if _p_life[i] >= _p_max_life[i] or (v.y < 0.0 and p.y <= _p_target_y[i]):
				_remove_pixel(i)
				continue
		else:
			if p.y <= _p_target_y[i] or _p_life[i] >= _p_max_life[i]:
				if _enable_splash and p.y <= _p_target_y[i]:
					_p_pos[i] = Vector3(p.x, _p_target_y[i] + 0.002, p.z)
					_p_vel[i] = Vector3(randf_range(-SPLASH_HORIZ_SPEED, SPLASH_HORIZ_SPEED) * 0.55, randf_range(SPLASH_UP_SPEED_MIN, SPLASH_UP_SPEED_MAX) * 0.45, randf_range(-0.01, 0.01))
					_p_col[i] = _p_col[i].lightened(0.16)
					_p_size[i] = _p_size[i] * randf_range(0.65, 0.90)
					_p_life[i] = 0.0
					_p_max_life[i] = randf_range(0.08, 0.15)
					_p_is_splash[i] = 1
					i += 1
					continue
				_remove_pixel(i)
				continue
		i += 1
	if _active_count <= 0:
		_mm_instance.visible = false
		_multi_mesh.visible_instance_count = 0
		return
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var cb := cam.global_transform.basis
	var bx := cb.x
	var by := cb.y
	var bz := cb.z
	for idx in _active_count:
		var s := _p_size[idx]
		var xf := Transform3D(Basis(bx * s, by * s, bz * s), _p_pos[idx])
		_multi_mesh.set_instance_transform(idx, xf)
		_multi_mesh.set_instance_color(idx, _p_col[idx])
	_multi_mesh.visible_instance_count = _active_count
	_mm_instance.visible = true