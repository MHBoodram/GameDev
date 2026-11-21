class_name CupFluidSim
extends Node

const GRID_RES: int = 64
const SUBVIEWPORT_W: int = 128
const SUBVIEWPORT_H: int = 64
const BEER_FOAM_COLOR: Color = Color(0.99, 0.95, 0.82, 1.0)

static var _sdf_cache: Dictionary = {}
static var _radial_tex: ImageTexture = null

var _owner_glass: Node3D
var _outside_sprite: Sprite3D
var _viewport: SubViewport
var _canvas: _CupFluidCanvas

var _sdf: Dictionary = {}
var _max_particles: int = 96
var _unit_volume: float = 0.05
var _rest_spacing: float = 3.6
var _kernel_radius: float = 5.4

# Particle arrays in 64x64 texture-grid space (x: 0..64, y: 0..64 where y=0 is top)
var _px: PackedFloat32Array = PackedFloat32Array()
var _py: PackedFloat32Array = PackedFloat32Array()
var _vx: PackedFloat32Array = PackedFloat32Array()
var _vy: PackedFloat32Array = PackedFloat32Array()
var _col: PackedColorArray = PackedColorArray()
var _ing: Array[String] = []
var _vol: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0

var _prev_world_pos: Vector3 = Vector3.ZERO
var _prev_world_vel: Vector3 = Vector3.ZERO
var _has_prev_motion: bool = false

# Spatial hash for O(N) neighbor pressure solver
const HASH_GRID_W: int = 16
const HASH_GRID_H: int = 16
var _cell_head: PackedInt32Array = PackedInt32Array()
var _next_p: PackedInt32Array = PackedInt32Array()

