extends Ingredients
class_name GarnishItem

@export var garnish_id: String = "lemon_whole"
@export var sprite: Sprite3D

var is_consumed: bool = false
var _skip_initial_snap: bool = false
var _active_trash: Area3D = null
var _previous_counter_position: Vector3 = Vector3.ZERO
var _trash_tinted: bool = false

func is_working_area_item() -> bool:
	return true

func _is_drag_blocked() -> bool:
	return super._is_drag_blocked() or is_consumed

func setup(p_garnish_id: String, p_counter: Node3D = null) -> void:
	counter_origin = p_counter
	set_garnish_id(p_garnish_id)

func set_garnish_id(new_id: String) -> void:
	garnish_id = GarnishDefinitions.normalize_id(new_id)
	_apply_visual_texture()

func _apply_visual_texture() -> void:
	var sp := sprite if is_instance_valid(sprite) else get_node_or_null("Sprite3D") as Sprite3D
	if sp:
		sprite = sp
		sp.texture = GarnishDefinitions.get_texture(garnish_id, false)

func ready() -> void:
	rotation = Vector3.ZERO
	if sprite == null:
		sprite = get_node_or_null("Sprite3D") as Sprite3D
	if area_body == null:
		area_body = get_node_or_null("CollisionShape3D") as CollisionShape3D
	_apply_visual_texture()
	if camera:
		_face_camera()
	if not _skip_initial_snap:
		_snap_to_working_area()
	else:
		base_y_position = get_working_area_surface_y()
	_last_counter_position = global_position
	_previous_counter_position = global_position

func start_drag_from_spawn(press_screen_pos: Vector2, from_shelf: bool = false) -> void:
	_apply_visual_texture()
	if from_shelf:
		var working_area_bounds = WorkingAreaService.get_working_area_bounds(self)
		if working_area_bounds is AABB:
			var center: Vector3 = (working_area_bounds as AABB).get_center()
			_last_counter_position = Vector3(center.x, get_working_area_surface_y(), center.z)
		else:
			_last_counter_position = _clamp_to_counter(global_position)
			_last_counter_position.y = get_working_area_surface_y()
	else:
		_last_counter_position = _clamp_to_counter(global_position)
		_last_counter_position.y = get_working_area_surface_y()
	_previous_counter_position = _last_counter_position
	if camera:
		_face_camera()
	super.start_drag_from_spawn(press_screen_pos, from_shelf)

func _on_drag_started() -> void:
	if not is_instance_valid(_active_trash) and not _is_returning_to_counter and absf(global_position.y - get_working_area_surface_y()) <= 0.15:
		var saved := _clamp_to_counter(global_position)
		saved.y = get_working_area_surface_y()
		_previous_counter_position = saved

func _on_working_area_settled() -> void:
	if not is_instance_valid(_active_trash):
		_previous_counter_position = global_position

func _on_returning_to_counter(target_pos: Vector3) -> void:
	super._on_returning_to_counter(target_pos)
	if not is_instance_valid(_active_trash):
		_previous_counter_position = target_pos

func _on_returned_to_counter(target_pos: Vector3) -> void:
	super._on_returned_to_counter(target_pos)
	if not is_instance_valid(_active_trash):
		_previous_counter_position = target_pos

func set_active_trash(trash_area: Area3D) -> void:
	_active_trash = trash_area
	var should_tint := is_instance_valid(_active_trash)
	if should_tint != _trash_tinted:
		_trash_tinted = should_tint
		if is_instance_valid(sprite):
			sprite.modulate = Color(1.0, 0.35, 0.35, 0.9) if should_tint else Color.WHITE

func _is_over_trash() -> bool:
	if is_instance_valid(_active_trash):
		return true
	for area in get_overlapping_areas():
		if area.is_in_group("trash"):
			return true
	return false

func _get_active_tool() -> String:
	if GameState.player and GameState.player.has_method("return_tool"):
		return str(GameState.player.return_tool()).to_lower().strip_edges()
	return "hand"

func can_highlight_on_hover() -> bool:
	if _is_drag_blocked():
		return false
	if _get_active_tool() == "knife":
		return GarnishDefinitions.get_next_cut_variation(garnish_id) != ""
	return true

func handle_immediate_tool_click() -> bool:
	if GameState.is_dialogue_open or ShakerMinigame.active or _is_drag_blocked():
		return false
	if _get_active_tool() == "knife":
		var next_var := GarnishDefinitions.get_next_cut_variation(garnish_id)
		if next_var != "":
			set_garnish_id(next_var)
			GameState.play_sfx("play_stab")
			_play_cut_bounce()
			return true
	return false

func _play_cut_bounce() -> void:
	if not is_instance_valid(sprite):
		return
	var base_scale := sprite.scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sprite.scale = base_scale * Vector3(1.22, 0.78, 1.0)
	tween.tween_property(sprite, "scale", base_scale, 0.16)

func can_interact_with(target: Ingredients) -> bool:
	if _is_drag_blocked() or not is_instance_valid(target) or target == self:
		return false
	if target is Glasses:
		return target.can_add_garnish(garnish_id)
	return false

func execute_interaction(target: Ingredients) -> void:
	if can_interact_with(target) and target is Glasses:
		var cup := target as Glasses
		if cup.add_garnish_item(garnish_id):
			_consume_to_cup()
			return
	on_drop_failed()

func on_drop_failed() -> void:
	if _is_over_trash():
		_consume_into_trash()
		return
	super.on_drop_failed()

func _consume_to_cup() -> void:
	if is_consumed:
		return
	is_consumed = true
	_is_pointer_pressed = false
	is_balls_dragging = false
	if area_body:
		area_body.set_deferred("disabled", true)
	queue_free()

func _consume_into_trash() -> void:
	if is_consumed:
		return
	is_consumed = true
	_is_pointer_pressed = false
	is_balls_dragging = false
	if _drag_return_tween and _drag_return_tween.is_valid():
		_drag_return_tween.kill()
	if area_body:
		area_body.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3.ONE * 0.02, 0.16)
	tween.tween_property(self, "global_position:y", global_position.y - 0.12, 0.16)
	tween.chain().tween_callback(queue_free)