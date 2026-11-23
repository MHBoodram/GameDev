class_name LiquidSim
extends Node3D

const MAX_PARTICLES: int = 1024
const WORLD_GRAVITY: float = 4.8
const NUM_CAVITY_SLICES: int = 32
const BEER_FOAM_COLOR: Color = Color(0.99, 0.95, 0.82, 1.0)
const FLUID_GRID_HEIGHT: int = 180
const FLUID_DEPTH_RANGE: float = 12.0

const KIND_STREAM: int = 1
const KIND_SPLASH: int = 2
const KIND_OVERFLOW: int = 3
const KIND_PUDDLE: int = 4

const METABALL_3D_SHADER := preload("res://Shader/fluid_metaball_3d.gdshader")
const DEPTH_3D_SHADER := preload("res://Shader/fluid_depth_3d.gdshader")
const OVERLAY_SHADER := preload("res://Shader/fluid_overlay.gdshader")

static var _cavity_cache: Dictionary = {}
static var _pending_sims: Dictionary = {}

var _shared_multimesh: MultiMesh
var _density_vp: SubViewport
var _color_vp: SubViewport
var _depth_vp: SubViewport
var _density_cam: Camera3D
var _color_cam: Camera3D
var _depth_cam: Camera3D
var _overlay_mesh: MeshInstance3D
var _overlay_mat: ShaderMaterial

var _last_grid_size: Vector2i = Vector2i(320, 180)
var _bounds_refresh_timer: float = 0.0

var _has_counter_bounds: bool = false
var _counter_surface_y: float = 2.18
var _counter_xz: Rect2 = Rect2()
var _sink_rects: Array[Rect2] = []

# Pooled particle data
var _active: PackedByteArray = PackedByteArray()
var _kind: PackedByteArray = PackedByteArray()
var _world_pos: PackedVector3Array = PackedVector3Array()
var _world_vel: PackedVector3Array = PackedVector3Array()
var _color: PackedColorArray = PackedColorArray()
var _ingredient_id: Array[String] = []
var _volume: PackedFloat32Array = PackedFloat32Array()
var _from_emitter: PackedByteArray = PackedByteArray()
var _size: PackedFloat32Array = PackedFloat32Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _max_age: PackedFloat32Array = PackedFloat32Array()
var _grounded: PackedByteArray = PackedByteArray()
var _target_cup: Array = []
var _ignore_cup: Array = []
var _ignore_timer: PackedFloat32Array = PackedFloat32Array()

var _active_slots: Array[int] = []
var _free_slots: Array[int] = []
var _cups: Dictionary = {}

static func get_sim(context: Node) -> LiquidSim:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	if not tree:
		return null
	var host: Node = tree.current_scene
	if not is_instance_valid(host):
		host = tree.root
	if not is_instance_valid(host):
		return null

	var existing := host.get_node_or_null("LiquidSim") as LiquidSim
	if is_instance_valid(existing):
		return existing

	var host_id: int = host.get_instance_id()
	if _pending_sims.has(host_id):
		var pending := _pending_sims[host_id] as LiquidSim
		if is_instance_valid(pending) and not pending.is_queued_for_deletion():
			return pending
		_pending_sims.erase(host_id)

	var sim := LiquidSim.new()
	sim.name = "LiquidSim"
	_pending_sims[host_id] = sim
	if host.is_node_ready():
		host.add_child(sim)
	else:
		host.call_deferred("add_child", sim)
	return sim

func _init() -> void:
	process_priority = 100
	_init_pool()
	_setup_render_pipeline()

func _ready() -> void:
	var parent_node := get_parent()
	if parent_node:
		_pending_sims.erase(parent_node.get_instance_id())
	_refresh_environment_bounds()
	_sync_viewport_sizes()

func _exit_tree() -> void:
	var parent_node := get_parent()
	if parent_node:
		_pending_sims.erase(parent_node.get_instance_id())
	_cups.clear()
	_active_slots.clear()

func _init_pool() -> void:
	_active.resize(MAX_PARTICLES)
	_active.fill(0)
	_kind.resize(MAX_PARTICLES)
	_world_pos.resize(MAX_PARTICLES)
	_world_vel.resize(MAX_PARTICLES)
	_color.resize(MAX_PARTICLES)
	_ingredient_id.resize(MAX_PARTICLES)
	_volume.resize(MAX_PARTICLES)
	_from_emitter.resize(MAX_PARTICLES)
	_size.resize(MAX_PARTICLES)
	_age.resize(MAX_PARTICLES)
	_max_age.resize(MAX_PARTICLES)
	_grounded.resize(MAX_PARTICLES)
	_target_cup.resize(MAX_PARTICLES)
	_ignore_cup.resize(MAX_PARTICLES)
	_ignore_timer.resize(MAX_PARTICLES)

	_free_slots.clear()
	for i in range(MAX_PARTICLES - 1, -1, -1):
		_ingredient_id[i] = ""
		_volume[i] = 0.0
		_from_emitter[i] = 0
		_target_cup[i] = null
		_ignore_cup[i] = null
		_free_slots.append(i)

