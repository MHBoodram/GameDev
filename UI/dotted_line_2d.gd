@tool
class_name DottedLine2D
extends Control

const DEFAULT_TOLERANCE_HALF_WIDTH: float = 24.0
const DEFAULT_TOLERANCE_COLOR: Color = Color(0.20, 0.90, 0.35, 0.28)
const DEFAULT_TOLERANCE_BORDER_COLOR: Color = Color(0.28, 1.0, 0.42, 0.72)
const DEFAULT_TOLERANCE_BORDER_WIDTH: float = 2.0
const DEFAULT_DANGER_COLOR: Color = Color(0.95, 0.20, 0.20, 0.32)

@export var start_point: Vector2 = Vector2.ZERO:
	set(value):
		start_point = value
		queue_redraw()

@export var end_point: Vector2 = Vector2(100.0, 0.0):
	set(value):
		end_point = value
		queue_redraw()

@export var dotted: bool = true:
	set(value):
		dotted = value
		queue_redraw()

@export var dash_length: float = 12.0:
	set(value):
		dash_length = maxf(1.0, value)
		queue_redraw()

@export var gap_length: float = 8.0:
	set(value):
		gap_length = maxf(0.0, value)
		queue_redraw()

@export var line_width: float = 4.0:
	set(value):
		line_width = maxf(1.0, value)
		queue_redraw()

@export var outline_width: float = 2.0:
	set(value):
		outline_width = maxf(0.0, value)
		queue_redraw()

@export var line_color: Color = Color(1.0, 0.98, 0.88, 0.95):
	set(value):
		line_color = value
		queue_redraw()

@export var outline_color: Color = Color(0.06, 0.05, 0.08, 0.85):
	set(value):
		outline_color = value
		queue_redraw()

@export var centered_pattern: bool = true:
	set(value):
		centered_pattern = value
		queue_redraw()

@export var scroll_speed: float = 0.0

@export_group("Circle Mode")
@export var circle_mode: bool = false:
	set(value):
		circle_mode = value
		queue_redraw()

@export var circle_center: Vector2 = Vector2.ZERO:
	set(value):
		circle_center = value
		queue_redraw()

@export var circle_radius: float = 80.0:
	set(value):
		circle_radius = maxf(0.0, value)
		queue_redraw()

@export var circle_segments: int = 72:
	set(value):
		circle_segments = maxi(16, value)
		queue_redraw()

@export var show_inner_danger_zone: bool = false:
	set(value):
		show_inner_danger_zone = value
		queue_redraw()

@export var inner_danger_color: Color = DEFAULT_DANGER_COLOR:
	set(value):
		inner_danger_color = value
		queue_redraw()

@export var tolerance_outer_only: bool = false:
	set(value):
		tolerance_outer_only = value
		queue_redraw()

@export_group("Tolerance Zone")
@export var show_tolerance_zone: bool = false:
	set(value):
		show_tolerance_zone = value
		queue_redraw()

@export var tolerance_half_width: float = DEFAULT_TOLERANCE_HALF_WIDTH:
	set(value):
		tolerance_half_width = maxf(0.0, value)
		queue_redraw()

@export var tolerance_color: Color = DEFAULT_TOLERANCE_COLOR:
	set(value):
		tolerance_color = value
		queue_redraw()

@export var tolerance_border_color: Color = DEFAULT_TOLERANCE_BORDER_COLOR:
	set(value):
		tolerance_border_color = value
		queue_redraw()

@export var tolerance_border_width: float = DEFAULT_TOLERANCE_BORDER_WIDTH:
	set(value):
		tolerance_border_width = maxf(0.0, value)
		queue_redraw()

@export var tolerance_zone_length: float = -1.0:
	set(value):
		tolerance_zone_length = value
		queue_redraw()

var _phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not Engine.is_editor_hint() and dotted and gap_length > 0.001 and not is_zero_approx(scroll_speed):
		_phase += scroll_speed * delta
		queue_redraw()

func set_points(p_start: Vector2, p_end: Vector2) -> void:
	if not circle_mode and start_point.is_equal_approx(p_start) and end_point.is_equal_approx(p_end):
		return
	circle_mode = false
	start_point = p_start
	end_point = p_end
	queue_redraw()

func set_circle(p_center: Vector2, p_radius: float, p_segments: int = 72) -> void:
	circle_mode = true
	circle_center = p_center
	circle_radius = maxf(0.0, p_radius)
	circle_segments = maxi(16, p_segments)
	queue_redraw()

func set_inner_danger_zone(enabled: bool, color: Color = DEFAULT_DANGER_COLOR) -> void:
	show_inner_danger_zone = enabled
	inner_danger_color = color
	queue_redraw()

