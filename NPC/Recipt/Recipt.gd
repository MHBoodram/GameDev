extends Ingredients

@onready var recipt_2d = get_node_or_null("Base_viewport/SubViewport/Recipt")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@export var recipt_marker : Marker3D
@export var seat_num : int = 1
var move_tween : Tween = null

var ordered : bool = false:
	set(value):
		ordered = value
		_update_ordered_state()

func _update_ordered_state() -> void:
	visible = ordered
	input_ray_pickable = ordered
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = not ordered
	if not ordered:
		is_balls_dragging = false
		_is_pointer_pressed = false
		set_highlight(false)

func ready() -> void:
	base_y_position = 1.6
	_update_ordered_state()
	if recipt_2d:
		recipt_2d._label_change("")
		var viewport = recipt_2d.get_parent() as SubViewport
		if viewport:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _process(delta: float) -> void:
	super._process(delta)

func _moving_to(to: Marker3D) -> void:
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	move_tween = get_tree().create_tween()
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, "global_position", to.global_position, 0.5)

func _write(words: String) -> void:
	if recipt_2d:
		recipt_2d._label_change(words)
		var viewport = recipt_2d.get_parent() as SubViewport
		if viewport:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func can_interact_with(target: Ingredients) -> bool:
	return ordered and target is Glasses and not (target is Drinks)

func execute_interaction(target: Ingredients) -> void:
	if can_interact_with(target):
		ordered = false
		target.set_highlight(false)
		if target is Glasses:
			target.is_being_served = true
		get_parent()._give_drink(self, target, seat_num)

func on_drop_failed() -> void:
	if ordered and recipt_marker:
		if move_tween and move_tween.is_valid():
			move_tween.kill()
		move_tween = get_tree().create_tween()
		move_tween.set_trans(Tween.TRANS_SINE)
		move_tween.set_ease(Tween.EASE_OUT)
		move_tween.tween_property(self, "global_position", recipt_marker.global_position, 0.4)

func _on_area_3d_input_event(camera_node: Node, event: InputEvent, event_pos: Vector3, normal: Vector3, shape_idx: int) -> void:
	if not ordered:
		return
	super._on_area_3d_input_event(camera_node, event, event_pos, normal, shape_idx)