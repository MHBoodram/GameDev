class_name FluidGpuBackend
extends RefCounted

const GRID_SIZE := FluidComputeGLSL.GRID_SIZE
const GRID_CELLS := FluidComputeGLSL.GRID_CELLS
const MAX_PARTICLES := FluidComputeGLSL.MAX_PARTICLES
const WORKGROUP_SIZE := FluidComputeGLSL.WORKGROUP_SIZE
const PARTICLE_STRIDE := 48
const GRID_GRAVITY := 65.0
const EOS_STIFFNESS := 11000.0
const REST_DENSITY := 1.00
const MOUTH_WEIGHT_THRESHOLD := 40
const SUBSTEP_DT := 0.0028
const MAX_SUBSTEP_DT := 0.0030
const MIN_SUBSTEPS := 8
const MAX_SUBSTEPS := 32

static var _shaders_ready: bool = false
static var _shaders: Dictionary = {}
static var _pipelines: Dictionary = {}
static var _shared_scratch_buf: RID = RID()
static var _shared_cull_meta_buf: RID = RID()
static var _shared_cull_scan_set: RID = RID()

var display_tex_rd: Texture2DRD = null
var mouth_touching: bool = false
var mouth_hits: int = 0
var mouth_contact_ratio: float = 0.0
var _mouth_readback_gen: int = 0
var _mouth_cell_count: int = 0
var _max_particles: int = 0
var _sdf_bytes: PackedByteArray = PackedByteArray()

var _disposed: bool = false
var _disposed_rt: bool = false
var _gpu_initialized: bool = false
var _flip_flop: bool = false
var _tex_cleared: bool = false
var _mouth_readback_pending_rt: bool = false

var _in_volume_a: RID = RID()
var _in_volume_b: RID = RID()
var _density_buf: RID = RID()
var _particles_buf: RID = RID()
var _wall_sdf_buf: RID = RID()
var _mouth_buf: RID = RID()
var _out_tex_rid: RID = RID()
var _sets: Dictionary = {}

func setup(sdf_bytes: PackedByteArray, max_particles: int, mouth_cell_count: int) -> Texture2DRD:
	_sdf_bytes = sdf_bytes
	_max_particles = max_particles
	_mouth_cell_count = mouth_cell_count
	display_tex_rd = Texture2DRD.new()
	RenderingServer.call_on_render_thread(FluidGpuBackend._gpu_init_static.bind(self, sdf_bytes))
	return display_tex_rd

func reset_mouth_state() -> void:
	_mouth_readback_gen += 1
	clear_mouth_state()

func clear_mouth_state() -> void:
	mouth_touching = false
	mouth_hits = 0
	mouth_contact_ratio = 0.0

func step(frame_dt: float, accel: Vector2, viscosity: float, active_count: int, down_dir: Vector2, ops: Array, want_mouth_readback: bool) -> void:
	if _disposed:
		return
	if active_count <= 0:
		clear_mouth_state()
	RenderingServer.call_on_render_thread(
		FluidGpuBackend._gpu_step_static.bind(self, frame_dt, accel, viscosity, active_count, down_dir, ops, want_mouth_readback, _mouth_readback_gen)
	)

func cleanup() -> void:
	if _disposed:
		return
	_disposed = true
	reset_mouth_state()
	if display_tex_rd:
		display_tex_rd.texture_rd_rid = RID()
		display_tex_rd = null
	var collected := _collect_and_clear_rids(false)
	var mouth_buf := _mouth_buf
	_mouth_buf = RID()
	if RenderingServer.get_rendering_device() != null and (not collected["rids"].is_empty() or not collected["sets"].is_empty() or mouth_buf.is_valid()):
		RenderingServer.call_on_render_thread(self._cleanup_gpu_rids_rt.bind(collected["rids"], collected["sets"], mouth_buf))

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _disposed:
			return
		_disposed = true
		reset_mouth_state()
		if display_tex_rd:
			display_tex_rd.texture_rd_rid = RID()
			display_tex_rd = null
		var collected := _collect_and_clear_rids(true)
		if RenderingServer.get_rendering_device() != null and (not collected["rids"].is_empty() or not collected["sets"].is_empty()):
			RenderingServer.call_on_render_thread(FluidGpuBackend._free_rids_on_render_thread.bind(collected["rids"], collected["sets"]))