static func _get_radial_texture() -> ImageTexture:
	if _radial_tex != null:
		return _radial_tex
	var size: int = 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half: float = float(size) * 0.5
	for y in size:
		for x in size:
			var dx: float = ((float(x) + 0.5) - half) / half
			var dy: float = ((float(y) + 0.5) - half) / half
			var r2: float = dx * dx + dy * dy
			var a: float = 0.0
			if r2 < 1.0:
				var w: float = 1.0 - r2
				a = clampf(w * w * 0.72, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_radial_tex = ImageTexture.create_from_image(img)
	return _radial_tex

func setup(glass: Node3D, outside_spr: Sprite3D, glass_capacity: float) -> void:
	_owner_glass = glass
	_outside_sprite = outside_spr
	_max_particles = clampi(int(roundf(glass_capacity * 15.0)), 75, 160)
	_unit_volume = maxf(glass_capacity / float(_max_particles), 0.005)

	_cell_head.resize(HASH_GRID_W * HASH_GRID_H)
	_sdf = _get_or_build_sdf(outside_spr, glass)

	var area_px: float = maxf(float(_sdf.get("cavity_area", 1400.0)), 400.0)
	_rest_spacing = clampf(sqrt(area_px / float(_max_particles)), 2.2, 5.2)
	_kernel_radius = _rest_spacing * 1.62

	_viewport = SubViewport.new()
	_viewport.name = "FluidFieldViewport"
	_viewport.size = Vector2i(SUBVIEWPORT_W, SUBVIEWPORT_H)
	_viewport.transparent_bg = false
	_viewport.own_world_3d = false
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(SUBVIEWPORT_W, SUBVIEWPORT_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(bg)

	_canvas = _CupFluidCanvas.new()
	_canvas.sim = self
	_canvas.radial_tex = _get_radial_texture()
	_viewport.add_child(_canvas)

	add_child(_viewport)
	if is_instance_valid(_owner_glass):
		_prev_world_pos = _owner_glass.global_position
		_has_prev_motion = true

func get_texture() -> ViewportTexture:
	if _viewport:
		return _viewport.get_texture()
	return null

func get_particle_count() -> int:
	return _count

func get_unit_volume() -> float:
	return _unit_volume

func get_local_up_uv() -> Vector2:
	if not is_instance_valid(_outside_sprite):
		return Vector2(0.0, -1.0)
	var local_down: Vector3 = _outside_sprite.global_transform.basis.inverse() * Vector3(0.0, -1.0, 0.0)
	var up_uv := Vector2(-local_down.x, local_down.y)
	if up_uv.length_squared() < 0.0001:
		return Vector2(0.0, -1.0)
	return up_uv.normalized()

func add_particle(ing_id: String, volume: float, col: Color, uv_pos: Vector2, uv_vel: Vector2) -> void:
	if volume <= 0.0:
		return
	var rim_y: float = float(_sdf.get("rim_y", 8.0))
	var bot_y: float = float(_sdf.get("bottom_y", 56.0))
	var px: float = clampf(uv_pos.x * float(GRID_RES), 6.0, float(GRID_RES) - 6.0)
	var py: float = clampf(uv_pos.y * float(GRID_RES), 2.0, bot_y - 2.0)

	# Keep spawn inside valid X span near rim if dropped from stream
	if py <= rim_y + 4.0:
		var lip_l: float = float(_sdf.get("lip_left_x", 18.0)) + 2.5
		var lip_r: float = float(_sdf.get("lip_right_x", 46.0)) - 2.5
		px = clampf(px, minf(lip_l, lip_r), maxf(lip_l, lip_r))

	_px.append(px)
	_py.append(py)
	_vx.append(clampf(uv_vel.x, -120.0, 120.0))
	_vy.append(clampf(uv_vel.y, -120.0, 120.0))
	_col.append(_apply_foam_hint(ing_id, col, 0.18))
	_ing.append(ing_id)
	_vol.append(volume)
	_count += 1
	_ensure_viewport_active()

func sync_fill_to_liquids(liquids: Array, total_liquids: float, glass_size: float, helper: LiquidVisualHelper) -> void:
	clear_particles()
	if liquids.is_empty() or total_liquids <= 0.0001:
		return

	var target_total_p: int = clampi(int(roundf((total_liquids / maxf(glass_size, 0.001)) * float(_max_particles))), 1, _max_particles)
	var rim_y: float = float(_sdf.get("rim_y", 8.0))
	var bot_y: float = float(_sdf.get("bottom_y", 56.0))
	var fill_ratio: float = clampf(total_liquids / maxf(glass_size, 0.001), 0.0, 1.0)
	var top_fill_y: float = lerpf(bot_y - 2.0, rim_y + 1.5, fill_ratio)

	var placed: int = 0
	var cur_y: float = bot_y - 2.5
	var layer_cursor: float = 0.0
	var layer_idx: int = 0
	var current_layer: Array = liquids[0]
	var cur_layer_end: float = float(current_layer[1])

	while placed < target_total_p and cur_y >= top_fill_y - 4.0:
		var span: Vector2 = _get_row_span(int(clampf(cur_y, 0.0, float(GRID_RES - 1))))
		var x_start: float = span.x + 2.0
		var x_end: float = span.y - 2.0
		if x_end > x_start:
			var x: float = x_start + randf_range(0.0, 0.8)
			while x <= x_end and placed < target_total_p:
				var progress_vol: float = (float(placed) / float(maxi(target_total_p, 1))) * total_liquids
				while layer_idx < liquids.size() - 1 and progress_vol > cur_layer_end:
					layer_idx += 1
					current_layer = liquids[layer_idx]
					cur_layer_end += float(current_layer[1])
				var p_col: Color = helper.get_layer_color(current_layer)
				var p_ing: String = helper.format_layer_name(current_layer[0])
				var p_vol: float = total_liquids / float(target_total_p)
				_px.append(x)
				_py.append(clampf(cur_y + randf_range(-0.4, 0.4), rim_y + 1.5, bot_y - 2.0))
				_vx.append(0.0)
				_vy.append(0.0)
				_col.append(_apply_foam_hint(p_ing, p_col, 0.1 if cur_y < top_fill_y + 4.0 else 0.0))
				_ing.append(p_ing)
				_vol.append(p_vol)
				_count += 1
				placed += 1
				x += _rest_spacing * 0.92
		cur_y -= _rest_spacing * 0.86
		layer_cursor += 1.0

	_ensure_viewport_active()

func recolor_mixed(mixed_color: Color, mixed_id: String = "mixed") -> void:
	for i in _count:
		_col[i] = mixed_color
		_ing[i] = mixed_id
		_vx[i] += randf_range(-28.0, 28.0)
		_vy[i] += randf_range(-22.0, 12.0)
	_ensure_viewport_active()

func clear_particles() -> void:
	_px.clear()
	_py.clear()
	_vx.clear()
	_vy.clear()
	_col.clear()
	_ing.clear()
	_vol.clear()
	_count = 0
	if _canvas:
		_canvas.queue_redraw()
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func step(delta: float, is_pouring_out: bool, pour_tilt_degrees: float, is_full_cup: bool) -> Array[Dictionary]:
	var ejected: Array[Dictionary] = []
	if _count <= 0:
		if _viewport and _viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return ejected

	var dt: float = clampf(delta, 0.001, 0.033)
	_ensure_viewport_active()

	# Compute cup-local gravity and inertial acceleration
	var grav_uv := Vector2(0.0, 140.0)
	if is_instance_valid(_outside_sprite):
		var local_g: Vector3 = _outside_sprite.global_transform.basis.inverse() * Vector3(0.0, -1.0, 0.0)
		grav_uv = Vector2(local_g.x, -local_g.y) * 145.0

	var inertial_uv := Vector2.ZERO
	if is_instance_valid(_owner_glass):
		var cur_pos: Vector3 = _owner_glass.global_position
		var cur_vel: Vector3 = (cur_pos - _prev_world_pos) / dt if _has_prev_motion else Vector3.ZERO
		var accel: Vector3 = (cur_vel - _prev_world_vel) / dt if _has_prev_motion else Vector3.ZERO
		_prev_world_pos = cur_pos
		_prev_world_vel = cur_vel
		_has_prev_motion = true

		if is_instance_valid(_outside_sprite):
			var local_a: Vector3 = _outside_sprite.global_transform.basis.inverse() * accel
			inertial_uv = Vector2(-local_a.x, local_a.y) * 16.0
			inertial_uv = inertial_uv.limit_length(180.0)

	var total_force: Vector2 = grav_uv + inertial_uv
	var rim_y: float = float(_sdf.get("rim_y", 8.0))
	var bot_y: float = float(_sdf.get("bottom_y", 56.0))
	var lip_l: float = float(_sdf.get("lip_left_x", 18.0))
	var lip_r: float = float(_sdf.get("lip_right_x", 46.0))

	# Integrate forces
	for i in _count:
		_vx[i] = (_vx[i] + total_force.x * dt) * exp(-2.4 * dt)
		_vy[i] = (_vy[i] + total_force.y * dt) * exp(-2.4 * dt)

		# Gentle pour guidance when steeply tilted in sink so liquid drains smoothly
		if is_pouring_out and pour_tilt_degrees > 35.0:
			var tilt_dir: float = -1.0 if grav_uv.x < 0.0 else 1.0
			var guide_strength: float = clampf((pour_tilt_degrees - 35.0) / 70.0, 0.0, 1.0)
			if _py[i] > rim_y + 1.0:
				_vy[i] -= guide_strength * 55.0 * dt
				_vx[i] += tilt_dir * guide_strength * 65.0 * dt

		_px[i] += _vx[i] * dt
		_py[i] += _vy[i] * dt

	# 2 PBF-lite relaxation iterations with spatial hash
	var cell_size: float = float(GRID_RES) / float(HASH_GRID_W)
	var min_dist: float = _rest_spacing * 0.94
	var min_dist_sq: float = min_dist * min_dist
	var cohesion_rad: float = _kernel_radius
	var cohesion_rad_sq: float = cohesion_rad * cohesion_rad

	_next_p.resize(_count)
	for _iter in 2:
		_cell_head.fill(-1)
		for i in _count:
			var cx: int = clampi(int(_px[i] / cell_size), 0, HASH_GRID_W - 1)
			var cy: int = clampi(int(_py[i] / cell_size), 0, HASH_GRID_H - 1)
			var c_idx: int = cx + cy * HASH_GRID_W
			_next_p[i] = _cell_head[c_idx]
			_cell_head[c_idx] = i

		for i in _count:
			var xi: float = _px[i]
			var yi: float = _py[i]
			var cx0: int = clampi(int(xi / cell_size), 0, HASH_GRID_W - 1)
			var cy0: int = clampi(int(yi / cell_size), 0, HASH_GRID_H - 1)
			var corr_x: float = 0.0
			var corr_y: float = 0.0

			for oy in range(-1, 2):
				var ny: int = cy0 + oy
				if ny < 0 or ny >= HASH_GRID_H:
					continue
				for ox in range(-1, 2):
					var nx: int = cx0 + ox
					if nx < 0 or nx >= HASH_GRID_W:
						continue
					var j: int = _cell_head[nx + ny * HASH_GRID_W]
					while j != -1:
						if j > i:
							var dx: float = _px[j] - xi
							var dy: float = _py[j] - yi
							var d2: float = dx * dx + dy * dy
							if d2 > 0.0001 and d2 < cohesion_rad_sq:
								var d: float = sqrt(d2)
								var inv_d: float = 1.0 / d
								var ux: float = dx * inv_d
								var uy: float = dy * inv_d
								if d2 < min_dist_sq:
									var push: float = (min_dist - d) * 0.42
									corr_x -= ux * push
									corr_y -= uy * push
									_px[j] += ux * push
									_py[j] += uy * push
									_vx[i] -= ux * push * 18.0
									_vy[i] -= uy * push * 18.0
									_vx[j] += ux * push * 18.0
									_vy[j] += uy * push * 18.0
								else:
									# Mild cohesion + viscosity damping
									var pull: float = (d - min_dist) * 0.014
									corr_x += ux * pull
									corr_y += uy * pull
									_px[j] -= ux * pull
									_py[j] -= uy * pull
									var dvx: float = (_vx[j] - _vx[i]) * 0.03
									var dvy: float = (_vy[j] - _vy[i]) * 0.03
									_vx[i] += dvx
									_vy[i] += dvy
									_vx[j] -= dvx
									_vy[j] -= dvy
						j = _next_p[j]

			_px[i] += corr_x
			_py[i] += corr_y

		# Enforce glass interior SDF boundaries below the rim
		for i in _count:
			_constrain_to_cavity(i, rim_y, bot_y)

	# Check for particles spilling out over the rim (sink pour-out or overfill)
	var write_idx: int = 0
	for i in _count:
		var px_i: float = _px[i]
		var py_i: float = _py[i]
		var spilled: bool = false
		var spill_side: float = 0.0

		if is_pouring_out:
			if py_i < rim_y + 0.8:
				var mid_lip: float = 0.5 * (lip_l + lip_r)
				if px_i <= lip_l + 3.5 or px_i >= lip_r - 3.5 or py_i < rim_y - 1.0:
					spilled = true
					spill_side = -1.0 if px_i < mid_lip else 1.0
		elif is_full_cup and py_i < rim_y - 0.6:
			var mid_lip: float = 0.5 * (lip_l + lip_r)
			if px_i <= lip_l + 2.0 or px_i >= lip_r - 2.0 or py_i < rim_y - 3.2:
				spilled = true
				spill_side = -1.0 if px_i < mid_lip else 1.0

		if spilled:
			var exit_u: float = clampf((lip_l if spill_side < 0.0 else lip_r) / float(GRID_RES), 0.05, 0.95)
			var exit_v: float = clampf((rim_y + 0.5) / float(GRID_RES), 0.02, 0.95)
			ejected.append({
				"ingredient_id": _ing[i],
				"volume": _vol[i],
				"color": _col[i],
				"uv_pos": Vector2(exit_u, exit_v),
				"uv_vel": Vector2(_vx[i] / float(GRID_RES), _vy[i] / float(GRID_RES)),
				"side": spill_side
			})
		else:
			if write_idx != i:
				_px[write_idx] = _px[i]
				_py[write_idx] = _py[i]
				_vx[write_idx] = _vx[i]
				_vy[write_idx] = _vy[i]
				_col[write_idx] = _col[i]
				_ing[write_idx] = _ing[i]
				_vol[write_idx] = _vol[i]
			write_idx += 1

	if write_idx < _count:
		_count = write_idx
		_px.resize(_count)
		_py.resize(_count)
		_vx.resize(_count)
		_vy.resize(_count)
		_col.resize(_count)
		_ing.resize(_count)
		_vol.resize(_count)

	if _canvas:
		_canvas.queue_redraw()
	return ejected

func _constrain_to_cavity(i: int, rim_y: float, bot_y: float) -> void:
	var x: float = _px[i]
	var y: float = _py[i]

	if y > bot_y - 1.5:
		y = bot_y - 1.5
		if _vy[i] > 0.0:
			_vy[i] *= -0.15

	# Above rim is open air, only clamp outer viewport borders
	if y < rim_y:
		if x < 2.0:
			x = 2.0
			_vx[i] = absf(_vx[i]) * 0.2
		elif x > float(GRID_RES - 2):
			x = float(GRID_RES - 2)
			_vx[i] = -absf(_vx[i]) * 0.2
		_px[i] = x
		_py[i] = y
		return

	var gx: int = clampi(int(roundf(x)), 0, GRID_RES - 1)
	var gy: int = clampi(int(roundf(y)), 0, GRID_RES - 1)
	var idx: int = gx + gy * GRID_RES

	var dist_arr: PackedFloat32Array = _sdf["dist"]
	var nx_arr: PackedFloat32Array = _sdf["nx"]
	var ny_arr: PackedFloat32Array = _sdf["ny"]

	var d: float = dist_arr[idx]
	if d < 1.2:
		var nx: float = nx_arr[idx]
		var ny: float = ny_arr[idx]
		var push: float = 1.2 - d
		x += nx * push
		y += ny * push
		var vn: float = _vx[i] * nx + _vy[i] * ny
		if vn < 0.0:
			_vx[i] -= nx * vn * 1.15
			_vy[i] -= ny * vn * 1.15

	_px[i] = clampf(x, 1.0, float(GRID_RES - 1))
	_py[i] = clampf(y, 0.5, float(GRID_RES - 1))

func _get_row_span(gy: int) -> Vector2:
	var min_x: PackedFloat32Array = _sdf.get("row_min_x", PackedFloat32Array())
	var max_x: PackedFloat32Array = _sdf.get("row_max_x", PackedFloat32Array())
	if gy >= 0 and gy < min_x.size():
		return Vector2(min_x[gy], max_x[gy])
	return Vector2(16.0, 48.0)

func _ensure_viewport_active() -> void:
	if _viewport and _viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _canvas:
		_canvas.queue_redraw()

func _apply_foam_hint(ing_id: String, base_col: Color, strength: float) -> Color:
	if ing_id == "beer" and strength > 0.0:
		return base_col.lerp(BEER_FOAM_COLOR, clampf(strength, 0.0, 0.75))
	return base_col

static func _get_or_build_sdf(spr: Sprite3D, glass: Node3D) -> Dictionary:
	if not is_instance_valid(spr) or spr.texture == null:
		return _build_fallback_sdf()
	var m_top: float = float(glass.inner_margin_top) if "inner_margin_top" in glass else 0.12
	var m_bot: float = float(glass.inner_margin_bottom) if "inner_margin_bottom" in glass else 0.88
	var tex_id: int = spr.texture.get_rid().get_id()
	var key: String = "%d_%.2f_%.2f_%s_%s" % [tex_id, m_top, m_bot, str(spr.flip_h), str(spr.flip_v)]
	if _sdf_cache.has(key):
		return _sdf_cache[key]

	var img: Image = spr.texture.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed() and img.decompress() != OK:
			img = null
	if img == null or img.is_empty() or img.is_compressed():
		var fb := _build_fallback_sdf()
		_sdf_cache[key] = fb
		return fb

	var tw: int = img.get_width()
	var th: int = img.get_height()
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		var fb := _build_fallback_sdf()
		_sdf_cache[key] = fb
		return fb

	var rim_px: int = maxi(used.position.y, int(floorf(m_top * float(th))))
	var bot_px: int = mini(used.end.y, int(ceilf(m_bot * float(th))))
	if bot_px <= rim_px + 2:
		rim_px = used.position.y
		bot_px = used.end.y

	var rim_gy: int = clampi(int(roundf((float(rim_px) / float(th)) * float(GRID_RES))), 2, GRID_RES - 10)
	var bot_gy: int = clampi(int(roundf((float(bot_px) / float(th)) * float(GRID_RES))), rim_gy + 6, GRID_RES - 2)

	var inside := PackedByteArray()
	inside.resize(GRID_RES * GRID_RES)
	inside.fill(0)

	var row_min_x := PackedFloat32Array()
	var row_max_x := PackedFloat32Array()
	row_min_x.resize(GRID_RES)
	row_max_x.resize(GRID_RES)
	row_min_x.fill(float(GRID_RES) * 0.5)
	row_max_x.fill(float(GRID_RES) * 0.5)

	var cavity_area: float = 0.0
	for gy in GRID_RES:
		var v_norm: float = (float(gy) + 0.5) / float(GRID_RES)
		var py: int = clampi(int((1.0 - v_norm if spr.flip_v else v_norm) * float(th)), 0, th - 1)
		var r_min: int = -1
		var r_max: int = -1
		for gx in GRID_RES:
			var u_norm: float = (float(gx) + 0.5) / float(GRID_RES)
			var px: int = clampi(int((1.0 - u_norm if spr.flip_h else u_norm) * float(tw)), 0, tw - 1)
			var solid_air_top: bool = gy < rim_gy
			var opaque: bool = img.get_pixel(px, py).a > 0.15
			if solid_air_top:
				# Open top channel within the rim horizontal bounds
				inside[gx + gy * GRID_RES] = 1
			elif gy <= bot_gy and opaque:
				inside[gx + gy * GRID_RES] = 1
				cavity_area += 1.0
				if r_min == -1:
					r_min = gx
				r_max = gx
		if r_min != -1:
			row_min_x[gy] = float(r_min)
			row_max_x[gy] = float(r_max)

	var lip_l: float = row_min_x[rim_gy]
	var lip_r: float = row_max_x[rim_gy]
	if lip_r <= lip_l + 2.0:
		for gy in range(rim_gy, mini(rim_gy + 6, GRID_RES)):
			if row_max_x[gy] > row_min_x[gy] + 2.0:
				lip_l = row_min_x[gy]
				lip_r = row_max_x[gy]
				break

	# Compute inward SDF distance + normal for walls below rim_gy
	var dist := PackedFloat32Array()
	var nx_arr := PackedFloat32Array()
	var ny_arr := PackedFloat32Array()
	dist.resize(GRID_RES * GRID_RES)
	nx_arr.resize(GRID_RES * GRID_RES)
	ny_arr.resize(GRID_RES * GRID_RES)

	for gy in GRID_RES:
		for gx in GRID_RES:
			var idx: int = gx + gy * GRID_RES
			if gy < rim_gy:
				dist[idx] = 10.0
				nx_arr[idx] = 0.0
				ny_arr[idx] = 1.0
				continue

			var is_in: bool = inside[idx] == 1
			var best_d2: float = 9999.0
			var best_dx: float = 0.0
			var best_dy: float = -1.0
			var search_r: int = 8
			for sy in range(maxi(rim_gy, gy - search_r), mini(GRID_RES, gy + search_r + 1)):
				for sx in range(maxi(0, gx - search_r), mini(GRID_RES, gx + search_r + 1)):
					var target_in: bool = inside[sx + sy * GRID_RES] == 1
					if target_in != is_in:
						var ddx: float = float(sx - gx)
						var ddy: float = float(sy - gy)
						var d2: float = ddx * ddx + ddy * ddy
						if d2 < best_d2:
							best_d2 = d2
							best_dx = ddx
							best_dy = ddy

			var d_len: float = sqrt(best_d2)
			if is_in:
				dist[idx] = d_len
				var inv: float = 1.0 / maxf(d_len, 0.001)
				nx_arr[idx] = -best_dx * inv
				ny_arr[idx] = -best_dy * inv
			else:
				dist[idx] = -d_len
				var inv: float = 1.0 / maxf(d_len, 0.001)
				nx_arr[idx] = best_dx * inv
				ny_arr[idx] = best_dy * inv

	var result := {
		"dist": dist,
		"nx": nx_arr,
		"ny": ny_arr,
		"rim_y": float(rim_gy),
		"bottom_y": float(bot_gy),
		"lip_left_x": lip_l,
		"lip_right_x": lip_r,
		"row_min_x": row_min_x,
		"row_max_x": row_max_x,
		"cavity_area": cavity_area
	}
	_sdf_cache[key] = result
	return result

static func _build_fallback_sdf() -> Dictionary:
	var dist := PackedFloat32Array()
	var nx_arr := PackedFloat32Array()
	var ny_arr := PackedFloat32Array()
	dist.resize(GRID_RES * GRID_RES)
	nx_arr.resize(GRID_RES * GRID_RES)
	ny_arr.resize(GRID_RES * GRID_RES)
	var row_min_x := PackedFloat32Array()
	var row_max_x := PackedFloat32Array()
	row_min_x.resize(GRID_RES)
	row_max_x.resize(GRID_RES)
	for gy in GRID_RES:
		row_min_x[gy] = 16.0
		row_max_x[gy] = 48.0
		for gx in GRID_RES:
			var idx: int = gx + gy * GRID_RES
			var dx_l: float = float(gx) - 16.0
			var dx_r: float = 48.0 - float(gx)
			var dy_b: float = 56.0 - float(gy)
			var m_d: float = minf(minf(dx_l, dx_r), dy_b)
			dist[idx] = m_d
			if m_d == dx_l:
				nx_arr[idx] = 1.0
				ny_arr[idx] = 0.0
			elif m_d == dx_r:
				nx_arr[idx] = -1.0
				ny_arr[idx] = 0.0
			else:
				nx_arr[idx] = 0.0
				ny_arr[idx] = -1.0
	return {
		"dist": dist,
		"nx": nx_arr,
		"ny": ny_arr,
		"rim_y": 8.0,
		"bottom_y": 56.0,
		"lip_left_x": 16.0,
		"lip_right_x": 48.0,
		"row_min_x": row_min_x,
		"row_max_x": row_max_x,
		"cavity_area": 1536.0
	}

class _CupFluidCanvas extends Node2D:
	var sim: CupFluidSim
	var radial_tex: Texture2D
	var _add_mat: CanvasItemMaterial

	func _ready() -> void:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = _add_mat

	func _draw() -> void:
		if not sim or not radial_tex or sim._count <= 0:
			return
		var rad: float = sim._kernel_radius
		var diam: float = rad * 2.0
		var half_w: float = float(SUBVIEWPORT_W) * 0.5
		for i in sim._count:
			var x: float = sim._px[i]
			var y: float = sim._py[i]
			var c: Color = sim._col[i]
			# Left 64x64: pure density weight in white
			draw_texture_rect(radial_tex, Rect2(x - rad, y - rad, diam, diam), false, Color(1.0, 1.0, 1.0, 1.0))
			# Right 64x64: weighted color
			draw_texture_rect(radial_tex, Rect2(half_w + x - rad, y - rad, diam, diam), false, Color(c.r, c.g, c.b, 1.0))