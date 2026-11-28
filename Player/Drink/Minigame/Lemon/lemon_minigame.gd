extends CanvasLayer
class_name LemonMinigame

signal finished(result: String)

const FONT_PATH := "res://Assets/Font/Merchant Copy.ttf"
const MIN_DRAG_DISTANCE: float = 10.0
const GUIDE_EXTRA_MARGIN: float = 72.0
const SLASH_SWEEP_DURATION: float = 0.09

@export var garnish_id: String = "lemon_whole"
@export var whole_time_limit: float = 10.0
@export var half_time_limit: float = 16.0
@export var tolerance_half_width: float = DottedLine2D.DEFAULT_TOLERANCE_HALF_WIDTH
@export var lemon_display_size: Vector2 = Vector2(260.0, 260.0)

var _is_half_stage: bool = false
var _required_cuts: int = 1
var _cuts_completed: int = 0
var _cuts_attempted: int = 0
var _wasted_cuts: int = 0
var _time_limit: float = 10.0
var _done: bool = false
var _is_dragging: bool = false

var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO

var _guide_center: Vector2 = Vector2.ZERO
var _guide_length: float = 340.0
var _active_guides: Array[DottedLine2D] = []

var _drawn_rect: Rect2 = Rect2()
var _lemon_image: Image = null

var _ui: Control
var _dim: ColorRect
var _lemon_rect_ctrl: TextureRect
var _guides_layer: Control
var _slash_layer: Control
var _title_label: Label
var _progress_label: Label
var _feedback_label: Label
var _hint_label: Label
var _result_label: Label
var _timer: MinigameTimer

var _lemon_base_pos: Vector2 = Vector2.ZERO
var _lemon_shake_tween: Tween
var _feedback_tween: Tween

func setup(p_garnish_id: String) -> void:
	garnish_id = GarnishDefinitions.normalize_id(p_garnish_id)
	_is_half_stage = (garnish_id == "lemon_half")
	_required_cuts = 4 if _is_half_stage else 1
	_time_limit = half_time_limit if _is_half_stage else whole_time_limit

func _ready() -> void:
	layer = 5
	setup(garnish_id)
	_build_ui()
	_compute_target_geometry()
	_spawn_cut_guides()
	SFXAudio.play_draw()
	_timer.start(_time_limit)

func _exit_tree() -> void:
	if not _done:
		_done = true
		finished.emit("cancelled")

func _get_title_text() -> String:
	return "Slice!" if _is_half_stage else "Slice in half!"

func _build_target_visual(_screen: Vector2) -> void:
	var tex := GarnishDefinitions.get_texture(garnish_id, false)
	_lemon_rect_ctrl = TextureRect.new()
	_lemon_rect_ctrl.texture = tex
	_lemon_rect_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lemon_rect_ctrl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lemon_rect_ctrl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lemon_rect_ctrl.size = lemon_display_size
	_lemon_rect_ctrl.pivot_offset = lemon_display_size * 0.5
	_lemon_rect_ctrl.position = _lemon_base_pos
	_lemon_rect_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_lemon_rect_ctrl)

func _compute_target_geometry() -> void:
	_compute_lemon_geometry()

func _get_shake_target() -> Control:
	return _lemon_rect_ctrl

func _get_shake_base_pos() -> Vector2:
	return _lemon_base_pos

