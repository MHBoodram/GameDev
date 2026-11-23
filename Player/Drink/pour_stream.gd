class_name PourStreamVisual
extends Node3D
# Renders mid-pour liquid
const MAX_PIXELS := 280
const GRAVITY := 5.4
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
var _active_count: int = 0
var _active: bool = false
var _splash_mode: bool = false
var _start_pos: Vector3 = Vector3.ZERO
var _end_pos: Vector3 = Vector3.ZERO
var _rim_pos: Vector3 = Vector3.ZERO
var _has_rim_pos: bool = false
var _eject_dir: Vector3 = Vector3.DOWN
var _color: Color = Color.WHITE
var _flow_rate: float = 0.0
var _snap_to_target: bool = true
var _enable_splash: bool = true
var _arrival_vel: Vector3 = Vector3(0.0, -1.5, 0.0)
var _spawn_accum: float = 0.0

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
	rim_pos: Variant = null
) -> void:
	_splash_mode = false
	_active = active and flow_rate > 0.01
	_start_pos = start_pos
	_end_pos = end_pos
	_has_rim_pos = rim_pos is Vector3
	_rim_pos = (rim_pos as Vector3) if _has_rim_pos else end_pos
	_color = Color(color.r, color.g, color.b, 1.0)
	_flow_rate = clampf(flow_rate, 0.0, 2.0)
	_eject_dir = eject_dir.normalized() if eject_dir.length_squared() > 0.0001 else Vector3.DOWN
	_snap_to_target = snap_to_target
	_enable_splash = enable_splash
	if not _active:
		_spawn_accum = 0.0

func set_splash_active(
	active: bool,
	pos: Vector3 = Vector3.ZERO,
	color: Color = Color.WHITE,
	flow_rate: float = 1.0,
	surface_y: float = -9999.0
) -> void:
	_splash_mode = true
	_active = active and flow_rate > 0.01
	_start_pos = pos
	_end_pos = Vector3(pos.x, surface_y if surface_y > -9000.0 else pos.y, pos.z)
	_has_rim_pos = false
	_rim_pos = _end_pos
	_color = Color(color.r, color.g, color.b, 1.0)
	_flow_rate = clampf(flow_rate, 0.0, 2.0)
	if not _active:
		_spawn_accum = 0.0

func get_arrival_velocity() -> Vector3:
	return _arrival_vel

func _compute_launch_velocity() -> Vector3:
	if _snap_to_target:
		var aim_pos := _rim_pos if _has_rim_pos else _end_pos
		var delta_pos := aim_pos - _start_pos
		var drop_h := maxf(-delta_pos.y, 0.04)
		var flight_time := clampf(sqrt((2.0 * drop_h) / GRAVITY), 0.12, 0.34)
		var vx := delta_pos.x / flight_time
		var vz := delta_pos.z / flight_time
		var vy := (delta_pos.y + 0.5 * GRAVITY * flight_time * flight_time) / flight_time
		var launch_v := Vector3(vx, vy, vz)
		_arrival_vel = Vector3(vx * 0.25, vy - GRAVITY * flight_time, vz * 0.25)
		return launch_v
	var eject_speed := lerpf(0.16, 0.42, clampf(_flow_rate * 0.5, 0.0, 1.0))
	var free_v := _eject_dir * eject_speed
	_arrival_vel = free_v + Vector3(0.0, -1.6, 0.0)
	return free_v

func _add_pixel(pos: Vector3, vel: Vector3, col: Color, size: float, max_life: float, target_y: float, rim_y: float, is_splash: bool) -> void:
	if _active_count >= MAX_PIXELS:
		return
	var i := _active_count
	_p_pos[i] = pos
	_p_vel[i] = vel
	_p_col[i] = col
	_p_size[i] = size
	_p_life[i] = 0.0
	_p_max_life[i] = max_life
	_p_target_y[i] = target_y
	_p_rim_y[i] = rim_y
	_p_is_splash[i] = 1 if is_splash else 0
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
	_active_count = last

