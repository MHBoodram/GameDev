extends Control

signal option_selected(option: WheelOption)

@export var outer_radius := 200.0
@export var inner_radius := 60.0
@export var line_width := 3.0
@export var bg_color := Color(0.1, 0.1, 0.1, 0.8)
@export var line_color := Color.WHITE
@export var highlight_color := Color(0.4, 0.4, 0.4, 0.9)
@export var options: Array[WheelOption] = []

var selection := -1  # -1 = nothing highlighted

func _ready():
	hide()

func _input(event):
	if event.is_action_pressed("Right_click"):
		position = get_viewport().get_mouse_position()
		show()
	elif event.is_action_released("Right_click") and visible:
		hide()
		if selection != -1:
			print("Selected: ", options[selection].id, " (index ", selection, ")")
			if(GameState.player):
				GameState.player._change_tool(options[selection].id)
			option_selected.emit(options[selection])

func _process(_delta):
	#https://www.youtube.com/watch?v=TtziEJZtWXc - Got code from this goat
	if not visible or options.is_empty():
		return
	var m := get_local_mouse_position()
	var dist := m.length()
	if dist < inner_radius or dist > outer_radius:
		selection = -1
	else:
		var angle := fposmod(m.angle() + PI / 2.0, TAU)  # 0 at top, clockwise
		selection = int(angle / (TAU / options.size()))
	queue_redraw()

func _draw():
	if options.is_empty():
		return
	var step := TAU / options.size()

	# Background and rings
	draw_circle(Vector2.ZERO, outer_radius, bg_color)
	draw_arc(Vector2.ZERO, outer_radius, 0, TAU, 64, line_color, line_width, true)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 64, line_color, line_width, true)

	# Highlighted cell
	if selection != -1:
		var a0 := selection * step - PI / 2.0
		var pts := PackedVector2Array()
		for i in 21:
			pts.append(Vector2.from_angle(a0 + step * i / 20.0) * outer_radius)
		for i in 21:
			pts.append(Vector2.from_angle(a0 + step * (20 - i) / 20.0) * inner_radius)
		draw_colored_polygon(pts, highlight_color)

	# Divider lines and icons
	for i in options.size():
		var a := i * step - PI / 2.0
		var dir := Vector2.from_angle(a)
		draw_line(dir * inner_radius, dir * outer_radius, line_color, line_width, true)

		var mid := Vector2.from_angle(a + step / 2.0) * (inner_radius + outer_radius) / 2.0
		var opt := options[i]
		if opt.icon:
			draw_texture(opt.icon, mid - opt.icon.get_size() / 2.0)

	# Selected label in the center
	if selection != -1:
		var font := get_theme_default_font()
		var text := options[selection].label
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		draw_string(font, Vector2(-text_size.x / 2.0, 5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