func _setup_render_pipeline() -> void:
	_shared_multimesh = MultiMesh.new()
	_shared_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_shared_multimesh.use_colors = true
	_shared_multimesh.instance_count = MAX_PARTICLES
	_shared_multimesh.visible_instance_count = 0

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_shared_multimesh.mesh = quad

	var density_mat := ShaderMaterial.new()
	density_mat.shader = METABALL_3D_SHADER
	density_mat.set_shader_parameter("is_color_pass", false)

	var color_mat := ShaderMaterial.new()
	color_mat.shader = METABALL_3D_SHADER
	color_mat.set_shader_parameter("is_color_pass", true)

	var depth_mat := ShaderMaterial.new()
	depth_mat.shader = DEPTH_3D_SHADER
	depth_mat.set_shader_parameter("depth_range", FLUID_DEPTH_RANGE)

	var d_pair := _create_fluid_subviewport("FluidDensityVP", density_mat)
	_density_vp = d_pair["vp"]
	_density_cam = d_pair["cam"]

	var c_pair := _create_fluid_subviewport("FluidColorVP", color_mat)
	_color_vp = c_pair["vp"]
	_color_cam = c_pair["cam"]

	var z_pair := _create_fluid_subviewport("FluidDepthVP", depth_mat)
	_depth_vp = z_pair["vp"]
	_depth_cam = z_pair["cam"]

	var overlay_quad := QuadMesh.new()
	overlay_quad.size = Vector2(2.0, 2.0)

	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = OVERLAY_SHADER
	_overlay_mat.render_priority = 3
	_overlay_mat.set_shader_parameter("fluid_density_tex", _density_vp.get_texture())
	_overlay_mat.set_shader_parameter("fluid_color_tex", _color_vp.get_texture())
	_overlay_mat.set_shader_parameter("fluid_depth_tex", _depth_vp.get_texture())
	_overlay_mat.set_shader_parameter("grid_resolution", Vector2(_last_grid_size))
	_overlay_mat.set_shader_parameter("density_threshold", 0.34)
	_overlay_mat.set_shader_parameter("fluid_alpha", 0.92)
	_overlay_mat.set_shader_parameter("depth_range", FLUID_DEPTH_RANGE)
	_overlay_mat.set_shader_parameter("depth_bias", 0.045)

	_overlay_mesh = MeshInstance3D.new()
	_overlay_mesh.name = "FluidOverlay"
	_overlay_mesh.mesh = overlay_quad
	_overlay_mesh.material_override = _overlay_mat
	_overlay_mesh.extra_cull_margin = 16384.0
	_overlay_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay_mesh.visible = false
	add_child(_overlay_mesh)

func _create_fluid_subviewport(vp_name: String, mat: ShaderMaterial) -> Dictionary:
	var vp := SubViewport.new()
	vp.name = vp_name
	vp.size = _last_grid_size
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.world_3d = World3D.new()
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK

	var cam := Camera3D.new()
	cam.name = "FluidCam"
	cam.environment = env
	cam.current = true
	vp.add_child(cam)

	var mm := MultiMeshInstance3D.new()
	mm.name = "FluidMM"
	mm.multimesh = _shared_multimesh
	mm.material_override = mat
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mm.custom_aabb = AABB(Vector3(-50.0, -50.0, -50.0), Vector3(100.0, 100.0, 100.0))
	vp.add_child(mm)

	add_child(vp)
	return {"vp": vp, "cam": cam}

func _sync_viewport_sizes() -> void:
	if not is_inside_tree():
		return
	var root_vp := get_viewport()
	if not root_vp:
		return
	var vp_size: Vector2 = root_vp.get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return
	var aspect: float = vp_size.x / vp_size.y
	var target_w: int = maxi(64, int(roundf(float(FLUID_GRID_HEIGHT) * aspect)))
	var target_size := Vector2i(target_w, FLUID_GRID_HEIGHT)
	if target_size != _last_grid_size:
		_last_grid_size = target_size
		_density_vp.size = target_size
		_color_vp.size = target_size
		_depth_vp.size = target_size
		if _overlay_mat:
			_overlay_mat.set_shader_parameter("grid_resolution", Vector2(target_size))

func _alloc_slot() -> int:
	if _free_slots.is_empty():
		return -1
	var slot: int = _free_slots.pop_back()
	_active[slot] = 1
	_active_slots.append(slot)
	return slot

func _release_slot(slot: int) -> void:
	_active[slot] = 0
	_target_cup[slot] = null
	_ignore_cup[slot] = null
	_ingredient_id[slot] = ""
	_volume[slot] = 0.0
	_from_emitter[slot] = 0

func register_glass(glass: Node3D) -> void:
	if not is_instance_valid(glass):
		return
	var gid: int = glass.get_instance_id()
	if not _cups.has(gid):
		_cups[gid] = glass
		_get_or_build_cavity_profile(glass)

func unregister_glass(glass: Node3D) -> void:
	if glass == null:
		return
	_cups.erase(glass.get_instance_id())

func get_cup_rim_world_position(glass: Node3D) -> Vector3:
	if not is_instance_valid(glass):
		return Vector3.ZERO
	var profile := _get_or_build_cavity_profile(glass)
	var inside := _get_glass_inside_node(glass)
	if not is_instance_valid(inside):
		return glass.global_position + Vector3(0.0, 0.08, 0.0)
	var xf: Transform3D = inside.global_transform
	var rim_y: float = float(profile["rim_y"])
	var rim_mid_x: float = 0.5 * (float(profile["rim_min_x"]) + float(profile["rim_max_x"]))
	var z_off: float = -0.013 * xf.basis.z.length()
	return xf.origin + xf.basis.x.normalized() * rim_mid_x + xf.basis.y.normalized() * rim_y + xf.basis.z.normalized() * z_off