func _build_ui() -> void:
	var screen := get_viewport().get_visible_rect().size
	if screen.x <= 1.0 or screen.y <= 1.0:
		screen = Vector2(1280.0, 720.0)
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.size = screen
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_ui)

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.0, 0.0, 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_dim)

	_lemon_base_pos = Vector2(screen.x * 0.5, screen.y * 0.52) - lemon_display_size * 0.5
	_build_target_visual(screen)

	_guides_layer = Control.new()
	_guides_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_guides_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_guides_layer)

	_slash_layer = Control.new()
	_slash_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_slash_layer)

	_title_label = _make_label(_get_title_text(), 56, font)
	_title_label.position = Vector2(0.0, 32.0)
	_title_label.size = Vector2(screen.x, 60.0)
	_ui.add_child(_title_label)

	_progress_label = _make_label("", 36, font)
	_progress_label.position = Vector2(0.0, 92.0)
	_progress_label.size = Vector2(screen.x, 42.0)
	_ui.add_child(_progress_label)
	_update_progress_label()

	_feedback_label = _make_label("", 38, font)
	_feedback_label.position = Vector2(0.0, _lemon_base_pos.y - 54.0)
	_feedback_label.size = Vector2(screen.x, 46.0)
	_feedback_label.modulate.a = 0.0
	_ui.add_child(_feedback_label)

	_hint_label = _make_label("", 28, font)
	_hint_label.position = Vector2(0.0, screen.y - 96.0)
	_hint_label.size = Vector2(screen.x, 76.0)
	_ui.add_child(_hint_label)
	_update_hint_label()

	_result_label = _make_label("", 68, font)
	_result_label.position = Vector2(0.0, screen.y * 0.5 - 44.0)
	_result_label.size = Vector2(screen.x, 90.0)
	_ui.add_child(_result_label)

	_timer = MinigameTimer.new()
	_ui.add_child(_timer)
	_timer.timed_out.connect(_on_timer_timed_out)

func _make_label(text_val: String, font_size: int, font: Font) -> Label:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	if font:
		lbl.add_theme_font_override("font", font)
	return lbl

func _compute_lemon_geometry() -> void:
	var tex := _lemon_rect_ctrl.texture
	if tex == null:
		_drawn_rect = Rect2(_lemon_base_pos, lemon_display_size)
		_guide_center = _drawn_rect.get_center()
		_guide_length = lemon_display_size.length() + GUIDE_EXTRA_MARGIN
		return

	var tex_size := tex.get_size()
	var tex_w := maxf(tex_size.x, 1.0)
	var tex_h := maxf(tex_size.y, 1.0)
	var scale_f := minf(lemon_display_size.x / tex_w, lemon_display_size.y / tex_h)
	var drawn_size := Vector2(tex_w * scale_f, tex_h * scale_f)
	var drawn_pos := _lemon_base_pos + (lemon_display_size - drawn_size) * 0.5
	_drawn_rect = Rect2(drawn_pos, drawn_size)

	var img := tex.get_image()
	if img != null and not img.is_empty():
		img = img.duplicate() as Image
		if img.is_compressed():
			img.decompress()
		_lemon_image = img
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var opaque_rect := Rect2(
				drawn_pos.x + (float(used.position.x) / tex_w) * drawn_size.x,
				drawn_pos.y + (float(used.position.y) / tex_h) * drawn_size.y,
				(float(used.size.x) / tex_w) * drawn_size.x,
				(float(used.size.y) / tex_h) * drawn_size.y
			)
			_guide_center = opaque_rect.get_center()
			_guide_length = opaque_rect.size.length() + GUIDE_EXTRA_MARGIN
			return

	_guide_center = _drawn_rect.get_center()
	_guide_length = drawn_size.length() + GUIDE_EXTRA_MARGIN

func _is_point_in_lemon(pt: Vector2) -> bool:
	if not _drawn_rect.has_point(pt):
		return false
	if _lemon_image != null and not _lemon_image.is_empty():
		var uv := (pt - _drawn_rect.position) / Vector2(maxf(_drawn_rect.size.x, 1.0), maxf(_drawn_rect.size.y, 1.0))
		var px := clampi(int(floorf(uv.x * float(_lemon_image.get_width()))), 0, _lemon_image.get_width() - 1)
		var py := clampi(int(floorf(uv.y * float(_lemon_image.get_height()))), 0, _lemon_image.get_height() - 1)
		return _lemon_image.get_pixel(px, py).a > 0.1
	return true

