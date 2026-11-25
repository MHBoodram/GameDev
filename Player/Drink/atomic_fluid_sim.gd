class_name AtomicFluidSim
extends RefCounted

const GRID_SIZE := AtomicFluidShaders.GRID_SIZE
const GRID_CELLS := AtomicFluidShaders.GRID_CELLS
const MAX_PARTICLES := AtomicFluidShaders.MAX_PARTICLES
const WORKGROUP_SIZE := AtomicFluidShaders.WORKGROUP_SIZE
const PARTICLES_PER_CELL := 4
const PARTICLE_VOLUME_WEIGHT := 0.25
const PARTICLE_STRIDE := 48
const GRID_GRAVITY := 65.0
const MAX_GRID_ACCEL := 550.0
const MAX_IMPULSE_VEL := 65.0
const EOS_STIFFNESS := 15000.0
const CFL_PRESSURE_LIMIT := 0.03
const REST_DENSITY := 1.00
const MOUTH_WEIGHT_THRESHOLD := 40

const STEPS_PER_SECOND := 1250.0
const STEP_SKIP := 2
const MIN_SUBSTEPS := 6
const MAX_SUBSTEPS := 28
const MIN_FRAME_DELTA := 0.001
const MAX_FRAME_DELTA := 0.033

const CPU_STEPS_PER_SECOND := 240.0
const CPU_MIN_SUBSTEPS := 2
const CPU_MAX_SUBSTEPS := 8
const CPU_PRESSURE_STIFFNESS := 65.0
const CPU_CFL_PRESSURE_LIMIT := 0.0045

# Shared static GPU resources across all containers
static var _gpu_checked: bool = false
static var _gpu_available: bool = false
static var _shaders_ready: bool = false
static var _shaders: Dictionary = {}
static var _pipelines: Dictionary = {}
static var _shared_scratch_buf: RID = RID()
static var _shared_cull_meta_buf: RID = RID()
static var _shared_cull_scan_set: RID = RID()

# Static container mask cache keyed by Texture2D RID id
static var _mask_cache: Dictionary = {}

# Instance state
var _disposed: bool = false
var _disposed_rt: bool = false
var _gpu_initialized: bool = false
var _flip_flop: bool = false
var _tex_cleared: bool = false

var _mask_cells: Array[Vector2i] = [] # sorted bottom-to-top up to brim
var _mask_bytes: PackedByteArray = PackedByteArray()
var _mouth_mask_bytes: PackedByteArray = PackedByteArray()
var _mouth_cell_count: int = 0
var _row_min_x: PackedInt32Array = PackedInt32Array()
var _row_max_x: PackedInt32Array = PackedInt32Array()
var _top_rim_y: int = 4
var _bottom_y: int = GRID_SIZE - 5
var _sdf_bytes: PackedByteArray = PackedByteArray()
var _max_particles: int = 0
var _active_count: int = 0

var _synced_amounts: Dictionary = {} # ingredient_key -> float amount
var _synced_total: float = 0.0
var _synced_mixed: bool = false
var _last_single_color: Color = Color(-1.0, -1.0, -1.0, -1.0)
var _last_single_rho: float = -1.0
var _last_single_visc: float = -1.0
var _pending_ops: Array[Dictionary] = []
var _pending_impulse: Vector2 = Vector2.ZERO
var _last_down_dir: Vector2 = Vector2(0.0, 1.0)

var _monitor_mouth: bool = false
var _mouth_touching: bool = false
var _mouth_hits: int = 0
var _mouth_contact_ratio: float = 0.0
var _mouth_readback_gen: int = 0
var _mouth_readback_pending_rt: bool = false

# GPU RIDs owned by this container instance
var _in_volume_a: RID = RID()
var _in_volume_b: RID = RID()
var _density_buf: RID = RID()
var _particles_buf: RID = RID()
var _wall_sdf_buf: RID = RID()
var _mouth_buf: RID = RID()
var _out_tex_rid: RID = RID()

var _sets: Dictionary = {}
var _display_tex_rd: Texture2DRD = null

# CPU fallback state (used only if RenderingServer.get_rendering_device() is null)
const CPU_N := 32
var _cpu_fallback_tex: ImageTexture = null
var _cpu_img: Image = null
var _cpu_mask: PackedByteArray = PackedByteArray()
var _cpu_mouth_mask: PackedByteArray = PackedByteArray()
var _cpu_mouth_cell_count: int = 0
var _cpu_sdf_nx: PackedFloat32Array = PackedFloat32Array()
var _cpu_sdf_ny: PackedFloat32Array = PackedFloat32Array()
var _cpu_sdf_d: PackedFloat32Array = PackedFloat32Array()
var _cpu_cells: Array[Vector2i] = []
var _cpu_pos: PackedVector2Array = PackedVector2Array()
var _cpu_pvel: PackedVector2Array = PackedVector2Array()
var _cpu_rho: PackedFloat32Array = PackedFloat32Array()
var _cpu_visc: PackedFloat32Array = PackedFloat32Array()
var _cpu_col: PackedColorArray = PackedColorArray()
var _cpu_vx: PackedFloat32Array = PackedFloat32Array()
var _cpu_vy: PackedFloat32Array = PackedFloat32Array()
var _cpu_mass: PackedFloat32Array = PackedFloat32Array()
var _cpu_vol: PackedFloat32Array = PackedFloat32Array()
var _cpu_cell_visc: PackedFloat32Array = PackedFloat32Array()
var _cpu_cell_p: PackedFloat32Array = PackedFloat32Array()
var _cpu_px: PackedFloat32Array = PackedFloat32Array()
var _cpu_py: PackedFloat32Array = PackedFloat32Array()
var _cpu_pr: PackedFloat32Array = PackedFloat32Array()
var _cpu_pg: PackedFloat32Array = PackedFloat32Array()
var _cpu_pb: PackedFloat32Array = PackedFloat32Array()
var _cpu_pw: PackedFloat32Array = PackedFloat32Array()
var _cpu_skip_acc: int = 0


func setup_from_texture(mask_texture: Texture2D) -> Texture2D:
	if not _gpu_checked:
		_gpu_checked = true
		_gpu_available = RenderingServer.get_rendering_device() != null

	_build_container_mask(mask_texture)

	if _gpu_available:
		_display_tex_rd = Texture2DRD.new()
		RenderingServer.call_on_render_thread(AtomicFluidSim._gpu_init_static.bind(self, _sdf_bytes))
		return _display_tex_rd
	else:
		_init_cpu_fallback(mask_texture)
		return _cpu_fallback_tex


func get_texture() -> Texture2D:
	if _gpu_available:
		return _display_tex_rd
	return _cpu_fallback_tex


func set_mouth_monitoring(enabled: bool) -> void:
	_monitor_mouth = enabled
	if not enabled and _active_count <= 0:
		_reset_mouth_state()


func is_liquid_touching_mouth() -> bool:
	return _active_count > 0 and _mouth_touching


func get_mouth_contact_ratio() -> float:
	if _active_count <= 0 or not _mouth_touching:
		return 0.0
	return _mouth_contact_ratio


func _reset_mouth_state() -> void:
	_mouth_readback_gen += 1
	_mouth_touching = false
	_mouth_hits = 0
	_mouth_contact_ratio = 0.0


func add_agitation(impulse_grid_vel: Vector2) -> void:
	_pending_impulse += impulse_grid_vel


func sync_bottle_liquid(id: String, current_amount: float, capacity: float, color: Color, buoyancy: float, viscosity_val: float = -1.0) -> void:
	if capacity <= 0.0001 or current_amount <= 0.0001:
		_sync_empty()
		return
	var clamped_amt := clampf(current_amount, 0.0, capacity)
	var layers := [[id, clamped_amt, color, {id: clamped_amt}]]
	var buoy_ov := {id: buoyancy} if buoyancy > 0.0 else {}
	var visc_ov := {id: viscosity_val} if viscosity_val >= 0.0 else {}
	sync_container_liquids(layers, capacity, false, buoy_ov, {}, visc_ov)


