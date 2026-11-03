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

var _grab_depth : float = 0.0
var _depth_now : float = 0.0
var _smooth_pos : Vector3 = Vector3.ZERO
var _return_tween : Tween

func setup(og_position: Marker3D, Counter: Node3D, _liquid: Liquid) -> void:
	liquid_resource = _liquid
	size = liquid_resource.liquid_size
	$Inside.texture = liquid_resource.sprite
	original_position = og_position
	counter_origin = Counter
	global_position = og_position.global_position
	rotation_degrees = Vector3.ZERO
	base_y_position = global_position.y

func _process(_delta: float) -> void:
	if in_game:
		return
	super._process(_delta)
	if is_balls_dragging:
		_follow_cursor(_delta)
	if camera:
		var target_flat: Vector3 = camera.global_position
		target_flat.y = $Inside.global_position.y
		$Inside.look_at(target_flat, Vector3.UP)

# new function that tracks cursor to see what's being hovered
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
	#global_position = global_position.lerp(target,1.0 - exp(-follow_speed * delta))

func _capture_grab_depth() -> void:
	_smooth_pos = global_position
	var cam := camera if camera else get_viewport().get_camera_3d()
	if cam == null:
		return
	var forward := -cam.global_transform.basis.z
	_grab_depth = (global_position - cam.global_position).dot(forward)
	_depth_now = _grab_depth

func _on_area_3d_input_event(camera_node: Node, event: InputEvent, event_pos: Vector3, normal: Vector3, shape_idx: int) -> void:
	if not in_game:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _return_tween:
				_return_tween.kill()
			_capture_grab_depth()
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
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", original_position.global_position, 0.5)
	tween.tween_property($Inside, "global_rotation", Vector3.ZERO, 0.5)
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
	if can_interact_with(target):
		pouring_into = target
		target.set_highlight(false)
		_pouring_game()

func on_drop_failed() -> void:
	_return_original()

func _on_interact_mouse_entered() -> void:
	_on_area_3d_mouse_entered()

func _on_interact_mouse_exited() -> void:
	_on_area_3d_mouse_exited()

#func _on_interact_area_entered(area: Area3D) -> void:
	#if area.is_in_group("glass") and is_balls_dragging and pouring_into == null:
		#pouring_into = area
		#if area.has_method("_on_hover"):
			#area._on_hover(true)

# targeting is now handeled by the base class (ray from under the cursor + set_highlight)
# the bottles don't sit on the counter tho, MATT NOTE (pls pls pls play around with this to make sure it looks good and doesn't feel cheap or janky)
func _on_interact_area_entered(area: Area3D) -> void:
	pass

#func _on_interact_area_exited(area: Area3D) -> void:
	#if area == pouring_into and is_balls_dragging:
		#if area.has_method("_on_hover"):
			#area._on_hover(false)
		#pouring_into = null
func _on_interact_area_exited(area: Area3D) -> void:
	pass