func get_cup_surface_world_position(glass: Node3D) -> Vector3:
	if not is_instance_valid(glass):
		return Vector3.ZERO
	var profile := _get_or_build_cavity_profile(glass)
	var inside := _get_glass_inside_node(glass)
	if not is_instance_valid(inside):
		return glass.global_position
	var xf: Transform3D = inside.global_transform
	var fill_ratio: float = _get_cup_fill_ratio(glass)
	var bottom_y: float = float(profile["bottom_y"])
	var rim_y: float = float(profile["rim_y"])
	var surf_y: float = lerpf(bottom_y, rim_y, fill_ratio)
	var xb := _sample_cavity_x_bounds(profile, surf_y)
	var mid_x: float = 0.5 * (xb.x + xb.y)
	var z_off: float = -0.013 * xf.basis.z.length()
	return xf.origin + xf.basis.x.normalized() * mid_x + xf.basis.y.normalized() * surf_y + xf.basis.z.normalized() * z_off

func emit_volume_stream(_emitter_id: int, world_pos: Vector3, world_vel: Vector3, color: Color, ingredient_id: String, total_volume: float, flow_ratio: float, delta: float, target_cup: Node3D = null, jitter_amount: float = 0.006, count_override: int = -1) -> void:
	if flow_ratio <= 0.001 or delta <= 0.0:
		return
	var clamped_flow: float = clampf(flow_ratio, 0.05, 1.0)
	var drop_size: float = lerpf(0.014, 0.022, clamped_flow)
	var spacing: float = drop_size * 0.45
	var speed: float = maxf(world_vel.length(), 0.35)
	var travel_dist: float = speed * delta
	var steps: int = count_override if count_override > 0 else clampi(int(ceilf(travel_dist / maxf(spacing, 0.002))), 1, 10)
	var per_p_vol: float = maxf(total_volume, 0.0) / float(steps)

	for i in steps:
		var t_sub: float = (float(i) / float(steps)) * delta
		var sub_pos: Vector3 = world_pos + world_vel * t_sub + Vector3(0.0, -0.5 * WORLD_GRAVITY * t_sub * t_sub, 0.0)
		sub_pos += Vector3(
			randf_range(-jitter_amount, jitter_amount),
			randf_range(-jitter_amount * 0.4, jitter_amount * 0.4),
			randf_range(-jitter_amount * 0.3, jitter_amount * 0.3)
		)
		var sub_vel: Vector3 = world_vel + Vector3(0.0, -WORLD_GRAVITY * t_sub, 0.0)
		var p_col: Color = color
		if ingredient_id == "beer" and randf() < 0.16:
			p_col = p_col.lerp(BEER_FOAM_COLOR, 0.65)
		_spawn_particle(KIND_STREAM, sub_pos, sub_vel, p_col, ingredient_id, per_p_vol, 1 if total_volume > 0.0 else 0, drop_size, 2.2, target_cup, null, 0.0)

func emit_stream(emitter_id: int, world_pos: Vector3, world_vel: Vector3, color: Color, ingredient_id: String, flow_ratio: float, delta: float, target_cup: Node3D = null, jitter_amount: float = 0.006) -> void:
	emit_volume_stream(emitter_id, world_pos, world_vel, color, ingredient_id, 0.0, flow_ratio, delta, target_cup, jitter_amount)

func emit_cup_spill_particle(glass: Node3D, world_pos: Vector3, world_vel: Vector3, color: Color, ingredient_id: String, volume: float, is_sink_pour: bool) -> void:
	var p_kind: int = KIND_STREAM if is_sink_pour else KIND_OVERFLOW
	var p_size: float = randf_range(0.015, 0.021) if is_sink_pour else randf_range(0.013, 0.018)
	var eff_col: Color = _apply_cup_spectral_tint(glass, color)
	if ingredient_id == "beer" and randf() < 0.25:
		eff_col = eff_col.lerp(BEER_FOAM_COLOR, 0.7)
	_spawn_particle(p_kind, world_pos, world_vel, eff_col, ingredient_id, volume, 0, p_size, 2.4, null, glass, 0.32)

func notify_overflow(glass: Node3D, ingredient_id: String, overflow_amount: float, color: Color) -> void:
	if not is_instance_valid(glass) or overflow_amount <= 0.0001:
		return
	if randf() < clampf(overflow_amount * 20.0, 0.25, 0.9):
		_spawn_rim_cascade(glass, color, ingredient_id, 1, 0.0)

func notify_cup_pour_out(_glass: Node3D, _drained_amount: float, _color: Color, _ingredient_id: String) -> void:
	pass

func _process(delta: float) -> void:
	var dt: float = clampf(delta, 0.0, 0.04)
	if dt <= 0.0:
		return

	_sync_viewport_sizes()
	_bounds_refresh_timer -= dt
	if _bounds_refresh_timer <= 0.0:
		_bounds_refresh_timer = 0.5
		_refresh_environment_bounds()

	_prune_invalid_cups()
	_step_particles(dt)
	_apply_puddle_cohesion(dt)
	_compact_active_slots()
	_update_multimesh()

