class_name AtomicFluidSim
extends RefCounted

const GRID_SIZE := FluidComputeGLSL.GRID_SIZE
const PARTICLES_PER_CELL := FluidContainerMask.PARTICLES_PER_CELL
const PARTICLE_VOLUME_WEIGHT := 0.278
const PARTICLE_STRIDE := 48
const GRID_GRAVITY := 65.0
const MAX_GRID_ACCEL := 550.0
const MAX_IMPULSE_VEL := 65.0

static var _gpu_checked: bool = false
static var _gpu_available: bool = false

var _disposed: bool = false
var _mask: FluidContainerMask = FluidContainerMask.new()
var _gpu: FluidGpuBackend = null
var _cpu: FluidCpuFallback = null

var _max_particles: int = 0
var _active_count: int = 0
var _synced_amounts: Dictionary = {}
var _synced_total: float = 0.0
var _synced_mixed: bool = false
var _last_single_color: Color = Color(-1.0, -1.0, -1.0, -1.0)
var _last_single_rho: float = -1.0
var _last_single_visc: float = -1.0
var _pending_ops: Array[Dictionary] = []
var _pending_impulse: Vector2 = Vector2.ZERO
var _last_down_dir: Vector2 = Vector2(0.0, 1.0)
var _monitor_mouth: bool = false

func setup_from_texture(mask_texture: Texture2D) -> Texture2D:
	if not _gpu_checked:
		_gpu_checked = true
		_gpu_available = RenderingServer.get_rendering_device() != null

	_mask.build_from_texture(mask_texture)
	if _gpu_available:
		_gpu = FluidGpuBackend.new()
		_max_particles = _mask.max_particles
		return _gpu.setup(_mask.sdf_bytes, _max_particles, _mask.mouth_cell_count)
	_cpu = FluidCpuFallback.new()
	var tex := _cpu.setup(mask_texture, _mask)
	_max_particles = _cpu.max_particles
	return tex

func get_texture() -> Texture2D:
	if _gpu_available:
		return _gpu.display_tex_rd if _gpu else null
	return _cpu.get_texture() if _cpu else null

func set_mouth_monitoring(enabled: bool) -> void:
	_monitor_mouth = enabled
	if not enabled and _active_count <= 0:
		_reset_mouth_state()

func is_liquid_touching_mouth() -> bool:
	if _active_count <= 0:
		return false
	return (_gpu.mouth_touching if _gpu else false) if _gpu_available else (_cpu.mouth_touching if _cpu else false)

func get_mouth_contact_ratio() -> float:
	if not is_liquid_touching_mouth():
		return 0.0
	return (_gpu.mouth_contact_ratio if _gpu else 0.0) if _gpu_available else (_cpu.mouth_contact_ratio if _cpu else 0.0)

func _reset_mouth_state() -> void:
	if _gpu:
		_gpu.reset_mouth_state()
	if _cpu:
		_cpu.reset_mouth_state()

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

func _extract_layer_spec(layer: Array, buoyancy_overrides: Dictionary, viscosity_overrides: Dictionary) -> Dictionary:
	var amt := float(layer[1])
	var buoy := LiquidProperties.get_layer_buoyancy(layer, buoyancy_overrides)
	var has_explicit_col := layer.size() > 2 and layer[2] is Color
	var key: String
	var col: Color
	var visc: float

	if layer[0] is Array or layer[0] is Dictionary:
		var keys := LiquidProperties.get_layer_ingredients(layer).keys()
		keys.sort()
		key = "+".join(keys)
		col = layer[2] if has_explicit_col else LiquidColorUtils.get_layer_color(layer)
		visc = LiquidProperties.get_layer_viscosity(layer, viscosity_overrides)
	else:
		key = str(layer[0])
		col = layer[2] if has_explicit_col else LiquidProperties.get_liquid_color(key)
		visc = clampf(float(viscosity_overrides.get(key, LiquidProperties.get_liquid_viscosity(key))), 0.0, 1.0)

	return {"key": key, "amount": amt, "color": col, "rho": 1.0 / clampf(buoy, 0.35, 2.5), "visc": visc}