func sync_container_liquids(liquids: Array, capacity: float, is_mixed_flag: bool, buoyancy_overrides: Dictionary = {}, pour_info: Dictionary = {}, viscosity_overrides: Dictionary = {}) -> void:
	if _max_particles <= 0 or capacity <= 0.0001 or liquids.is_empty():
		_sync_empty()
		return

	var total_amt := 0.0
	var layer_items: Array[Dictionary] = []
	var new_amounts: Dictionary = {}

	for layer in liquids:
		if not (layer is Array) or layer.size() < 2:
			continue
		var amt := float(layer[1])
		if amt <= 0.0001:
			continue
		total_amt += amt

		var key: String = ""
		var col: Color = Color.WHITE
		var buoy: float = AtomicFluidShaders.get_layer_buoyancy(layer, buoyancy_overrides)
		var visc: float = 0.0

		if layer.size() > 2 and layer[2] is Color:
			col = layer[2]

		if layer[0] is Array or layer[0] is Dictionary:
			var ing_weights: Dictionary = {}
			if layer.size() > 3 and layer[3] is Dictionary and not (layer[3] as Dictionary).is_empty():
				ing_weights = layer[3]
			elif layer[0] is Dictionary:
				ing_weights = layer[0]
			else:
				for k in layer[0]:
					ing_weights[str(k)] = amt / maxf(float(layer[0].size()), 1.0)

			var keys := ing_weights.keys()
			keys.sort()
			var key_parts: Array[String] = []
			var w_sum := 0.0
			var visc_sum := 0.0
			for k in keys:
				var ks := str(k)
				key_parts.append(ks)
				var kw := maxf(float(ing_weights[k]), 0.0)
				var kv: float = clampf(float(viscosity_overrides.get(ks, AtomicFluidShaders.get_liquid_viscosity(ks))), 0.0, 1.0)
				w_sum += kw
				visc_sum += kw * kv
			key = "+".join(key_parts)
			visc = clampf(visc_sum / maxf(w_sum, 0.0001), 0.0, 1.0)
		else:
			key = str(layer[0])
			if not (layer.size() > 2 and layer[2] is Color):
				col = AtomicFluidShaders.LIQUID_COLOR.get(key, Color.WHITE)
			visc = clampf(float(viscosity_overrides.get(key, AtomicFluidShaders.get_liquid_viscosity(key))), 0.0, 1.0)

		var rho := 1.0 / clampf(buoy, 0.35, 2.5)
		new_amounts[key] = new_amounts.get(key, 0.0) + amt
		layer_items.append({
			"key": key,
			"amount": amt,
			"color": col,
			"rho": rho,
			"visc": visc,
		})

	if total_amt <= 0.0001 or layer_items.is_empty():
		_sync_empty()
		return

	var fill_ratio := clampf(total_amt / capacity, 0.0, 1.0)
	var target_count := clampi(roundi(fill_ratio * float(_max_particles)), 1, _max_particles)

	if _active_count == 0:
		_reset_mouth_state()
		var specs: Array[Dictionary] = []
		var assigned := 0
		for i in layer_items.size():
			var item: Dictionary = layer_items[i]
			var share := float(item["amount"]) / total_amt
			var cnt := (target_count - assigned) if i == layer_items.size() - 1 else clampi(roundi(share * float(target_count)), 0, target_count - assigned)
			if cnt > 0:
				specs.append({"count": cnt, "color": item["color"], "rho": item["rho"], "visc": item["visc"]})
				assigned += cnt
		if bool(pour_info.get("from_pour", false)):
			_queue_append_stream(specs, 0, pour_info, true)
		else:
			_queue_init_fill(specs, target_count)
		_active_count = target_count
		_synced_amounts = new_amounts
		_synced_total = total_amt
		_synced_mixed = is_mixed_flag
		_last_single_color = (layer_items[0]["color"] as Color) if layer_items.size() == 1 else Color(-1.0, -1.0, -1.0, -1.0)
		_last_single_rho = float(layer_items[0]["rho"]) if layer_items.size() == 1 else -1.0
		_last_single_visc = float(layer_items[0]["visc"]) if layer_items.size() == 1 else -1.0
		return

	if layer_items.size() == 1:
		var single_item: Dictionary = layer_items[0]
		var single_col: Color = single_item["color"]
		var single_rho: float = float(single_item["rho"])
		var single_visc: float = float(single_item["visc"])
		if (is_mixed_flag and not _synced_mixed) or single_col != _last_single_color or not is_equal_approx(single_rho, _last_single_rho) or not is_equal_approx(single_visc, _last_single_visc):
			_queue_blend(single_col, single_rho, single_visc, _active_count)
			_last_single_color = single_col
			_last_single_rho = single_rho
			_last_single_visc = single_visc
	else:
		_last_single_color = Color(-1.0, -1.0, -1.0, -1.0)
		_last_single_rho = -1.0
		_last_single_visc = -1.0

	if target_count > _active_count:
		var add_total := target_count - _active_count
		var added_specs: Array[Dictionary] = []
		var delta_sum := 0.0
		for item in layer_items:
			var k: String = item["key"]
			var prev_a := float(_synced_amounts.get(k, 0.0))
			var cur_a := float(new_amounts.get(k, 0.0))
			var diff := maxf(cur_a - prev_a, 0.0)
			if diff > 0.0001:
				delta_sum += diff
				added_specs.append({"diff": diff, "color": item["color"], "rho": item["rho"], "visc": item["visc"]})

		if delta_sum <= 0.0001:
			var last_item: Dictionary = layer_items[layer_items.size() - 1]
			added_specs.append({"diff": 1.0, "color": last_item["color"], "rho": last_item["rho"], "visc": last_item["visc"]})
			delta_sum = 1.0

		var spawn_specs: Array[Dictionary] = []
		var assigned_add := 0
		for i in added_specs.size():
			var sp: Dictionary = added_specs[i]
			var cnt := (add_total - assigned_add) if i == added_specs.size() - 1 else clampi(roundi((float(sp["diff"]) / delta_sum) * float(add_total)), 0, add_total - assigned_add)
			if cnt > 0:
				spawn_specs.append({"count": cnt, "color": sp["color"], "rho": sp["rho"], "visc": sp["visc"]})
				assigned_add += cnt

		if assigned_add > 0:
			if bool(pour_info.get("from_pour", false)):
				_queue_append_stream(spawn_specs, _active_count, pour_info, false)
			else:
				_queue_append_surface(spawn_specs, _active_count)
			_active_count += assigned_add

	elif target_count < _active_count:
		var remove_count := _active_count - target_count
		_queue_cull(remove_count, _active_count, target_count)
		_active_count = target_count

	_synced_amounts = new_amounts
	_synced_total = total_amt
	_synced_mixed = is_mixed_flag


func _sync_empty() -> void:
	_reset_mouth_state()
	if _active_count == 0 and _synced_total <= 0.0:
		return
	_active_count = 0
	_synced_amounts.clear()
	_synced_total = 0.0
	_synced_mixed = false
	_last_single_color = Color(-1.0, -1.0, -1.0, -1.0)
	_last_single_rho = -1.0
	_last_single_visc = -1.0
	_pending_ops.append({"op": "clear"})


func step(delta: float, local_accel_world: Vector2, viscosity: float) -> void:
	if _disposed:
		return

	if _active_count <= 0:
		_mouth_touching = false
		_mouth_hits = 0
		_mouth_contact_ratio = 0.0

	var scale_g := GRID_GRAVITY / 9.8
	var grid_accel := Vector2(local_accel_world.x * scale_g, -local_accel_world.y * scale_g)
	if grid_accel.length() > MAX_GRID_ACCEL:
		grid_accel = grid_accel.normalized() * MAX_GRID_ACCEL

	var imp := _pending_impulse
	_pending_impulse = Vector2.ZERO
	if imp.length() > MAX_IMPULSE_VEL:
		imp = imp.normalized() * MAX_IMPULSE_VEL

	if grid_accel.length_squared() > 0.01:
		_last_down_dir = grid_accel.normalized()

	var clamped_delta := clampf(delta, MIN_FRAME_DELTA, MAX_FRAME_DELTA)
	var sim_dt := clamped_delta * float(maxi(STEP_SKIP, 1))
	var accel_with_imp := grid_accel + imp / maxf(sim_dt, 0.008)

	var ops_copy: Array = []
	if not _pending_ops.is_empty():
		ops_copy = _pending_ops.duplicate()
		_pending_ops.clear()

	var want_mouth_readback := _active_count > 0 and (
		_monitor_mouth
		or absf(local_accel_world.x) > 0.35
		or local_accel_world.y > -8.8
	)

	if _gpu_available:
		RenderingServer.call_on_render_thread(
			AtomicFluidSim._gpu_step_static.bind(self, clamped_delta, accel_with_imp, clampf(viscosity, 0.0, 1.0), _active_count, _last_down_dir, ops_copy, want_mouth_readback, _mouth_readback_gen)
		)
	else:
		_cpu_step(clamped_delta, accel_with_imp, clampf(viscosity, 0.0, 1.0), ops_copy)


