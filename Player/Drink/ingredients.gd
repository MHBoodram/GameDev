extends Area3D
class_name Ingredients

# base class for all pickable and draggable 3d items (glasses, bottles, shakers, receipts)

enum DragMode { FREE, COLLISION }

static var active_selected_item: Ingredients = null
static var active_dragging_item: Ingredients = null
static var current_hovered_target: Ingredients = null
static var current_hovered_npc: Base_NPC = null
static var _cached_query: PhysicsRayQueryParameters3D = null
static var _cup_opaque_rect_cache: Dictionary = {}
static var _cup_picker_runtime: _CupPickerRuntime = null
static var _visual_hovered_cup: Ingredients = null

static func reset_interaction_state() -> void:
	active_selected_item = null
	active_dragging_item = null
	current_hovered_target = null
	current_hovered_npc = null
	_visual_hovered_cup = null

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

var _cup_hitbox_min: Vector2 = Vector2.ZERO
var _cup_hitbox_max: Vector2 = Vector2.ZERO
var _cup_hitbox_local_center: Vector3 = Vector3.ZERO
var _cup_inside_base_pos: Vector3 = Vector3.ZERO
var _cup_inside_base_scale: Vector3 = Vector3.ONE
var _has_cup_hitbox: bool = false


class _CupPickerRuntime extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -80

	func _process(_delta: float) -> void:
		Ingredients._sync_visual_cup_hover(get_viewport())

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				Ingredients._handle_visual_cup_click(get_viewport(), mb)


static func _ensure_cup_picker_runtime() -> void:
	if is_instance_valid(_cup_picker_runtime) and _cup_picker_runtime.is_inside_tree():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return
	var host: Node = tree.root.get_node_or_null("GameState")
	if not is_instance_valid(host):
		host = tree.root
	var existing := host.get_node_or_null("CupPickerRuntime")
	if is_instance_valid(existing) and existing is _CupPickerRuntime:
		_cup_picker_runtime = existing as _CupPickerRuntime
		return
	var runtime := _CupPickerRuntime.new()
	runtime.name = "CupPickerRuntime"
	host.add_child(runtime)
	_cup_picker_runtime = runtime


static func _find_fisheye_node(viewport: Viewport) -> CanvasItem:
	if GameState and is_instance_valid(GameState.gameplay_ui):
		var fe := GameState.gameplay_ui.get_node_or_null("FishEye") as CanvasItem
		if is_instance_valid(fe):
			return fe
	if is_instance_valid(viewport) and viewport.get_tree() and viewport.get_tree().current_scene:
		var found := viewport.get_tree().current_scene.find_child("FishEye", true, false) as CanvasItem
		if is_instance_valid(found):
			return found
	return null


static func _unwarp_fisheye_screen_pos(viewport: Viewport, screen_pos: Vector2) -> Vector2:
	if not is_instance_valid(viewport):
		return screen_pos
	var vp_size := viewport.get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return screen_pos
	var fe := _find_fisheye_node(viewport)
	if not is_instance_valid(fe) or not fe.is_visible_in_tree():
		return screen_pos
	var mat := fe.material as ShaderMaterial
	if mat == null:
		return screen_pos
	var raw_power: Variant = mat.get_shader_parameter("effect_amount")
	var power: float = float(raw_power) if raw_power != null else 1.0
	if is_zero_approx(power):
		return screen_pos

	var prop := vp_size.x / vp_size.y
	var p := Vector2(screen_pos.x / vp_size.x, screen_pos.y / vp_size.x)
	var m := Vector2(0.5, 0.5 / prop)
	var d := p - m
	var r := d.length()
	if r <= 0.000001:
		return screen_pos

	var uv := p
	if power > 0.0:
		var bind := m.length()
		var denom := tan(bind * power)
		if absf(denom) <= 0.000001:
			return screen_pos
		var rp := clampf(r * power, -1.55, 1.55)
		uv = m + (d / r) * tan(rp) * bind / denom
	else:
		var bind := m.x if prop < 1.0 else m.y
		var denom := atan(-power * bind * 10.0)
		if absf(denom) <= 0.000001:
			return screen_pos
		uv = m + (d / r) * atan(r * -power * 10.0) * bind / denom

	uv.y *= prop
	return Vector2(uv.x * vp_size.x, uv.y * vp_size.y)