func set_horizontal(y_pos: float, min_x: float, max_x: float) -> void:
	set_points(Vector2(min_x, y_pos), Vector2(max_x, y_pos))

func set_vertical(x_pos: float, min_y: float, max_y: float) -> void:
	set_points(Vector2(x_pos, min_y), Vector2(x_pos, max_y))

func set_from_center(center: Vector2, angle_rad: float, length: float) -> void:
	var half_vec := Vector2.from_angle(angle_rad) * (maxf(1.0, length) * 0.5)
	set_points(center - half_vec, center + half_vec)

func set_colors(p_line_color: Color, p_outline_color: Color = outline_color) -> void:
	if line_color == p_line_color and outline_color == p_outline_color:
		return
	line_color = p_line_color
	outline_color = p_outline_color
	queue_redraw()

func set_dash_metrics(p_dash_length: float, p_gap_length: float, p_line_width: float, p_outline_width: float = -1.0) -> void:
	var next_dash := maxf(1.0, p_dash_length)
	var next_gap := maxf(0.0, p_gap_length)
	var next_thick := maxf(1.0, p_line_width)
	var next_outline := outline_width if p_outline_width < 0.0 else maxf(0.0, p_outline_width)
	if (
		is_equal_approx(dash_length, next_dash)
		and is_equal_approx(gap_length, next_gap)
		and is_equal_approx(line_width, next_thick)
		and is_equal_approx(outline_width, next_outline)
	):
		return
	dash_length = next_dash
	gap_length = next_gap
	line_width = next_thick
	outline_width = next_outline
	queue_redraw()

func set_tolerance_zone(
	enabled: bool,
	half_width: float = DEFAULT_TOLERANCE_HALF_WIDTH,
	fill_color: Color = DEFAULT_TOLERANCE_COLOR,
	border_color: Color = DEFAULT_TOLERANCE_BORDER_COLOR,
	border_width: float = DEFAULT_TOLERANCE_BORDER_WIDTH,
	length_override: float = -1.0,
	outer_only: bool = false
) -> void:
	show_tolerance_zone = enabled
	tolerance_half_width = maxf(0.0, half_width)
	tolerance_color = fill_color
	tolerance_border_color = border_color
	tolerance_border_width = maxf(0.0, border_width)
	tolerance_zone_length = length_override
	tolerance_outer_only = outer_only
	queue_redraw()

func get_line_midpoint() -> Vector2:
	return (start_point + end_point) * 0.5

func get_line_direction() -> Vector2:
	var delta_vec := end_point - start_point
	var len_val := delta_vec.length()
	return (delta_vec / len_val) if len_val > 0.0001 else Vector2.RIGHT

func get_signed_perpendicular_distance(point: Vector2) -> float:
	var dir := get_line_direction()
	var perp := Vector2(-dir.y, dir.x)
	return (point - get_line_midpoint()).dot(perp)

func get_along_distance(point: Vector2) -> float:
	var dir := get_line_direction()
	return (point - get_line_midpoint()).dot(dir)

func is_point_in_tolerance(point: Vector2, check_span: bool = false) -> bool:
	if circle_mode:
		var d := point.distance_to(circle_center)
		var min_r := circle_radius if tolerance_outer_only else maxf(0.0, circle_radius - tolerance_half_width)
		var max_r := circle_radius + tolerance_half_width
		return d >= min_r and d <= max_r
	if absf(get_signed_perpendicular_distance(point)) > tolerance_half_width:
		return false
	if check_span:
		var band_len := start_point.distance_to(end_point) if tolerance_zone_length < 0.0 else maxf(1.0, tolerance_zone_length)
		if absf(get_along_distance(point)) > band_len * 0.5:
			return false
	return true

