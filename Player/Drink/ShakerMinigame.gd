extends CanvasLayer
class_name ShakerMinigame

signal finished(success: bool)
signal pumped
signal mistake

static var active : bool = false

const DEFAULT_ICON := "res://Assets/Items/shaker.png"
const FONT_PATH := "res://Assets/Font/fs-a-pixel-away.otf"

@export_group("Controls")
@export var key_a : Key = KEY_Q
@export var key_b : Key = KEY_E

@export_group("Difficulty")

#buncha variables so we can tweak the settings, take care of these if you see 'em
@export_range(0.01, 0.5, 0.01) var pump_amount : float = 0.05 # How much of the bar's gonna fill up per press
@export_range(0.0,2.0, 0.01) var deflate_rate : float = 0.28 # How much the shaker bar's gonna drain per second
@export_range(0.0,1.0,0.01) var goal_center : float = 0.5 # setting where the goal zone is gonna be centered 0 -> 1 is bottom -> top
@export_range(0.05, 0.6, 0.01) var goal_size : float = 0.20 # setting the size of the goal zone as a fraction of the bar
@export_range(0.5, 15.0, 0.1) var hold_time : float = 3.0 # Seconds the icon has to stay in teh goal zone to clear
@export_range(0.0, 2.0, 0.05) var drain_multi : float = 0.5 # How fast progress drains outside the goal zone, relative to how fast it normally fills
@export_range(0.0, 60.0, 0.5) var time_limit : float = 20.0 # Seconds before the attempt is a fail BTW 0 = no time limit
@export_range(0.0, 1.0, 0.01) var start_fill : float = 0.05 # Where the bar is gonna start (from 0,1)

@export_group("Look")
@export var bar_size : Vector2 = Vector2(64,380)
@export var screen_position : Vector2 = Vector2(0.78,0.5) # Bar position as a fraction of the screen
@export var icon_texture : Texture2D # for shaker sprite
@export var icon_size : Vector2 = Vector2(56,56)
#@export var pump_key : Key = KEY_SPACE
@export var keycap_size : float = 56.0

var _fill : float = 0.0 # bar level that is drawn (0..1)
var _target_fill : float = 0.0 # level that the bar is headed to
var _progress : float = 0.0
var _elapsed : float = 0.0
var _done : bool = false

var _expected_idx : int = -1
var _caps : Array[Control] = []
var _cap_pop : Array[float] = [0.0, 0.0]
var _cap_wrong : Array[float] = [0.0, 0.0] # setting it to flash red with a key gets pressed at the wrong time

var _ui : Control
var _dim : ColorRect
var _track : ColorRect
var _goal : ColorRect
var _icon : Control
var _progress_fill : ColorRect
var _hint : Label
var _result : Label

func _ready() -> void:
	layer = 50
	active = true
	_fill = start_fill
	_target_fill = start_fill
	_build_ui()
	_refresh(false)

func _exit_tree() -> void:
	active = false
	if not _done:
		_done = true
		finished.emit(false)