func _step_particles(dt: float) -> void:
	var counter_floor_y: float = _counter_surface_y - 0.65 if _has_counter_bounds else -2.0

	for slot in _active_slots:
		if _active[slot] == 0:
			continue

		_age[slot] += dt
		if _ignore_timer[slot] > 0.0:
			_ignore_timer[slot] = maxf(0.0, _ignore_timer[slot] - dt)

		var max_a: float = _max_age[slot]
		if max_a > 0.0 and _age[slot] >= max_a:
			_release_slot(slot)
			continue

		var pos: Vector3 = _world_pos[slot]
		var vel: Vector3 = _world_vel[slot]

		if _grounded[slot] == 0:
			vel.y -= WORLD_GRAVITY * dt
		else:
			vel.x *= exp(-6.5 * dt)
			vel.z *= exp(-6.5 * dt)
			vel.y = 0.0

		pos += vel * dt
		_world_pos[slot] = pos
		_world_vel[slot] = vel

		# Check liquid stream interaction with open glasses
		if _grounded[slot] == 0 and _kind[slot] == KIND_STREAM:
			if _handle_stream_cup_impact(slot):
				continue

		# Check counter and sink collisions
		if _has_counter_bounds:
			var in_sink: bool = _is_point_in_sink(pos.x, pos.z)
			if in_sink:
				var sink_bottom_y: float = _counter_surface_y - 0.24
				if pos.y <= sink_bottom_y:
					pos.y = sink_bottom_y
					if _grounded[slot] == 0:
						_grounded[slot] = 1
						_kind[slot] = KIND_PUDDLE
						_size[slot] *= 0.9
						_max_age[slot] = _age[slot] + 0.45
						vel = Vector3(randf_range(-0.18, 0.18), 0.0, randf_range(-0.18, 0.18))
					_world_pos[slot] = pos
					_world_vel[slot] = vel
					continue
			elif _is_point_in_counter(pos.x, pos.z):
				if pos.y <= _counter_surface_y + 0.008 and pos.y >= _counter_surface_y - 0.14 and vel.y <= 0.0:
					pos.y = _counter_surface_y + 0.005
					if _grounded[slot] == 0 and absf(vel.y) > 0.35 and _kind[slot] != KIND_PUDDLE:
						if randf() < 0.25:
							vel.y = absf(vel.y) * 0.2
							vel.x += randf_range(-0.16, 0.16)
							vel.z += randf_range(-0.16, 0.16)
							_kind[slot] = KIND_SPLASH
							_size[slot] *= 0.78
							_max_age[slot] = _age[slot] + 0.6
						else:
							_grounded[slot] = 1
							_kind[slot] = KIND_PUDDLE
							_size[slot] *= 1.15
							vel = Vector3(vel.x * 0.35 + randf_range(-0.1, 0.1), 0.0, vel.z * 0.35 + randf_range(-0.1, 0.1))
							_max_age[slot] = _age[slot] + randf_range(2.2, 3.2)
					else:
						_grounded[slot] = 1
						_kind[slot] = KIND_PUDDLE
						vel.y = 0.0
						if _max_age[slot] > _age[slot] + 3.4:
							_max_age[slot] = _age[slot] + randf_range(2.2, 3.2)
					_world_pos[slot] = pos
					_world_vel[slot] = vel
					continue

		if pos.y < counter_floor_y:
			_release_slot(slot)

func _apply_puddle_cohesion(dt: float) -> void:
	# Light pairwise spreading among grounded counter puddles so drops merge into pools
	var puddle_slots: Array[int] = []
	for slot in _active_slots:
		if _active[slot] == 1 and _grounded[slot] == 1:
			puddle_slots.append(slot)
	var n: int = puddle_slots.size()
	if n < 2:
		return

	var min_sep: float = 0.022
	var min_sep_sq: float = min_sep * min_sep
	var max_checks: int = mini(n, 96)
	for i in max_checks:
		var si: int = puddle_slots[i]
		var pi: Vector3 = _world_pos[si]
		for j in range(i + 1, max_checks):
			var sj: int = puddle_slots[j]
			var pj: Vector3 = _world_pos[sj]
			var dx: float = pj.x - pi.x
			var dz: float = pj.z - pi.z
			var d2: float = dx * dx + dz * dz
			if d2 > 0.000001 and d2 < min_sep_sq:
				var d: float = sqrt(d2)
				var push: float = (min_sep - d) * 1.4 * dt
				var nx: float = dx / d
				var nz: float = dz / d
				pi.x -= nx * push
				pi.z -= nz * push
				pj.x += nx * push
				pj.z += nz * push
				_world_pos[si] = pi
				_world_pos[sj] = pj