static func _compute_cup_opaque_rect(s: Sprite3D) -> Variant:
	if not is_instance_valid(s):
		return null
	var dims: Rect2 = s.get_item_rect()
	if dims.size.x <= 0.0 or dims.size.y <= 0.0:
		return null

	var pad_left: float = 0.0
	var pad_right: float = 0.0
	var pad_bottom: float = 0.0
	var pad_top: float = 0.0

	if s.texture != null and s.hframes == 1 and s.vframes == 1 and not s.region_enabled:
		var tex_id: int = s.texture.get_rid().get_id()
		var used_rect := Rect2i()
		var tex_size := Vector2i.ZERO
		if _cup_opaque_rect_cache.has(tex_id):
			var cached: Dictionary = _cup_opaque_rect_cache[tex_id]
			used_rect = cached["used"]
			tex_size = cached["size"]
		else:
			var img: Image = s.texture.get_image()
			if img != null and not img.is_empty():
				if img.is_compressed():
					img.decompress()
				tex_size = img.get_size()
				var w := tex_size.x
				var h := tex_size.y
				var min_x := w
				var max_x := -1
				var min_y := h
				var max_y := -1
				for y in h:
					for x in w:
						if img.get_pixel(x, y).a > 0.05:
							if x < min_x:
								min_x = x
							if x > max_x:
								max_x = x
							if y < min_y:
								min_y = y
							if y > max_y:
								max_y = y
				if max_x >= min_x and max_y >= min_y:
					used_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
				else:
					used_rect = img.get_used_rect()
			_cup_opaque_rect_cache[tex_id] = {"used": used_rect, "size": tex_size}

		if used_rect.size.x > 0 and used_rect.size.y > 0 and tex_size.x > 0 and tex_size.y > 0:
			var sx: float = dims.size.x / float(tex_size.x)
			var sy: float = dims.size.y / float(tex_size.y)
			pad_left = float(tex_size.x - used_rect.end.x if s.flip_h else used_rect.position.x) * sx
			pad_right = float(used_rect.position.x if s.flip_h else tex_size.x - used_rect.end.x) * sx
			pad_bottom = float(used_rect.position.y if s.flip_v else tex_size.y - used_rect.end.y) * sy
			pad_top = float(tex_size.y - used_rect.end.y if s.flip_v else used_rect.position.y) * sy

	var ps: float = s.pixel_size
	var min_lx: float = (dims.position.x + pad_left) * ps
	var max_lx: float = (dims.end.x - pad_right) * ps
	var min_ly: float = (dims.position.y + pad_bottom) * ps
	var max_ly: float = (dims.end.y - pad_top) * ps
	return Rect2(min_lx, min_ly, maxf(max_lx - min_lx, 0.001), maxf(max_ly - min_ly, 0.001))


