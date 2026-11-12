extends Area3D
class_name Ingredients

static var active_selected_item: Ingredients = null
static var active_dragging_item: Ingredients = null
static var current_hovered_target: Ingredients = null
static var current_hovered_npc: Base_NPC = null
static var _cached_query: PhysicsRayQueryParameters3D = null

static var _working_area_node: Node3D = null
static var _working_area_transform: Transform3D = Transform3D.IDENTITY
static var _working_area_bounds: AABB = AABB()
static var _working_area_has_bounds: bool = false
static var _sprite_opaque_rect_cache: Dictionary = {}

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
var _pointer_down_pos: Vector2 = Vector2.ZERO
var _is_pointer_pressed: bool = false
var _has_dragged: bool = false
const DRAG_THRESHOLD: float = 4.0
var _original_modulates: Dictionary = {}
var _highlight_visuals: Array[Node] = []
var _explicit_highlight: Node3D = null

func _ready() -> void:
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

func uses_working_area_drag_plane() -> bool:
	return true

static func _find_working_area_node(search_root: Node) -> Node3D:
	if not is_instance_valid(search_root):
		return null
	var direct_match := search_root.find_child("Working area", true, false)
	if direct_match is Node3D:
		return direct_match
	var underscore_match := search_root.find_child("Working_area", true, false)
	if underscore_match is Node3D:
		return underscore_match
	for child in search_root.find_children("*", "Node3D", true, false):
		var normalized_name: String = child.name.to_lower().replace("_", " ").strip_edges()
		if normalized_name == "working area":
			return child
	for child in search_root.find_children("*", "Node3D", true, false):
		var normalized_name: String = child.name.to_lower().replace("_", " ").strip_edges()
		if normalized_name.begins_with("working area"):
			return child
	return null

static func _compute_node_world_bounds(target_node: Node3D) -> Variant:
	var bounds_initialized: bool = false
	var calculated_world_bounds: AABB = AABB()
	var mesh_instances: Array[Node] = []
	if target_node is MeshInstance3D:
		mesh_instances.append(target_node)
	mesh_instances.append_array(target_node.find_children("*", "MeshInstance3D", true, false))

	for mesh_node in mesh_instances:
		var current_mesh_instance := mesh_node as MeshInstance3D
		if current_mesh_instance and current_mesh_instance.mesh:
			var local_bounding_box: AABB = current_mesh_instance.mesh.get_aabb()
			var world_transform: Transform3D = current_mesh_instance.global_transform
			for corner_index in 8:
				var corner_position: Vector3 = world_transform * local_bounding_box.get_endpoint(corner_index)
				if not bounds_initialized:
					calculated_world_bounds = AABB(corner_position, Vector3.ZERO)
					bounds_initialized = true
				else:
					calculated_world_bounds = calculated_world_bounds.expand(corner_position)

	if bounds_initialized:
		return calculated_world_bounds

	if target_node is VisualInstance3D:
		var visual_bounding_box: AABB = (target_node as VisualInstance3D).get_aabb()
		if visual_bounding_box.size != Vector3.ZERO:
			var world_transform: Transform3D = target_node.global_transform
			for corner_index in 8:
				var corner_position: Vector3 = world_transform * visual_bounding_box.get_endpoint(corner_index)
				if not bounds_initialized:
					calculated_world_bounds = AABB(corner_position, Vector3.ZERO)
					bounds_initialized = true
				else:
					calculated_world_bounds = calculated_world_bounds.expand(corner_position)

	return calculated_world_bounds if bounds_initialized else null

static func get_working_area_bounds(calling_context: Node) -> Variant:
	if not is_instance_valid(calling_context) or not calling_context.is_inside_tree():
		return null
	var scene_tree := calling_context.get_tree()
	if not scene_tree:
		return null

	if not is_instance_valid(_working_area_node) or not _working_area_node.is_inside_tree() or _working_area_node.get_tree() != scene_tree:
		_working_area_node = null
		_working_area_has_bounds = false

		var candidate_roots: Array[Node] = []
		var current_ancestor: Node = calling_context
		while current_ancestor.get_parent() and current_ancestor.get_parent() != scene_tree.root:
			current_ancestor = current_ancestor.get_parent()
		candidate_roots.append(current_ancestor)
		if scene_tree.current_scene and not candidate_roots.has(scene_tree.current_scene):
			candidate_roots.append(scene_tree.current_scene)
		if scene_tree.root and not candidate_roots.has(scene_tree.root):
			candidate_roots.append(scene_tree.root)

		for root_candidate in candidate_roots:
			_working_area_node = _find_working_area_node(root_candidate)
			if _working_area_node:
				break

	if not is_instance_valid(_working_area_node):
		return null

	if _working_area_has_bounds and _working_area_node.global_transform == _working_area_transform:
		return _working_area_bounds

	var recalculated_bounds = _compute_node_world_bounds(_working_area_node)
	if recalculated_bounds is AABB:
		_working_area_transform = _working_area_node.global_transform
		_working_area_bounds = recalculated_bounds
		_working_area_has_bounds = true
		return _working_area_bounds

	return null

