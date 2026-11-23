class_name DragController
extends RefCounted

# mouse raycasting, dragging, obstacle collision, clamp cups to working counter

static var _cached_query: PhysicsRayQueryParameters3D = null

var _owner: Ingredients
var drag_grab_depth: float = 0.0
var drag_current_depth: float = 0.0
var drag_hold_lift: float = 0.25
var drag_return_tween: Tween = null
var is_returning_to_counter: bool = false
var waiting_for_working_area: bool = false

var active_drag_mode: int = 0
var is_mode_transitioning: bool = false
var mode_transition_elapsed: float = 0.0
var mode_transition_duration: float = 0.35
var mode_transition_start_pos: Vector3 = Vector3.ZERO

func _init(owner_node: Ingredients = null) -> void:
	_owner = owner_node

func _ensure_camera() -> Camera3D:
	if not _owner.camera:
		_owner.camera = _owner.get_viewport().get_camera_3d()
	return _owner.camera

func kill_return_tween() -> void:
	if drag_return_tween and drag_return_tween.is_valid():
		drag_return_tween.kill()

func capture_drag_depth() -> void:
	var cam := _ensure_camera()
	if not cam:
		return
	var forward: Vector3 = -cam.global_transform.basis.z
	var raw_depth := (_owner.global_position - cam.global_position).dot(forward)
	drag_grab_depth = clampf(raw_depth, 0.9, 3.2)
	drag_current_depth = drag_grab_depth

func get_free_drag_target(delta: float, hold_lift: float) -> Vector3:
	var cam := _ensure_camera()
	if not cam:
		return _owner.global_position
	var mouse_pos := _owner.get_viewport().get_mouse_position()
	var target_depth := maxf(drag_grab_depth - hold_lift, 0.85)
	drag_current_depth = lerpf(drag_current_depth, target_depth, 1.0 - exp(-12.0 * delta))
	return cam.project_position(mouse_pos, drag_current_depth)

func get_counter_drag_target() -> Vector3:
	var surface_y := get_working_area_surface_y()
	var cam := _ensure_camera()
	if not cam:
		var fallback := clamp_to_counter(_owner.global_position)
		fallback.y = surface_y
		return fallback

	var mouse_pos := _owner.get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var forward := -cam.global_transform.basis.z

	var intersection = Plane(Vector3.UP, surface_y).intersects_ray(from, dir)
	if intersection != null:
		var to_hit: Vector3 = intersection - from
		if to_hit.dot(forward) > 0.0 and to_hit.length() <= 5.0:
			var clamped_hit := clamp_to_counter(intersection)
			clamped_hit.y = surface_y
			return clamped_hit

	var clamped_cur := clamp_to_counter(_owner.global_position)
	clamped_cur.y = surface_y
	return clamped_cur

func begin_mode_transition(new_mode: int) -> void:
	active_drag_mode = new_mode
	is_mode_transitioning = true
	mode_transition_elapsed = 0.0
	mode_transition_start_pos = _owner.global_position

func step_drag_movement(delta: float, mode: int, target_pos: Vector3, follow_speed: float) -> void:
	if waiting_for_working_area:
		if GameState.gameplay_ui and not GameState.gameplay_ui.down:
			waiting_for_working_area = false
		elif is_pointer_over_working_area():
			waiting_for_working_area = false

	if mode != active_drag_mode:
		begin_mode_transition(mode)

	if is_mode_transitioning:
		mode_transition_elapsed += delta
		var t := clampf(mode_transition_elapsed / maxf(mode_transition_duration, 0.001), 0.0, 1.0)
		var ease_t := t * t * (3.0 - 2.0 * t)
		_owner.global_position = mode_transition_start_pos.lerp(target_pos, ease_t)
		if t >= 1.0:
			is_mode_transitioning = false
	else:
		_owner.global_position = _owner.global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))

func is_pointer_over_working_area() -> bool:
	var cam := _ensure_camera()
	return WorkingAreaService.is_pointer_over_working_area(cam, get_working_area_surface_y(), _owner, _owner.counter_origin)

func get_visual_sprite_nodes() -> Array[Sprite3D]:
	var visual_sprites: Array[Sprite3D] = []
	var inside_node := _owner.get_node_or_null("Inside")
	if inside_node is Sprite3D:
		visual_sprites.append(inside_node)
		var outside_node := inside_node.get_node_or_null("Outside")
		if outside_node is Sprite3D:
			visual_sprites.append(outside_node)
	else:
		var root_sprite := _owner.get_node_or_null("Sprite3D")
		if root_sprite is Sprite3D:
			visual_sprites.append(root_sprite)
	return visual_sprites