func _collect_and_clear_rids(include_mouth: bool) -> Dictionary:
	var sets_to_free: Array[RID] = []
	for urid in _sets.values():
		if urid.is_valid():
			sets_to_free.append(urid)
	var owned: Array[RID] = []
	var targets := [_in_volume_a, _in_volume_b, _density_buf, _particles_buf, _wall_sdf_buf, _out_tex_rid]
	if include_mouth:
		targets.append(_mouth_buf)
		_mouth_buf = RID()
	for rid in targets:
		if rid.is_valid():
			owned.append(rid)
	_in_volume_a = RID()
	_in_volume_b = RID()
	_density_buf = RID()
	_particles_buf = RID()
	_wall_sdf_buf = RID()
	_out_tex_rid = RID()
	_sets.clear()
	return {"rids": owned, "sets": sets_to_free}

func _cleanup_gpu_rids_rt(rids: Array[RID], uniform_sets: Array[RID], mouth_buf: RID) -> void:
	_disposed_rt = true
	var rd := RenderingServer.get_rendering_device()
	if not rd:
		return
	_free_rids_on_render_thread(rids, uniform_sets)
	if mouth_buf.is_valid() and not _mouth_readback_pending_rt:
		rd.free_rid(mouth_buf)
		_mouth_buf = RID()

static func _free_rids_on_render_thread(rids: Array[RID], uniform_sets: Array[RID] = []) -> void:
	var rd := RenderingServer.get_rendering_device()
	if not rd:
		return
	for urid in uniform_sets:
		if urid.is_valid() and rd.uniform_set_is_valid(urid):
			rd.free_rid(urid)
	for rid in rids:
		if rid.is_valid():
			rd.free_rid(rid)

static func _gpu_init_static(backend: FluidGpuBackend, sdf_bytes: PackedByteArray) -> void:
	if backend and not backend._disposed:
		backend._gpu_init_instance(sdf_bytes)

static func _gpu_step_static(backend: FluidGpuBackend, frame_dt: float, accel: Vector2, viscosity: float, active_count: int, down_dir: Vector2, ops: Array, want_mouth_readback: bool, readback_gen: int) -> void:
	if backend and not backend._disposed:
		backend._gpu_step(frame_dt, accel, viscosity, active_count, down_dir, ops, want_mouth_readback, readback_gen)

func _on_mouth_readback(data: PackedByteArray, gen: int) -> void:
	call_deferred("_apply_mouth_readback_main", data, gen)
	RenderingServer.call_on_render_thread(self._mark_mouth_readback_done_rt)

func _mark_mouth_readback_done_rt() -> void:
	_mouth_readback_pending_rt = false
	if _disposed_rt and _mouth_buf.is_valid():
		var rd := RenderingServer.get_rendering_device()
		if rd:
			rd.free_rid(_mouth_buf)
		_mouth_buf = RID()

func _apply_mouth_readback_main(data: PackedByteArray, gen: int) -> void:
	if _disposed or gen != _mouth_readback_gen or data.size() < 12:
		return
	var hits := int(data.decode_u32(0))
	var max_w := int(data.decode_u32(8))
	mouth_hits = hits
	mouth_touching = hits > 0 and max_w >= MOUTH_WEIGHT_THRESHOLD
	mouth_contact_ratio = clampf(float(hits) / maxf(float(_mouth_cell_count) * 0.5, 1.0), 0.0, 1.0) if mouth_touching else 0.0