func _spawn_cut_guides() -> void:
	_active_guides.clear()
	for child in _guides_layer.get_children():
		child.queue_free()

	var angles: Array[float] = []
	if _is_half_stage:
		var base_angle := randf_range(0.0, TAU)
		var step_angle := PI / float(_required_cuts)
		for i in _required_cuts:
			var jitter := randf_range(-step_angle * 0.25, step_angle * 0.25)
			angles.append(base_angle + float(i) * step_angle + jitter)
	else:
		angles.append(PI * 0.5)

	var zone_col := DottedLine2D.DEFAULT_TOLERANCE_COLOR
	var border_col := DottedLine2D.DEFAULT_TOLERANCE_BORDER_COLOR
	if _is_half_stage:
		zone_col = Color(zone_col.r, zone_col.g, zone_col.b, 0.20)
		border_col = Color(border_col.r, border_col.g, border_col.b, 0.60)

	for angle in angles:
		var guide := DottedLine2D.new()
		guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		guide.set_dash_metrics(14.0, 9.0, 4.0, 2.0)
		guide.set_colors(Color(1.0, 0.98, 0.88, 0.95), Color(0.06, 0.05, 0.08, 0.85))
		guide.set_tolerance_zone(true, tolerance_half_width, zone_col, border_col)
		guide.set_from_center(_guide_center, angle, _guide_length)
		_guides_layer.add_child(guide)
		_active_guides.append(guide)

func _update_progress_label() -> void:
	if not is_instance_valid(_progress_label):
		return
	if _is_half_stage:
		_progress_label.text = "Slices: %d / %d" % [_cuts_completed, _required_cuts]
	else:
		_progress_label.text = "Cut: %d / %d" % [_cuts_completed, _required_cuts]

func _update_hint_label() -> void:
	if not is_instance_valid(_hint_label):
		return
	var msg := "Drag a straight line all the way through the green"
	if _cuts_attempted == 0:
		msg += "\nRight-click to cancel"
	_hint_label.text = msg

func _show_feedback(msg: String, col: Color) -> void:
	if not is_instance_valid(_feedback_label):
		return
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_label.text = msg
	_feedback_label.add_theme_color_override("font_color", col)
	_feedback_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_feedback_label.position.y = _lemon_base_pos.y - 54.0
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.tween_property(_feedback_label, "position:y", _lemon_base_pos.y - 76.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.4).set_delay(0.35)

func _spawn_animated_slash(p0: Vector2, p1: Vector2, line_col: Color, fade_duration: float = 0.40, keep_scar: bool = false) -> void:
	if not is_instance_valid(_slash_layer):
		return
	var slash := DottedLine2D.new()
	slash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slash.dotted = false
	slash.set_dash_metrics(12.0, 0.0, 6.0, 2.0)
	slash.set_colors(line_col, Color(0.06, 0.05, 0.08, 0.92))
	slash.set_points(p0, p0)
	_slash_layer.add_child(slash)

	var sweep_tween := create_tween()
	sweep_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(slash):
			slash.set_points(p0, p0.lerp(p1, t))
			slash.line_width = lerpf(7.0, 4.0, t)
	, 0.0, 1.0, SLASH_SWEEP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if keep_scar:
		sweep_tween.tween_property(slash, "modulate:a", 0.55, 0.18)
	else:
		sweep_tween.tween_property(slash, "modulate:a", 0.0, fade_duration).set_delay(0.08)
		sweep_tween.finished.connect(slash.queue_free)

func _shake_lemon(strength: float = 8.0) -> void:
	var target := _get_shake_target()
	if not is_instance_valid(target):
		return
	var base_pos := _get_shake_base_pos()
	if _lemon_shake_tween and _lemon_shake_tween.is_valid():
		_lemon_shake_tween.kill()
	target.position = base_pos
	_lemon_shake_tween = create_tween()
	_lemon_shake_tween.tween_property(target, "position", base_pos + Vector2(-strength, strength * 0.5), 0.04)
	_lemon_shake_tween.tween_property(target, "position", base_pos + Vector2(strength, -strength * 0.5), 0.04)
	_lemon_shake_tween.tween_property(target, "position", base_pos, 0.06)

