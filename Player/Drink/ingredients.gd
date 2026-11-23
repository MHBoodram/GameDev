extends Area3D
class_name Ingredients

# base class for all pickable and draggable 3d items (glasses, bottles, shakers, receipts)

enum DragMode { FREE, COLLISION }

static var active_selected_item: Ingredients = null
static var active_dragging_item: Ingredients = null
static var current_hovered_target: Ingredients = null
static var current_hovered_npc: Base_NPC = null

var is_balls_dragging: bool = false:
	set(value):
		is_balls_dragging = value
		if value:
			active_dragging_item = self
		elif active_dragging_item == self:
			active_dragging_item = null

var is_selected: bool = false
var camera: Camera3D
@export var counter_origin: Node3D
var base_y_position: float = 1.6
var drag_height: float = 1.6
var drag_follow_speed: float = 0.0

var _pointer_down_pos: Vector2 = Vector2.ZERO
var _is_pointer_pressed: bool = false
var _has_dragged: bool = false
const DRAG_THRESHOLD: float = 4.0

var _highlight_helper: HighlightHelper = HighlightHelper.new()
var _drag_controller: DragController = DragController.new(self)

# compatibility properties forwarding to DragController
var _drag_current_depth: float:
	get: return _drag_controller.drag_current_depth
	set(value): _drag_controller.drag_current_depth = value

var _drag_return_tween: Tween:
	get: return _drag_controller.drag_return_tween
	set(value): _drag_controller.drag_return_tween = value

var _is_returning_to_counter: bool:
	get: return _drag_controller.is_returning_to_counter
	set(value): _drag_controller.is_returning_to_counter = value

var _waiting_for_working_area: bool:
	get: return _drag_controller.waiting_for_working_area
	set(value): _drag_controller.waiting_for_working_area = value

var _is_mode_transitioning: bool:
	get: return _drag_controller.is_mode_transitioning
	set(value): _drag_controller.is_mode_transitioning = value

static func get_working_area_bounds(context: Node) -> Variant:
	return WorkingAreaService.get_working_area_bounds(context)

static func get_working_area_usable_bounds(context: Node) -> Variant:
	return WorkingAreaService.get_working_area_usable_bounds(context)

static func get_working_area_aabb(context: Node) -> Variant:
	return WorkingAreaService.get_working_area_bounds(context)

static func _get_ray_collider_under_mouse(viewport: Viewport, exclude_rid: RID = RID()) -> Object:
	return DragController.get_ray_collider_under_mouse(viewport, exclude_rid)

static func get_interactable_under_mouse(viewport: Viewport, exclude_rid: RID = RID()) -> Ingredients:
	var collider: Object = DragController.get_ray_collider_under_mouse(viewport, exclude_rid)
	return collider as Ingredients if collider is Ingredients else null

func _ready() -> void:
	add_to_group("interactable")
	camera = get_viewport().get_camera_3d()
	if not input_event.is_connected(_on_area_3d_input_event):
		input_event.connect(_on_area_3d_input_event)
	if not mouse_entered.is_connected(_on_area_3d_mouse_entered):
		mouse_entered.connect(_on_area_3d_mouse_entered)
	if not mouse_exited.is_connected(_on_area_3d_mouse_exited):
		mouse_exited.connect(_on_area_3d_mouse_exited)
	_highlight_helper.cache_visual_nodes(self)
	_highlight_helper.setup_render_priority(self)
	ready()

func ready() -> void:
	pass

func is_working_area_item() -> bool:
	return false

func get_drag_mode() -> DragMode:
	if is_working_area_item() and not _waiting_for_working_area and (not GameState.gameplay_ui or (GameState.gameplay_ui.down and not GameState.gameplay_ui.is_transitioning)):
		return DragMode.COLLISION
	return DragMode.FREE

func uses_working_area_drag_plane() -> bool:
	return get_drag_mode() == DragMode.COLLISION

func _is_drag_blocked() -> bool:
	return false

func _get_drag_follow_speed() -> float:
	return 25.0

func _get_drag_hold_lift() -> float:
	return _drag_controller.drag_hold_lift

func can_highlight_on_hover() -> bool:
	return true

func handle_immediate_tool_click() -> bool:
	return false

func handle_non_drag_click() -> bool:
	return false

func _on_drag_started() -> void:
	pass

func _instiate(counter: Node3D) -> void:
	counter_origin = counter

func get_working_area_surface_y() -> float:
	return _drag_controller.get_working_area_surface_y()