func _build_ui() -> void:
	var screen := get_viewport().get_visible_rect().size
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	_ui = Control.new()
	_ui.size = screen
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_ui)

	_dim = ColorRect.new()
	_dim.color = Color(0,0,0, 0.35)
	_dim.size = screen
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_dim)

	var gap := 12.0
	var meter_w := 16.0
	var pad := 12.0
	var track_pos := screen * screen_position - bar_size * 0.5

	var frame := ColorRect.new()
	frame.color = Color(0.06,0.04,0.08,0.95)
	frame.position = track_pos - Vector2(pad, pad)
	frame.size = Vector2(bar_size.x + gap + meter_w + pad * 2.0, bar_size.y + pad * 2.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(frame)

	_track = ColorRect.new()
	_track.color = Color(0.2, 0.12, 0.08, 1.0)
	_track.position = track_pos
	_track.size = bar_size
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_track)

	var goal_top := _fill_to_y(clampf(goal_center + goal_size * 0.5, 0.0, 1.0))
	var goal_bottom := _fill_to_y(clampf(goal_center - goal_size * 0.5, 0.0, 1.0))
	_goal = ColorRect.new()
	_goal.color = Color(0.3, 0.85, 0.35, 0.55)
	_goal.position = Vector2(0.0, goal_top)
	_goal.size = Vector2(bar_size.x, goal_bottom - goal_top)
	_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_goal)

	var tex: Texture2D = icon_texture
	if tex == null and ResourceLoader.exists(DEFAULT_ICON):
		tex = load(DEFAULT_ICON)
	if tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon = tex_rect
	else:
		var block := ColorRect.new()
		block.color = Color(0.85,0.85,0.95)
		_icon = block
	_icon.size = icon_size
	_icon.pivot_offset = icon_size * 0.5
	_icon.position.x = (bar_size.x - icon_size.x) * 0.5
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_icon)

	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.2, 0.12, 0.08, 1.0)
	meter_bg.position = track_pos + Vector2(bar_size.x + gap, 0.0)
	meter_bg.size = Vector2(meter_w, bar_size.y)
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(meter_bg)

	#meter_bg.clip_contents = true # added this so nothing happens outside of the bar
	#_progress_fill = ColorRect.new()
	#_progress_fill.color = Color(1.0, 0.82, 0.2, 1.0)
	#_progress_fill.size = Vector2(meter_w, bar_size.y)
	#_progress_fill.position = Vector2.ZERO
	#_progress_fill.pivot_offset = Vector2(0.0, bar_size.y)
	#_progress_fill.scale = Vector2(1.0,0.0)
	#_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#meter_bg.add_child(_progress_fill)

	meter_bg.clip_contents = true

	_progress_fill = ColorRect.new()
	_progress_fill.color = Color(1.0, 0.82, 0.2, 1.0)
	_progress_fill.size = Vector2(meter_w, 0.0)
	_progress_fill.position = Vector2(0.0, bar_size.y)
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_bg.add_child(_progress_fill)

	var title := _make_label("SHAKE IT!", 34, font)
	title.position = Vector2(frame.position.x - 60.0, frame.position.y - 52.0)
	title.size = Vector2(frame.size.x + 120, 60.0)
	_ui.add_child(title)

	var cap_gap := 48.0
	var caps_width := keycap_size * 2.0 + cap_gap
	var caps_x := frame.position.x + frame.size.x * 0.5 - caps_width  * 0.5
	var caps_y := frame.position.y + frame.size.y + 10

	var cap_a := _make_keycap(OS.get_keycode_string(key_a), font)
	cap_a.position = Vector2(caps_x, caps_y)
	_ui.add_child(cap_a)
	var cap_b := _make_keycap(OS.get_keycode_string(key_b), font)
	cap_b.position = Vector2(caps_x + keycap_size + cap_gap, caps_y)
	_ui.add_child(cap_b)
	_caps = [cap_a, cap_b]

	var arrows := _make_label("<<--->>", 13, font)
	arrows.position = Vector2(caps_x + keycap_size, caps_y)
	arrows.size = Vector2(cap_gap, keycap_size)
	arrows.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui.add_child(arrows)

	_hint  = _make_label("", 22, font)
	_hint.position = Vector2(frame.position.x - 60.0, frame.position.y + frame.size.y + 8.0)
	_hint.size = Vector2(screen.x, 80.0)
	_ui.add_child(_hint)

	_result = _make_label("", 56, font)
	_result.position = Vector2(0.0, screen.y * 0.5 - 40.0)
	_result.size = Vector2(screen.x, 80.0)
	_ui.add_child(_result)


