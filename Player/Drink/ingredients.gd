extends Area3D
class_name Ingredients

# base class for all pickable and draggable 3d items (glasses, bottles, shakers, receipts)

enum DragMode { FREE, COLLISION }

static var active_selected_item: Ingredients = null
static var active_dragging_item: Ingredients = null
static var current_hovered_target: Ingredients = null
static var current_hovered_npc: Base_NPC = null
static var _cached_query: PhysicsRayQueryParameters3D = null

var is_balls_dragging: bool = false:
	set(value):
		is_balls_dragging = value
		if value:
			active_dragging_item = self
		elif active_dragging_item == self:
			active_dragging_item = null

var is_selected: bool = false
var is_preview_only: bool = false
var camera: Camera3D
@export var counter_origin: Node3D
@export var area_body: CollisionShape3D
@export var hold_lift: float = 0.25
@export var snap_to_glass: bool = false
@export var snap_offset: Vector3 = Vector3(0, 0.5, 0)
@export var follow_speed: float = 25.0

var base_y_position: float = 1.6
var drag_height: float = 1.6
var in_game: bool = false
var _last_counter_position: Vector3 = Vector3.ZERO

var _pointer_down_pos: Vector2 = Vector2.ZERO
var _is_pointer_pressed: bool = false
var _has_dragged: bool = false
const DRAG_THRESHOLD: float = 4.0

var _original_modulates: Dictionary = {}
var _highlight_visuals: Array[Node] = []
var _explicit_highlight: Node3D = null

var _drag_grab_depth: float = 0.0
var _drag_current_depth: float = 0.0
var _drag_return_tween: Tween = null
var _is_returning_to_counter: bool = false
var _waiting_for_working_area: bool = false

var _active_drag_mode: DragMode = DragMode.FREE
var _is_mode_transitioning: bool = false
var _mode_transition_elapsed: float = 0.0
var _mode_transition_duration: float = 0.35
var _mode_transition_start_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	if not is_preview_only:
		add_to_group("interactable")
	camera = get_viewport().get_camera_3d()
	if not input_event.is_connected(_on_area_3d_input_event):
		input_event.connect(_on_area_3d_input_event)
	if not mouse_entered.is_connected(_on_area_3d_mouse_entered):
		mouse_entered.connect(_on_area_3d_mouse_entered)
	if not mouse_exited.is_connected(_on_area_3d_mouse_exited):
		mouse_exited.connect(_on_area_3d_mouse_exited)
	_cache_visual_nodes()
	_setup_render_priority()
	ready()

func _setup_render_priority() -> void:
	for node in find_children("*", "VisualInstance3D", true, false):
		if node is Sprite3D:
			node.render_priority = 1
		elif node is GeometryInstance3D:
			node.sorting_offset = 1.0
	var outside = get_node_or_null("Inside/Outside")
	if outside and outside is Sprite3D:
		outside.render_priority = 2
	if _explicit_highlight and _explicit_highlight is Sprite3D:
		_explicit_highlight.render_priority = 3

func ready() -> void:
	pass

func is_working_area_item() -> bool:
	return false

# counter items use constrained collision mode when the camera is looking down at the bar
func get_drag_mode() -> DragMode:
	if is_working_area_item() and not _waiting_for_working_area and (not GameState.gameplay_ui or (GameState.gameplay_ui.down and not GameState.gameplay_ui.is_transitioning)):
		return DragMode.COLLISION
	return DragMode.FREE

func uses_working_area_drag_plane() -> bool:
	return get_drag_mode() == DragMode.COLLISION

func _is_drag_blocked() -> bool:
	return in_game or is_preview_only

func _get_drag_follow_speed() -> float:
	return follow_speed

func _get_drag_hold_lift() -> float:
	return hold_lift

func can_highlight_on_hover() -> bool:
	return true

func handle_immediate_tool_click() -> bool:
	return false

func _on_drag_started() -> void:
	pass

func _begin_mode_transition(new_mode: DragMode) -> void:
	_active_drag_mode = new_mode
	_is_mode_transitioning = true
	_mode_transition_elapsed = 0.0
	_mode_transition_start_pos = global_position