func _snap_to_working_area() -> void:
	_drag_controller.snap_to_working_area()

func _clamp_to_counter(target_position: Vector3) -> Vector3:
	return _drag_controller.clamp_to_counter(target_position)

func _get_free_drag_target(delta: float) -> Vector3:
	return _drag_controller.get_free_drag_target(delta, _get_drag_hold_lift())

func _get_counter_drag_target() -> Vector3:
	return _drag_controller.get_counter_drag_target()

func _get_saved_counter_position(saved_pos: Vector3) -> Vector3:
	return _drag_controller.get_saved_counter_position(saved_pos)

func _get_counter_drop_position(fallback_pos: Vector3) -> Vector3:
	return _drag_controller.get_counter_drop_position(fallback_pos)

func _return_to_counter_smoothly(target_pos: Vector3, duration: float = 0.3) -> void:
	_drag_controller.return_to_counter_smoothly(target_pos, duration, _on_returning_to_counter, _on_returned_to_counter)

func _on_returning_to_counter(_target_pos: Vector3) -> void:
	pass

func _on_returned_to_counter(_target_pos: Vector3) -> void:
	pass

func _post_process_counter_constraints() -> void:
	_drag_controller.post_process_counter_constraints(_is_drag_blocked(), get_drag_mode(), DragMode.COLLISION)

func start_drag_from_spawn(press_screen_pos: Vector2, from_shelf: bool = false) -> void:
	_drag_controller.is_returning_to_counter = false
	_drag_controller.kill_return_tween()
	_drag_controller.capture_drag_depth()
	_drag_controller.waiting_for_working_area = from_shelf and is_working_area_item() and (not GameState.gameplay_ui or GameState.gameplay_ui.down)
	_drag_controller.active_drag_mode = get_drag_mode()
	_drag_controller.is_mode_transitioning = false
	_pointer_down_pos = press_screen_pos
	_is_pointer_pressed = true
	_has_dragged = false
	is_balls_dragging = true
	GameEvents.hand_cursor_changed.emit("holding")

func _process(delta: float) -> void:
	if _is_pointer_pressed:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_drag_or_click()
			return

		var current_mouse := get_viewport().get_mouse_position()
		if not _has_dragged and current_mouse.distance_to(_pointer_down_pos) > DRAG_THRESHOLD:
			_has_dragged = true
			if active_selected_item == self:
				set_selected(false)
				active_selected_item = null
			GameEvents.hand_cursor_changed.emit("holding")

	if _is_drag_blocked():
		return

	if is_balls_dragging:
		var mode: DragMode = get_drag_mode()
		var target_pos := _get_counter_drag_target() if mode == DragMode.COLLISION else _get_free_drag_target(delta)
		_drag_controller.step_drag_movement(delta, mode, target_pos, _get_drag_follow_speed())
		_face_camera()
		_update_drag_hover()

	if get_drag_mode() == DragMode.COLLISION and not _is_returning_to_counter and not _is_mode_transitioning:
		call_deferred("_post_process_counter_constraints")

func _update_drag_hover() -> void:
	var collider: Object = DragController.get_ray_collider_under_mouse(get_viewport(), get_rid())
	var target: Ingredients = collider as Ingredients if collider is Ingredients else null
	var npc: Base_NPC = null
	if collider is Node:
		var parent_node := (collider as Node).get_parent()
		if parent_node is Base_NPC:
			npc = parent_node as Base_NPC

	if target != current_hovered_target:
		if is_instance_valid(current_hovered_target) and current_hovered_target != active_selected_item:
			current_hovered_target.set_highlight(false)
		current_hovered_target = target
		if is_instance_valid(current_hovered_target) and can_interact_with(current_hovered_target):
			current_hovered_target.set_highlight(true)

	if npc != current_hovered_npc:
		if is_instance_valid(current_hovered_npc):
			current_hovered_npc.set_highlight(false)
		current_hovered_npc = npc
		if is_instance_valid(current_hovered_npc) and can_serve_npc(current_hovered_npc):
			current_hovered_npc.set_highlight(true)

func _face_camera() -> void:
	if not camera:
		return
	var visual: Node3D = get_node_or_null("Inside")
	if not visual:
		visual = get_node_or_null("Sprite3D")
	if visual:
		var target_flat := camera.global_position
		target_flat.y = visual.global_position.y
		if target_flat.distance_squared_to(visual.global_position) > 0.0001:
			visual.look_at(target_flat, Vector3.UP)