func _handle_stream_cup_impact(slot: int) -> bool:
	var pos: Vector3 = _world_pos[slot]
	var vel: Vector3 = _world_vel[slot]
	var ig_cup = _ignore_cup[slot]
	var ig_t: float = _ignore_timer[slot]
	var pref_cup = _target_cup[slot]

	for glass in _cups.values():
		if not is_instance_valid(glass):
			continue
		if ig_t > 0.0 and glass == ig_cup:
			continue
		if ("is_consumed" in glass and glass.is_consumed) or ("is_pouring_out" in glass and glass.is_pouring_out):
			continue

		var inside := _get_glass_inside_node(glass)
		if not is_instance_valid(inside):
			continue

		var xf: Transform3D = inside.global_transform
		var right_axis: Vector3 = xf.basis.x.normalized()
		var up_axis: Vector3 = xf.basis.y.normalized()
		var back_axis: Vector3 = xf.basis.z.normalized()
		var delta_w: Vector3 = pos - xf.origin

		var lz: float = delta_w.dot(back_axis)
		var z_tol: float = 0.095 if glass == pref_cup else 0.06
		if absf(lz) > z_tol:
			continue

		var profile := _get_or_build_cavity_profile(glass)
		var bottom_y: float = float(profile["bottom_y"])
		var rim_y: float = float(profile["rim_y"])
		var fill_ratio: float = _get_cup_fill_ratio(glass)
		var surf_y: float = lerpf(bottom_y, rim_y, fill_ratio)

		var ly: float = delta_w.dot(up_axis)
		var lx: float = delta_w.dot(right_axis)

		if ly > rim_y + 0.012 or ly < bottom_y - 0.025:
			continue
		if vel.dot(up_axis) > 0.15:
			continue

		var xb_rim := _sample_cavity_x_bounds(profile, rim_y)
		if lx < xb_rim.x - 0.018 or lx > xb_rim.y + 0.018:
			continue

		# Map hit into cup Outside sprite UV space (0..1)
		var outside := inside.get_node_or_null("Outside") as Sprite3D
		var target_spr: Sprite3D = outside if is_instance_valid(outside) else inside
		var local_hit: Vector3 = target_spr.global_transform.affine_inverse() * pos
		var rect: Rect2 = target_spr.get_item_rect()
		var ps: float = maxf(target_spr.pixel_size, 0.0001)
		var u: float = clampf(((local_hit.x / ps) - rect.position.x) / maxf(rect.size.x, 0.001), 0.12, 0.88)
		var v_bot: float = ((local_hit.y / ps) - rect.position.y) / maxf(rect.size.y, 0.001)
		var v: float = clampf(v_bot if target_spr.flip_v else (1.0 - v_bot), 0.05, 0.92)

		var local_v: Vector3 = target_spr.global_transform.basis.inverse() * vel
		var uv_vel := Vector2(local_v.x * 16.0, -local_v.y * 16.0)

		var vol: float = _volume[slot]
		var ing_id: String = _ingredient_id[slot]
		var col: Color = _color[slot]

		var accepted: bool = true
		if _from_emitter[slot] == 1 and glass.has_method("receive_fluid_particle"):
			accepted = glass.receive_fluid_particle(ing_id, vol, col, Vector2(u, v), uv_vel)
		elif glass.has_method("is_full") and glass.is_full():
			accepted = false

		if accepted:
			if glass.has_method("on_liquid_stream_impact"):
				glass.on_liquid_stream_impact(clampf(_size[slot] / 0.015, 0.4, 1.5))
			# Small foam/splash pixel droplets near top surface
			if randf() < 0.18:
				var z_front: float = -0.014 * xf.basis.z.length()
				var hit_pos: Vector3 = xf.origin + right_axis * clampf(lx, xb_rim.x, xb_rim.y) + up_axis * maxf(surf_y, rim_y - 0.02) + back_axis * z_front
				var s_dir: float = -1.0 if randf() < 0.5 else 1.0
				var splash_vel: Vector3 = right_axis * (s_dir * randf_range(0.06, 0.16)) + up_axis * randf_range(0.10, 0.22) + back_axis * randf_range(-0.02, 0.02)
				var s_col: Color = col.lerp(BEER_FOAM_COLOR, 0.82) if ing_id == "beer" else col.lightened(0.24)
				_spawn_particle(KIND_SPLASH, hit_pos + up_axis * 0.004, splash_vel, s_col, ing_id, 0.0, 0, _size[slot] * 0.72, randf_range(0.24, 0.38), null, glass, 0.25)
			_release_slot(slot)
			return true
		else:
			# Cup is full, spill onto the counter
			var mid_x: float = 0.5 * (xb_rim.x + xb_rim.y)
			var side_bias: float = -1.0 if (lx < mid_x or (absf(lx - mid_x) < 0.004 and randf() < 0.5)) else 1.0
			_spawn_rim_cascade(glass, col, ing_id, 2, side_bias)
			_release_slot(slot)
			return true

	return false

func _spawn_rim_cascade(glass: Node3D, base_color: Color, ingredient_id: String, count: int, side_bias: float) -> void:
	var inside := _get_glass_inside_node(glass)
	if not is_instance_valid(inside):
		return
	var profile := _get_or_build_cavity_profile(glass)
	var xf: Transform3D = inside.global_transform
	var right_axis: Vector3 = xf.basis.x.normalized()
	var up_axis: Vector3 = xf.basis.y.normalized()
	var back_axis: Vector3 = xf.basis.z.normalized()
	var rim_y: float = float(profile["rim_y"])
	var rim_min_x: float = float(profile["rim_min_x"])
	var rim_max_x: float = float(profile["rim_max_x"])
	var z_front: float = -0.016 * xf.basis.z.length()

	var eff_col: Color = _apply_cup_spectral_tint(glass, base_color)
	for _i in count:
		var side: float = side_bias if not is_zero_approx(side_bias) else (-1.0 if randf() < 0.5 else 1.0)
		var lip_x: float = rim_min_x if side < 0.0 else rim_max_x
		var p_pos: Vector3 = xf.origin + right_axis * (lip_x + side * 0.004) + up_axis * (rim_y + 0.002) + back_axis * z_front
		var p_vel: Vector3 = right_axis * (side * randf_range(0.06, 0.14)) + up_axis * randf_range(0.02, 0.09) + back_axis * randf_range(-0.015, 0.015)
		var drop_col: Color = eff_col
		if ingredient_id == "beer" and randf() < 0.35:
			drop_col = drop_col.lerp(BEER_FOAM_COLOR, 0.72)
		_spawn_particle(KIND_OVERFLOW, p_pos, p_vel, drop_col, ingredient_id, 0.0, 0, randf_range(0.014, 0.019), 2.2, null, glass, 0.3)