func cleanup() -> void:
	if _disposed:
		return
	_disposed = true
	_reset_mouth_state()
	_pending_ops.clear()

	if _display_tex_rd:
		_display_tex_rd.texture_rd_rid = RID()
		_display_tex_rd = null

	var sets_to_free: Array[RID] = []
	for uset_key in _sets.keys():
		var urid: RID = _sets[uset_key]
		if urid.is_valid():
			sets_to_free.append(urid)
	var owned: Array[RID] = []
	for rid in [_in_volume_a, _in_volume_b, _density_buf, _particles_buf, _wall_sdf_buf, _out_tex_rid]:
		if rid.is_valid():
			owned.append(rid)
	var mouth_buf := _mouth_buf
	_in_volume_a = RID()
	_in_volume_b = RID()
	_density_buf = RID()
	_particles_buf = RID()
	_wall_sdf_buf = RID()
	_out_tex_rid = RID()
	_sets.clear()

	if _gpu_available and RenderingServer.get_rendering_device() != null and (not owned.is_empty() or not sets_to_free.is_empty() or mouth_buf.is_valid()):
		RenderingServer.call_on_render_thread(self._cleanup_gpu_rids_rt.bind(owned, sets_to_free, mouth_buf))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _disposed:
			return
		_disposed = true
		_reset_mouth_state()
		_pending_ops.clear()

		if _display_tex_rd:
			_display_tex_rd.texture_rd_rid = RID()
			_display_tex_rd = null

		var sets_to_free: Array[RID] = []
		for uset_key in _sets.keys():
			var urid: RID = _sets[uset_key]
			if urid.is_valid():
				sets_to_free.append(urid)
		var owned: Array[RID] = []
		for rid in [_in_volume_a, _in_volume_b, _density_buf, _particles_buf, _wall_sdf_buf, _mouth_buf, _out_tex_rid]:
			if rid.is_valid():
				owned.append(rid)
		_in_volume_a = RID()
		_in_volume_b = RID()
		_density_buf = RID()
		_particles_buf = RID()
		_wall_sdf_buf = RID()
		_mouth_buf = RID()
		_out_tex_rid = RID()
		_sets.clear()

		if _gpu_available and RenderingServer.get_rendering_device() != null and (not owned.is_empty() or not sets_to_free.is_empty()):
			RenderingServer.call_on_render_thread(AtomicFluidSim._free_rids_on_render_thread.bind(owned, sets_to_free))


func _cleanup_gpu_rids_rt(rids: Array[RID], uniform_sets: Array[RID], mouth_buf: RID) -> void:
	_disposed_rt = true
	var rd := RenderingServer.get_rendering_device()
	if not rd:
		return
	for urid in uniform_sets:
		if urid.is_valid() and rd.uniform_set_is_valid(urid):
			rd.free_rid(urid)
	for rid in rids:
		if rid.is_valid():
			rd.free_rid(rid)
	if mouth_buf.is_valid() and not _mouth_readback_pending_rt:
		rd.free_rid(mouth_buf)
		_mouth_buf = RID()


static func _gpu_init_static(sim: AtomicFluidSim, sdf_bytes: PackedByteArray) -> void:
	if sim and not sim._disposed:
		sim._gpu_init_instance(sdf_bytes)


static func _gpu_step_static(sim: AtomicFluidSim, frame_dt: float, accel: Vector2, viscosity: float, active_count: int, down_dir: Vector2, ops: Array, want_mouth_readback: bool, readback_gen: int) -> void:
	if sim and not sim._disposed:
		sim._gpu_step(frame_dt, accel, viscosity, active_count, down_dir, ops, want_mouth_readback, readback_gen)


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
	if _disposed or gen != _mouth_readback_gen or _active_count <= 0 or data.size() < 12:
		return
	var hits := int(data.decode_u32(0))
	var max_w := int(data.decode_u32(8))
	_mouth_hits = hits
	_mouth_touching = hits > 0 and max_w >= MOUTH_WEIGHT_THRESHOLD
	if _mouth_touching:
		_mouth_contact_ratio = clampf(float(hits) / maxf(float(_mouth_cell_count) * 0.5, 1.0), 0.0, 1.0)
	else:
		_mouth_contact_ratio = 0.0


func _encode_particle(bytes: PackedByteArray, pidx: int, px: float, py: float, rho: float, visc: float, col: Color, vx: float, vy: float, inject_vel: float) -> void:
	var base := pidx * PARTICLE_STRIDE
	bytes.encode_float(base + 0, px)
	bytes.encode_float(base + 4, py)
	bytes.encode_float(base + 8, rho)
	bytes.encode_float(base + 12, PARTICLE_VOLUME_WEIGHT)
	bytes.encode_float(base + 16, col.r)
	bytes.encode_float(base + 20, col.g)
	bytes.encode_float(base + 24, col.b)
	bytes.encode_float(base + 28, 1.0)
	bytes.encode_float(base + 32, vx)
	bytes.encode_float(base + 36, vy)
	bytes.encode_float(base + 40, inject_vel)
	bytes.encode_float(base + 44, clampf(visc, 0.0, 1.0))


func _queue_init_fill(specs: Array[Dictionary], total_particles: int) -> void:
	var sorted_specs: Array[Dictionary] = []
	sorted_specs.assign(specs)
	sorted_specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["rho"]) > float(b["rho"])
	)

	var bytes := PackedByteArray()
	bytes.resize(total_particles * PARTICLE_STRIDE)

	var offsets: Array[Vector2] = [
		Vector2(0.25, 0.25),
		Vector2(0.75, 0.25),
		Vector2(0.25, 0.75),
		Vector2(0.75, 0.75),
	]

	var cell_count := _mask_cells.size()
	var pidx := 0
	var spec_idx := 0
	var spec_rem := int(sorted_specs[0]["count"]) if not sorted_specs.is_empty() else 0

	for c_i in cell_count:
		if pidx >= total_particles:
			break
		var cell := _mask_cells[c_i]
		for sub in PARTICLES_PER_CELL:
			if pidx >= total_particles:
				break
			while spec_rem <= 0 and spec_idx + 1 < sorted_specs.size():
				spec_idx += 1
				spec_rem = int(sorted_specs[spec_idx]["count"])
			var sp: Dictionary = sorted_specs[spec_idx]
			spec_rem -= 1

			var off: Vector2 = offsets[sub]
			var px := clampf(float(cell.x) + off.x + randf_range(-0.06, 0.06), 0.55, float(GRID_SIZE) - 1.55)
			var py := clampf(float(cell.y) + off.y + randf_range(-0.06, 0.06), 0.55, float(GRID_SIZE) - 1.55)
			var rho := float(sp["rho"])
			var visc := float(sp.get("visc", 0.0))
			var col: Color = sp["color"]
			_encode_particle(bytes, pidx, px, py, rho, visc, col, 0.0, 0.0, 0.0)
			pidx += 1

	_pending_ops.append({
		"op": "init_upload",
		"bytes": bytes,
		"count": pidx,
	})


func _queue_append_surface(specs: Array[Dictionary], start_index: int) -> void:
	var total_add := 0
	for sp in specs:
		total_add += int(sp["count"])
	if total_add <= 0 or _mask_cells.is_empty():
		return

	var bytes := PackedByteArray()
	bytes.resize(total_add * PARTICLE_STRIDE)

	var offsets: Array[Vector2] = [
		Vector2(0.25, 0.25),
		Vector2(0.75, 0.25),
		Vector2(0.25, 0.75),
		Vector2(0.75, 0.75),
	]

	var cell_count := _mask_cells.size()
	var pidx := 0
	for sp in specs:
		var cnt := int(sp["count"])
		var rho := float(sp["rho"])
		var visc := float(sp.get("visc", 0.0))
		var col: Color = sp["color"]
		for _i in cnt:
			var global_idx := start_index + pidx
			var cell_idx := clampi(global_idx / PARTICLES_PER_CELL, 0, cell_count - 1)
			var sub := global_idx % PARTICLES_PER_CELL
			var cell := _mask_cells[cell_idx]
			var off: Vector2 = offsets[sub]
			var px := clampf(float(cell.x) + off.x + randf_range(-0.04, 0.04), 0.55, float(GRID_SIZE) - 1.55)
			var py := clampf(float(cell.y) + off.y + randf_range(-0.04, 0.04), 0.55, float(GRID_SIZE) - 1.55)
			_encode_particle(bytes, pidx, px, py, rho, visc, col, 0.0, 0.0, 0.0)
			pidx += 1

	_pending_ops.append({
		"op": "append_upload",
		"offset": start_index * PARTICLE_STRIDE,
		"bytes": bytes,
		"count": total_add,
	})


func _clamp_point_to_mask(px: float, py: float) -> Vector2:
	var cy := clampi(int(roundf(py)), _top_rim_y, _bottom_y)
	if _row_min_x[cy] >= 0 and _row_max_x[cy] >= _row_min_x[cy]:
		var min_x := float(_row_min_x[cy]) + 0.65
		var max_x := float(_row_max_x[cy]) + 0.35
		if min_x > max_x:
			var mid_x := (float(_row_min_x[cy]) + float(_row_max_x[cy])) * 0.5 + 0.5
			min_x = mid_x
			max_x = mid_x
		var clamped_x := clampf(px, min_x, max_x)
		var cx := clampi(int(clamped_x), 0, GRID_SIZE - 1)
		if _mask_bytes[cx + cy * GRID_SIZE] == 1:
			return Vector2(clampf(clamped_x, 0.55, float(GRID_SIZE) - 1.55), clampf(py, float(_top_rim_y) + 0.55, float(_bottom_y) + 0.45))
	var fallback := _mask_cells[_mask_cells.size() - 1]
	return Vector2(float(fallback.x) + 0.5, float(fallback.y) + 0.5)


