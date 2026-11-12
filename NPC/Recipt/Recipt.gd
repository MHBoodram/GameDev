extends Ingredients

@onready var recipt_2d = get_node_or_null("Base_viewport/SubViewport/Recipt")
@export var recipt_marker : Marker3D
@export var seat_num : int = 1
var ordered : bool = false
var has_board_slot : bool = false
var board_slot_position : Vector3 = Vector3.ZERO
var board_slot_quaternion : Quaternion = Quaternion.IDENTITY
var _move_tween : Tween = null

func ready() -> void:
	base_y_position = 1.6
	if recipt_2d:
		recipt_2d._set_seat_number(seat_num)

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

func get_receipt_dimensions() -> Vector2:
	var paper_mesh := get_node_or_null("PaperMesh") as MeshInstance3D
	if paper_mesh and paper_mesh.mesh:
		var aabb: AABB = paper_mesh.mesh.get_aabb()
		var width: float = aabb.size.x * absf(paper_mesh.scale.x) * absf(scale.x)
		var height_local: float = aabb.size.z * absf(paper_mesh.scale.z) * absf(scale.z)
		if aabb.size.z <= 0.001:
			height_local = aabb.size.y * absf(paper_mesh.scale.y) * absf(scale.y)
		if width > 0.001 and height_local > 0.001:
			return Vector2(width, height_local)
	return Vector2(0.25 * absf(scale.x), 0.35 * absf(scale.z))

func _moving_to_board(target_pos: Vector3, target_basis: Basis, duration: float = 0.5) -> void:
	has_board_slot = true
	board_slot_position = target_pos
	board_slot_quaternion = target_basis.get_rotation_quaternion()
	base_y_position = target_pos.y
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = get_tree().create_tween().set_parallel(true)
	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_position", board_slot_position, duration)
	_move_tween.tween_property(self, "quaternion", board_slot_quaternion, duration)

func clear_board_slot() -> void:
	has_board_slot = false
	ordered = false
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

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
	if ordered:
		if has_board_slot:
			_moving_to_board(board_slot_position, Basis(board_slot_quaternion), 0.4)
		elif recipt_marker:
			if _move_tween and _move_tween.is_valid():
				_move_tween.kill()
			_move_tween = get_tree().create_tween()
			_move_tween.set_trans(Tween.TRANS_SINE)
			_move_tween.set_ease(Tween.EASE_OUT)
			_move_tween.tween_property(self, "global_position", recipt_marker.global_position, 0.4)
			