func sync_container_liquids(liquids: Array, capacity: float, is_mixed_flag: bool, buoyancy_overrides: Dictionary = {}, pour_info: Dictionary = {}, viscosity_overrides: Dictionary = {}) -> void:
	if _max_particles <= 0 or capacity <= 0.0001 or liquids.is_empty():
		_sync_empty()
		return

	var total_amt := 0.0
	var layer_items: Array[Dictionary] = []
	var new_amounts: Dictionary = {}
	for layer in liquids:
		if not (layer is Array) or layer.size() < 2 or float(layer[1]) <= 0.0001:
			continue
		var spec := _extract_layer_spec(layer, buoyancy_overrides, viscosity_overrides)
		total_amt += float(spec["amount"])
		new_amounts[spec["key"]] = new_amounts.get(spec["key"], 0.0) + float(spec["amount"])
		layer_items.append(spec)

	if total_amt <= 0.0001 or layer_items.is_empty():
		_sync_empty()
		return

	var target_count := clampi(roundi(clampf(total_amt / capacity, 0.0, 1.0) * float(_max_particles)), 1, _max_particles)
	if _active_count == 0:
		_reset_mouth_state()
		var specs := _allocate_particle_counts(layer_items, target_count, total_amt, "amount")
		if bool(pour_info.get("from_pour", false)):
			_queue_append_stream(specs, 0, pour_info, true)
		else:
			_queue_init_fill(specs, target_count)
		_active_count = target_count
		_synced_amounts = new_amounts
		_synced_total = total_amt
		_synced_mixed = is_mixed_flag
		_update_single_cache(layer_items)
		return

	if layer_items.size() == 1:
		var item := layer_items[0]
		var col: Color = item["color"]
		var rho := float(item["rho"])
		var visc := float(item["visc"])
		if (is_mixed_flag and not _synced_mixed) or col != _last_single_color or not is_equal_approx(rho, _last_single_rho) or not is_equal_approx(visc, _last_single_visc):
			_pending_ops.append({"op": "blend", "color": col, "rho": rho, "visc": clampf(visc, 0.0, 1.0), "count": _active_count})
			_update_single_cache(layer_items)
	else:
		_clear_single_cache()

	if target_count > _active_count:
		var added_specs: Array[Dictionary] = []
		var delta_sum := 0.0
		for item in layer_items:
			var diff := maxf(float(new_amounts.get(item["key"], 0.0)) - float(_synced_amounts.get(item["key"], 0.0)), 0.0)
			if diff > 0.0001:
				delta_sum += diff
				added_specs.append({"diff": diff, "color": item["color"], "rho": item["rho"], "visc": item["visc"]})
		if delta_sum <= 0.0001:
			var last_item := layer_items[layer_items.size() - 1]
			added_specs.append({"diff": 1.0, "color": last_item["color"], "rho": last_item["rho"], "visc": last_item["visc"]})
			delta_sum = 1.0
		var spawn_specs := _allocate_particle_counts(added_specs, target_count - _active_count, delta_sum, "diff")
		var added_count := 0
		for sp in spawn_specs:
			added_count += int(sp["count"])
		if added_count > 0:
			_queue_append_stream(spawn_specs, _active_count, pour_info, false)
			_active_count += added_count
	elif target_count < _active_count:
		_pending_ops.append({"op": "cull", "remove_count": _active_count - target_count, "old_count": _active_count, "new_count": target_count})
		_active_count = target_count

	_synced_amounts = new_amounts
	_synced_total = total_amt
	_synced_mixed = is_mixed_flag

func _allocate_particle_counts(items: Array[Dictionary], total_count: int, weight_sum: float, weight_key: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var assigned := 0
	for i in items.size():
		var item := items[i]
		var cnt := (total_count - assigned) if i == items.size() - 1 else clampi(roundi((float(item[weight_key]) / weight_sum) * float(total_count)), 0, total_count - assigned)
		if cnt > 0:
			specs.append({"count": cnt, "color": item["color"], "rho": item["rho"], "visc": item["visc"]})
			assigned += cnt
	return specs

func _update_single_cache(layer_items: Array[Dictionary]) -> void:
	if layer_items.size() == 1:
		_last_single_color = layer_items[0]["color"]
		_last_single_rho = float(layer_items[0]["rho"])
		_last_single_visc = float(layer_items[0]["visc"])
	else:
		_clear_single_cache()

func _clear_single_cache() -> void:
	_last_single_color = Color(-1.0, -1.0, -1.0, -1.0)
	_last_single_rho = -1.0
	_last_single_visc = -1.0

func _sync_empty() -> void:
	_reset_mouth_state()
	if _active_count == 0 and _synced_total <= 0.0:
		return
	_active_count = 0
	_synced_amounts.clear()
	_synced_total = 0.0
	_synced_mixed = false
	_clear_single_cache()
	_pending_ops.append({"op": "clear"})

func step(delta: float, local_accel_world: Vector2, viscosity: float) -> void:
	if _disposed:
		return
	if _active_count <= 0:
		if _gpu: _gpu.clear_mouth_state()
		if _cpu: _cpu.reset_mouth_state()

	var grid_accel := Vector2(local_accel_world.x * (GRID_GRAVITY / 9.8), -local_accel_world.y * (GRID_GRAVITY / 9.8))
	if grid_accel.length() > MAX_GRID_ACCEL:
		grid_accel = grid_accel.normalized() * MAX_GRID_ACCEL
	var imp := _pending_impulse
	_pending_impulse = Vector2.ZERO
	if imp.length() > MAX_IMPULSE_VEL:
		imp = imp.normalized() * MAX_IMPULSE_VEL
	if grid_accel.length_squared() > 0.01:
		_last_down_dir = grid_accel.normalized()

	var dt := clampf(delta, 0.001, 0.033)
	var accel_with_imp := grid_accel + imp / maxf(dt, 0.008)
	var ops_copy := _pending_ops.duplicate()
	_pending_ops.clear()

	if _gpu_available and _gpu:
		var want_readback := _active_count > 0 and (_monitor_mouth or absf(local_accel_world.x) > 0.35 or local_accel_world.y > -8.8)
		_gpu.step(dt, accel_with_imp, clampf(viscosity, 0.0, 1.0), _active_count, _last_down_dir, ops_copy, want_readback)
	elif _cpu:
		_cpu.step(dt, accel_with_imp, clampf(viscosity, 0.0, 1.0), _last_down_dir, ops_copy)

func cleanup() -> void:
	if _disposed:
		return
	_disposed = true
	_pending_ops.clear()
	if _gpu:
		_gpu.cleanup()
		_gpu = null
	_cpu = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not _disposed:
		_disposed = true
		_pending_ops.clear()
		if _gpu:
			_gpu.cleanup()
			_gpu = null
		_cpu = null

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
	if specs.is_empty() or _mask.mask_cells.is_empty():
		return
	var sorted_specs: Array[Dictionary] = []
	sorted_specs.assign(specs)
	sorted_specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["rho"]) > float(b["rho"])
	)
	var bytes := PackedByteArray()
	bytes.resize(total_particles * PARTICLE_STRIDE)
	var offsets := [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]
	var pidx := 0
	var spec_idx := 0
	var spec_rem := int(sorted_specs[0]["count"])
	for cell in _mask.mask_cells:
		if pidx >= total_particles:
			break
		for sub in PARTICLES_PER_CELL:
			if pidx >= total_particles:
				break
			while spec_rem <= 0 and spec_idx + 1 < sorted_specs.size():
				spec_idx += 1
				spec_rem = int(sorted_specs[spec_idx]["count"])
			var sp := sorted_specs[spec_idx]
			spec_rem -= 1
			var off: Vector2 = offsets[sub]
			var px := clampf(float(cell.x) + off.x + randf_range(-0.06, 0.06), 0.55, float(GRID_SIZE) - 1.55)
			var py := clampf(float(cell.y) + off.y + randf_range(-0.06, 0.06), 0.55, float(GRID_SIZE) - 1.55)
			_encode_particle(bytes, pidx, px, py, float(sp["rho"]), float(sp.get("visc", 0.0)), sp["color"], 0.0, 0.0, 0.0)
			pidx += 1
	_pending_ops.append({"op": "init_upload", "bytes": bytes, "count": pidx})