func _queue_append_stream(specs: Array[Dictionary], start_index: int, pour_info: Dictionary, is_initial_upload: bool) -> void:
	var total_add := 0
	for sp in specs:
		total_add += int(sp["count"])
	if total_add <= 0 or _mask_cells.is_empty():
		return

	var bytes := PackedByteArray()
	bytes.resize(total_add * PARTICLE_STRIDE)

	var entry_u: float = clampf(float(pour_info.get("entry_u", 0.5)), 0.12, 0.88)
	var stream_vx: float = clampf(float(pour_info.get("stream_vx", 0.0)), -18.0, 18.0)
	var stream_vy: float = clampf(float(pour_info.get("stream_vy", 34.0)), 14.0, 50.0)

	var open_y := clampi(_top_rim_y + 1, 0, GRID_SIZE - 1)
	while open_y < _bottom_y and _row_min_x[open_y] < 0:
		open_y += 1
	var open_min_x := float(_row_min_x[open_y]) if _row_min_x[open_y] >= 0 else 16.0
	var open_max_x := float(_row_max_x[open_y]) if _row_max_x[open_y] >= 0 else 48.0
	var nozzle_x := lerpf(open_min_x + 1.0, open_max_x, entry_u)

	var cell_count := _mask_cells.size()
	var filled_cell_idx := clampi(start_index / PARTICLES_PER_CELL, 0, cell_count - 1)
	var surface_y := float(_mask_cells[filled_cell_idx].y) if start_index > 0 else float(_bottom_y)

	var stream_top_y := float(open_y) + 0.65
	var max_air_drop := maxf(surface_y - stream_top_y - 0.5, 1.5)
	var jet_depth := clampf(2.2 + float(total_add) / 22.0, 2.2, minf(max_air_drop, 12.0))
	var stream_half_width := clampf(1.1 + float(total_add) / 140.0, 1.1, 2.4)

	var pidx := 0
	for sp in specs:
		var cnt := int(sp["count"])
		var rho := float(sp["rho"])
		var visc := float(sp.get("visc", 0.0))
		var col: Color = sp["color"]
		for _i in cnt:
			var t := (float(pidx) + randf_range(0.0, 0.85)) / maxf(float(total_add), 1.0)
			t = clampf(t, 0.0, 1.0)
			var raw_y := stream_top_y + t * jet_depth
			var drift_x := stream_vx * (t * 0.06)
			var raw_x := nozzle_x + drift_x + randf_range(-stream_half_width, stream_half_width)
			var clamped_pos := _clamp_point_to_mask(raw_x, raw_y)

			var p_vx := stream_vx + randf_range(-1.8, 1.8)
			var p_vy := stream_vy + randf_range(-3.0, 3.0)
			_encode_particle(bytes, pidx, clamped_pos.x, clamped_pos.y, rho, visc, col, p_vx, p_vy, 1.0)
			pidx += 1

	_pending_ops.append({
		"op": "init_upload" if is_initial_upload else "append_upload",
		"offset": 0 if is_initial_upload else start_index * PARTICLE_STRIDE,
		"bytes": bytes,
		"count": total_add,
	})


func _queue_cull(remove_count: int, old_count: int, new_count: int) -> void:
	_pending_ops.append({
		"op": "cull",
		"remove_count": remove_count,
		"old_count": old_count,
		"new_count": new_count,
	})


func _queue_blend(col: Color, target_rho: float, target_visc: float, active_count: int) -> void:
	_pending_ops.append({
		"op": "blend",
		"color": col,
		"rho": target_rho,
		"visc": clampf(target_visc, 0.0, 1.0),
		"count": active_count,
	})


static func _build_mouth_mask(mask: PackedByteArray, row_min_x: PackedInt32Array, row_max_x: PackedInt32Array, top_rim_y: int, bottom_y: int) -> PackedByteArray:
	var mouth := PackedByteArray()
	mouth.resize(GRID_CELLS)
	if bottom_y < top_rim_y:
		return mouth

	var col_top_y := PackedInt32Array()
	col_top_y.resize(GRID_SIZE)
	col_top_y.fill(GRID_SIZE)
	for x in GRID_SIZE:
		for y in range(top_rim_y, bottom_y + 1):
			if mask[x + y * GRID_SIZE] == 1:
				col_top_y[x] = y
				break

	var max_body_width := 0
	for y in range(top_rim_y, bottom_y + 1):
		if row_max_x[y] >= row_min_x[y]:
			max_body_width = maxi(max_body_width, row_max_x[y] - row_min_x[y] + 1)

	var cavity_h := maxi(1, bottom_y - top_rim_y)
	var top_w := (row_max_x[top_rim_y] - row_min_x[top_rim_y] + 1) if row_max_x[top_rim_y] >= row_min_x[top_rim_y] else 0
	var next_y := mini(top_rim_y + 1, bottom_y)
	var next_w := (row_max_x[next_y] - row_min_x[next_y] + 1) if row_max_x[next_y] >= row_min_x[next_y] else top_w
	var probe_y := mini(top_rim_y + 2, bottom_y)
	var probe_w := (row_max_x[probe_y] - row_min_x[probe_y] + 1) if row_max_x[probe_y] >= row_min_x[probe_y] else next_w

	var is_narrow_neck := (
		float(top_w) < float(max_body_width) * 0.58
		and float(next_w) < float(max_body_width) * 0.60
		and float(probe_w) < float(max_body_width) * 0.65
	)

	var band_pct := 0.14 if is_narrow_neck else 0.08
	var min_band := 3 if is_narrow_neck else 2
	var y_limit := mini(bottom_y, top_rim_y + maxi(min_band, int(round(float(cavity_h) * band_pct))))

	var neck_ref_w := maxi(top_w, next_w)
	var effective_band_end := top_rim_y
	for y in range(top_rim_y, y_limit + 1):
		if row_max_x[y] < row_min_x[y]:
			break
		var w_y := row_max_x[y] - row_min_x[y] + 1
		if y > top_rim_y + 1:
			if is_narrow_neck:
				if y > top_rim_y + 2 and float(w_y) > float(maxi(neck_ref_w, 2)) * 1.65 and float(w_y) >= float(max_body_width) * 0.55:
					break
				if float(w_y) >= float(max_body_width) * 0.72:
					break
			else:
				var prev_w := (row_max_x[y - 1] - row_min_x[y - 1] + 1) if row_max_x[y - 1] >= row_min_x[y - 1] else w_y
				if float(prev_w) < float(max_body_width) * 0.45 and float(w_y) > float(maxi(prev_w, 1)) * 1.9:
					break
		effective_band_end = y

	if is_narrow_neck:
		for y in range(top_rim_y, effective_band_end + 1):
			if row_max_x[y] < row_min_x[y]:
				continue
			for x in range(row_min_x[y], row_max_x[y] + 1):
				if mask[x + y * GRID_SIZE] == 1:
					mouth[x + y * GRID_SIZE] = 1
		return mouth

	if row_max_x[effective_band_end] >= row_min_x[effective_band_end]:
		var end_w := row_max_x[effective_band_end] - row_min_x[effective_band_end] + 1
		if float(end_w) < float(max_body_width) * 0.45:
			effective_band_end = mini(bottom_y, top_rim_y + 2)

	var has_multi_row_rim := false
	for x in GRID_SIZE:
		var ty := col_top_y[x]
		if ty > effective_band_end:
			continue
		if mask[x + ty * GRID_SIZE] == 1:
			mouth[x + ty * GRID_SIZE] = 1
			if x == GRID_SIZE - 1 and x > 0 and mask[(x - 1) + ty * GRID_SIZE] == 1:
				mouth[(x - 1) + ty * GRID_SIZE] = 1
		var max_drop := ty
		if x > 0 and col_top_y[x - 1] <= effective_band_end and col_top_y[x - 1] > ty + 1:
			max_drop = maxi(max_drop, col_top_y[x - 1] - 1)
		if x + 1 < GRID_SIZE and col_top_y[x + 1] <= effective_band_end and col_top_y[x + 1] > ty + 1:
			max_drop = maxi(max_drop, col_top_y[x + 1] - 1)
		if max_drop > ty:
			has_multi_row_rim = true
		for y in range(ty + 1, max_drop + 1):
			if mask[x + y * GRID_SIZE] == 1:
				mouth[x + y * GRID_SIZE] = 1

	if not has_multi_row_rim:
		for x in GRID_SIZE:
			var ty := col_top_y[x]
			if ty < effective_band_end and ty + 1 <= bottom_y and mask[x + (ty + 1) * GRID_SIZE] == 1:
				mouth[x + (ty + 1) * GRID_SIZE] = 1

	return mouth


