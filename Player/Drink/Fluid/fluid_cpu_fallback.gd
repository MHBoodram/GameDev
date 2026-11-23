class_name FluidCpuFallback
extends RefCounted

const CPU_N := 32
const GRID_SIZE := FluidComputeGLSL.GRID_SIZE
const PARTICLE_VOLUME_WEIGHT := 0.278
const PARTICLE_STRIDE := 48
const REST_DENSITY := 1.00

var mouth_touching: bool = false
var mouth_hits: int = 0
var mouth_contact_ratio: float = 0.0
var max_particles: int = 0

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
var _cpu_pr: PackedFloat32Array = PackedFloat32Array()
var _cpu_pg: PackedFloat32Array = PackedFloat32Array()
var _cpu_pb: PackedFloat32Array = PackedFloat32Array()
var _cpu_pw: PackedFloat32Array = PackedFloat32Array()
var _cpu_skip_acc: int = 0

func setup(tex: Texture2D, container_mask: FluidContainerMask) -> ImageTexture:
	_cpu_img = Image.create(CPU_N, CPU_N, false, Image.FORMAT_RGBA8)
	_cpu_fallback_tex = ImageTexture.create_from_image(_cpu_img)
	var cells := CPU_N * CPU_N
	_cpu_mask.resize(cells)
	_cpu_mouth_mask.resize(cells)
	_cpu_mouth_mask.fill(0)
	_cpu_mouth_cell_count = 0
	for arr in [_cpu_sdf_nx, _cpu_sdf_ny, _cpu_sdf_d, _cpu_vx, _cpu_vy, _cpu_mass, _cpu_vol, _cpu_cell_visc, _cpu_cell_p, _cpu_pr, _cpu_pg, _cpu_pb, _cpu_pw]:
		arr.resize(cells)

	var src_img: Image = tex.get_image() if tex else null
	if src_img and not src_img.is_empty():
		_cpu_mask = FluidContainerMask.sample_image_mask(src_img, CPU_N)
	else:
		for y in range(2, CPU_N - 2):
			for x in range(5, CPU_N - 5):
				_cpu_mask[x + y * CPU_N] = 1

	var mouth_src := container_mask.mouth_mask_bytes if container_mask else PackedByteArray()
	for cy in CPU_N:
		for cx in CPU_N:
			var idx := cx + cy * CPU_N
			if _cpu_mask[idx] == 0 or mouth_src.size() < GRID_SIZE * GRID_SIZE:
				continue
			var has_mouth := false
			for dy in 2:
				for dx in 2:
					var gx := mini(cx * 2 + dx, GRID_SIZE - 1)
					var gy := mini(cy * 2 + dy, GRID_SIZE - 1)
					if mouth_src[gx + gy * GRID_SIZE] == 1:
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
	max_particles = _cpu_cells.size() * 4

	for y in CPU_N:
		for x in CPU_N:
			var i := x + y * CPU_N
			_cpu_sdf_d[i] = 1.5 if _cpu_mask[i] == 1 else -1.0
			_cpu_sdf_nx[i] = clampf((float(CPU_N) * 0.5 - float(x)) * 0.1, -1.0, 1.0)
			_cpu_sdf_ny[i] = clampf((float(CPU_N) * 0.5 - float(y)) * 0.1, -1.0, 1.0)
	return _cpu_fallback_tex

func get_texture() -> ImageTexture:
	return _cpu_fallback_tex

func reset_mouth_state() -> void:
	mouth_touching = false
	mouth_hits = 0
	mouth_contact_ratio = 0.0

func _cull_particles(new_cnt: int, last_down_dir: Vector2) -> void:
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
		var score_a := _cpu_pos[a].dot(last_down_dir) + clampf((_cpu_rho[a] - 1.0) * 1.5, -1.5, 1.5)
		var score_b := _cpu_pos[b].dot(last_down_dir) + clampf((_cpu_rho[b] - 1.0) * 1.5, -1.5, 1.5)
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