func evaluate_straight_cut(cut_start: Vector2, cut_end: Vector2, is_inside_shape: Callable, sample_step_px: float = 2.0) -> Dictionary:
	var delta_vec := end_point - start_point
	var total_len := delta_vec.length()
	if total_len <= 0.5 or not is_inside_shape.is_valid():
		return {"status": "missed", "accuracy": 0.0, "avg_offset": 0.0, "max_offset": 0.0}

	var dir := delta_vec / total_len
	var perp := Vector2(-dir.y, dir.x)
	var mid := (start_point + end_point) * 0.5

	var cut_len := cut_start.distance_to(cut_end)
	var steps := maxi(16, ceili(cut_len / maxf(sample_step_px, 0.5)))
	var start_inside := bool(is_inside_shape.call(cut_start))
	var end_inside := bool(is_inside_shape.call(cut_end))

	var hit_shape := false
	var outside_tolerance := false
	var min_u := INF
	var max_u := -INF
	var max_abs_v := 0.0
	var sum_abs_v := 0.0
	var in_shape_count := 0

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var pt := cut_start.lerp(cut_end, t)
		if bool(is_inside_shape.call(pt)):
			hit_shape = true
			var rel := pt - mid
			var u := rel.dot(dir)
			var abs_v := absf(rel.dot(perp))
			min_u = minf(min_u, u)
			max_u = maxf(max_u, u)
			max_abs_v = maxf(max_abs_v, abs_v)
			sum_abs_v += abs_v
			in_shape_count += 1
			if abs_v > tolerance_half_width:
				outside_tolerance = true

	if not hit_shape:
		return {
			"status": "missed",
			"accuracy": 0.0,
			"avg_offset": 0.0,
			"max_offset": 0.0,
		}

	var avg_abs_v := sum_abs_v / float(maxi(in_shape_count, 1))
	if outside_tolerance:
		return {
			"status": "outside_zone",
			"accuracy": 0.0,
			"avg_offset": avg_abs_v,
			"max_offset": max_abs_v,
		}

	if start_inside or end_inside or not (min_u <= 0.0 and max_u >= 0.0):
		return {
			"status": "incomplete",
			"accuracy": clampf(1.0 - (avg_abs_v / maxf(tolerance_half_width, 1.0)), 0.0, 1.0),
			"avg_offset": avg_abs_v,
			"max_offset": max_abs_v,
		}

	var accuracy := clampf(1.0 - (avg_abs_v / maxf(tolerance_half_width, 1.0)), 0.0, 1.0)
	return {
		"status": "success",
		"accuracy": accuracy,
		"avg_offset": avg_abs_v,
		"max_offset": max_abs_v,
	}

static func evaluate_multi_cuts(guides: Array[DottedLine2D], cut_start: Vector2, cut_end: Vector2, is_inside_shape: Callable, sample_step_px: float = 2.0) -> Dictionary:
	var best_success_idx := -1
	var best_success_eval := {}
	var best_accuracy := -1.0
	var best_incomplete_idx := -1
	var best_incomplete_eval := {}
	var any_hit_shape := false

	for i in guides.size():
		var g := guides[i]
		if not is_instance_valid(g) or not g.visible:
			continue
		var res := g.evaluate_straight_cut(cut_start, cut_end, is_inside_shape, sample_step_px)
		var st := str(res.get("status", "missed"))
		if st != "missed":
			any_hit_shape = true
		if st == "success":
			var acc := float(res.get("accuracy", 0.0))
			if acc > best_accuracy:
				best_accuracy = acc
				best_success_idx = i
				best_success_eval = res
		elif st == "incomplete" and best_incomplete_idx == -1:
			best_incomplete_idx = i
			best_incomplete_eval = res

	if best_success_idx != -1:
		return {
			"status": "success",
			"guide_index": best_success_idx,
			"guide": guides[best_success_idx],
			"accuracy": best_accuracy,
			"avg_offset": best_success_eval.get("avg_offset", 0.0),
			"max_offset": best_success_eval.get("max_offset", 0.0),
		}

	if best_incomplete_idx != -1:
		return {
			"status": "incomplete",
			"guide_index": best_incomplete_idx,
			"guide": guides[best_incomplete_idx],
			"accuracy": best_incomplete_eval.get("accuracy", 0.0),
			"avg_offset": best_incomplete_eval.get("avg_offset", 0.0),
			"max_offset": best_incomplete_eval.get("max_offset", 0.0),
		}

	if any_hit_shape:
		return {
			"status": "outside_zone",
			"guide_index": -1,
			"guide": null,
			"accuracy": 0.0,
			"avg_offset": 0.0,
			"max_offset": 0.0,
		}

	return {
		"status": "missed",
		"guide_index": -1,
		"guide": null,
		"accuracy": 0.0,
		"avg_offset": 0.0,
		"max_offset": 0.0,
	}