static func _sample_image_mask(img: Image, grid_n: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(grid_n * grid_n)
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		for y in grid_n:
			var y0 := clampi(int(floor(float(y) / float(grid_n) * float(h))), 0, h - 1)
			var y1 := clampi(int(ceil(float(y + 1) / float(grid_n) * float(h))) - 1, y0, h - 1)
			for x in grid_n:
				var x0 := clampi(int(floor(float(x) / float(grid_n) * float(w))), 0, w - 1)
				var x1 := clampi(int(ceil(float(x + 1) / float(grid_n) * float(w))) - 1, x0, w - 1)
				var max_a := 0.0
				for sy in range(y0, y1 + 1):
					for sx in range(x0, x1 + 1):
						max_a = maxf(max_a, img.get_pixel(sx, sy).a)
						if max_a > 0.1:
							break
					if max_a > 0.1:
						break
				mask[x + y * grid_n] = 1 if max_a > 0.1 else 0
	return mask


func _build_container_mask(tex: Texture2D) -> void:
	var cache_key: int = tex.get_rid().get_id() if tex else -1
	if cache_key != -1 and _mask_cache.has(cache_key):
		var cached: Dictionary = _mask_cache[cache_key]
		_mask_cells = cached["cells"]
		_mask_bytes = cached["mask_bytes"]
		_mouth_mask_bytes = cached["mouth_mask_bytes"]
		_mouth_cell_count = int(cached["mouth_cell_count"])
		_row_min_x = cached["row_min_x"]
		_row_max_x = cached["row_max_x"]
		_top_rim_y = int(cached["top_rim_y"])
		_bottom_y = int(cached["bottom_y"])
		_sdf_bytes = cached["sdf_bytes"]
		_max_particles = _mask_cells.size() * PARTICLES_PER_CELL
		return

	var mask := PackedByteArray()
	var img: Image = tex.get_image() if tex else null
	if img != null and not img.is_empty():
		mask = _sample_image_mask(img, GRID_SIZE)
	else:
		mask.resize(GRID_CELLS)
		for y in range(4, GRID_SIZE - 4):
			for x in range(10, GRID_SIZE - 10):
				mask[x + y * GRID_SIZE] = 1

	var cells: Array[Vector2i] = []
	for y in range(GRID_SIZE - 1, -1, -1):
		var row_cells: Array[Vector2i] = []
		for x in GRID_SIZE:
			if mask[x + y * GRID_SIZE] == 1:
				row_cells.append(Vector2i(x, y))
		row_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return absf(float(a.x) - 31.5) < absf(float(b.x) - 31.5)
		)
		cells.append_array(row_cells)

	if cells.is_empty():
		for y in range(4, GRID_SIZE - 4):
			for x in range(10, GRID_SIZE - 10):
				mask[x + y * GRID_SIZE] = 1
		for y in range(GRID_SIZE - 1, -1, -1):
			for x in GRID_SIZE:
				if mask[x + y * GRID_SIZE] == 1:
					cells.append(Vector2i(x, y))

	var row_min_x := PackedInt32Array()
	var row_max_x := PackedInt32Array()
	row_min_x.resize(GRID_SIZE)
	row_max_x.resize(GRID_SIZE)
	var top_rim_y := GRID_SIZE - 1
	var bottom_y := 0
	for y in GRID_SIZE:
		var r_min := GRID_SIZE
		var r_max := -1
		for x in GRID_SIZE:
			if mask[x + y * GRID_SIZE] == 1:
				r_min = mini(r_min, x)
				r_max = maxi(r_max, x)
		if r_max >= r_min:
			row_min_x[y] = r_min
			row_max_x[y] = r_max
			top_rim_y = mini(top_rim_y, y)
			bottom_y = maxi(bottom_y, y)
		else:
			row_min_x[y] = -1
			row_max_x[y] = -1

	var mouth_mask := _build_mouth_mask(mask, row_min_x, row_max_x, top_rim_y, bottom_y)
	var mouth_cell_count := 0
	for i in GRID_CELLS:
		if mouth_mask[i] == 1:
			mouth_cell_count += 1

	var dist_in := PackedFloat32Array()
	var dist_out := PackedFloat32Array()
	dist_in.resize(GRID_CELLS)
	dist_out.resize(GRID_CELLS)

	var big := 1000.0
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var idx := x + y * GRID_SIZE
			var on_border := (x == 0 or x == GRID_SIZE - 1 or y == 0 or y == GRID_SIZE - 1)
			if mask[idx] == 1 and not on_border:
				dist_in[idx] = big
				dist_out[idx] = 0.0
			elif mask[idx] == 1 and on_border:
				dist_in[idx] = 0.5
				dist_out[idx] = 0.0
			else:
				dist_in[idx] = 0.0
				dist_out[idx] = big

	_edt_2d_pass(dist_in)
	_edt_2d_pass(dist_out)

	var signed_dist := PackedFloat32Array()
	signed_dist.resize(GRID_CELLS)
	for i in GRID_CELLS:
		if mask[i] == 1:
			signed_dist[i] = maxf(0.15, dist_in[i])
		else:
			signed_dist[i] = -maxf(0.25, dist_out[i])

	var sdf_bytes := PackedByteArray()
	sdf_bytes.resize(GRID_CELLS * 16)
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var idx := x + y * GRID_SIZE
			var xl := signed_dist[maxi(x - 1, 0) + y * GRID_SIZE]
			var xr := signed_dist[mini(x + 1, GRID_SIZE - 1) + y * GRID_SIZE]
			var yu := signed_dist[x + maxi(y - 1, 0) * GRID_SIZE]
			var yd := signed_dist[x + mini(y + 1, GRID_SIZE - 1) * GRID_SIZE]
			var grad := Vector2(xr - xl, yd - yu)
			if grad.length_squared() > 0.00001:
				grad = grad.normalized()
			else:
				grad = Vector2(0.0, -1.0)
			var wall_flag := 2.0 if mouth_mask[idx] == 1 else (1.0 if mask[idx] == 1 else 0.0)
			var off := idx * 16
			sdf_bytes.encode_float(off + 0, grad.x)
			sdf_bytes.encode_float(off + 4, grad.y)
			sdf_bytes.encode_float(off + 8, signed_dist[idx])
			sdf_bytes.encode_float(off + 12, wall_flag)

	_mask_cells = cells
	_mask_bytes = mask
	_mouth_mask_bytes = mouth_mask
	_mouth_cell_count = mouth_cell_count
	_row_min_x = row_min_x
	_row_max_x = row_max_x
	_top_rim_y = top_rim_y
	_bottom_y = bottom_y
	_sdf_bytes = sdf_bytes
	_max_particles = _mask_cells.size() * PARTICLES_PER_CELL

	if cache_key != -1:
		_mask_cache[cache_key] = {
			"cells": cells,
			"mask_bytes": mask,
			"mouth_mask_bytes": mouth_mask,
			"mouth_cell_count": mouth_cell_count,
			"row_min_x": row_min_x,
			"row_max_x": row_max_x,
			"top_rim_y": top_rim_y,
			"bottom_y": bottom_y,
			"sdf_bytes": sdf_bytes,
		}


static func _edt_2d_pass(d: PackedFloat32Array) -> void:
	var sqrt2 := 1.41421356
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var i := x + y * GRID_SIZE
			var v := d[i]
			if v <= 0.0:
				continue
			if x > 0:
				v = minf(v, d[(x - 1) + y * GRID_SIZE] + 1.0)
			if y > 0:
				v = minf(v, d[x + (y - 1) * GRID_SIZE] + 1.0)
				if x > 0:
					v = minf(v, d[(x - 1) + (y - 1) * GRID_SIZE] + sqrt2)
				if x < GRID_SIZE - 1:
					v = minf(v, d[(x + 1) + (y - 1) * GRID_SIZE] + sqrt2)
			d[i] = v

	for y in range(GRID_SIZE - 1, -1, -1):
		for x in range(GRID_SIZE - 1, -1, -1):
			var i := x + y * GRID_SIZE
			var v := d[i]
			if v <= 0.0:
				continue
			if x < GRID_SIZE - 1:
				v = minf(v, d[(x + 1) + y * GRID_SIZE] + 1.0)
			if y < GRID_SIZE - 1:
				v = minf(v, d[x + (y + 1) * GRID_SIZE] + 1.0)
				if x > 0:
					v = minf(v, d[(x - 1) + (y + 1) * GRID_SIZE] + sqrt2)
				if x < GRID_SIZE - 1:
					v = minf(v, d[(x + 1) + (y + 1) * GRID_SIZE] + sqrt2)
			d[i] = v


