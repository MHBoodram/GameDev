extends Ingredients
class_name Drinks

var pouring_into : Node3D
@export var liquid_resource : Liquid
var original_position : Marker3D
var is_pouring : bool = false
@export var size : float = 50.0
var in_game : bool = false
var current_liquid : float = size
@export var hold_lift : float = 0.2
@export var snap_to_glass : bool = true
@export var snap_offset : Vector3 = Vector3(0, 0.5, 0)
@export var follow_speed : float = 30.0

func _is_drag_blocked() -> bool:
	return in_game

func _get_drag_follow_speed() -> float:
	return follow_speed

func _get_drag_hold_lift() -> float:
	return hold_lift

func _get_free_drag_target(delta: float) -> Vector3:
	if snap_to_glass and camera and is_instance_valid(current_hovered_target) and can_interact_with(current_hovered_target):
		var to_cam := (camera.global_position - current_hovered_target.global_position).normalized()
		return current_hovered_target.global_position + snap_offset + to_cam * hold_lift
	return super._get_free_drag_target(delta)

func setup(og_position: Marker3D, Counter: Node3D, _liquid: Liquid) -> void:
	liquid_resource = _liquid
	size = liquid_resource.liquid_size
	$Inside.texture = liquid_resource.sprite
	original_position = og_position
	counter_origin = Counter
	global_position = og_position.global_position
	rotation_degrees = Vector3.ZERO
	base_y_position = global_position.y

func _process(delta: float) -> void:
	if in_game:
		return
	super._process(delta)
	_face_camera()

func _on_area_3d_input_event(camera_node: Node, event: InputEvent, event_pos: Vector3, normal: Vector3, shape_idx: int) -> void:
	if not in_game:
		super._on_area_3d_input_event(camera_node, event, event_pos, normal, shape_idx)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_pouring:
			return
		is_pouring = true
		if GameState.player:
			GameState.player._update_hand("holding")
		rotation_degrees.z = 80
		if pouring_into:
			$CPUParticles3D.emitting = true
			while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.get_action_strength("Left_click") > 0.0:
				if is_instance_valid(pouring_into):
					pouring_into._pouring(liquid_resource.id, 0.25)
					current_liquid -= 0.25
				await get_tree().create_timer(0.1).timeout
		$CPUParticles3D.emitting = false
		rotation_degrees.z = 0
		if GameState.player:
			GameState.player._update_hand("idle")
		is_pouring = false
		await get_tree().create_timer(0.2).timeout
		if in_game and GameState.player:
			GameState.player._out_of_game()

func _look_at_sprite(looking_at: Vector3) -> void:
	if looking_at:
		var target_flat: Vector3 = looking_at
		target_flat.y = $Inside.global_position.y
		$Inside.look_at(target_flat, Vector3.UP)

func _return_original() -> void:
	if _drag_return_tween and _drag_return_tween.is_valid():
		_drag_return_tween.kill()
	_drag_return_tween = get_tree().create_tween().set_parallel(true)
	_drag_return_tween.set_trans(Tween.TRANS_SINE)
	_drag_return_tween.set_ease(Tween.EASE_OUT)
	if original_position:
		_drag_return_tween.tween_property(self, "global_position", original_position.global_position, 0.5)
	_drag_return_tween.tween_property($Inside, "global_rotation", Vector3.ZERO, 0.5)
	rotation_degrees = Vector3.ZERO

func _in_game() -> void:
	in_game = true
	if pouring_into and pouring_into.has_method("_on_hover"):
		pouring_into._on_hover(false)

func _out_of_game() -> void:
	in_game = false
	_return_original()
	pouring_into = null

func _pouring_game() -> void:
	if not pouring_into:
		return
	pouring_into.in_game = true
	in_game = true
	GameState.player._perfect_pour(self, pouring_into)
	$CollisionShape3D.disabled = true
	await get_tree().create_timer(0.2).timeout
	$CollisionShape3D.disabled = false
	is_balls_dragging = false

func can_interact_with(target: Ingredients) -> bool:
	return target is Glasses and not (target is Drinks)

func execute_interaction(target: Ingredients) -> void:
	if can_interact_with(target) && target.is_in_group("glass"):
		pouring_into = target
		target.set_highlight(false)
		_pouring_game()

func on_drop_failed() -> void:
	_return_original()

func _on_interact_mouse_entered() -> void:
	_on_area_3d_mouse_entered()

func _on_interact_mouse_exited() -> void:
	_on_area_3d_mouse_exited()

func _on_interact_area_entered(_area: Area3D) -> void:
	pass

func _on_interact_area_exited(_area: Area3D) -> void:
	pass
	