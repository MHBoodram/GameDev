@tool
class_name DottedLine2D
extends Control

@export var start_point: Vector2 = Vector2.ZERO:
	set(value):
		start_point = value
		queue_redraw()

@export var end_point: Vector2 = Vector2(100.0, 0.0):
	set(value):
		end_point = value
		queue_redraw()

@export var dash_length: float = 12.0:
	set(value):
		dash_length = maxf(1.0, value)
		queue_redraw()

@export var gap_length: float = 8.0:
	set(value):
		gap_length = maxf(1.0, value)
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

var _phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not Engine.is_editor_hint() and not is_zero_approx(scroll_speed):
		_phase += scroll_speed * delta
		queue_redraw()

func set_points(p_start: Vector2, p_end: Vector2) -> void:
	if start_point.is_equal_approx(p_start) and end_point.is_equal_approx(p_end):
		return
	start_point = p_start
	end_point = p_end
	queue_redraw()

func set_horizontal(y_pos: float, min_x: float, max_x: float) -> void:
	set_points(Vector2(min_x, y_pos), Vector2(max_x, y_pos))

func _draw() -> void:
	var delta_vec := end_point - start_point
	var total_len := delta_vec.length()
	if total_len <= 0.5:
		return

	var dir := delta_vec / total_len
	var pattern := maxf(dash_length + gap_length, 2.0)
	var ranges: Array[Vector2] = []

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