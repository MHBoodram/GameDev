class_name FluidContainerMask
extends RefCounted

const GRID_SIZE := FluidComputeGLSL.GRID_SIZE
const GRID_CELLS := FluidComputeGLSL.GRID_CELLS
const PARTICLES_PER_CELL := 4

static var _mask_cache: Dictionary = {}

var mask_cells: Array[Vector2i] = []
var mask_bytes: PackedByteArray = PackedByteArray()
var mouth_mask_bytes: PackedByteArray = PackedByteArray()
var mouth_cell_count: int = 0
var row_min_x: PackedInt32Array = PackedInt32Array()
var row_max_x: PackedInt32Array = PackedInt32Array()
var top_rim_y: int = 4
var bottom_y: int = GRID_SIZE - 5
var sdf_bytes: PackedByteArray = PackedByteArray()
var max_particles: int = 0

func build_from_texture(tex: Texture2D) -> void:
	var cache_key: int = tex.get_rid().get_id() if tex else -1
	if cache_key != -1 and _mask_cache.has(cache_key):
		var cached: Dictionary = _mask_cache[cache_key]
		mask_cells = cached["cells"]
		mask_bytes = cached["mask_bytes"]
		mouth_mask_bytes = cached["mouth_mask_bytes"]
		mouth_cell_count = int(cached["mouth_cell_count"])
		row_min_x = cached["row_min_x"]
		row_max_x = cached["row_max_x"]
		top_rim_y = int(cached["top_rim_y"])
		bottom_y = int(cached["bottom_y"])
		sdf_bytes = cached["sdf_bytes"]
		max_particles = mask_cells.size() * PARTICLES_PER_CELL
		return

	var mask := PackedByteArray()
	var img: Image = tex.get_image() if tex else null
	if img != null and not img.is_empty():
		mask = sample_image_mask(img, GRID_SIZE)
	else:
		mask.resize(GRID_CELLS)

	var has_any := false
	for b in mask:
		if b == 1:
			has_any = true
			break
	if not has_any:
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

	var r_min_arr := PackedInt32Array()
	var r_max_arr := PackedInt32Array()
	r_min_arr.resize(GRID_SIZE)
	r_max_arr.resize(GRID_SIZE)
	var rim_y := GRID_SIZE - 1
	var bot_y := 0
	for y in GRID_SIZE:
		var r_min := GRID_SIZE
		var r_max := -1
		for x in GRID_SIZE:
			if mask[x + y * GRID_SIZE] == 1:
				r_min = mini(r_min, x)
				r_max = maxi(r_max, x)
		if r_max >= r_min:
			r_min_arr[y] = r_min
			r_max_arr[y] = r_max
			rim_y = mini(rim_y, y)
			bot_y = maxi(bot_y, y)
		else:
			r_min_arr[y] = -1
			r_max_arr[y] = -1

	var mouth_mask := _build_mouth_mask(mask, r_min_arr, r_max_arr, rim_y, bot_y)
	var mouth_cnt := 0
	for i in GRID_CELLS:
		if mouth_mask[i] == 1:
			mouth_cnt += 1

	var encoded_sdf := _build_sdf_bytes(mask, mouth_mask)

	mask_cells = cells
	mask_bytes = mask
	mouth_mask_bytes = mouth_mask
	mouth_cell_count = mouth_cnt
	row_min_x = r_min_arr
	row_max_x = r_max_arr
	top_rim_y = rim_y
	bottom_y = bot_y
	sdf_bytes = encoded_sdf
	max_particles = mask_cells.size() * PARTICLES_PER_CELL

	if cache_key != -1:
		_mask_cache[cache_key] = {
			"cells": cells,
			"mask_bytes": mask,
			"mouth_mask_bytes": mouth_mask,
			"mouth_cell_count": mouth_cnt,
			"row_min_x": r_min_arr,
			"row_max_x": r_max_arr,
			"top_rim_y": rim_y,
			"bottom_y": bot_y,
			"sdf_bytes": encoded_sdf,
		}

func clamp_point_to_mask(px: float, py: float) -> Vector2:
	var cy := clampi(int(roundf(py)), top_rim_y, bottom_y)
	if row_min_x[cy] >= 0 and row_max_x[cy] >= row_min_x[cy]:
		var min_x := float(row_min_x[cy]) + 0.65
		var max_x := float(row_max_x[cy]) + 0.35
		if min_x > max_x:
			var mid_x := (float(row_min_x[cy]) + float(row_max_x[cy])) * 0.5 + 0.5
			min_x = mid_x
			max_x = mid_x
		var clamped_x := clampf(px, min_x, max_x)
		var cx := clampi(int(clamped_x), 0, GRID_SIZE - 1)
		if mask_bytes[cx + cy * GRID_SIZE] == 1:
			return Vector2(clampf(clamped_x, 0.55, float(GRID_SIZE) - 1.55), clampf(py, float(top_rim_y) + 0.55, float(bottom_y) + 0.45))
	var fallback := mask_cells[mask_cells.size() - 1]
	return Vector2(float(fallback.x) + 0.5, float(fallback.y) + 0.5)

static func sample_image_mask(img: Image, grid_n: int) -> PackedByteArray:
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

