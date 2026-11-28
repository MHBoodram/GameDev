class_name MinigameTimer
extends Control

signal time_updated(time_left: float, duration: float)
signal timed_out()

const FONT_PATH := "res://Assets/Font/Merchant Copy.ttf"

@export var duration: float = 15.0
@export var autostart: bool = false
@export var bar_size: Vector2 = Vector2(22.0, 360.0)
@export var right_margin: float = 34.0
@export var vertical_center_ratio: float = 0.5
@export var frame_padding: float = 8.0
@export var show_seconds_label: bool = true
@export var fill_color_high: Color = Color(0.28, 0.90, 0.36, 1.0)
@export var fill_color_mid: Color = Color(1.0, 0.82, 0.20, 1.0)
@export var fill_color_low: Color = Color(0.95, 0.25, 0.25, 1.0)

var _time_left: float = 0.0
var _running: bool = false
var _paused: bool = false
var _last_viewport_size: Vector2 = Vector2.ZERO

var _frame: ColorRect
var _track: ColorRect
var _fill: ColorRect
var _title_label: Label
var _time_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	if autostart and duration > 0.0:
		start(duration)
	else:
		visible = false

func _build_ui() -> void:
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

	_frame = ColorRect.new()
	_frame.color = Color(0.06, 0.04, 0.08, 0.95)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_track = ColorRect.new()
	_track.color = Color(0.20, 0.12, 0.08, 1.0)
	_track.clip_contents = true
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_track)

	_fill = ColorRect.new()
	_fill.color = fill_color_high
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_fill)

	_title_label = _make_label("TIME", 24, font)
	add_child(_title_label)

	_time_label = _make_label("", 28, font)
	add_child(_time_label)

	_layout_ui()

func _make_label(text_val: String, font_size: int, font: Font) -> Label:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	if font:
		lbl.add_theme_font_override("font", font)
	return lbl

func _layout_ui() -> void:
	if not is_instance_valid(_frame):
		return
	var screen := get_viewport_rect().size
	if screen.x <= 1.0 or screen.y <= 1.0:
		screen = Vector2(1280.0, 720.0)
	_last_viewport_size = screen

	var frame_size := bar_size + Vector2(frame_padding * 2.0, frame_padding * 2.0)
	var frame_x := screen.x - right_margin - frame_size.x
	var frame_y := screen.y * vertical_center_ratio - frame_size.y * 0.5
	_frame.position = Vector2(frame_x, frame_y)
	_frame.size = frame_size

	_track.position = Vector2(frame_padding, frame_padding)
	_track.size = bar_size

	if is_instance_valid(_title_label):
		_title_label.position = Vector2(frame_x - 24.0, frame_y - 34.0)
		_title_label.size = Vector2(frame_size.x + 48.0, 32.0)

	if is_instance_valid(_time_label):
		_time_label.visible = show_seconds_label
		_time_label.position = Vector2(frame_x - 24.0, frame_y + frame_size.y + 4.0)
		_time_label.size = Vector2(frame_size.x + 48.0, 34.0)

	_refresh_visuals()

func start(p_duration: float = -1.0) -> void:
	if p_duration >= 0.0:
		duration = p_duration
	if duration <= 0.0:
		_time_left = 0.0
		_running = false
		_paused = false
		visible = false
		return
	_time_left = duration
	_running = true
	_paused = false
	visible = true
	_layout_ui()
	time_updated.emit(_time_left, duration)

func stop() -> void:
	_running = false
	_paused = false

func set_paused(paused_state: bool) -> void:
	_paused = paused_state

func get_time_left() -> float:
	return maxf(0.0, _time_left)

func get_progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(_time_left / duration, 0.0, 1.0)

func is_running() -> bool:
	return _running and not _paused

func _process(delta: float) -> void:
	if not visible:
		return
	var cur_vp := get_viewport_rect().size
	if cur_vp != _last_viewport_size:
		_layout_ui()

	if not _running or _paused or duration <= 0.0:
		return

	_time_left = maxf(0.0, _time_left - delta)
	_refresh_visuals()
	time_updated.emit(_time_left, duration)

	if _time_left <= 0.0:
		_running = false
		timed_out.emit()

func _refresh_visuals() -> void:
	if not is_instance_valid(_fill) or not is_instance_valid(_track):
		return
	var ratio := get_progress()
	var fill_h := bar_size.y * ratio
	_fill.size = Vector2(bar_size.x, fill_h)
	_fill.position = Vector2(0.0, bar_size.y - fill_h)

	if ratio > 0.5:
		_fill.color = fill_color_mid.lerp(fill_color_high, (ratio - 0.5) * 2.0)
	else:
		_fill.color = fill_color_low.lerp(fill_color_mid, ratio * 2.0)

	if is_instance_valid(_time_label) and show_seconds_label:
		_time_label.text = "%ds" % ceili(_time_left)
		_time_label.modulate = Color(1.0, 0.4, 0.4) if ratio <= 0.25 else Color.WHITE