func _make_label(text: String, font_size:int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	if font:
		label.add_theme_font_override("font", font)
	return label

func _make_keycap(text: String, font: Font) -> Control:
	var cap := Control.new()
	cap.size = Vector2(keycap_size, keycap_size)
	cap.pivot_offset = cap.size * 0.5
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var border := ColorRect.new()
	border.color = Color(0.05, 0.04, 0.07)
	border.size = cap.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(border)

	var face := ColorRect.new()
	face.color = Color(0.85, 0.82, 0.75)
	face.position = Vector2(4.0, 4.0)
	face.size = cap.size - Vector2(8.0, 8.0)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(face)

	var label := _make_label(text, int(keycap_size * 0.6), font)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_color", Color(0.1,0.08,0.12))
	label.size = cap.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(label)
	return cap

func _fill_to_y(level: float) -> float:
	var half := icon_size. y * 0.5
	return lerpf(bar_size.y - half, half, clampf(level, 0.0, 1.0))

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta

	_target_fill = maxf(0.0, _target_fill - deflate_rate * delta) # the bar drains on its own, the drawn level eases towards the value it's headed
	_fill = lerpf(_fill, _target_fill, 1.0 - exp(-18.0 * delta))

	var in_zone := absf(_fill - goal_center) <= goal_size * 0.5
	if in_zone:
		_progress += delta / hold_time
	else:
		_progress -= delta / hold_time * drain_multi
	_progress = clampf(_progress, 0.0, 1.0)

	_refresh(in_zone)

	if _progress >= 1.0:
		_finish(true, "MIXED!", Color(0.4,1.0,0.5))
	elif time_limit > 0.0 and _elapsed >= time_limit:
		_finish(false, "TOO SLOW", Color(1.0, 0.4, 0.4))

func _refresh(in_zone: bool) -> void:
	_icon.position.y = _fill_to_y(_fill) - icon_size.y * 0.5
	_icon.modulate = Color(0.7, 1.0, 0.7) if in_zone else Color.WHITE
	_progress_fill.size.y = bar_size.y * _progress
	_progress_fill.position.y = bar_size.y - _progress_fill.size.y

	for i in _caps.size():
		var due := _expected_idx == -1 or _expected_idx == i
		var pulse := 0.06 * sin(_elapsed * 9.0) if due else 0.0
		_caps[i].scale = Vector2.ONE * (1.0 + pulse + 0.3 * _cap_pop[i])
		var base := Color(1.0, 0.95, 0.5) if due else Color(0.55, 0.55, 0.6)
		_caps[i].modulate = base.lerp(Color(1.0, 0.3, 0.3), _cap_wrong[i])

	var text := "Alternate %s and %s" % [OS.get_keycode_string(key_a), OS.get_keycode_string(key_b)]
	if time_limit > 0.0:
		text += "   %ds" % ceili(maxf(time_limit - _elapsed, 0.0))
	_hint.text = text + "\nRight-click to cancel"

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey:
		var idx := _key_index(event)
		if idx != -1:
			if event.pressed and not event.echo:
				_pump()
			get_viewport().set_input_as_handled()
			return
		# No stool / camera movement while shaking.
		for action in ["Up", "Down", "Left", "Right"]:
			if InputMap.has_action(action) and event.is_action(action):
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_finish(false)
		get_viewport().set_input_as_handled()

func _key_index(event: InputEventKey) -> int:
	if event.keycode == key_a or event.physical_keycode == key_a:
		return 0
	if event.keycode == key_b or event.physical_keycode == key_b:
		return 1
	return -1

func _try_pump(idx: int) -> void:
	if _expected_idx != -1 and idx != _expected_idx:
		_cap_wrong[idx] = 1.0
		mistake.emit()
		return
	_expected_idx = 1 - idx
	_cap_pop[idx] = 1.0
	_pump()

func _pump() -> void:
	_target_fill = minf(1.0, _target_fill + pump_amount)
	pumped.emit()
	var tween := create_tween()
	_icon.scale = Vector2(1.3,1.3)
	tween.tween_property(_icon, "scale", Vector2.ONE, 0.12)

func _finish(success: bool, message: String = "", color: Color = Color.WHITE) -> void:
	if _done:
		return
	_done = true
	active = false
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.text = message
	_result.add_theme_color_override("font_color", color)
	finished.emit(success)
	if message != "":
		await get_tree().create_timer(0.7, false).timeout # Pausable timer so it behaves with the pause menu.
	queue_free()
