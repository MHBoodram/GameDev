extends Ingredients

@onready var recipt_2d = get_node_or_null("Base_viewport/SubViewport/Recipt")
@export var recipt_marker : Marker3D
@export var seat_num : int = 1
var ordered : bool = false

@export var hold_lift : float = 0.3
@export var snap_to_glass : bool = true
@export var snap_offset : Vector3 = Vector3(0, 0.5, 0)
@export var follow_speed : float = 20.0

var _grab_depth : float = 0.0
var _depth_now : float = 0.0
var _smooth_pos : Vector3 = Vector3.ZERO
var _return_tween : Tween

func ready() -> void:
	base_y_position = 1.6

func _process(delta: float) -> void:
	super._process(delta)
	if is_balls_dragging:
		_follow_cursor(delta)
	#if not is_balls_dragging and ordered and recipt_marker:
		#if global_position.distance_to(recipt_marker.global_position) > 0.01:
			#var tween = get_tree().create_tween()
			#tween.set_trans(Tween.TRANS_SINE)
			#tween.set_ease(Tween.EASE_OUT)
			#tween.tween_property(self, "global_position", recipt_marker.global_position, 0.3)

func _follow_cursor(delta: float) -> void:
	if not camera:
		return
	var target : Vector3
	var glass := current_hovered_target
	if snap_to_glass and is_instance_valid(glass) and can_interact_with(glass):
		var to_cam := (camera.global_position - glass.global_position).normalized()
		target = glass.global_position + snap_offset + to_cam * hold_lift
	else:
		var mouse_pos := get_viewport().get_mouse_position()
		_depth_now = lerpf(_depth_now, _grab_depth - hold_lift, 1.0 - exp(-12.0 * delta))
		target = camera.project_position(mouse_pos, _depth_now)
	_smooth_pos = _smooth_pos.lerp(target, 1.0 - exp(-follow_speed * delta))
	global_position = _smooth_pos 

func _capture_grab_depth() -> void:
	_smooth_pos = global_position
	var cam := camera if camera else get_viewport().get_camera_3d()
	if cam == null:
		return
	var foward := -cam.global_transform.basis.z
	_grab_depth = (global_position - cam.global_position).dot(foward)
	_depth_now = _grab_depth

func _on_area_3d_input_event(cam_node: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _return_tween:
			_return_tween.kill()
		_capture_grab_depth()
	super._on_area_3d_input_event(cam_node, event, _pos, _normal, _shape_idx)

func _return_to_marker(time: float) -> void:
	if _return_tween:
		_return_tween.kill()
	_return_tween = create_tween()
	_return_tween.set_trans(Tween.TRANS_SINE)
	_return_tween.set_ease(Tween.EASE_OUT)
	_return_tween.tween_property(self, "global_position", recipt_marker.global_position, time)
	

func _moving_to(to: Marker3D) -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", to.global_position, 0.5)


func _write(words: String) -> void:
	if recipt_2d:
		recipt_2d._label_change(words)

func can_interact_with(target: Ingredients) -> bool:
	return ordered and target is Glasses and not (target is Drinks)

func execute_interaction(target: Ingredients) -> void:
	if can_interact_with(target) && target.is_in_group("glass"):
		ordered = false
		target.set_highlight(false)
		if target is Glasses :
			target.is_being_served = true
			get_parent()._give_drink(self, target, seat_num)

func on_drop_failed() -> void:
	if ordered and recipt_marker:
		_return_to_marker(0.4)
		#var tween = get_tree().create_tween()
		#tween.set_trans(Tween.TRANS_SINE)
		#tween.set_ease(Tween.EASE_OUT)
		#tween.tween_property(self, "global_position", recipt_marker.global_position, 0.4)