func _spawn_particle(kind: int, w_pos: Vector3, w_vel: Vector3, col: Color, ing_id: String, vol: float, from_emit: int, p_size: float, max_a: float, target_cup: Node3D, ignore_cup: Node3D, ignore_t: float) -> int:
	var slot: int = _alloc_slot()
	if slot == -1:
		return -1
	_kind[slot] = kind
	_world_pos[slot] = w_pos
	_world_vel[slot] = w_vel
	_color[slot] = col
	_ingredient_id[slot] = ing_id
	_volume[slot] = vol
	_from_emitter[slot] = from_emit
	_size[slot] = p_size
	_age[slot] = 0.0
	_max_age[slot] = max_a
	_grounded[slot] = 0
	_target_cup[slot] = target_cup
	_ignore_cup[slot] = ignore_cup
	_ignore_timer[slot] = ignore_t
	return slot

func _compact_active_slots() -> void:
	var write_idx: int = 0
	for read_idx in _active_slots.size():
		var slot: int = _active_slots[read_idx]
		if _active[slot] == 0:
			_free_slots.append(slot)
		else:
			_active_slots[write_idx] = slot
			write_idx += 1
	_active_slots.resize(write_idx)

func _sync_subviewport_camera(sub_cam: Camera3D, main_cam: Camera3D) -> void:
	if not is_instance_valid(sub_cam) or not is_instance_valid(main_cam):
		return
	sub_cam.global_transform = main_cam.global_transform
	sub_cam.fov = main_cam.fov
	sub_cam.keep_aspect = main_cam.keep_aspect
	sub_cam.h_offset = main_cam.h_offset
	sub_cam.v_offset = main_cam.v_offset
	sub_cam.near = main_cam.near
	sub_cam.far = main_cam.far
	sub_cam.projection = main_cam.projection

func _update_multimesh() -> void:
	if _active_slots.is_empty():
		_shared_multimesh.visible_instance_count = 0
		if _overlay_mesh:
			_overlay_mesh.visible = false
		_density_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_color_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_depth_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	_sync_subviewport_camera(_density_cam, cam)
	_sync_subviewport_camera(_color_cam, cam)
	_sync_subviewport_camera(_depth_cam, cam)

	_density_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_color_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_depth_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _overlay_mesh:
		_overlay_mesh.visible = true

	var cam_basis: Basis = cam.global_transform.basis if is_instance_valid(cam) else Basis.IDENTITY

	var draw_idx: int = 0
	for slot in _active_slots:
		if _active[slot] == 0:
			continue

		var p_size: float = _size[slot] * 2.15
		var out_col: Color = _color[slot]
		var max_a: float = _max_age[slot]
		if max_a > 0.0 and _kind[slot] == KIND_PUDDLE:
			var fade_start: float = max_a * 0.65
			if _age[slot] > fade_start:
				var fade_t: float = clampf((_age[slot] - fade_start) / maxf(max_a - fade_start, 0.001), 0.0, 1.0)
				p_size *= (1.0 - fade_t * 0.85)

		var w_size_x: float = p_size * (1.35 if _kind[slot] == KIND_PUDDLE else 1.0)
		var w_size_y: float = p_size * (0.72 if _kind[slot] == KIND_PUDDLE else 1.0)

		var xform := Transform3D(
			Basis(cam_basis.x * w_size_x, cam_basis.y * w_size_y, cam_basis.z),
			_world_pos[slot]
		)
		_shared_multimesh.set_instance_transform(draw_idx, xform)
		_shared_multimesh.set_instance_color(draw_idx, Color(out_col.r, out_col.g, out_col.b, 1.0))
		draw_idx += 1

	_shared_multimesh.visible_instance_count = draw_idx

func _apply_cup_spectral_tint(glass: Node3D, base_color: Color) -> Color:
	var col: Color = base_color
	if not is_instance_valid(glass):
		return col
	if "liquid_transparency" in glass:
		col.a = minf(col.a, clampf(float(glass.liquid_transparency), 0.0, 1.0))
	if "visual_helper" in glass and glass.visual_helper:
		var vh = glass.visual_helper
		var ov: Dictionary = vh._visual_override if "_visual_override" in vh else {}
		if ov.has("liquid_tint_color"):
			var tint_col: Color = ov["liquid_tint_color"]
			var strength: float = float(ov.get("liquid_tint_strength", 0.35))
			col = col.lerp(Color(tint_col.r, tint_col.g, tint_col.b, col.a), strength)
		if ov.has("liquid_transparency"):
			col.a = minf(col.a, clampf(float(ov["liquid_transparency"]), 0.0, 1.0))
	return col

func _get_cup_fill_ratio(glass: Node3D) -> float:
	var total_liq: float = float(glass.total_liquids) if "total_liquids" in glass else 0.0
	var cap: float = float(glass.size) if "size" in glass else 1.0
	return clampf(total_liq / maxf(cap, 0.001), 0.0, 1.0)

