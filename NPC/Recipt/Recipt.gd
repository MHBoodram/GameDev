# Physical draggable 3D receipt representing an active customer order
# Mounts to the 3D board or snaps to drink glasses to complete orders
extends Ingredients

@onready var recipt_2d = get_node_or_null("Base_viewport/SubViewport/Recipt")
@export var recipt_marker: Marker3D
@export var seat_num: int = 1
var ordered: bool = false
var has_board_slot: bool = false
var board_slot_position: Vector3 = Vector3.ZERO
var board_slot_quaternion: Quaternion = Quaternion.IDENTITY
var board_slot_scale: Vector3 = Vector3.ONE
var _move_tween: Tween = null

@export var hold_lift: float = 0.3
@export var snap_to_glass: bool = true
@export var snap_offset: Vector3 = Vector3(0, 0.5, 0)
@export var follow_speed: float = 20.0

func ready() -> void:
	base_y_position = 1.6
	if recipt_2d:
		recipt_2d._set_seat_number(seat_num)

func _is_drag_blocked() -> bool:
	return not ordered

func _get_drag_follow_speed() -> float:
	return follow_speed

func _get_drag_hold_lift() -> float:
	return hold_lift

func _get_free_drag_target(delta: float) -> Vector3:
	if snap_to_glass and camera and is_instance_valid(current_hovered_target) and can_interact_with(current_hovered_target):
		var to_cam := (camera.global_position - current_hovered_target.global_position).normalized()
		return current_hovered_target.global_position + snap_offset + to_cam * hold_lift
	return super._get_free_drag_target(delta)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_balls_dragging and ordered and not has_board_slot and recipt_marker:
		if global_position.distance_to(recipt_marker.global_position) > 0.01:
			if _move_tween == null or not _move_tween.is_valid():
				_move_tween = get_tree().create_tween()
				_move_tween.set_trans(Tween.TRANS_SINE)
				_move_tween.set_ease(Tween.EASE_OUT)
				_move_tween.tween_property(self, "global_position", recipt_marker.global_position, 0.3)

func _on_area_3d_input_event(cam: Node, event: InputEvent, pos: Vector3, normal: Vector3, shape_idx: int) -> void:
	if not ordered:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _move_tween and _move_tween.is_valid():
			_move_tween.kill()
	super._on_area_3d_input_event(cam, event, pos, normal, shape_idx)

func get_base_receipt_dimensions() -> Vector2:
	var paper_mesh := get_node_or_null("PaperMesh") as MeshInstance3D
	if paper_mesh and paper_mesh.mesh:
		var aabb: AABB = paper_mesh.mesh.get_aabb()
		var width: float = aabb.size.x * absf(paper_mesh.scale.x)
		var height_local: float = aabb.size.z * absf(paper_mesh.scale.z)
		if aabb.size.z <= 0.001:
			height_local = aabb.size.y * absf(paper_mesh.scale.y)
		if width > 0.001 and height_local > 0.001:
			return Vector2(width, height_local)
	return Vector2(0.25, 0.35)

func get_receipt_dimensions() -> Vector2:
	var base_dims := get_base_receipt_dimensions()
	return Vector2(base_dims.x * absf(scale.x), base_dims.y * absf(scale.z))

func _moving_to_board(target_pos: Vector3, target_basis: Basis, duration: float = 0.5, target_scale: Vector3 = Vector3.ONE) -> void:
	has_board_slot = true
	board_slot_position = target_pos
	board_slot_quaternion = target_basis.get_rotation_quaternion()
	board_slot_scale = target_scale
	base_y_position = target_pos.y
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = get_tree().create_tween().set_parallel(true)
	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_position", board_slot_position, duration)
	_move_tween.tween_property(self, "quaternion", board_slot_quaternion, duration)
	_move_tween.tween_property(self, "scale", board_slot_scale, duration)

func clear_board_slot() -> void:
	has_board_slot = false
	ordered = false
	board_slot_scale = Vector3.ONE
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	scale = Vector3.ONE

func _moving_to(to: Marker3D) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = get_tree().create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_position", to.global_position, 0.5)

func _write(words: String) -> void:
	if recipt_2d:
		recipt_2d._label_change(words)
		recipt_2d._set_seat_number(seat_num)

func _set_customer_info(seat: int, race: String = "", icon_texture: Texture2D = null) -> void:
	seat_num = seat
	if recipt_2d:
		recipt_2d._set_seat_number(seat_num)
		if icon_texture != null:
			recipt_2d._set_customer_icon(icon_texture)
		elif race != "":
			recipt_2d._set_customer_race(race)

func apply_customer_visuals(sp: SpeciesBase, mod: ModifierBase) -> void:
	if recipt_2d and recipt_2d.has_method("_set_customer_icon_modulate"):
		recipt_2d._set_customer_icon_modulate(Color.WHITE)
	if sp and recipt_2d:
		sp.modify_receipt_appearance(self, recipt_2d)
	if mod and recipt_2d:
		mod.modify_receipt_appearance(self, recipt_2d)

func apply_modifier_visuals(mod: ModifierBase) -> void:
	apply_customer_visuals(null, mod)

func _get_npc() -> Base_NPC:
	if GameState.seat_manager:
		return GameState.seat_manager.get_customer_at_seat(seat_num)
	return null

func can_interact_with(target: Ingredients) -> bool:
	if not ordered or not is_instance_valid(target):
		return false
	if target is Glasses:
		var npc := _get_npc()
		if is_instance_valid(npc):
			return target.can_serve_npc(npc)
	return false

func execute_interaction(target: Ingredients) -> void:
	if can_interact_with(target) and target is Glasses:
		var npc := _get_npc()
		if is_instance_valid(npc) and target.can_serve_npc(npc):
			target.set_highlight(false)
			if _move_tween and _move_tween.is_valid():
				_move_tween.kill()
			target.execute_npc_interaction(npc)
		else:
			on_drop_failed()

func on_drop_failed() -> void:
	if ordered:
		if has_board_slot:
			_moving_to_board(board_slot_position, Basis(board_slot_quaternion), 0.4, board_slot_scale)
		elif recipt_marker:
			if _move_tween and _move_tween.is_valid():
				_move_tween.kill()
			_move_tween = get_tree().create_tween()
			_move_tween.set_trans(Tween.TRANS_SINE)
			_move_tween.set_ease(Tween.EASE_OUT)
			_move_tween.tween_property(self, "global_position", recipt_marker.global_position, 0.4)