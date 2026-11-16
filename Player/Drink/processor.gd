extends Ingredients
class_name Processor

var in_game: bool = false
var _last_counter_position: Vector3 = Vector3.ZERO
@export var area_body: CollisionShape3D

func is_working_area_item() -> bool:
	return true

func _is_drag_blocked() -> bool:
	return in_game

func ready() -> void:
	super.ready()
	if area_body == null:
		area_body = get_node_or_null("CollisionShape3D")
	rotation = Vector3.ZERO
	_face_camera()
	_snap_to_working_area()
	_last_counter_position = global_position

func _process(delta: float) -> void:
	super._process(delta)
	if in_game:
		return
	if camera and not is_balls_dragging:
		_face_camera()
	if not is_balls_dragging and get_drag_mode() == DragMode.COLLISION and not _is_returning_to_counter and not _is_mode_transitioning:
		if not is_selected:
			var target_y: float = get_working_area_surface_y()
			base_y_position = target_y
			if absf(global_position.y - target_y) <= 0.002:
				global_position.y = target_y
			else:
				global_position.y = lerpf(global_position.y, target_y, 1.0 - exp(-20.0 * delta))
		_last_counter_position = global_position

func _in_game() -> void:
	in_game = true
	_is_pointer_pressed = false
	is_balls_dragging = false
	_is_returning_to_counter = false
	_is_mode_transitioning = false
	if _drag_return_tween and _drag_return_tween.is_valid():
		_drag_return_tween.kill()
	if area_body:
		area_body.disabled = true

func _out_of_game() -> void:
	in_game = false
	if area_body:
		area_body.disabled = false
	var target_pos: Vector3 = _get_saved_counter_position(_last_counter_position)
	if global_position.distance_to(target_pos) > 0.005:
		_return_to_counter_smoothly(target_pos)
	else:
		global_position = target_pos
		base_y_position = target_pos.y
		_last_counter_position = target_pos

func _on_hover(hovered: bool) -> void:
	set_highlight(hovered)

func can_interact_with(target: Ingredients) -> bool:
	if not is_instance_valid(target) or in_game:
		return false
	if target is Glasses:
		return target.can_be_shaken()
	return false

func execute_interaction(target: Ingredients) -> void:
	if target is Glasses and can_interact_with(target):
		start_shake(target as Glasses)

func on_drop_failed() -> void:
	var target_pos: Vector3 = _get_counter_drop_position(_last_counter_position) if _has_dragged else _get_saved_counter_position(_last_counter_position)
	_return_to_counter_smoothly(target_pos)

func _on_returning_to_counter(target_pos: Vector3) -> void:
	_last_counter_position = target_pos

func _on_returned_to_counter(target_pos: Vector3) -> void:
	_last_counter_position = target_pos

func start_shake(_glass: Glasses) -> void:
	pass