static func _build_mouth_mask(mask: PackedByteArray, r_min_x: PackedInt32Array, r_max_x: PackedInt32Array, rim_y: int, bot_y: int) -> PackedByteArray:
	var mouth := PackedByteArray()
	mouth.resize(GRID_CELLS)
	if bot_y < rim_y:
		return mouth

	var col_top_y := PackedInt32Array()
	col_top_y.resize(GRID_SIZE)
	col_top_y.fill(GRID_SIZE)
	for x in GRID_SIZE:
		for y in range(rim_y, bot_y + 1):
			if mask[x + y * GRID_SIZE] == 1:
				col_top_y[x] = y
				break

	var max_body_width := 0
	for y in range(rim_y, bot_y + 1):
		if r_max_x[y] >= r_min_x[y]:
			max_body_width = maxi(max_body_width, r_max_x[y] - r_min_x[y] + 1)

	var cavity_h := maxi(1, bot_y - rim_y)
	var top_w := (r_max_x[rim_y] - r_min_x[rim_y] + 1) if r_max_x[rim_y] >= r_min_x[rim_y] else 0
	var next_y := mini(rim_y + 1, bot_y)
	var next_w := (r_max_x[next_y] - r_min_x[next_y] + 1) if r_max_x[next_y] >= r_min_x[next_y] else top_w
	var probe_y := mini(rim_y + 2, bot_y)
	var probe_w := (r_max_x[probe_y] - r_min_x[probe_y] + 1) if r_max_x[probe_y] >= r_min_x[probe_y] else next_w

	var is_narrow_neck := (
		float(top_w) < float(max_body_width) * 0.58
		and float(next_w) < float(max_body_width) * 0.60
		and float(probe_w) < float(max_body_width) * 0.65
	)

	var band_pct := 0.14 if is_narrow_neck else 0.08
	var min_band := 3 if is_narrow_neck else 2
	var y_limit := mini(bot_y, rim_y + maxi(min_band, int(round(float(cavity_h) * band_pct))))

	var neck_ref_w := maxi(top_w, next_w)
	var effective_band_end := rim_y
	for y in range(rim_y, y_limit + 1):
		if r_max_x[y] < r_min_x[y]:
			break
		var w_y := r_max_x[y] - r_min_x[y] + 1
		if y > rim_y + 1:
			if is_narrow_neck:
				if y > rim_y + 2 and float(w_y) > float(maxi(neck_ref_w, 2)) * 1.65 and float(w_y) >= float(max_body_width) * 0.55:
					break
				if float(w_y) >= float(max_body_width) * 0.72:
					break
			else:
				var prev_w := (r_max_x[y - 1] - r_min_x[y - 1] + 1) if r_max_x[y - 1] >= r_min_x[y - 1] else w_y
				if float(prev_w) < float(max_body_width) * 0.45 and float(w_y) > float(maxi(prev_w, 1)) * 1.9:
					break
		effective_band_end = y

	if is_narrow_neck:
		for y in range(rim_y, effective_band_end + 1):
			if r_max_x[y] < r_min_x[y]:
				continue
			for x in range(r_min_x[y], r_max_x[y] + 1):
				if mask[x + y * GRID_SIZE] == 1:
					mouth[x + y * GRID_SIZE] = 1
		return mouth

	if r_max_x[effective_band_end] >= r_min_x[effective_band_end]:
		var end_w := r_max_x[effective_band_end] - r_min_x[effective_band_end] + 1
		if float(end_w) < float(max_body_width) * 0.45:
			effective_band_end = mini(bot_y, rim_y + 2)

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
			if ty < effective_band_end and ty + 1 <= bot_y and mask[x + (ty + 1) * GRID_SIZE] == 1:
				mouth[x + (ty + 1) * GRID_SIZE] = 1

	return mouth

static func _build_sdf_bytes(mask: PackedByteArray, mouth_mask: PackedByteArray) -> PackedByteArray:
	var dist_in := PackedFloat32Array()
	var dist_out := PackedFloat32Array()
	dist_in.resize(GRID_CELLS)
	dist_out.resize(GRID_CELLS)
	var big := 1000.0
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var idx := x + y * GRID_SIZE
			var on_border := (x == 0 or x == GRID_SIZE - 1 or y == 0 or y == GRID_SIZE - 1)
			if mask[idx] == 1:
				dist_in[idx] = 0.5 if on_border else big
				dist_out[idx] = 0.0
			else:
				dist_in[idx] = 0.0
				dist_out[idx] = big

	_edt_2d_pass(dist_in)
	_edt_2d_pass(dist_out)

	var signed_dist := PackedFloat32Array()
	signed_dist.resize(GRID_CELLS)
	for i in GRID_CELLS:
		signed_dist[i] = maxf(0.15, dist_in[i]) if mask[i] == 1 else -maxf(0.25, dist_out[i])

	var encoded := PackedByteArray()
	encoded.resize(GRID_CELLS * 16)
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var idx := x + y * GRID_SIZE
			var xl := signed_dist[maxi(x - 1, 0) + y * GRID_SIZE]
			var xr := signed_dist[mini(x + 1, GRID_SIZE - 1) + y * GRID_SIZE]
			var yu := signed_dist[x + maxi(y - 1, 0) * GRID_SIZE]
			var yd := signed_dist[x + mini(y + 1, GRID_SIZE - 1) * GRID_SIZE]
			var grad := Vector2(xr - xl, yd - yu)
			grad = grad.normalized() if grad.length_squared() > 0.00001 else Vector2(0.0, -1.0)
			var wall_flag := 2.0 if mouth_mask[idx] == 1 else (1.0 if mask[idx] == 1 else 0.0)
			var off := idx * 16
			encoded.encode_float(off + 0, grad.x)
			encoded.encode_float(off + 4, grad.y)
			encoded.encode_float(off + 8, signed_dist[idx])
			encoded.encode_float(off + 12, wall_flag)
	return encoded

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