static func get_working_area_aabb(calling_context: Node) -> Variant:
	return get_working_area_bounds(calling_context)

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

func _get_sprite_world_bounds(target_sprite: Sprite3D) -> Variant:
	if not is_instance_valid(target_sprite) or target_sprite.texture == null:
		return null
	var sprite_dimensions: Rect2 = target_sprite.get_item_rect()
	if sprite_dimensions.size.x <= 0.0 or sprite_dimensions.size.y <= 0.0:
		return null

	var left_padding_pixels: float = 0.0
	var right_padding_pixels: float = 0.0
	var bottom_padding_pixels: float = 0.0
	var top_padding_pixels: float = 0.0

	if target_sprite.hframes == 1 and target_sprite.vframes == 1 and not target_sprite.region_enabled:
		var texture_identifier: int = target_sprite.texture.get_rid().get_id()
		var opaque_pixel_rect: Rect2i
		var texture_dimensions: Vector2i
		if _sprite_opaque_rect_cache.has(texture_identifier):
			var cached_data: Dictionary = _sprite_opaque_rect_cache[texture_identifier]
			opaque_pixel_rect = cached_data["used"]
			texture_dimensions = cached_data["size"]
		else:
			var source_image: Image = target_sprite.texture.get_image()
			if source_image != null and not source_image.is_empty():
				opaque_pixel_rect = source_image.get_used_rect()
				texture_dimensions = source_image.get_size()
			else:
				opaque_pixel_rect = Rect2i()
				texture_dimensions = Vector2i.ZERO
			_sprite_opaque_rect_cache[texture_identifier] = {"used": opaque_pixel_rect, "size": texture_dimensions}

		if opaque_pixel_rect.size.x > 0 and opaque_pixel_rect.size.y > 0 and texture_dimensions.x > 0 and texture_dimensions.y > 0:
			var scale_x: float = sprite_dimensions.size.x / float(texture_dimensions.x)
			var scale_y: float = sprite_dimensions.size.y / float(texture_dimensions.y)
			if target_sprite.flip_h:
				left_padding_pixels = float(texture_dimensions.x - opaque_pixel_rect.end.x) * scale_x
				right_padding_pixels = float(opaque_pixel_rect.position.x) * scale_x
			else:
				left_padding_pixels = float(opaque_pixel_rect.position.x) * scale_x
				right_padding_pixels = float(texture_dimensions.x - opaque_pixel_rect.end.x) * scale_x
			if target_sprite.flip_v:
				bottom_padding_pixels = float(opaque_pixel_rect.position.y) * scale_y
				top_padding_pixels = float(texture_dimensions.y - opaque_pixel_rect.end.y) * scale_y
			else:
				bottom_padding_pixels = float(texture_dimensions.y - opaque_pixel_rect.end.y) * scale_y
				top_padding_pixels = float(opaque_pixel_rect.position.y) * scale_y

	var pixel_scale: float = target_sprite.pixel_size
	var min_local_x: float = (sprite_dimensions.position.x + left_padding_pixels) * pixel_scale
	var max_local_x: float = (sprite_dimensions.end.x - right_padding_pixels) * pixel_scale
	var min_local_y: float = (sprite_dimensions.position.y + bottom_padding_pixels) * pixel_scale
	var max_local_y: float = (sprite_dimensions.end.y - top_padding_pixels) * pixel_scale

	var quad_corners: Array[Vector3]
	match target_sprite.axis:
		Vector3.AXIS_X:
			quad_corners = [
				Vector3(0.0, min_local_y, min_local_x), Vector3(0.0, min_local_y, max_local_x),
				Vector3(0.0, max_local_y, min_local_x), Vector3(0.0, max_local_y, max_local_x)
			]
		Vector3.AXIS_Y:
			quad_corners = [
				Vector3(min_local_x, 0.0, min_local_y), Vector3(max_local_x, 0.0, min_local_y),
				Vector3(min_local_x, 0.0, max_local_y), Vector3(max_local_x, 0.0, max_local_y)
			]
		_:
			quad_corners = [
				Vector3(min_local_x, min_local_y, 0.0), Vector3(max_local_x, min_local_y, 0.0),
				Vector3(min_local_x, max_local_y, 0.0), Vector3(max_local_x, max_local_y, 0.0)
			]

	var sprite_world_transform: Transform3D = target_sprite.global_transform
	var bounding_box := AABB(sprite_world_transform * quad_corners[0], Vector3.ZERO)
	for corner_index in range(1, quad_corners.size()):
		bounding_box = bounding_box.expand(sprite_world_transform * quad_corners[corner_index])
	return bounding_box