func _finish_drag_or_click() -> void:
	_is_pointer_pressed = false
	is_balls_dragging = false
	_drag_controller.is_mode_transitioning = false
	_drag_controller.waiting_for_working_area = false
	GameEvents.hand_cursor_changed.emit("idle")

	if not _has_dragged and handle_non_drag_click():
		if is_instance_valid(current_hovered_npc):
			current_hovered_npc.set_highlight(false)
		current_hovered_npc = null
		if is_instance_valid(current_hovered_target):
			current_hovered_target.set_highlight(false)
		current_hovered_target = null
		_has_dragged = false
		return

	var collider: Object = DragController.get_ray_collider_under_mouse(get_viewport(), get_rid())
	var npc: Base_NPC = current_hovered_npc if is_instance_valid(current_hovered_npc) else null
	if npc == null and collider is Node:
		var parent_node := (collider as Node).get_parent()
		if parent_node is Base_NPC:
			npc = parent_node as Base_NPC

	if is_instance_valid(npc) and can_serve_npc(npc):
		current_hovered_npc = null
		npc.set_highlight(false)
		if is_instance_valid(current_hovered_target):
			current_hovered_target.set_highlight(false)
		current_hovered_target = null
		execute_npc_interaction(npc)
		_has_dragged = false
		return

	if is_instance_valid(current_hovered_npc):
		current_hovered_npc.set_highlight(false)
	current_hovered_npc = null

	var target: Ingredients = current_hovered_target if is_instance_valid(current_hovered_target) else null
	if not target and collider is Ingredients:
		target = collider as Ingredients

	if target and can_interact_with(target):
		current_hovered_target = null
		target.set_highlight(false)
		execute_interaction(target)
	else:
		if is_instance_valid(current_hovered_target):
			current_hovered_target.set_highlight(false)
		current_hovered_target = null
		on_drop_failed()
	_has_dragged = false

func _on_area_3d_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if _is_drag_blocked():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if handle_immediate_tool_click():
			get_viewport().set_input_as_handled()
			return

		if active_selected_item != null and active_selected_item != self:
			if active_selected_item.can_interact_with(self):
				var actor := active_selected_item
				actor.set_selected(false)
				active_selected_item = null
				actor.execute_interaction(self)
				get_viewport().set_input_as_handled()
				return
			else:
				active_selected_item.set_selected(false)
				active_selected_item = null

		_on_drag_started()
		_drag_controller.is_returning_to_counter = false
		_drag_controller.kill_return_tween()
		_drag_controller.capture_drag_depth()
		_drag_controller.waiting_for_working_area = false
		_drag_controller.active_drag_mode = get_drag_mode()
		_drag_controller.is_mode_transitioning = false
		_pointer_down_pos = get_viewport().get_mouse_position()
		_is_pointer_pressed = true
		_has_dragged = false
		is_balls_dragging = true
		GameEvents.hand_cursor_changed.emit("holding")
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if active_selected_item:
			active_selected_item.set_selected(false)
			active_selected_item = null
			GameEvents.hand_cursor_changed.emit("idle")

func _on_area_3d_mouse_entered() -> void:
	if active_dragging_item != null:
		return
	if not is_balls_dragging:
		current_hovered_target = self
		if active_selected_item != null and active_selected_item != self:
			if active_selected_item.can_interact_with(self) and can_highlight_on_hover():
				set_highlight(true)
		elif can_highlight_on_hover():
			set_highlight(true)
			GameEvents.hand_cursor_changed.emit("interact")

func _on_area_3d_mouse_exited() -> void:
	if active_dragging_item != null:
		return
	if not is_balls_dragging and current_hovered_target == self:
		current_hovered_target = null
	if not is_selected:
		set_highlight(false)
	if not is_balls_dragging and not active_selected_item:
		GameEvents.hand_cursor_changed.emit("idle")

func set_selected(selected: bool) -> void:
	is_selected = selected
	set_highlight(selected)
	var target_y := base_y_position + 0.15 if selected else base_y_position
	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", target_y, 0.15)

func set_highlight(enabled: bool) -> void:
	_highlight_helper.set_highlight(enabled)

func can_interact_with(_target: Ingredients) -> bool:
	return false

func execute_interaction(_target: Ingredients) -> void:
	pass

func can_serve_npc(_npc: Base_NPC) -> bool:
	return false

func execute_npc_interaction(_npc: Base_NPC) -> void:
	pass

func on_drop_failed() -> void:
	pass