func step(frame_dt: float, accel: Vector2, viscosity: float, last_down_dir: Vector2, ops: Array) -> void:
	for op in ops:
		match op["op"]:
			"clear":
				_cpu_pos.clear()
				_cpu_pvel.clear()
				_cpu_rho.clear()
				_cpu_visc.clear()
				_cpu_col.clear()
				_cpu_skip_acc = 0
				reset_mouth_state()
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
					if _cpu_pos.size() >= max_particles:
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
				_cull_particles(new_cnt, last_down_dir)
			"blend":
				var col: Color = op["color"]
				var rho: float = float(op["rho"])
				var visc: float = float(op.get("visc", 0.0))
				for i in _cpu_col.size():
					_cpu_col[i] = col
					_cpu_rho[i] = rho
					_cpu_visc[i] = visc

	if _cpu_pos.is_empty():
		reset_mouth_state()
		_cpu_img.fill(Color(0, 0, 0, 0))
		_cpu_fallback_tex.update(_cpu_img)
		return

	var n := _cpu_pos.size()
	var dt := clampf(frame_dt * 0.25, 0.001, 0.008)
	var half_accel := accel * 0.5

	for _sub in 4:
		_cpu_mass.fill(0.0)
		_cpu_vol.fill(0.0)
		_cpu_cell_visc.fill(0.0)

		for i in n:
			var p := _cpu_pos[i]
			var idx := clampi(int(p.x), 1, CPU_N - 2) + clampi(int(p.y), 1, CPU_N - 2) * CPU_N
			var m := PARTICLE_VOLUME_WEIGHT * _cpu_rho[i]
			var p_v := clampf(maxf(_cpu_visc[i], viscosity), 0.0, 1.0)
			_cpu_vol[idx] += PARTICLE_VOLUME_WEIGHT
			_cpu_mass[idx] += m
			_cpu_cell_visc[idx] += m * p_v

		for idx in CPU_N * CPU_N:
			_cpu_cell_p[idx] = clampf(maxf(0.0, _cpu_vol[idx] - REST_DENSITY) * 65.0, 0.0, 120.0)

		for y in CPU_N:
			for x in CPU_N:
				var idx := x + y * CPU_N
				if _cpu_mask[idx] == 1 and _cpu_mass[idx] > 0.001:
					var cell_visc := clampf(_cpu_cell_visc[idx] / _cpu_mass[idx], 0.0, 1.0)
					var cell_damp := maxf(0.0, 1.0 - (0.25 + cell_visc * 8.0) * dt)
					var grad_px := (_cpu_cell_p[idx + 1] - _cpu_cell_p[idx - 1]) * 0.5 if (x > 0 and x < CPU_N - 1 and y > 0 and y < CPU_N - 1) else 0.0
					var grad_py := (_cpu_cell_p[idx + CPU_N] - _cpu_cell_p[idx - CPU_N]) * 0.5 if (x > 0 and x < CPU_N - 1 and y > 0 and y < CPU_N - 1) else 0.0
					var vx := _cpu_vx[idx] * cell_damp + (half_accel.x - grad_px * 24.0) * dt
					var vy := _cpu_vy[idx] * cell_damp + (half_accel.y - grad_py * 24.0) * dt
					if x <= 1 or _cpu_mask[idx - 1] == 0: vx = maxf(vx, 0.0)
					if x >= CPU_N - 2 or _cpu_mask[idx + 1] == 0: vx = minf(vx, 0.0)
					if y <= 1 or _cpu_mask[idx - CPU_N] == 0: vy = maxf(vy, 0.0)
					if y >= CPU_N - 2 or _cpu_mask[idx + CPU_N] == 0: vy = minf(vy, 0.0)
					_cpu_vx[idx] = vx
					_cpu_vy[idx] = vy
				else:
					_cpu_vx[idx] = 0.0
					_cpu_vy[idx] = 0.0

		for i in n:
			var p := _cpu_pos[i]
			var pv := _cpu_pvel[i]
			var p_visc := clampf(maxf(_cpu_visc[i], viscosity), 0.0, 1.0)
			var p_damp := maxf(0.0, 1.0 - (0.25 + p_visc * 8.0) * dt)
			var idx := clampi(int(p.x), 1, CPU_N - 2) + clampi(int(p.y), 1, CPU_N - 2) * CPU_N
			var local_rho := _cpu_mass[idx] / maxf(_cpu_vol[idx], 0.001)
			var rel := clampf((_cpu_rho[i] - local_rho) / maxf(_cpu_rho[i], 0.25), -1.0, 1.0)
			var buoy_speed := maxf(0.0, 20.0 - p_visc * 17.0)
			p += (Vector2(_cpu_vx[idx], _cpu_vy[idx]) + pv) * dt + last_down_dir * (rel * buoy_speed * dt)
			_cpu_pvel[i] = pv * p_damp
			p = Vector2(clampf(p.x, 1.0, float(CPU_N - 2)), clampf(p.y, 1.0, float(CPU_N - 2)))
			var nc := int(p.x) + int(p.y) * CPU_N
			if _cpu_mask[nc] == 0:
				var n_vec := Vector2(_cpu_sdf_nx[nc], _cpu_sdf_ny[nc])
				n_vec = n_vec.normalized() if n_vec.length_squared() > 0.0001 else Vector2(0.0, -1.0)
				p += n_vec * 0.25
				var vn := _cpu_pvel[i].dot(n_vec)
				var v_tan := _cpu_pvel[i] - n_vec * vn
				if vn < 0.0: vn = 0.0
				_cpu_pvel[i] = n_vec * vn + v_tan * exp(-dt * p_visc * 240.0)
			_cpu_pos[i] = p

	_cpu_pr.fill(0.0)
	_cpu_pg.fill(0.0)
	_cpu_pb.fill(0.0)
	_cpu_pw.fill(0.0)
	for i in n:
		var p := _cpu_pos[i]
		var c := _cpu_col[i]
		var idx := clampi(int(p.x), 0, CPU_N - 1) + clampi(int(p.y), 0, CPU_N - 1) * CPU_N
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
	mouth_hits = cpu_mouth_hits
	mouth_touching = cpu_mouth_hits > 0
	mouth_contact_ratio = clampf(float(cpu_mouth_hits) / maxf(float(_cpu_mouth_cell_count) * 0.5, 1.0), 0.0, 1.0) if mouth_touching else 0.0
	_cpu_fallback_tex.update(_cpu_img)