func _vary_pixel_color(base: Color) -> Color:
	var r := randf()
	if r < 0.18:
		return base.lightened(0.28)
	if r < 0.40:
		return base.darkened(0.14)
	return base

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	var dt := minf(delta, 0.05)
	if _active:
		var px_size := 1.0 / LiquidVisualHelper.UNIFORM_PIXEL_DENSITY
		if _splash_mode:
			var pixels_per_sec := lerpf(35.0, 100.0, clampf(_flow_rate * 0.5, 0.0, 1.0))
			_spawn_accum += pixels_per_sec * dt
			var to_spawn := int(_spawn_accum)
			_spawn_accum -= float(to_spawn)
			var cam_spawn := get_viewport().get_camera_3d()
			var cam_right := cam_spawn.global_transform.basis.x.normalized() if cam_spawn else Vector3.RIGHT
			var cam_fwd := cam_spawn.global_transform.basis.z.normalized() if cam_spawn else Vector3.BACK
			var flow_scale := lerpf(0.7, 1.25, clampf(_flow_rate * 0.5, 0.0, 1.0))
			var surface_y := _end_pos.y
			for _s_i in to_spawn:
				var horiz_speed := randf_range(-0.28, 0.28) * flow_scale
				var up_speed := randf_range(0.16, 0.36) * flow_scale
				var depth_speed := randf_range(0.0, 0.05) * flow_scale
				var v := cam_right * horiz_speed + Vector3.UP * up_speed + cam_fwd * depth_speed
				var p := _start_pos + cam_right * randf_range(-0.008, 0.008) + Vector3.UP * randf_range(0.0, 0.004)
				_add_pixel(
					p,
					v,
					_vary_pixel_color(_color).lightened(0.16),
					px_size * randf_range(0.55, 0.85),
					randf_range(0.10, 0.20),
					surface_y,
					-9999.0,
					true
				)
		else:
			var base_vel := _compute_launch_velocity()
			var pixels_per_sec := lerpf(60.0, 175.0, clampf(_flow_rate * 0.5, 0.0, 1.0))
			_spawn_accum += pixels_per_sec * dt
			var to_spawn := int(_spawn_accum)
			_spawn_accum -= float(to_spawn)
			var nozzle_spread := lerpf(0.0022, 0.0055, clampf(_flow_rate * 0.5, 0.0, 1.0))
			var use_end_y := _snap_to_target or _enable_splash or _end_pos != Vector3.ZERO
			var target_y := _end_pos.y if use_end_y else (_start_pos.y - 2.2)
			var rim_y := (_rim_pos.y if _has_rim_pos else target_y) if _snap_to_target else -9999.0
			for s_i in to_spawn:
				var sub_t := (float(s_i) / maxf(float(to_spawn), 1.0)) * dt
				var jitter_pos := Vector3(
					randf_range(-nozzle_spread, nozzle_spread),
					randf_range(-nozzle_spread * 0.5, nozzle_spread * 0.5),
					randf_range(-nozzle_spread, nozzle_spread)
				)
				var jitter_vel := Vector3(
					randf_range(-0.035, 0.035),
					randf_range(-0.07, 0.07),
					randf_range(-0.025, 0.025)
				)
				var v := base_vel + jitter_vel
				var p := _start_pos + jitter_pos + v * sub_t
				_add_pixel(p, v, _vary_pixel_color(_color), px_size, 0.9, target_y, rim_y, false)
	var horiz_damp := exp(-14.0 * dt)
	var i := 0
	while i < _active_count:
		_p_life[i] += dt
		var v := _p_vel[i]
		v.y -= GRAVITY * dt
		var splash := _p_is_splash[i] == 1
		if not splash and _p_pos[i].y <= _p_rim_y[i]:
			v.x *= horiz_damp
			v.z *= horiz_damp
		var p := _p_pos[i] + v * dt
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
					_p_vel[i] = Vector3(randf_range(-0.16, 0.16), randf_range(0.09, 0.22), randf_range(-0.05, 0.05))
					_p_col[i] = _p_col[i].lightened(0.18)
					_p_size[i] = _p_size[i] * 0.72
					_p_life[i] = 0.0
					_p_max_life[i] = randf_range(0.07, 0.13)
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