static func _ensure_shared_pipelines(rd: RenderingDevice) -> bool:
	if _shaders_ready:
		return true
	var sources := FluidComputeGLSL.get_shader_sources()
	for key in sources.keys():
		var src := RDShaderSource.new()
		src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		src.source_compute = sources[key]
		var spirv := rd.shader_compile_spirv_from_source(src)
		if spirv == null or spirv.compile_error_compute != "":
			push_error("FluidGpuBackend shader compile error (%s): %s" % [key, spirv.compile_error_compute if spirv else "null spirv"])
			return false
		var sh := rd.shader_create_from_spirv(spirv)
		if not sh.is_valid():
			push_error("FluidGpuBackend failed to create shader (%s)" % key)
			return false
		_shaders[key] = sh
		_pipelines[key] = rd.compute_pipeline_create(sh)

	_shared_scratch_buf = _create_zero_ssbo(rd, MAX_PARTICLES * PARTICLE_STRIDE)
	_shared_cull_meta_buf = _create_zero_ssbo(rd, 272)
	_shared_cull_scan_set = _make_uniform_set(rd, _shaders["cull_scan"], [_ssbo_uniform(0, _shared_cull_meta_buf)])
	_shaders_ready = true
	return true

static func _create_zero_ssbo(rd: RenderingDevice, byte_size: int) -> RID:
	var buf := PackedByteArray()
	buf.resize(byte_size)
	return rd.storage_buffer_create(byte_size, buf)

static func _ssbo_uniform(binding: int, buf_rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(buf_rid)
	return u

static func _img_uniform(binding: int, tex_rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex_rid)
	return u

static func _make_uniform_set(rd: RenderingDevice, shader_rid: RID, uniforms: Array[RDUniform]) -> RID:
	return rd.uniform_set_create(uniforms, shader_rid, 0)

static func _pack_pc(f0: float, f1: float, f2: float, f3: float, f4: float, f5: float, f6: float, u7: int) -> PackedByteArray:
	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_float(0, f0)
	pc.encode_float(4, f1)
	pc.encode_float(8, f2)
	pc.encode_float(12, f3)
	pc.encode_float(16, f4)
	pc.encode_float(20, f5)
	pc.encode_float(24, f6)
	pc.encode_u32(28, u7)
	return pc

static func _groups_for(count: int) -> int:
	return int(ceili(float(count) / float(WORKGROUP_SIZE)))

static func _dispatch(rd: RenderingDevice, pip: RID, uset: RID, groups_x: int, groups_y: int, pc: PackedByteArray = PackedByteArray()) -> void:
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pip)
	rd.compute_list_bind_uniform_set(cl, uset, 0)
	if not pc.is_empty():
		rd.compute_list_set_push_constant(cl, pc, pc.size())
	rd.compute_list_dispatch(cl, groups_x, groups_y, 1)
	rd.compute_list_end()