func _is_pointer_over_working_area() -> bool:
	if not camera:
		camera = get_viewport().get_camera_3d()
	return WorkingAreaService.is_pointer_over_working_area(camera, get_working_area_surface_y(), self, counter_origin)

func _get_drag_collision_bounds() -> AABB:
	var visual_bounds = _get_combined_visual_world_bounds()
	if visual_bounds is AABB and (visual_bounds as AABB).size != Vector3.ZERO:
		return visual_bounds
	var mesh_bounds = WorkingAreaService.compute_node_world_bounds(self)
	if mesh_bounds is AABB and (mesh_bounds as AABB).size != Vector3.ZERO:
		return mesh_bounds
	return AABB(global_position - Vector3(0.08, 0.12, 0.08), Vector3(0.16, 0.24, 0.16))

func _resolve_bar_collisions() -> void:
	var push := WorkingAreaService.resolve_bar_collisions(_get_drag_collision_bounds(), self)
	if push.length_squared() > 0.0000001:
		global_position += push

func _post_process_counter_constraints() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if _is_drag_blocked() or _is_returning_to_counter or _is_mode_transitioning or get_drag_mode() != DragMode.COLLISION:
		return
	if absf(global_position.y - get_working_area_surface_y()) > 0.15:
		return

	var current_y := global_position.y
	var clamped := _clamp_to_counter(global_position)
	clamped.y = current_y
	global_position = clamped
	_resolve_bar_collisions()
	clamped = _clamp_to_counter(global_position)
	clamped.y = current_y
	global_position = clamped

func _get_visual_sprite_nodes() -> Array[Sprite3D]:
	var visual_sprites: Array[Sprite3D] = []
	var inside_node := get_node_or_null("Inside")
	if inside_node is Sprite3D:
		visual_sprites.append(inside_node)
		var outside_node := inside_node.get_node_or_null("Outside")
		if outside_node is Sprite3D:
			visual_sprites.append(outside_node)
	else:
		var root_sprite := get_node_or_null("Sprite3D")
		if root_sprite is Sprite3D:
			visual_sprites.append(root_sprite)
	return visual_sprites

func _get_combined_visual_world_bounds() -> Variant:
	var bounds_found: bool = false
	var total_visual_bounds := AABB()
	for s in _get_visual_sprite_nodes():
		var b = WorkingAreaService.get_sprite_world_bounds(s)
		if b is AABB:
			if not bounds_found:
				total_visual_bounds = b
				bounds_found = true
			else:
				total_visual_bounds = total_visual_bounds.merge(b)
	return total_visual_bounds if bounds_found else null

func _get_working_area_bottom_offset() -> float:
	var visual_bounds = _get_combined_visual_world_bounds()
	if visual_bounds is AABB:
		return global_position.y - (visual_bounds as AABB).position.y
	return 0.0

func _get_working_area_horizontal_extents() -> Vector2:
	var visual_bounds = _get_combined_visual_world_bounds()
	if visual_bounds is AABB:
		var b_size: Vector3 = (visual_bounds as AABB).size
		return Vector2(b_size.x * 0.5, b_size.z * 0.5)
	return Vector2.ZERO

func get_working_area_surface_y() -> float:
	var surface_bounds = WorkingAreaService.get_working_area_bounds(self)
	if surface_bounds is AABB:
		return (surface_bounds as AABB).end.y + _get_working_area_bottom_offset()
	return base_y_position

func _snap_to_working_area() -> void:
	var surface_bounds = WorkingAreaService.get_working_area_bounds(self)
	if surface_bounds is AABB:
		var target_y := (surface_bounds as AABB).end.y + _get_working_area_bottom_offset()
		var clamped := _clamp_to_counter(global_position)
		clamped.y = target_y
		global_position = clamped
		base_y_position = target_y