func _get_glass_inside_node(glass: Node3D) -> Sprite3D:
	if "sprite" in glass and is_instance_valid(glass.sprite) and glass.sprite is Sprite3D:
		return glass.sprite as Sprite3D
	return glass.get_node_or_null("Inside") as Sprite3D

func _prune_invalid_cups() -> void:
	var dead: Array[int] = []
	for gid in _cups.keys():
		var g: Node3D = _cups[gid]
		if not is_instance_valid(g) or g.is_queued_for_deletion():
			dead.append(gid)
	for gid in dead:
		_cups.erase(gid)

func _refresh_environment_bounds() -> void:
	if not is_inside_tree():
		return
	var bounds = WorkingAreaService.get_working_area_bounds(self)
	if bounds is AABB:
		var box: AABB = bounds
		_has_counter_bounds = true
		_counter_surface_y = box.end.y
		_counter_xz = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	else:
		_has_counter_bounds = false

	_sink_rects.clear()
	var tree := get_tree()
	if tree:
		for trash_node in tree.get_nodes_in_group("trash"):
			if not is_instance_valid(trash_node) or not (trash_node is Node3D):
				continue
			var indicator := trash_node.get_node_or_null("TrashIndicator") as Node3D
			var target_node: Node3D = indicator if is_instance_valid(indicator) else (trash_node as Node3D)
			var t_bounds = WorkingAreaService.compute_node_world_bounds(target_node)
			if t_bounds is AABB:
				var tb: AABB = t_bounds
				_sink_rects.append(Rect2(tb.position.x, tb.position.z, tb.size.x, tb.size.z))
			elif trash_node is Node3D:
				var p: Vector3 = (trash_node as Node3D).global_position
				_sink_rects.append(Rect2(p.x - 0.3, p.z - 0.3, 0.6, 0.6))

func _is_point_in_counter(wx: float, wz: float) -> bool:
	return wx >= _counter_xz.position.x and wx <= _counter_xz.end.x and wz >= _counter_xz.position.y and wz <= _counter_xz.end.y

func _is_point_in_sink(wx: float, wz: float) -> bool:
	for rect in _sink_rects:
		if rect.has_point(Vector2(wx, wz)):
			return true
	return false

func _sample_cavity_x_bounds(profile: Dictionary, ly: float) -> Vector2:
	var bottom_y: float = float(profile["bottom_y"])
	var rim_y: float = float(profile["rim_y"])
	var t: float = clampf((ly - bottom_y) / maxf(rim_y - bottom_y, 0.001), 0.0, 1.0)
	var f_idx: float = t * float(NUM_CAVITY_SLICES - 1)
	var i0: int = clampi(int(floorf(f_idx)), 0, NUM_CAVITY_SLICES - 1)
	var i1: int = mini(i0 + 1, NUM_CAVITY_SLICES - 1)
	var w: float = f_idx - float(i0)
	var min_arr: PackedFloat32Array = profile["slice_min_x"]
	var max_arr: PackedFloat32Array = profile["slice_max_x"]
	return Vector2(lerpf(min_arr[i0], min_arr[i1], w), lerpf(max_arr[i0], max_arr[i1], w))

func _get_or_build_cavity_profile(glass: Node3D) -> Dictionary:
	var inside := _get_glass_inside_node(glass)
	var outside := inside.get_node_or_null("Outside") as Sprite3D if is_instance_valid(inside) else null
	var target_sprite: Sprite3D = outside if is_instance_valid(outside) and outside.texture != null else inside
	if not is_instance_valid(target_sprite) or target_sprite.texture == null:
		return _build_fallback_profile(0.08, 0.12)

	var inside_xf: Transform3D = inside.global_transform
	var sx: float = inside_xf.basis.x.length()
	var sy: float = inside_xf.basis.y.length()
	var m_top: float = float(glass.inner_margin_top) if "inner_margin_top" in glass else 0.12
	var m_bot: float = float(glass.inner_margin_bottom) if "inner_margin_bottom" in glass else 0.88
	var tex_id: int = target_sprite.texture.get_rid().get_id()
	var cache_key: String = "%d_%.3f_%.3f_%.2f_%.2f_%s" % [tex_id, sx, sy, m_top, m_bot, target_sprite.name]
	if _cavity_cache.has(cache_key):
		return _cavity_cache[cache_key]

	var profile := _extract_profile_from_sprite(target_sprite, outside == target_sprite, sx, sy, m_top, m_bot)
	_cavity_cache[cache_key] = profile
	return profile