func _gpu_init_instance(sdf_bytes: PackedByteArray) -> void:
	if _disposed or _disposed_rt or _gpu_initialized:
		return
	var rd := RenderingServer.get_rendering_device()
	if not rd or not _ensure_shared_pipelines(rd):
		return

	_in_volume_a = _create_zero_ssbo(rd, GRID_CELLS * 16)
	_in_volume_b = _create_zero_ssbo(rd, GRID_CELLS * 16)
	_density_buf = _create_zero_ssbo(rd, GRID_CELLS * 8)
	_particles_buf = _create_zero_ssbo(rd, maxi(_max_particles, 64) * PARTICLE_STRIDE)
	_wall_sdf_buf = rd.storage_buffer_create(sdf_bytes.size(), sdf_bytes)
	_mouth_buf = _create_zero_ssbo(rd, 16)

	var fmt := RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.width = GRID_SIZE
	fmt.height = GRID_SIZE
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	_out_tex_rid = rd.texture_create(fmt, RDTextureView.new())
	rd.texture_clear(_out_tex_rid, Color(0, 0, 0, 0), 0, 1, 0, 1)
	_tex_cleared = true

	_sets["clear"] = _make_uniform_set(rd, _shaders["clear"], [_ssbo_uniform(0, _in_volume_a), _ssbo_uniform(1, _in_volume_b), _ssbo_uniform(2, _density_buf)])
	for i in 2:
		var vin := _in_volume_a if i == 0 else _in_volume_b
		var vout := _in_volume_b if i == 0 else _in_volume_a
		var s := str(i)
		_sets["grid_ops_" + s] = _make_uniform_set(rd, _shaders["grid_ops"], [_ssbo_uniform(0, vin), _ssbo_uniform(1, vout), _ssbo_uniform(2, _density_buf), _ssbo_uniform(3, _wall_sdf_buf)])
		_sets["density_" + s] = _make_uniform_set(rd, _shaders["density_scatter"], [_ssbo_uniform(0, vin), _ssbo_uniform(1, _density_buf), _ssbo_uniform(2, _particles_buf), _ssbo_uniform(3, _wall_sdf_buf)])
		_sets["fluid_" + s] = _make_uniform_set(rd, _shaders["fluid"], [_ssbo_uniform(0, vin), _ssbo_uniform(1, vout), _ssbo_uniform(2, _density_buf), _ssbo_uniform(3, _particles_buf), _ssbo_uniform(4, _wall_sdf_buf)])
		_sets["disp_clear_" + s] = _make_uniform_set(rd, _shaders["display_clear"], [_ssbo_uniform(0, vin), _ssbo_uniform(1, _mouth_buf)])
		_sets["disp_splat_" + s] = _make_uniform_set(rd, _shaders["display_splat"], [_ssbo_uniform(0, vin), _ssbo_uniform(1, _particles_buf)])
		_sets["disp_resolve_" + s] = _make_uniform_set(rd, _shaders["display_resolve"], [_ssbo_uniform(0, vin), _ssbo_uniform(1, _wall_sdf_buf), _img_uniform(2, _out_tex_rid), _ssbo_uniform(3, _mouth_buf)])

	_sets["cull_hist"] = _make_uniform_set(rd, _shaders["cull_hist"], [_ssbo_uniform(0, _particles_buf), _ssbo_uniform(1, _shared_cull_meta_buf)])
	_sets["cull_compact"] = _make_uniform_set(rd, _shaders["cull_compact"], [_ssbo_uniform(0, _particles_buf), _ssbo_uniform(1, _shared_cull_meta_buf), _ssbo_uniform(2, _shared_scratch_buf)])
	_sets["cull_copyback"] = _make_uniform_set(rd, _shaders["cull_copyback"], [_ssbo_uniform(0, _particles_buf), _ssbo_uniform(1, _shared_scratch_buf)])
	_sets["blend"] = _make_uniform_set(rd, _shaders["blend"], [_ssbo_uniform(0, _particles_buf)])

	if display_tex_rd:
		display_tex_rd.texture_rd_rid = _out_tex_rid
	_gpu_initialized = true

