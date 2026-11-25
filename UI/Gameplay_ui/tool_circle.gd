extends Control

signal option_selected(option: WheelOption)

@export var outer_radius := 200.0
@export var inner_radius := 60.0
@export var line_width := 3.0
@export var bg_color := Color(0.1, 0.1, 0.1, 0.8)
@export var line_color := Color.WHITE
@export var highlight_color := Color(0.4, 0.4, 0.4, 0.9)
@export var locked_bg_color := Color(0.03, 0.03, 0.03, 0.65)
@export var locked_icon_color := Color(0.45, 0.45, 0.45, 0.45)
@export var locked_text_color := Color(0.65, 0.65, 0.65, 0.9)
@export var options: Array[WheelOption] = []

var selection := -1  # -1 = nothing highlighted
var _hovered_index := -1
var _grayscale_cache: Dictionary = {}

func _ready():
	hide()

func _is_option_unlocked(opt: WheelOption) -> bool:
	if opt == null:
		return false
	var id_str := str(opt.id).to_lower().strip_edges()
	if id_str == "" or id_str == "hand":
		return true
	if PlayerStats and PlayerStats.has_method("is_tool_unlocked"):
		return PlayerStats.is_tool_unlocked(id_str)
	return true

func _get_grayscale_icon(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _grayscale_cache.has(tex):
		return _grayscale_cache[tex] as Texture2D
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		_grayscale_cache[tex] = tex
		return tex
	img = img.duplicate()
	if img.is_compressed() and img.decompress() != OK:
		_grayscale_cache[tex] = tex
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var gray := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			img.set_pixel(x, y, Color(gray, gray, gray, c.a))
	var gray_tex := ImageTexture.create_from_image(img)
	_grayscale_cache[tex] = gray_tex
	return gray_tex

func _input(event):
	if event.is_action_pressed("Right_click"):
		position = get_viewport().get_mouse_position()
		selection = -1
		_hovered_index = -1
		show()
		queue_redraw()
	elif event.is_action_released("Right_click") and visible:
		hide()
		if selection != -1 and selection < options.size() and _is_option_unlocked(options[selection]):
			print("Selected: ", options[selection].id, " (index ", selection, ")")
			if(GameState.player):
				GameState.player._change_tool(options[selection].id)
			option_selected.emit(options[selection])
		selection = -1
		_hovered_index = -1

func _process(_delta):
	#https://www.youtube.com/watch?v=TtziEJZtWXc - Got code from this goat
	if not visible or options.is_empty():
		return
	var m := get_local_mouse_position()
	var dist := m.length()
	if dist < inner_radius or dist > outer_radius:
		_hovered_index = -1
		selection = -1
	else:
		var angle := fposmod(m.angle() + PI / 2.0, TAU)  # 0 at top, clockwise
		var idx := clampi(int(angle / (TAU / options.size())), 0, options.size() - 1)
		_hovered_index = idx
		selection = idx if _is_option_unlocked(options[idx]) else -1
	queue_redraw()

func _draw_sector(index: int, step: float, color: Color) -> void:
	var a0 := index * step - PI / 2.0
	var pts := PackedVector2Array()
	for i in 21:
		pts.append(Vector2.from_angle(a0 + step * i / 20.0) * outer_radius)
	for i in 21:
		pts.append(Vector2.from_angle(a0 + step * (20 - i) / 20.0) * inner_radius)
	draw_colored_polygon(pts, color)

func _draw():
	if options.is_empty():
		return
	var step := TAU / options.size()

	# Background and rings
	draw_circle(Vector2.ZERO, outer_radius, bg_color)

	# Grayed-out cells for locked tools
	for i in options.size():
		if not _is_option_unlocked(options[i]):
			_draw_sector(i, step, locked_bg_color)

	# Highlighted cell
	if selection != -1 and selection < options.size() and _is_option_unlocked(options[selection]):
		_draw_sector(selection, step, highlight_color)

	draw_arc(Vector2.ZERO, outer_radius, 0, TAU, 64, line_color, line_width, true)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 64, line_color, line_width, true)

	# Divider lines and icons
	for i in options.size():
		var a := i * step - PI / 2.0
		var dir := Vector2.from_angle(a)
		draw_line(dir * inner_radius, dir * outer_radius, line_color, line_width, true)

		var mid := Vector2.from_angle(a + step / 2.0) * (inner_radius + outer_radius) / 2.0
		var opt := options[i]
		if opt and opt.icon:
			if _is_option_unlocked(opt):
				draw_texture(opt.icon, mid - opt.icon.get_size() / 2.0)
			else:
				var gray_tex := _get_grayscale_icon(opt.icon)
				draw_texture(gray_tex, mid - gray_tex.get_size() / 2.0, locked_icon_color)

	# Selected label in the center
	var font := get_theme_default_font()
	if selection != -1 and selection < options.size() and _is_option_unlocked(options[selection]):
		var text := options[selection].label
		if text != "":
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			draw_string(font, Vector2(-text_size.x / 2.0, 5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	elif _hovered_index != -1 and _hovered_index < options.size() and not _is_option_unlocked(options[_hovered_index]):
		var unlock_night := NightManager.get_tool_unlock_night(str(options[_hovered_index].id))
		var locked_text := ("Night %d" % unlock_night) if unlock_night > 1 else "Locked"
		var text_size := font.get_string_size(locked_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, Vector2(-text_size.x / 2.0, 5), locked_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, locked_text_color)