func _extract_profile_from_sprite(spr: Sprite3D, is_outside_child: bool, sx: float, sy: float, margin_top: float, margin_bot: float) -> Dictionary:
	var rect: Rect2 = spr.get_item_rect()
	var ps: float = spr.pixel_size
	var ox_scale: float = spr.scale.x * sx if is_outside_child else sx
	var oy_scale: float = spr.scale.y * sy if is_outside_child else sy
	var ox_off: float = spr.position.x * sx if is_outside_child else 0.0
	var oy_off: float = spr.position.y * sy if is_outside_child else 0.0

	var tex: Texture2D = spr.texture
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			if img.decompress() != OK:
				img = null
	if img == null or img.is_empty() or img.is_compressed():
		return _build_fallback_profile(rect.size.x * ps * ox_scale, rect.size.y * ps * oy_scale)

	var tex_w: int = img.get_width()
	var tex_h: int = img.get_height()
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return _build_fallback_profile(rect.size.x * ps * ox_scale, rect.size.y * ps * oy_scale)

	var row_start: int = maxi(used.position.y, int(floorf(margin_top * float(tex_h))))
	var row_end: int = mini(used.end.y, int(ceilf(margin_bot * float(tex_h))))
	if row_end <= row_start + 2:
		row_start = used.position.y
		row_end = used.end.y

	var bottom_y: float = INF
	var rim_y: float = -INF
	var pts_x: PackedFloat32Array = PackedFloat32Array()
	var pts_y: PackedFloat32Array = PackedFloat32Array()

	for py in range(row_start, row_end):
		var v_norm: float = (float(py) + 0.5) / float(tex_h)
		var v_from_bottom: float = v_norm if spr.flip_v else (1.0 - v_norm)
		var ly: float = ((rect.position.y + v_from_bottom * rect.size.y) * ps) * oy_scale + oy_off

		var row_min_px: int = -1
		var row_max_px: int = -1
		for px in range(used.position.x, used.end.x):
			if img.get_pixel(px, py).a > 0.15:
				if row_min_px == -1:
					row_min_px = px
				row_max_px = px
		if row_min_px == -1:
			continue

		var u0: float = (float(row_min_px) + 0.5) / float(tex_w)
		var u1: float = (float(row_max_px) + 0.5) / float(tex_w)
		if spr.flip_h:
			u0 = 1.0 - u0
			u1 = 1.0 - u1
		var lx0: float = ((rect.position.x + u0 * rect.size.x) * ps) * ox_scale + ox_off
		var lx1: float = ((rect.position.x + u1 * rect.size.x) * ps) * ox_scale + ox_off

		bottom_y = minf(bottom_y, ly)
		rim_y = maxf(rim_y, ly)
		pts_x.append(minf(lx0, lx1))
		pts_x.append(maxf(lx0, lx1))
		pts_y.append(ly)

	if pts_y.is_empty() or rim_y <= bottom_y + 0.005:
		return _build_fallback_profile(rect.size.x * ps * ox_scale, rect.size.y * ps * oy_scale)

	var slice_min: PackedFloat32Array = PackedFloat32Array()
	var slice_max: PackedFloat32Array = PackedFloat32Array()
	var slice_has: PackedByteArray = PackedByteArray()
	slice_min.resize(NUM_CAVITY_SLICES)
	slice_max.resize(NUM_CAVITY_SLICES)
	slice_has.resize(NUM_CAVITY_SLICES)
	slice_min.fill(INF)
	slice_max.fill(-INF)
	slice_has.fill(0)

	for k in pts_y.size():
		var ly: float = pts_y[k]
		var s: int = clampi(int(roundf(((ly - bottom_y) / (rim_y - bottom_y)) * float(NUM_CAVITY_SLICES - 1))), 0, NUM_CAVITY_SLICES - 1)
		slice_min[s] = minf(slice_min[s], pts_x[k * 2])
		slice_max[s] = maxf(slice_max[s], pts_x[k * 2 + 1])
		slice_has[s] = 1

	for s in NUM_CAVITY_SLICES:
		if slice_has[s] == 0:
			var found: bool = false
			for offset in range(1, NUM_CAVITY_SLICES):
				if s - offset >= 0 and slice_has[s - offset] == 1:
					slice_min[s] = slice_min[s - offset]
					slice_max[s] = slice_max[s - offset]
					found = true
					break
				if s + offset < NUM_CAVITY_SLICES and slice_has[s + offset] == 1:
					slice_min[s] = slice_min[s + offset]
					slice_max[s] = slice_max[s + offset]
					found = true
					break
			if not found:
				slice_min[s] = -0.04
				slice_max[s] = 0.04

	return {
		"bottom_y": bottom_y,
		"rim_y": rim_y,
		"slice_min_x": slice_min,
		"slice_max_x": slice_max,
		"rim_min_x": slice_min[NUM_CAVITY_SLICES - 1],
		"rim_max_x": slice_max[NUM_CAVITY_SLICES - 1]
	}

func _build_fallback_sdf_bounds(width_est: float, height_est: float) -> Dictionary:
	return _build_fallback_profile(width_est, height_est)

func _build_fallback_profile(width_est: float, height_est: float) -> Dictionary:
	var h: float = maxf(height_est * 0.72, 0.08)
	var half_bot: float = maxf(width_est * 0.28, 0.025)
	var half_top: float = maxf(width_est * 0.36, 0.032)
	var slice_min: PackedFloat32Array = PackedFloat32Array()
	var slice_max: PackedFloat32Array = PackedFloat32Array()
	slice_min.resize(NUM_CAVITY_SLICES)
	slice_max.resize(NUM_CAVITY_SLICES)
	for s in NUM_CAVITY_SLICES:
		var t: float = float(s) / float(NUM_CAVITY_SLICES - 1)
		var hw: float = lerpf(half_bot, half_top, t)
		slice_min[s] = -hw
		slice_max[s] = hw
	return {
		"bottom_y": -h * 0.5,
		"rim_y": h * 0.5,
		"slice_min_x": slice_min,
		"slice_max_x": slice_max,
		"rim_min_x": -half_top,
		"rim_max_x": half_top
	}