func _init_cup_2d_hitbox() -> void:
	if area_body == null:
		area_body = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not is_instance_valid(area_body):
		return

	var visual: Sprite3D = get("sprite") as Sprite3D
	if not is_instance_valid(visual):
		visual = get_node_or_null("Inside") as Sprite3D
	if not is_instance_valid(visual):
		return

	_cup_inside_base_pos = visual.position
	_cup_inside_base_scale = visual.scale

	var combined_min := Vector2(INF, INF)
	var combined_max := Vector2(-INF, -INF)
	var has_rect := false

	var in_rect = _compute_cup_opaque_rect(visual)
	if in_rect is Rect2:
		var r := in_rect as Rect2
		combined_min = r.position
		combined_max = r.end
		has_rect = true

	var center_z := 0.0
	var outside_sp := visual.get_node_or_null("Outside") as Sprite3D
	var out_rect = _compute_cup_opaque_rect(outside_sp)
	if out_rect is Rect2:
		center_z = outside_sp.position.z * 0.5
		var r_out := out_rect as Rect2
		var out_xf := outside_sp.transform
		var corners: Array[Vector3] = [
			out_xf * Vector3(r_out.position.x, r_out.position.y, 0.0),
			out_xf * Vector3(r_out.end.x, r_out.position.y, 0.0),
			out_xf * Vector3(r_out.position.x, r_out.end.y, 0.0),
			out_xf * Vector3(r_out.end.x, r_out.end.y, 0.0),
		]
		for c in corners:
			if not has_rect:
				combined_min = Vector2(c.x, c.y)
				combined_max = Vector2(c.x, c.y)
				has_rect = true
			else:
				combined_min.x = minf(combined_min.x, c.x)
				combined_min.y = minf(combined_min.y, c.y)
				combined_max.x = maxf(combined_max.x, c.x)
				combined_max.y = maxf(combined_max.y, c.y)

	if not has_rect:
		return

	var min_x := minf(combined_min.x * _cup_inside_base_scale.x, combined_max.x * _cup_inside_base_scale.x)
	var max_x := maxf(combined_min.x * _cup_inside_base_scale.x, combined_max.x * _cup_inside_base_scale.x)
	var min_y := minf(combined_min.y * _cup_inside_base_scale.y, combined_max.y * _cup_inside_base_scale.y)
	var max_y := maxf(combined_min.y * _cup_inside_base_scale.y, combined_max.y * _cup_inside_base_scale.y)

	_cup_hitbox_min = Vector2(min_x, min_y)
	_cup_hitbox_max = Vector2(max_x, max_y)
	_cup_hitbox_local_center = Vector3((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, center_z * _cup_inside_base_scale.z)
	_has_cup_hitbox = true

	var box := area_body.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
		area_body.shape = box
	elif not box.has_meta("_unique_cup_hitbox"):
		box = box.duplicate() as BoxShape3D
		area_body.shape = box
	box.set_meta("_unique_cup_hitbox", true)
	box.size = Vector3(maxf(max_x - min_x, 0.01), maxf(max_y - min_y, 0.01), 0.12)

	_sync_cup_2d_hitbox_transform()


func _sync_cup_2d_hitbox_transform() -> void:
	if not _has_cup_hitbox or not is_instance_valid(area_body):
		return
	var visual: Node3D = get("sprite") as Node3D
	if not is_instance_valid(visual):
		visual = get_node_or_null("Inside") as Node3D
	if not is_instance_valid(visual):
		return
	var rot_basis := visual.transform.basis.orthonormalized()
	area_body.transform = Transform3D(rot_basis, _cup_inside_base_pos + rot_basis * _cup_hitbox_local_center)


func _get_cup_visual_hit(viewport: Viewport, screen_pos: Vector2) -> Dictionary:
	if not _has_cup_hitbox or not is_inside_tree() or not is_visible_in_tree() or is_preview_only:
		return {}
	if "is_consumed" in self and bool(get("is_consumed")):
		return {}
	if "is_being_served" in self and bool(get("is_being_served")):
		return {}
	if "is_delivering" in self and bool(get("is_delivering")):
		return {}

	var cam := camera if is_instance_valid(camera) else viewport.get_camera_3d()
	if not is_instance_valid(cam):
		return {}
	var visual: Node3D = get("sprite") as Node3D
	if not is_instance_valid(visual):
		visual = get_node_or_null("Inside") as Node3D
	if not is_instance_valid(visual) or not visual.is_inside_tree():
		return {}

	var ray_pos := _unwarp_fisheye_screen_pos(viewport, screen_pos)
	var from := cam.project_ray_origin(ray_pos)
	var dir := cam.project_ray_normal(ray_pos)

	var rot_basis := visual.transform.basis.orthonormalized()
	var plane_point_world := global_transform * (_cup_inside_base_pos + rot_basis * _cup_hitbox_local_center)
	var plane_normal_world := (global_transform.basis * rot_basis.z).normalized()
	if plane_normal_world.length_squared() < 0.0001:
		return {}

	var hit = Plane(plane_normal_world, plane_point_world).intersects_ray(from, dir)
	if hit == null:
		return {}
	var hit_world := hit as Vector3
	if (hit_world - from).dot(dir) <= 0.0:
		return {}

	var cup_local := global_transform.affine_inverse() * hit_world
	var rel := rot_basis.inverse() * (cup_local - _cup_inside_base_pos)
	if (
		rel.x >= _cup_hitbox_min.x
		and rel.x <= _cup_hitbox_max.x
		and rel.y >= _cup_hitbox_min.y
		and rel.y <= _cup_hitbox_max.y
	):
		return {
			"pos": hit_world,
			"normal": plane_normal_world,
			"distance": from.distance_to(hit_world),
			"ray_from": from,
			"ray_dir": dir,
		}
	return {}


static func _pick_cup_hit_at_screen_pos(viewport: Viewport, screen_pos: Vector2, exclude_rid: RID = RID()) -> Dictionary:
	if not is_instance_valid(viewport):
		return {}
	var tree := viewport.get_tree()
	if tree == null:
		return {}
	var best_hit: Dictionary = {}
	var best_dist := INF
	for node in tree.get_nodes_in_group("glass"):
		if not (node is Ingredients):
			continue
		var cup := node as Ingredients
		if not is_instance_valid(cup) or not cup.is_inside_tree():
			continue
		if exclude_rid.is_valid() and cup.get_rid() == exclude_rid:
			continue
		var hit_data := cup._get_cup_visual_hit(viewport, screen_pos)
		if hit_data.is_empty():
			continue
		var dist := float(hit_data["distance"])
		if dist < best_dist:
			best_dist = dist
			best_hit = hit_data
			best_hit["cup"] = cup
	return best_hit


static func _has_closer_pickable_blocker(viewport: Viewport, from: Vector3, dir: Vector3, max_dist: float) -> bool:
	var cam := viewport.get_camera_3d()
	if not is_instance_valid(cam):
		return false
	var space := cam.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.from = from
	query.to = from + dir * maxf(max_dist, 0.01)
	var excluded: Array[RID] = []
	for _step in 6:
		query.exclude = excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		var col: Object = hit.get("collider")
		if col is Glasses:
			excluded.append((col as CollisionObject3D).get_rid())
			continue
		if col is CollisionObject3D:
			var co := col as CollisionObject3D
			if not co.input_ray_pickable:
				excluded.append(co.get_rid())
				continue
			return from.distance_to(hit["position"] as Vector3) < max_dist - 0.005
		return false
	return false


static func _is_cup_picking_blocked(viewport: Viewport) -> bool:
	if not is_instance_valid(viewport):
		return true
	var tree := viewport.get_tree()
	if tree == null or tree.paused:
		return true
	if GameState:
		if GameState.is_dialogue_open:
			return true
		if is_instance_valid(GameState.pause_menu) and GameState.pause_menu.visible:
			return true
		if is_instance_valid(GameState.debug_menu) and GameState.debug_menu.visible:
			var dbg_box := GameState.debug_menu.get_node_or_null("TextureRect") as Control
			if is_instance_valid(dbg_box) and dbg_box.get_global_rect().has_point(viewport.get_mouse_position()):
				return true
		if GameState.minigame_host and GameState.minigame_host.is_minigame_active:
			return true
		if is_instance_valid(GameState.player) and "in_game" in GameState.player and GameState.player.in_game:
			return true
		if is_instance_valid(GameState.gameplay_ui):
			var tc := GameState.gameplay_ui.get_node_or_null("ToolCircle") as Control
			if is_instance_valid(tc) and tc.visible:
				return true
	if ShakerMinigame.active:
		return true
	var hovered_ctrl := viewport.gui_get_hovered_control()
	if is_instance_valid(hovered_ctrl) and hovered_ctrl.is_visible_in_tree():
		return true
	return false


static func _clear_visual_cup_hover() -> void:
	if is_instance_valid(_visual_hovered_cup) and _visual_hovered_cup.is_inside_tree():
		var old_cup := _visual_hovered_cup
		_visual_hovered_cup = null
		old_cup._on_area_3d_mouse_exited()
		if old_cup == active_dragging_item:
			old_cup.set_highlight(false)
	else:
		_visual_hovered_cup = null


static func _sync_visual_cup_hover(viewport: Viewport) -> void:
	if not is_instance_valid(viewport):
		_clear_visual_cup_hover()
		return
	var tree := viewport.get_tree()
	if tree == null or tree.get_nodes_in_group("glass").is_empty():
		_clear_visual_cup_hover()
		return
	if active_dragging_item != null or _is_cup_picking_blocked(viewport):
		_clear_visual_cup_hover()
		return

	var target_cup: Ingredients = null
	var hit_data := _pick_cup_hit_at_screen_pos(viewport, viewport.get_mouse_position())
	if not hit_data.is_empty():
		if not _has_closer_pickable_blocker(viewport, hit_data["ray_from"] as Vector3, hit_data["ray_dir"] as Vector3, float(hit_data["distance"])):
			target_cup = hit_data["cup"] as Ingredients

	if target_cup != _visual_hovered_cup:
		_clear_visual_cup_hover()
		_visual_hovered_cup = target_cup
		if is_instance_valid(_visual_hovered_cup):
			_visual_hovered_cup._on_area_3d_mouse_entered()


static func _handle_visual_cup_click(viewport: Viewport, mb: InputEventMouseButton) -> void:
	if not is_instance_valid(viewport) or active_dragging_item != null or _is_cup_picking_blocked(viewport):
		return
	var hit_data := _pick_cup_hit_at_screen_pos(viewport, viewport.get_mouse_position())
	if hit_data.is_empty():
		return
	var cup := hit_data["cup"] as Ingredients
	if not is_instance_valid(cup) or cup._is_drag_blocked():
		return
	if _has_closer_pickable_blocker(viewport, hit_data["ray_from"] as Vector3, hit_data["ray_dir"] as Vector3, float(hit_data["distance"])):
		return
	var cam_ref := cup.camera if is_instance_valid(cup.camera) else viewport.get_camera_3d()
	cup._on_area_3d_input_event(cam_ref, mb, hit_data["pos"] as Vector3, hit_data["normal"] as Vector3, 0)


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
	if self is Glasses:
		input_ray_pickable = false
		if not is_preview_only:
			_ensure_cup_picker_runtime()
			_init_cup_2d_hitbox()

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
		if _has_cup_hitbox:
			_sync_cup_2d_hitbox_transform()
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

	if _has_cup_hitbox:
		_sync_cup_2d_hitbox_transform()

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
	var ray_pos := _unwarp_fisheye_screen_pos(viewport, mouse_pos)
	var from := cam.project_ray_origin(ray_pos)
	var to := from + cam.project_ray_normal(ray_pos) * 100.0

	if not _cached_query:
		_cached_query = PhysicsRayQueryParameters3D.new()
		_cached_query.collide_with_areas = true
		_cached_query.collide_with_bodies = false

	_cached_query.from = from
	_cached_query.to = to
	_cached_query.exclude = [exclude_rid] if exclude_rid.is_valid() else []

	var result := cam.get_world_3d().direct_space_state.intersect_ray(_cached_query)
	var phys_collider: Object = result.collider if result else null
	var phys_dist: float = from.distance_to(result.position as Vector3) if result else INF

	var cup_hit: Dictionary = _pick_cup_hit_at_screen_pos(viewport, mouse_pos, exclude_rid)
	if not cup_hit.is_empty():
		var cup := cup_hit["cup"] as Ingredients
		var cup_dist := float(cup_hit["distance"])
		if (
			phys_collider == null
			or phys_collider is Glasses
			or not (phys_collider is CollisionObject3D and (phys_collider as CollisionObject3D).input_ray_pickable)
			or cup_dist <= phys_dist
		):
			return cup

	return phys_collider

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

		if self is Glasses:
			set_highlight(false)
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
	if not is_balls_dragging and not active_selected_item and current_hovered_target == null and GameState.player:
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