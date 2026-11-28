extends LemonMinigame
class_name IceMinigame

const POLY_EPS: float = 0.001
const CIRCLE_POLY_SEGMENTS: int = 64
const ICE_BASE_COLOR: Color = Color(0.84, 0.95, 1.0, 1.0)
const ICE_OUTLINE_COLOR: Color = Color(0.10, 0.20, 0.32, 0.95)
const ICE_RED_FILL_COLOR: Color = Color(0.95, 0.16, 0.16, 0.42)
const ICE_GREEN_FILL_COLOR: Color = Color(0.18, 0.92, 0.34, 0.42)
const ICE_GUIDE_GREEN_TINT: Color = Color(0.20, 0.90, 0.35, 0.06)
const ICE_GUIDE_GREEN_BORDER: Color = Color(0.28, 1.0, 0.42, 0.85)

@export var ice_time_limit: float = 25.0
@export var ice_display_size: Vector2 = Vector2(280.0, 280.0)
@export var circle_radius_ratio: float = 0.255
@export var green_margin_width: float = 25.0
@export var red_cut_grace: float = 1.0
@export var trim_win_padding: float = 2.5
@export var win_excess_area_threshold: float = 25.0

var _ice_texture: Texture2D = null
var _ice_rect: Rect2 = Rect2()
var _circle_center: Vector2 = Vector2.ZERO
var _circle_radius: float = 71.0
var _circle_outer_radius: float = 96.0

var _ice_poly: PackedVector2Array = PackedVector2Array()
var _green_circle_poly: PackedVector2Array = PackedVector2Array()
var _initial_excess_area: float = 0.0

var _ice_holder: Control
var _ice_poly_node: Polygon2D
var _ice_zone_drawer: _IceZoneDrawer
var _ice_outline_drawer: _IceOutlineDrawer
var _shards_layer: Control
var _circle_guide: DottedLine2D


class _IceZoneDrawer extends Node2D:
	var center: Vector2 = Vector2.ZERO
	var inner_radius: float = 71.0
	var outer_radius: float = 96.0
	var red_color: Color = ICE_RED_FILL_COLOR
	var green_color: Color = ICE_GREEN_FILL_COLOR
	var segments: int = CIRCLE_POLY_SEGMENTS

	func _draw() -> void:
		if inner_radius <= 0.5:
			return
		var segs := maxi(16, segments)
		if green_color.a > 0.001 and outer_radius > inner_radius:
			for i in segs:
				var a0 := float(i) / float(segs) * TAU
				var a1 := float(i + 1) / float(segs) * TAU
				var d0 := Vector2.from_angle(a0)
				var d1 := Vector2.from_angle(a1)
				var quad := PackedVector2Array([
					center + d0 * inner_radius,
					center + d0 * outer_radius,
					center + d1 * outer_radius,
					center + d1 * inner_radius,
				])
				draw_colored_polygon(quad, green_color)
		if red_color.a > 0.001:
			draw_circle(center, inner_radius, red_color)


class _IceOutlineDrawer extends Node2D:
	var polygon: PackedVector2Array = PackedVector2Array()
	var outline_color: Color = ICE_OUTLINE_COLOR
	var outline_width: float = 3.0

	func _draw() -> void:
		if polygon.size() < 3:
			return
		var closed := polygon.duplicate()
		closed.append(polygon[0])
		draw_polyline(closed, outline_color, outline_width, true)


class _FallingShard extends Node2D:
	var vel: Vector2 = Vector2.ZERO
	var rot_vel: float = 0.0
	var gravity: float = 980.0
	var life: float = 0.0
	var max_life: float = 0.48

	func _process(delta: float) -> void:
		life += delta
		if life >= max_life:
			queue_free()
			return
		vel.y += gravity * delta
		position += vel * delta
		rotation += rot_vel * delta
		var t := clampf(life / max_life, 0.0, 1.0)
		modulate.a = 1.0 - t * t


func setup(p_garnish_id: String) -> void:
	garnish_id = GarnishDefinitions.normalize_id(p_garnish_id)
	if garnish_id == "":
		garnish_id = "ice"
	_is_half_stage = false
	_required_cuts = 1
	_time_limit = ice_time_limit
	lemon_display_size = ice_display_size

func _get_title_text() -> String:
	return "Carve!"