func _queue_append_stream(specs: Array[Dictionary], start_index: int, pour_info: Dictionary, is_initial_upload: bool) -> void:
	var total_add := 0
	for sp in specs:
		total_add += int(sp["count"])
	if total_add <= 0 or _mask.mask_cells.is_empty():
		return

	var bytes := PackedByteArray()
	bytes.resize(total_add * PARTICLE_STRIDE)
	var entry_u := clampf(float(pour_info.get("entry_u", 0.5)), 0.12, 0.88)
	var stream_vx := clampf(float(pour_info.get("stream_vx", 0.0)), -18.0, 18.0)
	var stream_vy := clampf(float(pour_info.get("stream_vy", 34.0)), 14.0, 50.0)

	var open_y := clampi(_mask.top_rim_y + 1, 0, GRID_SIZE - 1)
	while open_y < _mask.bottom_y and _mask.row_min_x[open_y] < 0:
		open_y += 1
	var open_min_x := float(_mask.row_min_x[open_y]) if _mask.row_min_x[open_y] >= 0 else 16.0
	var open_max_x := float(_mask.row_max_x[open_y]) if _mask.row_max_x[open_y] >= 0 else 48.0
	var nozzle_x := lerpf(open_min_x + 1.0, open_max_x, entry_u)

	var filled_idx := clampi(start_index / PARTICLES_PER_CELL, 0, _mask.mask_cells.size() - 1)
	var surface_y := float(_mask.mask_cells[filled_idx].y) if start_index > 0 else float(_mask.bottom_y)
	var stream_top_y := float(open_y) + 0.65
	var jet_depth := clampf(2.2 + float(total_add) / 22.0, 2.2, minf(maxf(surface_y - stream_top_y - 0.5, 1.5), 12.0))
	var half_w := clampf(1.1 + float(total_add) / 140.0, 1.1, 2.4)

	var pidx := 0
	for sp in specs:
		for _i in int(sp["count"]):
			var t := clampf((float(pidx) + randf_range(0.0, 0.85)) / maxf(float(total_add), 1.0), 0.0, 1.0)
			var pos := _mask.clamp_point_to_mask(nozzle_x + stream_vx * (t * 0.06) + randf_range(-half_w, half_w), stream_top_y + t * jet_depth)
			_encode_particle(bytes, pidx, pos.x, pos.y, float(sp["rho"]), float(sp.get("visc", 0.0)), sp["color"], stream_vx + randf_range(-1.8, 1.8), stream_vy + randf_range(-3.0, 3.0), 1.0)
			pidx += 1

	_pending_ops.append({
		"op": "init_upload" if is_initial_upload else "append_upload",
		"offset": 0 if is_initial_upload else start_index * PARTICLE_STRIDE,
		"bytes": bytes,
		"count": total_add,
	})
