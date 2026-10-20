extends Area3D
class_name Ingredients

static var active_selected_item: Ingredients = null
static var current_hovered_target: Ingredients = null
static var _cached_query: PhysicsRayQueryParameters3D = null

var is_balls_dragging: bool = false
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
	ready()

func ready() -> void:
	pass

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
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var hit = _get_drag_point(mouse_pos, 1.6)
		if hit != null:
			var p: Vector3 = _clamp_to_counter(hit)
			p.y = 1.6
			global_position = p
		_face_camera()
		_update_drag_hover()

func _update_drag_hover() -> void:
	var target: Ingredients = get_interactable_under_mouse(get_viewport(), get_rid())
	if target != current_hovered_target:
		if current_hovered_target and current_hovered_target != active_selected_item:
			current_hovered_target.set_highlight(false)
		current_hovered_target = target
		if current_hovered_target and can_interact_with(current_hovered_target):
			current_hovered_target.set_highlight(true)

static func get_interactable_under_mouse(viewport: Viewport, exclude_rid: RID = RID()) -> Ingredients:
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
	if result and result.collider is Ingredients:
		return result.collider
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
		visual.look_at(target_flat, Vector3.UP)

func _finish_drag_or_click() -> void:
	_is_pointer_pressed = false
	is_balls_dragging = false
	if GameState.player:
		GameState.player._update_hand("idle")

	if _has_dragged:
		var target: Ingredients = current_hovered_target
		if not target:
			target = get_interactable_under_mouse(get_viewport(), get_rid())
		if target and can_interact_with(target):
			current_hovered_target = null
			target.set_highlight(false)
			execute_interaction(target)
		else:
			if current_hovered_target:
				current_hovered_target.set_highlight(false)
				current_hovered_target = null
			on_drop_failed()
	else:
		_handle_click_selection()
	_has_dragged = false

func _get_drag_point(mouse_pos: Vector2, plane_y: float) -> Variant:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return null
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)
	return Plane(Vector3.UP, plane_y).intersects_ray(from, dir)

func _clamp_to_counter(p: Vector3) -> Vector3:
	if counter_origin:
		var min_x: float = counter_origin.global_position.x - 1.15
		var max_x: float = counter_origin.global_position.x + 1.82
		var min_z: float = counter_origin.global_position.z - 0.35
		var max_z: float = counter_origin.global_position.z + 0.38
		p.x = clampf(p.x, min_x, max_x)
		p.z = clampf(p.z, min_z, max_z)
	return p

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
	if not is_balls_dragging:
		current_hovered_target = self
		if active_selected_item != null and active_selected_item != self:
			if active_selected_item.can_interact_with(self):
				set_highlight(true)
		else:
			set_highlight(true)
			if GameState.player:
				GameState.player._update_hand("interact")

func _on_area_3d_mouse_exited() -> void:
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
	tween.tween_property(self, "position:y", target_y, 0.15)

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

func on_drop_failed() -> void:
	pass