static func _ensure_shared_pipelines(rd: RenderingDevice) -> bool:
	if _shaders_ready:
		return true

	var sources := {
		"clear": AtomicFluidShaders.CLEAR_GLSL,
		"grid_ops": AtomicFluidShaders.GRID_OPS_GLSL,
		"density_scatter": AtomicFluidShaders.DENSITY_SCATTER_GLSL,
		"fluid": AtomicFluidShaders.FLUID_GLSL,
		"display_clear": AtomicFluidShaders.DISPLAY_CLEAR_GLSL,
		"display_splat": AtomicFluidShaders.DISPLAY_SPLAT_GLSL,
		"display_resolve": AtomicFluidShaders.DISPLAY_RESOLVE_GLSL,
		"cull_hist": AtomicFluidShaders.CULL_HIST_GLSL,
		"cull_scan": AtomicFluidShaders.CULL_SCAN_GLSL,
		"cull_compact": AtomicFluidShaders.CULL_COMPACT_GLSL,
		"cull_copyback": AtomicFluidShaders.CULL_COPYBACK_GLSL,
		"blend": AtomicFluidShaders.BLEND_PARTICLES_GLSL,
	}

	for key in sources.keys():
		var src := RDShaderSource.new()
		src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		src.source_compute = sources[key]
		var spirv := rd.shader_compile_spirv_from_source(src)
		if spirv == null or spirv.compile_error_compute != "":
			push_error("AtomicFluidSim shader compile error (%s): %s" % [key, spirv.compile_error_compute if spirv else "null spirv"])
			return false
		var sh := rd.shader_create_from_spirv(spirv)
		if not sh.is_valid():
			push_error("AtomicFluidSim failed to create shader (%s)" % key)
			return false
		var pip := rd.compute_pipeline_create(sh)
		_shaders[key] = sh
		_pipelines[key] = pip

	var scratch_zero := PackedByteArray()
	scratch_zero.resize(MAX_PARTICLES * PARTICLE_STRIDE)
	_shared_scratch_buf = rd.storage_buffer_create(scratch_zero.size(), scratch_zero)

	var meta_zero := PackedByteArray()
	meta_zero.resize(272)
	_shared_cull_meta_buf = rd.storage_buffer_create(272, meta_zero)
	_shared_cull_scan_set = _make_uniform_set(rd, _shaders["cull_scan"], [
		_ssbo_uniform(0, _shared_cull_meta_buf),
	])
	_shaders_ready = true
	return true


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


func _gpu_init_instance(sdf_bytes: PackedByteArray) -> void:
	if _disposed or _disposed_rt or _gpu_initialized:
		return
	var rd := RenderingServer.get_rendering_device()
	if not rd or not _ensure_shared_pipelines(rd):
		return

	var vol_zero := PackedByteArray()
	vol_zero.resize(GRID_CELLS * 16)
	_in_volume_a = rd.storage_buffer_create(vol_zero.size(), vol_zero)
	_in_volume_b = rd.storage_buffer_create(vol_zero.size(), vol_zero)

	var den_zero := PackedByteArray()
	den_zero.resize(GRID_CELLS * 8)
	_density_buf = rd.storage_buffer_create(den_zero.size(), den_zero)

	var part_zero := PackedByteArray()
	part_zero.resize(maxi(_max_particles, 64) * PARTICLE_STRIDE)
	_particles_buf = rd.storage_buffer_create(part_zero.size(), part_zero)

	_wall_sdf_buf = rd.storage_buffer_create(sdf_bytes.size(), sdf_bytes)

	var mouth_zero := PackedByteArray()
	mouth_zero.resize(16)
	_mouth_buf = rd.storage_buffer_create(16, mouth_zero)

	var fmt := RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.width = GRID_SIZE
	fmt.height = GRID_SIZE
	fmt.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	_out_tex_rid = rd.texture_create(fmt, RDTextureView.new())
	rd.texture_clear(_out_tex_rid, Color(0, 0, 0, 0), 0, 1, 0, 1)
	_tex_cleared = true

	_sets["clear"] = _make_uniform_set(rd, _shaders["clear"], [
		_ssbo_uniform(0, _in_volume_a),
		_ssbo_uniform(1, _in_volume_b),
		_ssbo_uniform(2, _density_buf),
	])

	_sets["grid_ops_0"] = _make_uniform_set(rd, _shaders["grid_ops"], [
		_ssbo_uniform(0, _in_volume_a),
		_ssbo_uniform(1, _in_volume_b),
		_ssbo_uniform(2, _density_buf),
		_ssbo_uniform(3, _wall_sdf_buf),
	])
	_sets["grid_ops_1"] = _make_uniform_set(rd, _shaders["grid_ops"], [
		_ssbo_uniform(0, _in_volume_b),
		_ssbo_uniform(1, _in_volume_a),
		_ssbo_uniform(2, _density_buf),
		_ssbo_uniform(3, _wall_sdf_buf),
	])

	_sets["density_0"] = _make_uniform_set(rd, _shaders["density_scatter"], [
		_ssbo_uniform(0, _in_volume_a),
		_ssbo_uniform(1, _density_buf),
		_ssbo_uniform(2, _particles_buf),
		_ssbo_uniform(3, _wall_sdf_buf),
	])
	_sets["density_1"] = _make_uniform_set(rd, _shaders["density_scatter"], [
		_ssbo_uniform(0, _in_volume_b),
		_ssbo_uniform(1, _density_buf),
		_ssbo_uniform(2, _particles_buf),
		_ssbo_uniform(3, _wall_sdf_buf),
	])

	_sets["fluid_0"] = _make_uniform_set(rd, _shaders["fluid"], [
		_ssbo_uniform(0, _in_volume_a),
		_ssbo_uniform(1, _in_volume_b),
		_ssbo_uniform(2, _density_buf),
		_ssbo_uniform(3, _particles_buf),
		_ssbo_uniform(4, _wall_sdf_buf),
	])
	_sets["fluid_1"] = _make_uniform_set(rd, _shaders["fluid"], [
		_ssbo_uniform(0, _in_volume_b),
		_ssbo_uniform(1, _in_volume_a),
		_ssbo_uniform(2, _density_buf),
		_ssbo_uniform(3, _particles_buf),
		_ssbo_uniform(4, _wall_sdf_buf),
	])

	_sets["disp_clear_0"] = _make_uniform_set(rd, _shaders["display_clear"], [
		_ssbo_uniform(0, _in_volume_a),
		_ssbo_uniform(1, _mouth_buf),
	])
	_sets["disp_clear_1"] = _make_uniform_set(rd, _shaders["display_clear"], [
		_ssbo_uniform(0, _in_volume_b),
		_ssbo_uniform(1, _mouth_buf),
	])

	_sets["disp_splat_0"] = _make_uniform_set(rd, _shaders["display_splat"], [
		_ssbo_uniform(0, _in_volume_a),
		_ssbo_uniform(1, _particles_buf),
	])
	_sets["disp_splat_1"] = _make_uniform_set(rd, _shaders["display_splat"], [
		_ssbo_uniform(0, _in_volume_b),
		_ssbo_uniform(1, _particles_buf),
	])

	_sets["disp_resolve_0"] = _make_uniform_set(rd, _shaders["display_resolve"], [
		_ssbo_uniform(0, _in_volume_a),
		_ssbo_uniform(1, _wall_sdf_buf),
		_img_uniform(2, _out_tex_rid),
		_ssbo_uniform(3, _mouth_buf),
	])
	_sets["disp_resolve_1"] = _make_uniform_set(rd, _shaders["display_resolve"], [
		_ssbo_uniform(0, _in_volume_b),
		_ssbo_uniform(1, _wall_sdf_buf),
		_img_uniform(2, _out_tex_rid),
		_ssbo_uniform(3, _mouth_buf),
	])

	_sets["cull_hist"] = _make_uniform_set(rd, _shaders["cull_hist"], [
		_ssbo_uniform(0, _particles_buf),
		_ssbo_uniform(1, _shared_cull_meta_buf),
	])
	_sets["cull_compact"] = _make_uniform_set(rd, _shaders["cull_compact"], [
		_ssbo_uniform(0, _particles_buf),
		_ssbo_uniform(1, _shared_cull_meta_buf),
		_ssbo_uniform(2, _shared_scratch_buf),
	])
	_sets["cull_copyback"] = _make_uniform_set(rd, _shaders["cull_copyback"], [
		_ssbo_uniform(0, _particles_buf),
		_ssbo_uniform(1, _shared_scratch_buf),
	])
	_sets["blend"] = _make_uniform_set(rd, _shaders["blend"], [
		_ssbo_uniform(0, _particles_buf),
	])

	if _display_tex_rd:
		_display_tex_rd.texture_rd_rid = _out_tex_rid

	_gpu_initialized = true


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

	var grid_groups: int = _groups_for(GRID_CELLS)
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
				var off: int = int(op["offset"])
				if not bytes.is_empty():
					rd.buffer_update(_particles_buf, off, bytes.size(), bytes)
			"cull":
				var old_cnt: int = int(op["old_count"])
				var rem_cnt: int = int(op["remove_count"])
				var new_cnt: int = int(op["new_count"])
				if old_cnt > 0 and rem_cnt > 0:
					var meta_zero := PackedByteArray()
					meta_zero.resize(272)
					rd.buffer_update(_shared_cull_meta_buf, 0, 272, meta_zero)
					var groups_old: int = _groups_for(old_cnt)
					_dispatch(rd, _pipelines["cull_hist"], _sets["cull_hist"], groups_old, 1, _pack_pc(0.0, down_dir.x, down_dir.y, 0.0, 0.0, 0.0, 0.0, old_cnt))
					_dispatch(rd, _pipelines["cull_scan"], _shared_cull_scan_set, 1, 1, _pack_pc(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, rem_cnt))
					_dispatch(rd, _pipelines["cull_compact"], _sets["cull_compact"], groups_old, 1, _pack_pc(0.0, down_dir.x, down_dir.y, 0.0, 0.0, 0.0, 0.0, old_cnt))
					if new_cnt > 0:
						var groups_new: int = _groups_for(new_cnt)
						_dispatch(rd, _pipelines["cull_copyback"], _sets["cull_copyback"], groups_new, 1, _pack_pc(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, new_cnt))
			"blend":
				var cnt: int = int(op["count"])
				if cnt > 0:
					var col: Color = op["color"]
					var rho: float = float(op["rho"])
					var visc: float = float(op.get("visc", 0.0))
					var groups: int = _groups_for(cnt)
					_dispatch(rd, _pipelines["blend"], _sets["blend"], groups, 1, _pack_pc(col.r, col.g, col.b, rho, visc, 0.0, 0.0, cnt))

	if active_count <= 0:
		if not cleared_this_frame and not _tex_cleared:
			rd.texture_clear(_out_tex_rid, Color(0, 0, 0, 0), 0, 1, 0, 1)
			_tex_cleared = true
		return

	var substeps := clampi(int(ceili(frame_dt * STEPS_PER_SECOND)), MIN_SUBSTEPS, MAX_SUBSTEPS)
	var sim_dt := frame_dt * float(maxi(STEP_SKIP, 1))
	var sub_dt := sim_dt / float(substeps)
	var effective_stiffness := minf(EOS_STIFFNESS, CFL_PRESSURE_LIMIT / maxf(sub_dt * sub_dt, 0.0000001))
	var part_groups: int = _groups_for(active_count)
	var pc := _pack_pc(sub_dt, accel.x, accel.y, viscosity, GRID_GRAVITY, effective_stiffness, REST_DENSITY, active_count)

	for _s in substeps:
		_flip_flop = not _flip_flop
		var idx_str := "0" if _flip_flop else "1"
		_dispatch(rd, _pipelines["grid_ops"], _sets["grid_ops_" + idx_str], grid_groups, 1, pc)
		_dispatch(rd, _pipelines["density_scatter"], _sets["density_" + idx_str], part_groups, 1, pc)
		_dispatch(rd, _pipelines["fluid"], _sets["fluid_" + idx_str], part_groups, 1, pc)

	var disp_idx := "0" if _flip_flop else "1"
	_dispatch(rd, _pipelines["display_clear"], _sets["disp_clear_" + disp_idx], grid_groups, 1)
	_dispatch(rd, _pipelines["display_splat"], _sets["disp_splat_" + disp_idx], part_groups, 1, pc)
	_dispatch(rd, _pipelines["display_resolve"], _sets["disp_resolve_" + disp_idx], int(GRID_SIZE / 8.0), int(GRID_SIZE / 8.0))
	_tex_cleared = false

	if want_mouth_readback and not _mouth_readback_pending_rt and _mouth_buf.is_valid():
		_mouth_readback_pending_rt = true
		var err := rd.buffer_get_data_async(_mouth_buf, _on_mouth_readback.bind(readback_gen))
		if err != OK:
			_mouth_readback_pending_rt = false