func _cache_visual_nodes() -> void:
	_explicit_highlight = get_node_or_null("Inside/highlight")
	if not _explicit_highlight:
		_explicit_highlight = get_node_or_null("highlight")
	if _explicit_highlight:
		return

	for child_name in ["Inside", "Sprite3D", "PaperMesh", "Base_viewport"]:
		var node := get_node_or_null(child_name)
		if node:
			_highlight_visuals.append(node)
	if _highlight_visuals.is_empty():
		for child in get_children():
			if child is Sprite3D or child is MeshInstance3D:
				_highlight_visuals.append(child)

func _instiate(counter: Node3D) -> void:
	counter_origin = counter

# captures initial pickup distance along camera forward axis
func _capture_drag_depth() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var forward: Vector3 = -camera.global_transform.basis.z
	var raw_depth := (global_position - camera.global_position).dot(forward)
	_drag_grab_depth = clampf(raw_depth, 0.9, 3.2)
	_drag_current_depth = _drag_grab_depth

# projects cursor to 3d depth when moving freely in 3d view
func _get_free_drag_target(delta: float) -> Vector3:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return global_position
	if snap_to_glass and is_instance_valid(current_hovered_target) and can_interact_with(current_hovered_target):
		var to_cam := (camera.global_position - current_hovered_target.global_position).normalized()
		return current_hovered_target.global_position + snap_offset + to_cam * _get_drag_hold_lift()
	var mouse_pos := get_viewport().get_mouse_position()
	var target_depth := maxf(_drag_grab_depth - _get_drag_hold_lift(), 0.85)
	_drag_current_depth = lerpf(_drag_current_depth, target_depth, 1.0 - exp(-12.0 * delta))
	return camera.project_position(mouse_pos, _drag_current_depth)

# raycasts cursor to table plane when looking down at the counter
func _get_counter_drag_target() -> Vector3:
	var surface_y := get_working_area_surface_y()
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		var fallback := _clamp_to_counter(global_position)
		fallback.y = surface_y
		return fallback

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var forward := -camera.global_transform.basis.z

	var intersection = Plane(Vector3.UP, surface_y).intersects_ray(from, dir)
	if intersection != null:
		var to_hit: Vector3 = intersection - from
		if to_hit.dot(forward) > 0.0 and to_hit.length() <= 5.0:
			var clamped_hit := _clamp_to_counter(intersection)
			clamped_hit.y = surface_y
			return clamped_hit

	var clamped_cur := _clamp_to_counter(global_position)
	clamped_cur.y = surface_y
	return clamped_cur

func _get_saved_counter_position(saved_pos: Vector3) -> Vector3:
	var drag_surface_y := get_working_area_surface_y()
	var clamped_saved := _clamp_to_counter(saved_pos)
	clamped_saved.y = drag_surface_y
	return clamped_saved

func _get_counter_drop_position(fallback_pos: Vector3) -> Vector3:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if camera and (not GameState.gameplay_ui or (GameState.gameplay_ui.down and not GameState.gameplay_ui.is_transitioning)):
		return _get_counter_drag_target()
	return _get_saved_counter_position(fallback_pos)

func _return_to_counter_smoothly(target_pos: Vector3, duration: float = 0.3) -> void:
	if not is_inside_tree():
		return
	_is_returning_to_counter = true
	_on_returning_to_counter(target_pos)
	if _drag_return_tween and _drag_return_tween.is_valid():
		_drag_return_tween.kill()
	_drag_return_tween = get_tree().create_tween()
	_drag_return_tween.set_trans(Tween.TRANS_SINE)
	_drag_return_tween.set_ease(Tween.EASE_OUT)
	_drag_return_tween.tween_property(self, "global_position", target_pos, duration)
	_drag_return_tween.finished.connect(func():
		_is_returning_to_counter = false
		base_y_position = target_pos.y
		_on_returned_to_counter(target_pos)
	)

func _on_returning_to_counter(target_pos: Vector3) -> void:
	if is_working_area_item():
		_last_counter_position = target_pos

func _on_returned_to_counter(target_pos: Vector3) -> void:
	if is_working_area_item():
		_last_counter_position = target_pos

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
	if is_working_area_item():
		var target_pos: Vector3 = _get_saved_counter_position(_last_counter_position)
		if global_position.distance_to(target_pos) > 0.005:
			_return_to_counter_smoothly(target_pos)
		else:
			global_position = target_pos
			base_y_position = target_pos.y
			_last_counter_position = target_pos