func _get_combined_visual_world_bounds() -> Variant:
	var bounds_found: bool = false
	var total_visual_bounds: AABB = AABB()
	for visual_sprite in _get_visual_sprite_nodes():
		var sprite_bounds = _get_sprite_world_bounds(visual_sprite)
		if sprite_bounds is AABB:
			if not bounds_found:
				total_visual_bounds = sprite_bounds
				bounds_found = true
			else:
				total_visual_bounds = total_visual_bounds.merge(sprite_bounds)
	return total_visual_bounds if bounds_found else null

func _get_working_area_bottom_offset() -> float:
	var visual_bounds = _get_combined_visual_world_bounds()
	if visual_bounds is AABB:
		return global_position.y - (visual_bounds as AABB).position.y
	return 0.0

func _get_working_area_horizontal_extents() -> Vector2:
	var visual_bounds = _get_combined_visual_world_bounds()
	if visual_bounds is AABB:
		var bounds_size: Vector3 = (visual_bounds as AABB).size
		return Vector2(bounds_size.x * 0.5, bounds_size.z * 0.5)
	return Vector2.ZERO

func get_working_area_surface_y() -> float:
	var surface_bounds = get_working_area_bounds(self)
	if surface_bounds is AABB:
		return (surface_bounds as AABB).end.y + _get_working_area_bottom_offset()
	return base_y_position

func _snap_to_working_area() -> void:
	var surface_bounds = get_working_area_bounds(self)
	if surface_bounds is AABB:
		var target_y: float = (surface_bounds as AABB).end.y + _get_working_area_bottom_offset()
		var clamped_position: Vector3 = _clamp_to_counter(global_position)
		clamped_position.y = target_y
		global_position = clamped_position
		base_y_position = target_y

func _cache_visual_nodes() -> void:
	_explicit_highlight = get_node_or_null("Inside/highlight")
	if not _explicit_highlight:
		_explicit_highlight = get_node_or_null("highlight")
	if _explicit_highlight:
		return

	var inside_sprite = get_node_or_null("Inside")
	if inside_sprite:
		_highlight_visuals.append(inside_sprite)
	var root_sprite = get_node_or_null("Sprite3D")
	if root_sprite:
		_highlight_visuals.append(root_sprite)
	var paper_mesh = get_node_or_null("PaperMesh")
	if paper_mesh:
		_highlight_visuals.append(paper_mesh)
	var base_viewport = get_node_or_null("Base_viewport")
	if base_viewport:
		_highlight_visuals.append(base_viewport)

	if _highlight_visuals.is_empty():
		for child in get_children():
			if child is Sprite3D or child is MeshInstance3D:
				_highlight_visuals.append(child)

func _instiate(counter: Node3D) -> void:
	counter_origin = counter

func start_drag_from_spawn(press_screen_pos: Vector2) -> void:
	_pointer_down_pos = press_screen_pos
	_is_pointer_pressed = true
	_has_dragged = false
	is_balls_dragging = true
	if GameState.player:
		GameState.player._update_hand("holding")