func get_combined_visual_world_bounds() -> Variant:
	var bounds_found: bool = false
	var total_visual_bounds := AABB()
	for s in get_visual_sprite_nodes():
		var b = WorkingAreaService.get_sprite_world_bounds(s)
		if b is AABB:
			if not bounds_found:
				total_visual_bounds = b
				bounds_found = true
			else:
				total_visual_bounds = total_visual_bounds.merge(b)
	return total_visual_bounds if bounds_found else null

func get_working_area_bottom_offset() -> float:
	var visual_bounds = get_combined_visual_world_bounds()
	if visual_bounds is AABB:
		return _owner.global_position.y - (visual_bounds as AABB).position.y
	return 0.0

func get_working_area_horizontal_extents() -> Vector2:
	var visual_bounds = get_combined_visual_world_bounds()
	if visual_bounds is AABB:
		var b_size: Vector3 = (visual_bounds as AABB).size
		return Vector2(b_size.x * 0.5, b_size.z * 0.5)
	return Vector2.ZERO

func get_working_area_surface_y() -> float:
	var surface_bounds = WorkingAreaService.get_working_area_bounds(_owner)
	if surface_bounds is AABB:
		return (surface_bounds as AABB).end.y + get_working_area_bottom_offset()
	return _owner.base_y_position

func snap_to_working_area() -> void:
	var surface_bounds = WorkingAreaService.get_working_area_bounds(_owner)
	if surface_bounds is AABB:
		var target_y := (surface_bounds as AABB).end.y + get_working_area_bottom_offset()
		var clamped := clamp_to_counter(_owner.global_position)
		clamped.y = target_y
		_owner.global_position = clamped
		_owner.base_y_position = target_y

func get_drag_collision_bounds() -> AABB:
	var visual_bounds = get_combined_visual_world_bounds()
	if visual_bounds is AABB and (visual_bounds as AABB).size != Vector3.ZERO:
		return visual_bounds
	var mesh_bounds = WorkingAreaService.compute_node_world_bounds(_owner)
	if mesh_bounds is AABB and (mesh_bounds as AABB).size != Vector3.ZERO:
		return mesh_bounds
	return AABB(_owner.global_position - Vector3(0.08, 0.12, 0.08), Vector3(0.16, 0.24, 0.16))

func resolve_bar_collisions() -> void:
	var push := WorkingAreaService.resolve_bar_collisions(get_drag_collision_bounds(), _owner)
	if push.length_squared() > 0.0000001:
		_owner.global_position += push

func clamp_to_counter(target_position: Vector3) -> Vector3:
	return WorkingAreaService.clamp_to_counter(target_position, get_working_area_horizontal_extents(), _owner, _owner.counter_origin)

func post_process_counter_constraints(drag_blocked: bool, mode: int, collision_mode: int) -> void:
	if not _owner.is_inside_tree() or _owner.is_queued_for_deletion():
		return
	if drag_blocked or is_returning_to_counter or is_mode_transitioning or mode != collision_mode:
		return
	if absf(_owner.global_position.y - get_working_area_surface_y()) > 0.15:
		return

	var current_y := _owner.global_position.y
	var clamped := clamp_to_counter(_owner.global_position)
	clamped.y = current_y
	_owner.global_position = clamped
	resolve_bar_collisions()
	clamped = clamp_to_counter(_owner.global_position)
	clamped.y = current_y
	_owner.global_position = clamped

func get_saved_counter_position(saved_pos: Vector3) -> Vector3:
	var drag_surface_y := get_working_area_surface_y()
	var clamped_saved := clamp_to_counter(saved_pos)
	clamped_saved.y = drag_surface_y
	return clamped_saved

func get_counter_drop_position(fallback_pos: Vector3) -> Vector3:
	var cam := _ensure_camera()
	if cam and (not GameState.gameplay_ui or (GameState.gameplay_ui.down and not GameState.gameplay_ui.is_transitioning)):
		return get_counter_drag_target()
	return get_saved_counter_position(fallback_pos)

func return_to_counter_smoothly(target_pos: Vector3, duration: float, on_returning: Callable, on_returned: Callable) -> void:
	if not _owner.is_inside_tree():
		return
	is_returning_to_counter = true
	if on_returning.is_valid():
		on_returning.call(target_pos)
	kill_return_tween()
	drag_return_tween = _owner.get_tree().create_tween()
	drag_return_tween.set_trans(Tween.TRANS_SINE)
	drag_return_tween.set_ease(Tween.EASE_OUT)
	drag_return_tween.tween_property(_owner, "global_position", target_pos, duration)
	drag_return_tween.finished.connect(func():
		is_returning_to_counter = false
		_owner.base_y_position = target_pos.y
		if on_returned.is_valid():
			on_returned.call(target_pos)
	)

static func get_ray_collider_under_mouse(viewport: Viewport, exclude_rid: RID = RID()) -> Object:
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