func start_drag_from_spawn(press_screen_pos: Vector2, from_shelf: bool = false) -> void:
	_is_returning_to_counter = false
	if _drag_return_tween and _drag_return_tween.is_valid():
		_drag_return_tween.kill()
	_capture_drag_depth()
	_waiting_for_working_area = from_shelf and is_working_area_item() and (not GameState.gameplay_ui or GameState.gameplay_ui.down)
	_active_drag_mode = get_drag_mode()
	_is_mode_transitioning = false
	_pointer_down_pos = press_screen_pos
	_is_pointer_pressed = true
	_has_dragged = false
	is_balls_dragging = true
	if GameState.player:
		GameState.player._update_hand("holding")

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
			if GameState.player:
				GameState.player._update_hand("holding")

	if _is_drag_blocked():
		return

	if is_balls_dragging:
		if _waiting_for_working_area:
			if GameState.gameplay_ui and not GameState.gameplay_ui.down:
				_waiting_for_working_area = false
			elif _is_pointer_over_working_area():
				_waiting_for_working_area = false

		var mode: DragMode = get_drag_mode()
		if mode != _active_drag_mode:
			_begin_mode_transition(mode)

		var target_pos := _get_counter_drag_target() if mode == DragMode.COLLISION else _get_free_drag_target(delta)
		if _is_mode_transitioning:
			_mode_transition_elapsed += delta
			var t := clampf(_mode_transition_elapsed / maxf(_mode_transition_duration, 0.001), 0.0, 1.0)
			var ease_t := t * t * (3.0 - 2.0 * t)
			global_position = _mode_transition_start_pos.lerp(target_pos, ease_t)
			if t >= 1.0:
				_is_mode_transitioning = false
		else:
			global_position = global_position.lerp(target_pos, 1.0 - exp(-_get_drag_follow_speed() * delta))

		_face_camera()
		_update_drag_hover()
	elif is_working_area_item() and camera:
		_face_camera()

	if get_drag_mode() == DragMode.COLLISION and not _is_returning_to_counter and not _is_mode_transitioning:
		if is_working_area_item():
			_on_working_area_step(delta)
		call_deferred("_post_process_counter_constraints")

func _on_working_area_step(delta: float) -> void:
	if not is_balls_dragging:
		_settle_on_working_area(delta)

func _settle_on_working_area(delta: float) -> void:
	if not is_selected:
		var target_y := get_working_area_surface_y()
		base_y_position = target_y
		if absf(global_position.y - target_y) <= 0.002:
			global_position.y = target_y
		else:
			global_position.y = lerpf(global_position.y, target_y, 1.0 - exp(-20.0 * delta))
	_last_counter_position = global_position
	_on_working_area_settled()

func _on_working_area_settled() -> void:
	pass

func _update_drag_hover() -> void:
	var collider: Object = _get_ray_collider_under_mouse(get_viewport(), get_rid())
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

static func _get_ray_collider_under_mouse(viewport: Viewport, exclude_rid: RID = RID()) -> Object:
	var cam: Camera3D = viewport.get_camera_3d()
	if not cam:
		return null
	var mouse_pos := viewport.get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * 100.0

	if not _cached_query:
		_cached_query = PhysicsRayQueryParameters3D.new()
		_cached_query.collide_with_areas = true
		_cached_query.collide_with_bodies = false

	_cached_query.from = from
	_cached_query.to = to
	_cached_query.exclude = [exclude_rid] if exclude_rid.is_valid() else []

	var result := cam.get_world_3d().direct_space_state.intersect_ray(_cached_query)
	return result.collider if result else null

static func get_interactable_under_mouse(viewport: Viewport, exclude_rid: RID = RID()) -> Ingredients:
	var collider: Object = _get_ray_collider_under_mouse(viewport, exclude_rid)
	return collider as Ingredients if collider is Ingredients else null

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

