class_name PourStreamVisual
extends Node3D
# Renders mid-pour liquid
const MAX_PIXELS := 280
const GRAVITY := 5.4

const SPLASH_PIXELS_PER_SEC_MIN := 42.0
const SPLASH_PIXELS_PER_SEC_MAX := 115.0
const SPLASH_HORIZ_SPEED := 0.34
const SPLASH_UP_SPEED_MIN := 0.30
const SPLASH_UP_SPEED_MAX := 0.58
const SPLASH_DEPTH_SPEED := 0.06
const SPLASH_FLOW_SCALE_MIN := 0.72
const SPLASH_FLOW_SCALE_MAX := 1.28
const SPLASH_SIZE_MIN := 0.60
const SPLASH_SIZE_MAX := 0.92
const SPLASH_LIFE_MIN := 0.16
const SPLASH_LIFE_MAX := 0.30

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
			var flow_t := clampf(_flow_rate * 0.5, 0.0, 1.0)
			_spawn_accum += lerpf(SPLASH_PIXELS_PER_SEC_MIN, SPLASH_PIXELS_PER_SEC_MAX, flow_t) * dt
			var to_spawn := int(_spawn_accum)
			_spawn_accum -= float(to_spawn)
			var cam_spawn := get_viewport().get_camera_3d()
			var cam_right := cam_spawn.global_transform.basis.x.normalized() if cam_spawn else Vector3.RIGHT
			var cam_fwd := cam_spawn.global_transform.basis.z.normalized() if cam_spawn else Vector3.BACK
			var flow_scale := lerpf(SPLASH_FLOW_SCALE_MIN, SPLASH_FLOW_SCALE_MAX, flow_t)
			for _s_i in to_spawn:
				var v := cam_right * (randf_range(-SPLASH_HORIZ_SPEED, SPLASH_HORIZ_SPEED) * flow_scale) + Vector3.UP * (randf_range(SPLASH_UP_SPEED_MIN, SPLASH_UP_SPEED_MAX) * flow_scale) + cam_fwd * (randf_range(0.0, SPLASH_DEPTH_SPEED) * flow_scale)
				var p := _start_pos + cam_right * randf_range(-0.008, 0.008) + Vector3.UP * randf_range(0.0, 0.005)
				_add_pixel(p, v, _vary_pixel_color(_color).lightened(0.16), px_size * randf_range(SPLASH_SIZE_MIN, SPLASH_SIZE_MAX), randf_range(SPLASH_LIFE_MIN, SPLASH_LIFE_MAX), _end_pos.y, -9999.0, true)
		else:
			var base_vel := _compute_launch_velocity()
			_spawn_accum += lerpf(60.0, 175.0, clampf(_flow_rate * 0.5, 0.0, 1.0)) * dt
			var to_spawn := int(_spawn_accum)
			_spawn_accum -= float(to_spawn)
			var spread := lerpf(0.0022, 0.0055, clampf(_flow_rate * 0.5, 0.0, 1.0))
			var target_y := _end_pos.y if (_snap_to_target or _enable_splash or _end_pos != Vector3.ZERO) else (_start_pos.y - 2.2)
			var rim_y := (_rim_pos.y if _has_rim_pos else target_y) if _snap_to_target else -9999.0
			for s_i in to_spawn:
				var sub_t := (float(s_i) / maxf(float(to_spawn), 1.0)) * dt
				var v := base_vel + Vector3(randf_range(-0.035, 0.035), randf_range(-0.07, 0.07), randf_range(-0.025, 0.025))
				var p := _start_pos + Vector3(randf_range(-spread, spread), randf_range(-spread * 0.5, spread * 0.5), randf_range(-spread, spread)) + v * sub_t
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
		elif p.y <= _p_target_y[i] or _p_life[i] >= _p_max_life[i]:
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
	for idx in _active_count:
		var s := _p_size[idx]
		_multi_mesh.set_instance_transform(idx, Transform3D(Basis(cb.x * s, cb.y * s, cb.z * s), _p_pos[idx]))
		_multi_mesh.set_instance_color(idx, _p_col[idx])
	_multi_mesh.visible_instance_count = _active_count
	_mm_instance.visible = true