func _input(event: InputEvent) -> void:
	if _done:
		return
	if get_tree().paused or GameState.is_dialogue_open:
		_is_dragging = false
		return

	if event is InputEventKey:
		for action in ["Up", "Down", "Left", "Right"]:
			if InputMap.has_action(action) and event.is_action(action):
				get_viewport().set_input_as_handled()
				return
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_drag_start = mb.position
				_drag_current = mb.position
			elif _is_dragging:
				_is_dragging = false
				_drag_current = mb.position
				_evaluate_drag_cut(_drag_start, _drag_current)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _cuts_attempted == 0 and not _is_dragging:
				_finish("cancelled", "", Color.WHITE)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_dragging:
		_drag_current = (event as InputEventMouseMotion).position
		get_viewport().set_input_as_handled()

func _retire_guide(guide: DottedLine2D) -> void:
	if not is_instance_valid(guide):
		return
	_active_guides.erase(guide)
	var tween := create_tween()
	tween.tween_property(guide, "modulate:a", 0.0, 0.16)
	tween.finished.connect(guide.queue_free)

func _evaluate_drag_cut(p0: Vector2, p1: Vector2) -> void:
	if p0.distance_to(p1) < MIN_DRAG_DISTANCE:
		return

	var eval := DottedLine2D.evaluate_multi_cuts(_active_guides, p0, p1, _is_point_in_lemon, 2.0)
	var status := str(eval.get("status", "missed"))

	if status == "missed":
		_spawn_animated_slash(p0, p1, Color(0.90, 0.90, 0.95, 0.55), 0.25, false)
		_show_feedback("Slice!", Color(0.95, 0.85, 0.4))
		return

	_cuts_attempted += 1
	_update_hint_label()

	match status:
		"outside_zone":
			_spawn_animated_slash(p0, p1, Color(1.0, 0.25, 0.25, 0.95), 0.65, false)
			_shake_lemon(14.0)
			SFXAudio.play_stab()
			if is_instance_valid(_lemon_rect_ctrl):
				_lemon_rect_ctrl.modulate = Color(1.0, 0.45, 0.45, 0.75)
			_finish("wasted", "Lemon wasted!", Color(1.0, 0.35, 0.35))
		"incomplete":
			_wasted_cuts += 1
			_spawn_animated_slash(p0, p1, Color(1.0, 0.68, 0.22, 0.90), 0.65, false)
			_shake_lemon(5.0)
			SFXAudio.play_draw()
			_show_feedback("Incomplete cut", Color(1.0, 0.68, 0.22))
		"success":
			var matched_guide := eval.get("guide", null) as DottedLine2D
			_retire_guide(matched_guide)
			_cuts_completed += 1
			_update_progress_label()
			_spawn_animated_slash(p0, p1, Color(0.45, 1.0, 0.65, 1.0), 0.35, _cuts_completed < _required_cuts)
			_shake_lemon(7.0)
			# SFXAudio.play_slice()
			SFXAudio.play_stab()
			if GameState.player and GameState.player.camera_rig and GameState.player.camera_rig.has_method("add_shake"):
				GameState.player.camera_rig.add_shake(0.12)

			var accuracy := float(eval.get("accuracy", 0.0))
			if accuracy >= 0.85:
				_show_feedback("Perfect!", Color(0.38, 0.96, 1.0))
			elif accuracy >= 0.60:
				_show_feedback("Great!", Color(0.35, 0.96, 0.45))
			else:
				_show_feedback("Good!", Color(0.85, 0.95, 0.35))

			if _cuts_completed >= _required_cuts:
				var win_text := "Sliced!" if _is_half_stage else "Halved!"
				_finish("success", win_text, Color(0.4, 1.0, 0.5))

func _on_timer_timed_out() -> void:
	if not _done:
		_is_dragging = false
		_finish("wasted", "Too slow!", Color(1.0, 0.4, 0.4))

func _finish(result: String, message: String = "", color: Color = Color.WHITE) -> void:
	if _done:
		return
	_done = true
	_is_dragging = false
	if is_instance_valid(_timer):
		_timer.stop()
	if is_instance_valid(_dim):
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_result_label):
		_result_label.text = message
		_result_label.add_theme_color_override("font_color", color)
	finished.emit(result)
	if message != "":
		await get_tree().create_timer(0.65, false).timeout
	queue_free()