func _init_cpu_fallback(tex: Texture2D) -> void:
	_cpu_img = Image.create(CPU_N, CPU_N, false, Image.FORMAT_RGBA8)
	_cpu_fallback_tex = ImageTexture.create_from_image(_cpu_img)
	_cpu_mask.resize(CPU_N * CPU_N)
	_cpu_mouth_mask.resize(CPU_N * CPU_N)
	_cpu_mouth_mask.fill(0)
	_cpu_mouth_cell_count = 0
	_cpu_sdf_nx.resize(CPU_N * CPU_N)
	_cpu_sdf_ny.resize(CPU_N * CPU_N)
	_cpu_sdf_d.resize(CPU_N * CPU_N)
	_cpu_vx.resize(CPU_N * CPU_N)
	_cpu_vy.resize(CPU_N * CPU_N)
	_cpu_mass.resize(CPU_N * CPU_N)
	_cpu_vol.resize(CPU_N * CPU_N)
	_cpu_cell_visc.resize(CPU_N * CPU_N)
	_cpu_cell_p.resize(CPU_N * CPU_N)
	_cpu_px.resize(CPU_N * CPU_N)
	_cpu_py.resize(CPU_N * CPU_N)
	_cpu_pr.resize(CPU_N * CPU_N)
	_cpu_pg.resize(CPU_N * CPU_N)
	_cpu_pb.resize(CPU_N * CPU_N)
	_cpu_pw.resize(CPU_N * CPU_N)

	var src_img: Image = tex.get_image() if tex else null
	if src_img and not src_img.is_empty():
		_cpu_mask = _sample_image_mask(src_img, CPU_N)
	else:
		for y in range(2, CPU_N - 2):
			for x in range(5, CPU_N - 5):
				_cpu_mask[x + y * CPU_N] = 1

	for cy in CPU_N:
		for cx in CPU_N:
			var idx := cx + cy * CPU_N
			if _cpu_mask[idx] == 0:
				continue
			var has_mouth := false
			for dy in 2:
				for dx in 2:
					var gx := mini(cx * 2 + dx, GRID_SIZE - 1)
					var gy := mini(cy * 2 + dy, GRID_SIZE - 1)
					if _mouth_mask_bytes[gx + gy * GRID_SIZE] == 1:
						has_mouth = true
						break
				if has_mouth:
					break
			if has_mouth:
				_cpu_mouth_mask[idx] = 1
				_cpu_mouth_cell_count += 1

	_cpu_cells.clear()
	for y in range(CPU_N - 1, -1, -1):
		for x in CPU_N:
			if _cpu_mask[x + y * CPU_N] == 1:
				_cpu_cells.append(Vector2i(x, y))
	_max_particles = _cpu_cells.size() * 4

	for y in CPU_N:
		for x in CPU_N:
			var i := x + y * CPU_N
			if _cpu_mask[i] == 1:
				_cpu_sdf_d[i] = 1.5
			else:
				_cpu_sdf_d[i] = -1.0
			_cpu_sdf_nx[i] = clampf((float(CPU_N) * 0.5 - float(x)) * 0.1, -1.0, 1.0)
			_cpu_sdf_ny[i] = clampf((float(CPU_N) * 0.5 - float(y)) * 0.1, -1.0, 1.0)


func _cpu_cull_particles(new_cnt: int) -> void:
	var old_cnt := _cpu_pos.size()
	if new_cnt >= old_cnt:
		return
	if new_cnt <= 0:
		_cpu_pos.clear()
		_cpu_pvel.clear()
		_cpu_rho.clear()
		_cpu_visc.clear()
		_cpu_col.clear()
		return

	var indices: Array[int] = []
	indices.resize(old_cnt)
	for i in old_cnt:
		indices[i] = i
	indices.sort_custom(func(a: int, b: int) -> bool:
		var score_a := _cpu_pos[a].dot(_last_down_dir) + clampf((_cpu_rho[a] - 1.0) * 1.5, -1.5, 1.5)
		var score_b := _cpu_pos[b].dot(_last_down_dir) + clampf((_cpu_rho[b] - 1.0) * 1.5, -1.5, 1.5)
		return score_a > score_b
	)

	var keep_pos := PackedVector2Array()
	var keep_pvel := PackedVector2Array()
	var keep_rho := PackedFloat32Array()
	var keep_visc := PackedFloat32Array()
	var keep_col := PackedColorArray()
	keep_pos.resize(new_cnt)
	keep_pvel.resize(new_cnt)
	keep_rho.resize(new_cnt)
	keep_visc.resize(new_cnt)
	keep_col.resize(new_cnt)

	for i in new_cnt:
		var src_i := indices[i]
		keep_pos[i] = _cpu_pos[src_i]
		keep_pvel[i] = _cpu_pvel[src_i]
		keep_rho[i] = _cpu_rho[src_i]
		keep_visc[i] = _cpu_visc[src_i]
		keep_col[i] = _cpu_col[src_i]

	_cpu_pos = keep_pos
	_cpu_pvel = keep_pvel
	_cpu_rho = keep_rho
	_cpu_visc = keep_visc
	_cpu_col = keep_col