func _gpu_step(frame_dt: float, accel: Vector2, viscosity: float, active_count: int, down_dir: Vector2, ops: Array, want_mouth_readback: bool, readback_gen: int) -> void:
	if _disposed or _disposed_rt:
		return
	var rd := RenderingServer.get_rendering_device()
	if not rd:
		return
	if not _gpu_initialized:
		_gpu_init_instance(_sdf_bytes)
		if not _gpu_initialized:
			return

	var grid_groups := _groups_for(GRID_CELLS)
	var cleared_this_frame := false
	for op in ops:
		match op["op"]:
			"clear":
				_dispatch(rd, _pipelines["clear"], _sets["clear"], grid_groups, 1)
				rd.texture_clear(_out_tex_rid, Color(0, 0, 0, 0), 0, 1, 0, 1)
				cleared_this_frame = true
				_tex_cleared = true
			"init_upload":
				var bytes: PackedByteArray = op["bytes"]
				if not bytes.is_empty():
					_dispatch(rd, _pipelines["clear"], _sets["clear"], grid_groups, 1)
					rd.buffer_update(_particles_buf, 0, bytes.size(), bytes)
			"append_upload":
				var bytes: PackedByteArray = op["bytes"]
				if not bytes.is_empty():
					rd.buffer_update(_particles_buf, int(op["offset"]), bytes.size(), bytes)
			"cull":
				var old_cnt := int(op["old_count"])
				var rem_cnt := int(op["remove_count"])
				var new_cnt := int(op["new_count"])
				if old_cnt > 0 and rem_cnt > 0:
					var meta_zero := PackedByteArray()
					meta_zero.resize(272)
					rd.buffer_update(_shared_cull_meta_buf, 0, 272, meta_zero)
					var groups_old := _groups_for(old_cnt)
					_dispatch(rd, _pipelines["cull_hist"], _sets["cull_hist"], groups_old, 1, _pack_pc(0.0, down_dir.x, down_dir.y, 0.0, 0.0, 0.0, 0.0, old_cnt))
					_dispatch(rd, _pipelines["cull_scan"], _shared_cull_scan_set, 1, 1, _pack_pc(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, rem_cnt))
					_dispatch(rd, _pipelines["cull_compact"], _sets["cull_compact"], groups_old, 1, _pack_pc(0.0, down_dir.x, down_dir.y, 0.0, 0.0, 0.0, 0.0, old_cnt))
					if new_cnt > 0:
						_dispatch(rd, _pipelines["cull_copyback"], _sets["cull_copyback"], _groups_for(new_cnt), 1, _pack_pc(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, new_cnt))
			"blend":
				var cnt := int(op["count"])
				if cnt > 0:
					var col: Color = op["color"]
					_dispatch(rd, _pipelines["blend"], _sets["blend"], _groups_for(cnt), 1, _pack_pc(col.r, col.g, col.b, float(op["rho"]), float(op.get("visc", 0.0)), 0.0, 0.0, cnt))

	if active_count <= 0:
		if not cleared_this_frame and not _tex_cleared:
			rd.texture_clear(_out_tex_rid, Color(0, 0, 0, 0), 0, 1, 0, 1)
			_tex_cleared = true
		return

	var substeps := clampi(int(ceili(frame_dt / SUBSTEP_DT)), MIN_SUBSTEPS, MAX_SUBSTEPS)
	var step_dt := minf(frame_dt, float(substeps) * MAX_SUBSTEP_DT)
	var part_groups := _groups_for(active_count)
	var pc := _pack_pc(step_dt / float(substeps), accel.x, accel.y, viscosity, GRID_GRAVITY, EOS_STIFFNESS, REST_DENSITY, active_count)
	for _s in substeps:
		_flip_flop = not _flip_flop
		var s := "0" if _flip_flop else "1"
		_dispatch(rd, _pipelines["grid_ops"], _sets["grid_ops_" + s], grid_groups, 1, pc)
		_dispatch(rd, _pipelines["density_scatter"], _sets["density_" + s], part_groups, 1, pc)
		_dispatch(rd, _pipelines["fluid"], _sets["fluid_" + s], part_groups, 1, pc)

	var disp_idx := "0" if _flip_flop else "1"
	_dispatch(rd, _pipelines["display_clear"], _sets["disp_clear_" + disp_idx], grid_groups, 1)
	_dispatch(rd, _pipelines["display_splat"], _sets["disp_splat_" + disp_idx], part_groups, 1, pc)
	_dispatch(rd, _pipelines["display_resolve"], _sets["disp_resolve_" + disp_idx], int(GRID_SIZE / 8.0), int(GRID_SIZE / 8.0))
	_tex_cleared = false

	if want_mouth_readback and not _mouth_readback_pending_rt and _mouth_buf.is_valid():
		_mouth_readback_pending_rt = true
		if rd.buffer_get_data_async(_mouth_buf, _on_mouth_readback.bind(readback_gen)) != OK:
			_mouth_readback_pending_rt = false