func _build_target_visual(screen: Vector2) -> void:
	_ice_texture = GarnishDefinitions.get_texture(garnish_id, false)

	_ice_holder = Control.new()
	_ice_holder.position = Vector2.ZERO
	_ice_holder.size = screen
	_ice_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_ice_holder)

	_ice_poly_node = Polygon2D.new()
	_ice_poly_node.color = ICE_BASE_COLOR
	_ice_poly_node.texture = _ice_texture
	_ice_poly_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ice_poly_node.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_ice_holder.add_child(_ice_poly_node)

	_ice_zone_drawer = _IceZoneDrawer.new()
	_ice_poly_node.add_child(_ice_zone_drawer)

	_ice_outline_drawer = _IceOutlineDrawer.new()
	_ice_holder.add_child(_ice_outline_drawer)

	_shards_layer = Control.new()
	_shards_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_shards_layer)

func _get_shake_target() -> Control:
	return _ice_holder

func _get_shake_base_pos() -> Vector2:
	return Vector2.ZERO

func _compute_target_geometry() -> void:
	var drawn_pos := _lemon_base_pos
	var drawn_size := ice_display_size
	if _ice_texture != null:
		var tex_size := _ice_texture.get_size()
		var tex_w := maxf(tex_size.x, 1.0)
		var tex_h := maxf(tex_size.y, 1.0)
		var scale_f := minf(ice_display_size.x / tex_w, ice_display_size.y / tex_h)
		drawn_size = Vector2(tex_w * scale_f, tex_h * scale_f)
		drawn_pos = _lemon_base_pos + (ice_display_size - drawn_size) * 0.5
		_drawn_rect = Rect2(drawn_pos, drawn_size)

		var img := _ice_texture.get_image()
		if img != null and not img.is_empty():
			img = img.duplicate() as Image
			if img.is_compressed():
				img.decompress()
			var used := img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				_ice_rect = Rect2(
					drawn_pos.x + (float(used.position.x) / tex_w) * drawn_size.x,
					drawn_pos.y + (float(used.position.y) / tex_h) * drawn_size.y,
					(float(used.size.x) / tex_w) * drawn_size.x,
					(float(used.size.y) / tex_h) * drawn_size.y
				)
			else:
				_ice_rect = _drawn_rect
		else:
			_ice_rect = _drawn_rect
	else:
		_drawn_rect = Rect2(drawn_pos, drawn_size)
		_ice_rect = _drawn_rect

	_circle_center = _ice_rect.get_center()
	_guide_center = _circle_center

	var min_dim := minf(_ice_rect.size.x, _ice_rect.size.y)
	_circle_radius = maxf(24.0, roundf(min_dim * circle_radius_ratio))
	var max_green_margin := maxf(10.0, min_dim * 0.5 - _circle_radius - 12.0)
	var eff_green_margin := minf(green_margin_width, max_green_margin)
	_circle_outer_radius = _circle_radius + eff_green_margin

	_ice_poly = PackedVector2Array([
		_ice_rect.position,
		Vector2(_ice_rect.end.x, _ice_rect.position.y),
		_ice_rect.end,
		Vector2(_ice_rect.position.x, _ice_rect.end.y),
	])

	_green_circle_poly = PackedVector2Array()
	for i in CIRCLE_POLY_SEGMENTS:
		var ang := float(i) / float(CIRCLE_POLY_SEGMENTS) * TAU
		_green_circle_poly.append(_circle_center + Vector2.from_angle(ang) * _circle_outer_radius)

	_initial_excess_area = _compute_excess_area(_ice_poly)
	_sync_ice_visual_polygons()
	_update_progress_label()

func _sync_ice_visual_polygons() -> void:
	if is_instance_valid(_ice_poly_node):
		_ice_poly_node.polygon = _ice_poly
		_ice_poly_node.uv = _compute_uvs_for_polygon(_ice_poly)
	if is_instance_valid(_ice_zone_drawer):
		_ice_zone_drawer.center = _circle_center
		_ice_zone_drawer.inner_radius = _circle_radius
		_ice_zone_drawer.outer_radius = _circle_outer_radius
		_ice_zone_drawer.queue_redraw()
	if is_instance_valid(_ice_outline_drawer):
		_ice_outline_drawer.polygon = _ice_poly
		_ice_outline_drawer.queue_redraw()