func handle_non_drag_click() -> bool:
	return false

# finishes drag drop double dispatch check on mouse release
func _finish_drag_or_click() -> void:
	_is_pointer_pressed = false
	is_balls_dragging = false
	_is_mode_transitioning = false
	_waiting_for_working_area = false
	if GameState.player:
		GameState.player._update_hand("idle")

	if not _has_dragged and handle_non_drag_click():
		if is_instance_valid(current_hovered_npc):
			current_hovered_npc.set_highlight(false)
		current_hovered_npc = null
		if is_instance_valid(current_hovered_target):
			current_hovered_target.set_highlight(false)
		current_hovered_target = null
		_has_dragged = false
		return

	var collider: Object = _get_ray_collider_under_mouse(get_viewport(), get_rid())
	var npc: Base_NPC = current_hovered_npc if is_instance_valid(current_hovered_npc) else null
	if npc == null and collider is Node:
		var parent_node := (collider as Node).get_parent()
		if parent_node is Base_NPC:
			npc = parent_node as Base_NPC

	# check customer serving interaction first
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

	# double dispatch onto target ingredient or appliance
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

func _clamp_to_counter(target_position: Vector3) -> Vector3:
	return WorkingAreaService.clamp_to_counter(target_position, _get_working_area_horizontal_extents(), self, counter_origin)

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
		_is_returning_to_counter = false
		if _drag_return_tween and _drag_return_tween.is_valid():
			_drag_return_tween.kill()
		_capture_drag_depth()
		_waiting_for_working_area = false
		_active_drag_mode = get_drag_mode()
		_is_mode_transitioning = false
		_pointer_down_pos = get_viewport().get_mouse_position()
		_is_pointer_pressed = true
		_has_dragged = false
		is_balls_dragging = true
		if GameState.player:
			GameState.player._update_hand("holding")
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if active_selected_item:
			active_selected_item.set_selected(false)
			active_selected_item = null
			if GameState.player:
				GameState.player._update_hand("idle")

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
			if GameState.player:
				GameState.player._update_hand("interact")

func _on_area_3d_mouse_exited() -> void:
	if active_dragging_item != null:
		return
	if not is_balls_dragging and current_hovered_target == self:
		current_hovered_target = null
	if not is_selected:
		set_highlight(false)
	if not is_balls_dragging and not active_selected_item and GameState.player:
		GameState.player._update_hand("idle")

func set_selected(selected: bool) -> void:
	is_selected = selected
	set_highlight(selected)
	var target_y := base_y_position + 0.15 if selected else base_y_position
	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", target_y, 0.15)

func set_highlight(enabled: bool) -> void:
	if _explicit_highlight:
		_explicit_highlight.visible = enabled
		return

	for visual in _highlight_visuals:
		var node_id := visual.get_instance_id()
		if enabled:
			if visual is Sprite3D:
				if not _original_modulates.has(node_id):
					_original_modulates[node_id] = visual.modulate
				visual.modulate = _original_modulates[node_id] * Color(1.5, 1.5, 0.4, 1.0)
			elif visual is MeshInstance3D:
				if not _original_modulates.has(node_id):
					_original_modulates[node_id] = visual.scale
				visual.scale = _original_modulates[node_id] * Vector3(1.15, 1.15, 1.15)
		else:
			if _original_modulates.has(node_id):
				if visual is Sprite3D:
					visual.modulate = _original_modulates[node_id]
				elif visual is MeshInstance3D:
					visual.scale = _original_modulates[node_id]
				_original_modulates.erase(node_id)

func can_interact_with(_target: Ingredients) -> bool:
	return false

func execute_interaction(_target: Ingredients) -> void:
	pass

func can_serve_npc(_npc: Base_NPC) -> bool:
	return false

func execute_npc_interaction(_npc: Base_NPC) -> void:
	pass

func on_drop_failed() -> void:
	if is_working_area_item():
		var target_pos: Vector3 = _get_counter_drop_position(_last_counter_position) if _has_dragged else _get_saved_counter_position(_last_counter_position)
		_return_to_counter_smoothly(target_pos)