func _process(_delta: float) -> void:
	if _is_pointer_pressed:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_drag_or_click()
			return

		var current_mouse: Vector2 = get_viewport().get_mouse_position()
		if not _has_dragged and current_mouse.distance_to(_pointer_down_pos) > DRAG_THRESHOLD:
			_has_dragged = true
			if active_selected_item == self:
				set_selected(false)
				active_selected_item = null
			if GameState.player:
				GameState.player._update_hand("holding")

	if is_balls_dragging:
		if uses_working_area_drag_plane():
			var drag_surface_y: float = get_working_area_surface_y()
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			var intersection = _get_drag_point(mouse_pos, drag_surface_y)
			if intersection != null:
				var clamped_point: Vector3 = _clamp_to_counter(intersection)
				clamped_point.y = drag_surface_y
				global_position = clamped_point
			_face_camera()
		_update_drag_hover()

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
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var to: Vector3 = from + cam.project_ray_normal(mouse_pos) * 100.0

	if not _cached_query:
		_cached_query = PhysicsRayQueryParameters3D.new()
		_cached_query.collide_with_areas = true
		_cached_query.collide_with_bodies = false

	_cached_query.from = from
	_cached_query.to = to
	if exclude_rid.is_valid():
		_cached_query.exclude = [exclude_rid]
	else:
		_cached_query.exclude = []

	var result := cam.get_world_3d().direct_space_state.intersect_ray(_cached_query)
	if result:
		return result.collider
	return null

static func get_interactable_under_mouse(viewport: Viewport, exclude_rid: RID = RID()) -> Ingredients:
	var collider: Object = _get_ray_collider_under_mouse(viewport, exclude_rid)
	if collider is Ingredients:
		return collider as Ingredients
	return null

func _face_camera() -> void:
	if not camera:
		return
	var visual: Node3D = get_node_or_null("Inside")
	if not visual:
		visual = get_node_or_null("Sprite3D")
	if visual:
		var target_flat: Vector3 = camera.global_position
		target_flat.y = visual.global_position.y
		if target_flat.distance_squared_to(visual.global_position) > 0.0001:
			visual.look_at(target_flat, Vector3.UP)

func _finish_drag_or_click() -> void:
	_is_pointer_pressed = false
	is_balls_dragging = false
	if GameState.player:
		GameState.player._update_hand("idle")

	var collider: Object = _get_ray_collider_under_mouse(get_viewport(), get_rid())
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

func _get_drag_point(mouse_pos: Vector2, plane_y: float) -> Variant:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return null
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)
	return Plane(Vector3.UP, plane_y).intersects_ray(from, dir)

func _clamp_to_counter(target_position: Vector3) -> Vector3:
	var surface_bounds = get_working_area_bounds(self)
	if surface_bounds is AABB:
		var counter_boundary: AABB = surface_bounds
		var half_extents: Vector2 = _get_working_area_horizontal_extents()
		var margin_x: float = minf(half_extents.x, counter_boundary.size.x * 0.45)
		var margin_z: float = minf(maxf(half_extents.y, 0.02), counter_boundary.size.z * 0.45)
		target_position.x = clampf(target_position.x, counter_boundary.position.x + margin_x, counter_boundary.end.x - margin_x)
		target_position.z = clampf(target_position.z, counter_boundary.position.z + margin_z, counter_boundary.end.z - margin_z)
		return target_position
	if counter_origin:
		var min_x: float = counter_origin.global_position.x - 1.15
		var max_x: float = counter_origin.global_position.x + 1.82
		var min_z: float = counter_origin.global_position.z - 0.35
		var max_z: float = counter_origin.global_position.z + 0.38
		target_position.x = clampf(target_position.x, min_x, max_x)
		target_position.z = clampf(target_position.z, min_z, max_z)
	return target_position

func _on_area_3d_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if active_selected_item != null and active_selected_item != self:
				if active_selected_item.can_interact_with(self):
					var actor: Ingredients = active_selected_item
					actor.set_selected(false)
					active_selected_item = null
					actor.execute_interaction(self)
					get_viewport().set_input_as_handled()
					return
				else:
					active_selected_item.set_selected(false)
					active_selected_item = null

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
		if active_selected_item != null and active_selected_item != self :
			if active_selected_item.can_interact_with(self):
				set_highlight(true)
		else:
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

func _handle_click_selection() -> void:
	if active_selected_item == self:
		set_selected(false)
		active_selected_item = null
	elif active_selected_item == null:
		active_selected_item = self
		set_selected(true)
	else:
		active_selected_item.set_selected(false)
		active_selected_item = self
		set_selected(true)

func set_selected(selected: bool) -> void:
	is_selected = selected
	set_highlight(selected)
	var target_y: float = base_y_position + 0.15 if selected else base_y_position
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", target_y, 0.15)

func set_highlight(enabled: bool) -> void:
	if _explicit_highlight:
		_explicit_highlight.visible = enabled
		return

	for visual in _highlight_visuals:
		var node_id: int = visual.get_instance_id()
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
	pass

	