func _cpu_step(frame_dt: float, accel: Vector2, viscosity: float, ops: Array) -> void:
	for op in ops:
		match op["op"]:
			"clear":
				_cpu_pos.clear()
				_cpu_pvel.clear()
				_cpu_rho.clear()
				_cpu_visc.clear()
				_cpu_col.clear()
				_cpu_skip_acc = 0
				_mouth_touching = false
				_mouth_hits = 0
				_mouth_contact_ratio = 0.0
			"init_upload", "append_upload":
				var bytes: PackedByteArray = op["bytes"]
				var cnt: int = int(op["count"])
				if op["op"] == "init_upload":
					_cpu_pos.clear()
					_cpu_pvel.clear()
					_cpu_rho.clear()
					_cpu_visc.clear()
					_cpu_col.clear()
					_cpu_skip_acc = 0
				var scale := float(CPU_N) / float(GRID_SIZE)
				for i in cnt:
					_cpu_skip_acc += 1
					if _cpu_skip_acc < 4:
						continue
					_cpu_skip_acc -= 4
					if _cpu_pos.size() >= _max_particles:
						break
					var b := i * PARTICLE_STRIDE
					var p := Vector2(bytes.decode_float(b), bytes.decode_float(b + 4)) * scale
					var v_flag := bytes.decode_float(b + 40)
					var pv := Vector2(bytes.decode_float(b + 32), bytes.decode_float(b + 36)) * scale if v_flag > 0.5 else Vector2.ZERO
					_cpu_pos.append(p)
					_cpu_pvel.append(pv)
					_cpu_rho.append(bytes.decode_float(b + 8))
					_cpu_visc.append(clampf(bytes.decode_float(b + 44), 0.0, 1.0))
					_cpu_col.append(Color(bytes.decode_float(b + 16), bytes.decode_float(b + 20), bytes.decode_float(b + 24), 1.0))
			"cull":
				var new_cnt: int = mini(roundi(float(op["new_count"]) * 0.25), _cpu_pos.size())
				_cpu_cull_particles(new_cnt)
			"blend":
				var col: Color = op["color"]
				var rho: float = float(op["rho"])
				var visc: float = float(op.get("visc", 0.0))
				for i in _cpu_col.size():
					_cpu_col[i] = col
					_cpu_rho[i] = rho
					_cpu_visc[i] = visc

	if _cpu_pos.is_empty():
		_mouth_touching = false
		_mouth_hits = 0
		_mouth_contact_ratio = 0.0
		_cpu_img.fill(Color(0, 0, 0, 0))
		_cpu_fallback_tex.update(_cpu_img)
		return

	var n := _cpu_pos.size()
	var cpu_substeps := clampi(int(ceili(frame_dt * CPU_STEPS_PER_SECOND)), CPU_MIN_SUBSTEPS, CPU_MAX_SUBSTEPS)
	var sim_dt := frame_dt * float(maxi(STEP_SKIP, 1))
	var dt := clampf(sim_dt / float(cpu_substeps), 0.001, 0.018)
	var cpu_stiffness := minf(CPU_PRESSURE_STIFFNESS, CPU_CFL_PRESSURE_LIMIT / maxf(dt * dt, 0.00001))
	var half_accel := accel * 0.5

	for _sub in cpu_substeps:
		_cpu_mass.fill(0.0)
		_cpu_vol.fill(0.0)
		_cpu_cell_visc.fill(0.0)
		_cpu_px.fill(0.0)
		_cpu_py.fill(0.0)

		for i in n:
			var p := _cpu_pos[i]
			var cx := clampi(int(p.x), 1, CPU_N - 2)
			var cy := clampi(int(p.y), 1, CPU_N - 2)
			var idx := cx + cy * CPU_N
			var m := PARTICLE_VOLUME_WEIGHT * _cpu_rho[i]
			var p_v := clampf(maxf(_cpu_visc[i], viscosity), 0.0, 1.0)
			_cpu_vol[idx] += PARTICLE_VOLUME_WEIGHT
			_cpu_mass[idx] += m
			_cpu_cell_visc[idx] += m * p_v

		for idx in CPU_N * CPU_N:
			_cpu_cell_p[idx] = clampf(maxf(0.0, _cpu_vol[idx] - REST_DENSITY) * cpu_stiffness, 0.0, 120.0)

		for y in CPU_N:
			for x in CPU_N:
				var idx := x + y * CPU_N
				if _cpu_mask[idx] == 1 and _cpu_mass[idx] > 0.001:
					var cell_visc := clampf(_cpu_cell_visc[idx] / _cpu_mass[idx], 0.0, 1.0)
					var cell_damp := exp(-(1.0 + cell_visc * 8.0) * dt)
					var grad_px := 0.0
					var grad_py := 0.0
					if x > 0 and x < CPU_N - 1 and y > 0 and y < CPU_N - 1:
						grad_px = (_cpu_cell_p[idx + 1] - _cpu_cell_p[idx - 1]) * 0.5
						grad_py = (_cpu_cell_p[idx + CPU_N] - _cpu_cell_p[idx - CPU_N]) * 0.5
					var vx := _cpu_vx[idx] * cell_damp + (half_accel.x - grad_px * 24.0) * dt
					var vy := _cpu_vy[idx] * cell_damp + (half_accel.y - grad_py * 24.0) * dt
					if x <= 1 or _cpu_mask[idx - 1] == 0:
						vx = maxf(vx, 0.0)
					if x >= CPU_N - 2 or _cpu_mask[idx + 1] == 0:
						vx = minf(vx, 0.0)
					if y <= 1 or _cpu_mask[idx - CPU_N] == 0:
						vy = maxf(vy, 0.0)
					if y >= CPU_N - 2 or _cpu_mask[idx + CPU_N] == 0:
						vy = minf(vy, 0.0)
					_cpu_vx[idx] = vx
					_cpu_vy[idx] = vy
				else:
					_cpu_vx[idx] = 0.0
					_cpu_vy[idx] = 0.0

		for i in n:
			var p := _cpu_pos[i]
			var pv := _cpu_pvel[i]
			var p_visc := clampf(maxf(_cpu_visc[i], viscosity), 0.0, 1.0)
			var p_damp := exp(-(1.0 + p_visc * 8.0) * dt)
			var cx := clampi(int(p.x), 1, CPU_N - 2)
			var cy := clampi(int(p.y), 1, CPU_N - 2)
			var idx := cx + cy * CPU_N
			var local_rho := _cpu_mass[idx] / maxf(_cpu_vol[idx], 0.001)
			var rel := clampf((_cpu_rho[i] - local_rho) / maxf(_cpu_rho[i], 0.25), -1.0, 1.0)
			if absf(rel) <= 0.005:
				rel = 0.0
			var buoy_speed := maxf(0.0, 20.0 - p_visc * 17.0)
			var step_v := Vector2(_cpu_vx[idx], _cpu_vy[idx]) + pv
			p += step_v * dt + _last_down_dir * (rel * buoy_speed * dt)
			_cpu_pvel[i] = pv * p_damp
			p.x = clampf(p.x, 1.0, float(CPU_N - 2))
			p.y = clampf(p.y, 1.0, float(CPU_N - 2))
			var nc := int(p.x) + int(p.y) * CPU_N
			if _cpu_mask[nc] == 0:
				var n_vec := Vector2(_cpu_sdf_nx[nc], _cpu_sdf_ny[nc])
				n_vec = n_vec.normalized() if n_vec.length_squared() > 0.0001 else Vector2(0.0, -1.0)
				p += n_vec * 0.25
				var vn := _cpu_pvel[i].dot(n_vec)
				var v_tan := _cpu_pvel[i] - n_vec * vn
				if vn < 0.0:
					vn = 0.0
				_cpu_pvel[i] = n_vec * vn + v_tan * exp(-dt * p_visc * 240.0)
			_cpu_pos[i] = p

	_cpu_pr.fill(0.0)
	_cpu_pg.fill(0.0)
	_cpu_pb.fill(0.0)
	_cpu_pw.fill(0.0)
	for i in n:
		var p := _cpu_pos[i]
		var c := _cpu_col[i]
		var cx := clampi(int(p.x), 0, CPU_N - 1)
		var cy := clampi(int(p.y), 0, CPU_N - 1)
		var idx := cx + cy * CPU_N
		if _cpu_mask[idx] == 1:
			_cpu_pr[idx] += c.r
			_cpu_pg[idx] += c.g
			_cpu_pb[idx] += c.b
			_cpu_pw[idx] += 1.0

	var cpu_mouth_hits := 0
	_cpu_img.fill(Color(0, 0, 0, 0))
	for y in CPU_N:
		for x in CPU_N:
			var idx := x + y * CPU_N
			if _cpu_pw[idx] > 0.0 and _cpu_mask[idx] == 1:
				var w := _cpu_pw[idx]
				_cpu_img.set_pixel(x, y, Color(_cpu_pr[idx] / w, _cpu_pg[idx] / w, _cpu_pb[idx] / w, 1.0))
				if _cpu_mouth_mask[idx] == 1:
					cpu_mouth_hits += 1
	_mouth_hits = cpu_mouth_hits
	_mouth_touching = cpu_mouth_hits > 0
	if _mouth_touching:
		_mouth_contact_ratio = clampf(float(cpu_mouth_hits) / maxf(float(_cpu_mouth_cell_count) * 0.5, 1.0), 0.0, 1.0)
	else:
		_mouth_contact_ratio = 0.0
	_cpu_fallback_tex.update(_cpu_img)