func _draw() -> void:
	if circle_mode:
		_draw_circle_mode()
		return

	var delta_vec := end_point - start_point
	var total_len := delta_vec.length()
	if total_len <= 0.5:
		return

	var dir := delta_vec / total_len
	var perp := Vector2(-dir.y, dir.x)

	if show_tolerance_zone and tolerance_half_width > 0.0:
		var mid := (start_point + end_point) * 0.5
		var band_len := total_len if tolerance_zone_length < 0.0 else maxf(1.0, tolerance_zone_length)
		var half_len := band_len * 0.5
		var b0 := mid - dir * half_len
		var b1 := mid + dir * half_len
		var off := perp * tolerance_half_width
		var poly := PackedVector2Array([b0 - off, b1 - off, b1 + off, b0 + off])
		draw_colored_polygon(poly, tolerance_color)
		if tolerance_border_width > 0.0 and tolerance_border_color.a > 0.001:
			draw_line(b0 - off, b1 - off, tolerance_border_color, tolerance_border_width, false)
			draw_line(b0 + off, b1 + off, tolerance_border_color, tolerance_border_width, false)

	var ranges: Array[Vector2] = []
	if not dotted or gap_length <= 0.001:
		ranges.append(Vector2(0.0, total_len))
	else:
		var pattern := maxf(dash_length + gap_length, 2.0)
		if centered_pattern and is_zero_approx(scroll_speed):
			var num_dashes := maxi(1, int(floor((total_len + gap_length + 0.01) / pattern)))
			if num_dashes == 1 and dash_length >= total_len:
				ranges.append(Vector2(0.0, total_len))
			else:
				var used_len := float(num_dashes) * dash_length + float(num_dashes - 1) * gap_length
				var cursor := maxf(0.0, (total_len - used_len) * 0.5)
				for _i in num_dashes:
					var d0 := cursor
					var d1 := minf(total_len, d0 + dash_length)
					if d1 - d0 > 0.5:
						ranges.append(Vector2(d0, d1))
					cursor += pattern
		else:
			var pos := fposmod(_phase, pattern) - pattern
			while pos < total_len:
				var d0 := maxf(0.0, pos)
				var d1 := minf(total_len, pos + dash_length)
				if d1 - d0 > 0.5:
					ranges.append(Vector2(d0, d1))
				pos += pattern

	var draw_outline := outline_width > 0.0 and outline_color.a > 0.001
	if draw_outline:
		var full_out_w := line_width + outline_width * 2.0
		for seg in ranges:
			var od0 := maxf(0.0, seg.x - outline_width)
			var od1 := minf(total_len, seg.y + outline_width)
			draw_line(start_point + dir * od0, start_point + dir * od1, outline_color, full_out_w, false)

	for seg in ranges:
		draw_line(start_point + dir * seg.x, start_point + dir * seg.y, line_color, line_width, false)

func _draw_circle_mode() -> void:
	if circle_radius <= 0.5:
		return

	var segs := maxi(16, circle_segments)

	if show_inner_danger_zone and inner_danger_color.a > 0.001:
		draw_circle(circle_center, circle_radius, inner_danger_color)

	if show_tolerance_zone and tolerance_half_width > 0.0:
		var inner_r := circle_radius if tolerance_outer_only else maxf(0.0, circle_radius - tolerance_half_width)
		var outer_r := circle_radius + tolerance_half_width
		if tolerance_color.a > 0.001:
			for i in segs:
				var a0 := float(i) / float(segs) * TAU
				var a1 := float(i + 1) / float(segs) * TAU
				var d0 := Vector2.from_angle(a0)
				var d1 := Vector2.from_angle(a1)
				var quad := PackedVector2Array([
					circle_center + d0 * inner_r,
					circle_center + d0 * outer_r,
					circle_center + d1 * outer_r,
					circle_center + d1 * inner_r,
				])
				draw_colored_polygon(quad, tolerance_color)
		if tolerance_border_width > 0.0 and tolerance_border_color.a > 0.001:
			draw_arc(circle_center, outer_r, 0.0, TAU, segs, tolerance_border_color, tolerance_border_width, true)
			if not tolerance_outer_only and inner_r > 0.5:
				draw_arc(circle_center, inner_r, 0.0, TAU, segs, tolerance_border_color, tolerance_border_width, true)

	var draw_outline := outline_width > 0.0 and outline_color.a > 0.001
	if not dotted or gap_length <= 0.001:
		if draw_outline:
			draw_arc(circle_center, circle_radius, 0.0, TAU, segs, outline_color, line_width + outline_width * 2.0, true)
		draw_arc(circle_center, circle_radius, 0.0, TAU, segs, line_color, line_width, true)
		return

	var circumference := TAU * circle_radius
	var pattern := maxf(dash_length + gap_length, 2.0)
	var dash_count := maxi(6, roundi(circumference / pattern))
	var step_ang := TAU / float(dash_count)
	var dash_frac := clampf(dash_length / pattern, 0.15, 0.90)
	var dash_ang := step_ang * dash_frac
	var phase_ang := _phase / maxf(circle_radius, 1.0)

	if draw_outline:
		var out_w := line_width + outline_width * 2.0
		var out_pad_ang := outline_width / maxf(circle_radius, 1.0)
		for i in dash_count:
			var a0 := phase_ang + float(i) * step_ang - out_pad_ang
			var a1 := phase_ang + float(i) * step_ang + dash_ang + out_pad_ang
			draw_arc(circle_center, circle_radius, a0, a1, 5, outline_color, out_w, true)

	for i in dash_count:
		var a0 := phase_ang + float(i) * step_ang
		var a1 := a0 + dash_ang
		draw_arc(circle_center, circle_radius, a0, a1, 5, line_color, line_width, true)