func _compute_uvs_for_polygon(poly: PackedVector2Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	if _ice_texture == null:
		return uvs
	var tex_size := _ice_texture.get_size()
	var w := maxf(_drawn_rect.size.x, 1.0)
	var h := maxf(_drawn_rect.size.y, 1.0)
	for pt in poly:
		var u := clampf((pt.x - _drawn_rect.position.x) / w, 0.0, 1.0) * tex_size.x
		var v := clampf((pt.y - _drawn_rect.position.y) / h, 0.0, 1.0) * tex_size.y
		uvs.append(Vector2(u, v))
	return uvs

func _spawn_cut_guides() -> void:
	_active_guides.clear()
	for child in _guides_layer.get_children():
		child.queue_free()

	var eff_green_margin := maxf(1.0, _circle_outer_radius - _circle_radius)
	_circle_guide = DottedLine2D.new()
	_circle_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_circle_guide.set_dash_metrics(12.0, 8.0, 4.0, 2.0)
	_circle_guide.set_colors(Color(1.0, 0.98, 0.88, 0.95), Color(0.06, 0.05, 0.08, 0.85))
	_circle_guide.set_circle(_circle_center, _circle_radius, CIRCLE_POLY_SEGMENTS)
	_circle_guide.set_inner_danger_zone(false)
	_circle_guide.set_tolerance_zone(true, eff_green_margin, ICE_GUIDE_GREEN_TINT, ICE_GUIDE_GREEN_BORDER, 2.5, -1.0, true)
	_guides_layer.add_child(_circle_guide)
	_active_guides.append(_circle_guide)

func _update_progress_label() -> void:
	if not is_instance_valid(_progress_label):
		return
	var pct := roundi(_compute_trimmed_ratio() * 100.0)
	_progress_label.text = "Trimmed: %d%%" % pct

func _update_hint_label() -> void:
	if not is_instance_valid(_hint_label):
		return
	var msg := "Trim all unhighlighted ice outside the green ring — don't cut into the red!"
	if _cuts_attempted == 0:
		msg += "\nRight-click to cancel"
	_hint_label.text = msg

func _evaluate_drag_cut(p0: Vector2, p1: Vector2) -> void:
	if p0.distance_to(p1) < MIN_DRAG_DISTANCE:
		return

	# Check whether the cut passes inside the red circle
	var closest_red := Geometry2D.get_closest_point_to_segment(_circle_center, p0, p1)
	if closest_red.distance_to(_circle_center) < _circle_radius - red_cut_grace:
		_cuts_attempted += 1
		_update_hint_label()
		_spawn_animated_slash(p0, p1, Color(1.0, 0.25, 0.25, 0.95), 0.65, false)
		_shake_lemon(14.0)
		SFXAudio.play_stab()
		if is_instance_valid(_ice_poly_node):
			_ice_poly_node.color = Color(1.0, 0.45, 0.45, 0.82)
		_finish("wasted", "Ice wasted!", Color(1.0, 0.35, 0.35))
		return

	var hit_seg := _clip_segment_to_convex_poly(p0, p1, _ice_poly)
	if hit_seg.is_empty():
		_spawn_animated_slash(p0, p1, Color(0.90, 0.90, 0.95, 0.55), 0.25, false)
		_show_feedback("Slice!", Color(0.95, 0.85, 0.4))
		return

	_cuts_attempted += 1
	_update_hint_label()

	var p0_in := Geometry2D.is_point_in_polygon(p0, _ice_poly)
	var p1_in := Geometry2D.is_point_in_polygon(p1, _ice_poly)
	if p0_in or p1_in:
		_wasted_cuts += 1
		_spawn_animated_slash(p0, p1, Color(1.0, 0.68, 0.22, 0.90), 0.65, false)
		_shake_lemon(5.0)
		SFXAudio.play_draw()
		_show_feedback("Wasted cut", Color(1.0, 0.68, 0.22))
		return

	var split_res := _split_convex_polygon(_ice_poly, p0, p1)
	var pos_poly: PackedVector2Array = split_res["pos"]
	var neg_poly: PackedVector2Array = split_res["neg"]

	var keep_poly: PackedVector2Array
	var cut_poly: PackedVector2Array
	var center_side := _signed_side(p0, p1, _circle_center)
	if center_side >= 0.0:
		keep_poly = pos_poly
		cut_poly = neg_poly
	else:
		keep_poly = neg_poly
		cut_poly = pos_poly

	if keep_poly.size() < 3 or _polygon_area(keep_poly) < 10.0:
		_spawn_animated_slash(p0, p1, Color(1.0, 0.68, 0.22, 0.90), 0.55, false)
		_show_feedback("Slice outside the circle", Color(0.95, 0.85, 0.4))
		return

	if cut_poly.size() < 3 or _polygon_area(cut_poly) < 1.0:
		_spawn_animated_slash(p0, p1, Color(0.90, 0.90, 0.95, 0.55), 0.25, false)
		_show_feedback("Barely nicked", Color(0.95, 0.85, 0.4))
		return

	var prev_excess := _compute_excess_area(_ice_poly)
	_ice_poly = keep_poly
	_sync_ice_visual_polygons()
	_spawn_cut_shard(cut_poly, p0, p1)

	_cuts_completed += 1
	_update_progress_label()
	_spawn_animated_slash(p0, p1, Color(0.55, 0.95, 1.0, 1.0), 0.32, false)
	_shake_lemon(6.0)
	SFXAudio.play_stab()
	if GameState.player and GameState.player.camera_rig and GameState.player.camera_rig.has_method("add_shake"):
		GameState.player.camera_rig.add_shake(0.10)

	if _is_all_trimmed():
		if is_instance_valid(_progress_label):
			_progress_label.text = "Trimmed: 100%"
		_finish("success", "Ice ball!", Color(0.4, 1.0, 0.5))
		return

	var new_excess := _compute_excess_area(_ice_poly)
	var closest_dist := closest_red.distance_to(_circle_center)
	if closest_dist <= _circle_radius + 8.0 and new_excess < prev_excess:
		_show_feedback("Clean!", Color(0.38, 0.96, 1.0))
	elif new_excess < prev_excess:
		_show_feedback("Chop!", Color(0.45, 0.96, 0.55))

func _spawn_cut_shard(cut_poly: PackedVector2Array, cut_a: Vector2, cut_b: Vector2) -> void:
	if not is_instance_valid(_shards_layer) or cut_poly.size() < 3:
		return

	var centroid := Vector2.ZERO
	for v in cut_poly:
		centroid += v
	centroid /= float(cut_poly.size())

	var local_pts := PackedVector2Array()
	for v in cut_poly:
		local_pts.append(v - centroid)

	var shard := _FallingShard.new()
	shard.position = centroid

	var outward := centroid - _circle_center
	if outward.length_squared() < 1.0:
		var edge_dir := (cut_b - cut_a).normalized()
		outward = Vector2(-edge_dir.y, edge_dir.x)
		if outward.dot(centroid - _circle_center) < 0.0:
			outward = -outward
	else:
		outward = outward.normalized()

	shard.vel = outward * randf_range(95.0, 155.0) + Vector2(0.0, randf_range(-85.0, -35.0))
	var spin_sign := -1.0 if outward.x < 0.0 else 1.0
	shard.rot_vel = spin_sign * randf_range(1.6, 3.6)

	var poly_vis := Polygon2D.new()
	poly_vis.polygon = local_pts
	poly_vis.uv = _compute_uvs_for_polygon(cut_poly)
	poly_vis.texture = _ice_texture
	poly_vis.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	poly_vis.color = Color(0.84, 0.95, 1.0, 0.94)
	shard.add_child(poly_vis)

	var line_vis := Line2D.new()
	line_vis.points = local_pts
	line_vis.closed = true
	line_vis.width = 2.5
	line_vis.default_color = Color(0.10, 0.20, 0.32, 0.85)
	shard.add_child(line_vis)

	_shards_layer.add_child(shard)

func _is_all_trimmed() -> bool:
	if _ice_poly.size() < 3:
		return false
	if _compute_excess_area(_ice_poly) <= win_excess_area_threshold:
		return true
	var max_allowed := _circle_outer_radius + trim_win_padding
	var max_allowed_sq := max_allowed * max_allowed
	for v in _ice_poly:
		if v.distance_squared_to(_circle_center) > max_allowed_sq:
			return false
	return true

func _compute_excess_area(poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 0.0
	var total_area := _polygon_area(poly)
	if _green_circle_poly.size() < 3:
		return total_area
	var inside_polys := Geometry2D.intersect_polygons(poly, _green_circle_poly)
	var inside_area := 0.0
	for p in inside_polys:
		inside_area += _polygon_area(p)
	return maxf(0.0, total_area - inside_area)

func _compute_trimmed_ratio() -> float:
	if _initial_excess_area <= 0.001:
		return 0.0
	if _is_all_trimmed():
		return 1.0
	var denom := maxf(_initial_excess_area - win_excess_area_threshold, 1.0)
	var rem_excess := maxf(0.0, _compute_excess_area(_ice_poly) - win_excess_area_threshold)
	return clampf(1.0 - (rem_excess / denom), 0.0, 0.99)

static func _polygon_area(poly: PackedVector2Array) -> float:
	var n := poly.size()
	if n < 3:
		return 0.0
	var acc := 0.0
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		acc += a.x * b.y - b.x * a.y
	return absf(acc) * 0.5

static func _signed_side(a: Vector2, b: Vector2, pt: Vector2) -> float:
	return (b.x - a.x) * (pt.y - a.y) - (b.y - a.y) * (pt.x - a.x)

static func _intersect_lines(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> Vector2:
	var da := a2 - a1
	var db := b2 - b1
	var denom := da.x * db.y - da.y * db.x
	if absf(denom) < 0.00001:
		return (b1 + b2) * 0.5
	var t := ((b1.x - a1.x) * db.y - (b1.y - a1.y) * db.x) / denom
	return a1 + da * t

static func _split_convex_polygon(poly: PackedVector2Array, line_a: Vector2, line_b: Vector2) -> Dictionary:
	var pos := PackedVector2Array()
	var neg := PackedVector2Array()
	var n := poly.size()
	if n < 3:
		return {"pos": pos, "neg": neg}

	for i in n:
		var curr := poly[i]
		var nxt := poly[(i + 1) % n]
		var d_curr := _signed_side(line_a, line_b, curr)
		var d_nxt := _signed_side(line_a, line_b, nxt)

		if d_curr >= -POLY_EPS:
			pos.append(curr)
		if d_curr <= POLY_EPS:
			neg.append(curr)

		if (d_curr > POLY_EPS and d_nxt < -POLY_EPS) or (d_curr < -POLY_EPS and d_nxt > POLY_EPS):
			var hit := _intersect_lines(line_a, line_b, curr, nxt)
			pos.append(hit)
			neg.append(hit)

	return {
		"pos": _dedupe_poly(pos),
		"neg": _dedupe_poly(neg),
	}

static func _dedupe_poly(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for pt in poly:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(pt) > 0.25:
			out.append(pt)
	if out.size() >= 2 and out[0].distance_squared_to(out[out.size() - 1]) <= 0.25:
		out.remove_at(out.size() - 1)
	return out

static func _clip_segment_to_convex_poly(p0: Vector2, p1: Vector2, poly: PackedVector2Array) -> PackedVector2Array:
	var n := poly.size()
	if n < 3:
		return PackedVector2Array()
	var area_sign := 0.0
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		area_sign += a.x * b.y - b.x * a.y
	if absf(area_sign) < 0.001:
		return PackedVector2Array()

	var t_enter := 0.0
	var t_exit := 1.0
	var d := p1 - p0
	var inside_sign := 1.0 if area_sign > 0.0 else -1.0

	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var edge := b - a
		var num := (edge.x * (p0.y - a.y) - edge.y * (p0.x - a.x)) * inside_sign
		var den := (edge.x * d.y - edge.y * d.x) * inside_sign
		if absf(den) < 0.00001:
			if num < -POLY_EPS:
				return PackedVector2Array()
		elif den > 0.0:
			t_enter = maxf(t_enter, -num / den)
		else:
			t_exit = minf(t_exit, -num / den)
		if t_enter > t_exit + 0.0001:
			return PackedVector2Array()

	var hit0 := p0 + d * clampf(t_enter, 0.0, 1.0)
	var hit1 := p0 + d * clampf(t_exit, 0.0, 1.0)
	if hit0.distance_to(hit1) < 0.25 and not Geometry2D.is_point_in_polygon((p0 + p1) * 0.5, poly):
		return PackedVector2Array()
	return PackedVector2Array([hit0, hit1])