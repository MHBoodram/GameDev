# Physical 3D drink container holding a typed DrinkMix instance
# Liquid pouring, fluid sim
extends Ingredients
class_name Glasses

const OVERFLOW_STREAM_HOLD_TIME: float = 0.075
const POUR_SPLASH_HOLD_TIME: float = 0.075
const MIN_POUR_OUT_TILT_DEGREES: float = 5.0
const SPILL_INDICATOR_COOLDOWN: float = 0.55
const OVERFLOW_EPSILON: float = 0.0005

@export var liquids: Array = []
@export var size: float = 1.0
@export var glass_type: String = ""
@export var sprite: Sprite3D
@export var customer_hold_distance: float = 1.0

var drink_mix: DrinkMix = DrinkMix.new()
var visual_helper: LiquidVisualHelper = LiquidVisualHelper.new()
var garnish_visuals: CupGarnishVisuals = CupGarnishVisuals.new()
var _pour_out_stream: PourStreamVisual = null
var _pour_splash_stream: PourStreamVisual = null
var _pour_splash_timer: float = 0.0
var _pour_splash_flow_rate: float = 0.0
var _pour_splash_color: Color = Color.WHITE
var _pour_splash_entry_u: float = 0.5
var _overflow_stream_left: PourStreamVisual = null
var _overflow_stream_right: PourStreamVisual = null
var _overflow_timer: float = 0.0
var _overflow_flow_rate: float = 0.0
var _overflow_color: Color = Color.WHITE

var total_liquids: float = 0.0
var is_being_served: bool = false
var is_delivering: bool = false
var is_consumed: bool = false
var is_pouring_out: bool = false
var _is_actively_pouring_out: bool = false
var pour_tilt_degrees: float = 0.0
var _target_pour_tilt_degrees: float = 0.0
var _pour_tilt_tween: Tween = null
var _active_trash: Area3D = null
var _previous_counter_position: Vector3 = Vector3.ZERO
var _skip_initial_snap: bool = false
var _spill_indicator_cooldown: float = 0.0
var _spill_accumulated_percent: float = 0.0

var push_velocity: Vector3 = Vector3.ZERO
const PUSH_FRICTION: float = 14.0
const INTERACTION_SEPARATION_DISTANCE: float = 0.14

@export var dead_zone := 50.0
@export var full_pull := 150.0
@export var max_hand_distance := 20.0

signal snappedIn(point: Node3D)
signal snappedOut(point: Node3D)

var _snap_point: Node3D = null
var _snap_pos: Vector3 = Vector3.ZERO
var _snap_blend: float = 0.0
var _snap_suppressed: bool = false
var _snap_locked: bool = false
var _snap_pull_speed: float = 22.0
var _snap_release_speed: float = 16.0
var _snap_break_distance: float = 0.25
var _inside_base_scale: Vector3 = Vector3.ONE
var _inside_base_pos: Vector3 = Vector3.ZERO

@onready var highlight = get_node_or_null("Inside/highlight")

func is_working_area_item() -> bool:
	return true

func _is_drag_blocked() -> bool:
	return super._is_drag_blocked() or is_being_served or is_consumed or is_pouring_out

func _on_drag_started() -> void:
	if not is_instance_valid(_active_trash) and not _is_returning_to_counter and absf(global_position.y - get_working_area_surface_y()) <= 0.15:
		var saved := _clamp_to_counter(global_position)
		saved.y = get_working_area_surface_y()
		_previous_counter_position = saved

func set_active_trash(trash_area: Area3D) -> void:
	_active_trash = trash_area
	visual_helper.set_mouth_monitoring(is_instance_valid(_active_trash) or _is_actively_pouring_out)

func can_pour_out_from_mouth() -> bool:
	if is_consumed or total_liquids <= 0.0001:
		return false
	if absf(pour_tilt_degrees) <= MIN_POUR_OUT_TILT_DEGREES:
		return false
	return visual_helper.is_liquid_touching_mouth()

func _sync_drink_mix_metadata() -> void:
	drink_mix.cup_capacity = size
	if glass_type != "" and drink_mix.glass_type == "":
		drink_mix.glass_type = glass_type

func get_drink_mix() -> DrinkMix:
	_sync_drink_mix_metadata()
	return drink_mix

func can_add_garnish(garnish_id: String) -> bool:
	if _is_drag_blocked():
		return false
	return GarnishDefinitions.can_add_to_mix(drink_mix, garnish_id)

func add_garnish_item(garnish_id: String) -> bool:
	if not can_add_garnish(garnish_id):
		return false
	var clean_id := GarnishDefinitions.normalize_id(garnish_id)
	var added := false
	if GarnishDefinitions.is_ice(clean_id):
		added = drink_mix.add_ice()
	else:
		added = drink_mix.add_garnish(clean_id, 1)
	if added:
		sync_garnish_visuals()
		GameState.play_sfx("play_mugpickup")
	return added

func sync_garnish_visuals() -> void:
	if garnish_visuals:
		garnish_visuals.sync_from_mix(drink_mix)

func get_resource_usage_multiplier(liquid_id: String = "") -> float:
	return SpeciesRegistry.get_glass_resource_multiplier(self, liquid_id)

func _get_tool_controller() -> ToolController:
	if GameState.player:
		return GameState.player.get("tool_controller") as ToolController
	return null

func can_highlight_on_hover() -> bool:
	if _is_drag_blocked():
		return false
	var tool_ctrl := _get_tool_controller()
	if tool_ctrl:
		return tool_ctrl.can_highlight_glass(self)
	var active_tool: String = GameState.player.return_tool() if GameState.player and GameState.player.has_method("return_tool") else "hand"
	return SpeciesRegistry.can_highlight_glass(active_tool, self)

func handle_immediate_tool_click() -> bool:
	if GameState.is_dialogue_open or ShakerMinigame.active or _is_drag_blocked():
		return false
	var tool_ctrl := _get_tool_controller()
	if tool_ctrl:
		var active_tool: String = tool_ctrl.get_tool()
		if active_tool != "hand":
			if tool_ctrl.handle_glass_click(self, GameState.player):
				return true
			if tool_ctrl.should_consume_glass_click(self):
				return true
		elif is_instance_valid(_active_trash) and _active_trash.has_method("can_pour_glass") and _active_trash.can_pour_glass(self):
			_active_trash.call("start_pour")
			return true
	elif is_instance_valid(_active_trash) and _active_trash.has_method("can_pour_glass") and _active_trash.can_pour_glass(self):
		_active_trash.call("start_pour")
		return true
	return false

func handle_non_drag_click() -> bool:
	var tool_ctrl := _get_tool_controller()
	if tool_ctrl:
		return tool_ctrl.handle_glass_click(self, GameState.player)
	return false

func _get_free_drag_target(delta: float) -> Vector3:
	if _waiting_for_working_area:
		return super._get_free_drag_target(delta)
	if camera:
		_drag_current_depth = lerpf(_drag_current_depth, customer_hold_distance, 1.0 - exp(-12.0 * delta))
		return camera.project_position(get_viewport().get_mouse_position(), _drag_current_depth)
	return global_position

func _get_container_sprite() -> Sprite3D:
	var outside_sprite := get_node_or_null("Inside/Outside") as Sprite3D
	if is_instance_valid(outside_sprite) and outside_sprite.texture:
		return outside_sprite
	if is_instance_valid(sprite):
		return sprite
	return get_node_or_null("Inside") as Sprite3D

func get_rim_center_world_position() -> Vector3:
	var sp := _get_container_sprite()
	if sp:
		return PourStreamVisual.get_sprite_top_spout_world_position(sp)
	return global_position + Vector3(0.0, 0.08, 0.0)

func get_liquid_surface_world_position() -> Vector3:
	var sp := _get_container_sprite()
	if sp:
		var fill_ratio := clampf(total_liquids / maxf(size, 0.001), 0.05, 0.96)
		return PourStreamVisual.get_sprite_surface_world_position(sp, fill_ratio)
	return global_position

func get_pour_spout_world_position() -> Vector3:
	var sp := _get_container_sprite()
	if sp:
		return PourStreamVisual.get_sprite_rim_spout_world_position(sp, pour_tilt_degrees)
	return global_position

func _get_top_buoyant_layer_index() -> int:
	if liquids.is_empty():
		return -1
	var best_idx: int = -1
	var best_buoyancy: float = -INF
	for i in liquids.size():
		var layer = liquids[i]
		if not (layer is Array) or layer.size() < 2:
			continue
		if float(layer[1]) <= 0.0001:
			continue
		var buoy := LiquidVisualHelper.get_layer_buoyancy(layer)
		if buoy >= best_buoyancy:
			best_buoyancy = buoy
			best_idx = i
	return best_idx

func get_top_liquid_color() -> Color:
	var top_idx := _get_top_buoyant_layer_index()
	if top_idx == -1:
		return Color.WHITE
	var top_layer = liquids[top_idx]
	if top_layer is Array:
		return visual_helper.get_layer_color(top_layer)
	return Color.WHITE

func compute_pour_info_from_world(impact_world_pos: Vector3, incoming_world_vel: Vector3) -> Dictionary:
	var sp := _get_container_sprite()
	var entry_u := 0.5
	var grid_vel := Vector2(0.0, 36.0)
	if sp:
		entry_u = PourStreamVisual.world_pos_to_sprite_u(sp, impact_world_pos)
		grid_vel = PourStreamVisual.world_vel_to_grid_vel(sp, incoming_world_vel)
	return {
		"from_pour": true,
		"entry_u": clampf(entry_u, 0.15, 0.85),
		"stream_vx": clampf(grid_vel.x, -16.0, 16.0),
		"stream_vy": clampf(maxf(grid_vel.y, 28.0), 28.0, 48.0),
	}

func _ensure_pour_out_stream() -> void:
	if not is_instance_valid(_pour_out_stream):
		_pour_out_stream = PourStreamVisual.new()
		add_child(_pour_out_stream)

func _ensure_pour_splash_stream() -> void:
	if not is_instance_valid(_pour_splash_stream):
		_pour_splash_stream = PourStreamVisual.new()
		add_child(_pour_splash_stream)

func _stop_pour_splash() -> void:
	_pour_splash_timer = 0.0
	_pour_splash_flow_rate = 0.0
	if is_instance_valid(_pour_splash_stream):
		_pour_splash_stream.set_splash_active(false)

func _get_blended_stream_color(id: String, top_weight: float) -> Color:
	var incoming_col: Color = visual_helper.LIQUID_COLOR.get(id, Color.WHITE)
	var base_col: Color = incoming_col.lerp(get_top_liquid_color(), top_weight) if not liquids.is_empty() else incoming_col
	if visual_helper and visual_helper._visual_override.has("liquid_tint_color"):
		var tint_col: Color = visual_helper._visual_override.get("liquid_tint_color", Color.WHITE)
		var tint_mix: float = float(visual_helper._visual_override.get("liquid_tint_strength", 0.35))
		base_col = base_col.lerp(Color(tint_col.r, tint_col.g, tint_col.b, base_col.a), tint_mix)
	return base_col

func _trigger_pour_splash(id: String, liquids_num: float, pour_info: Dictionary) -> void:
	_pour_splash_color = _get_blended_stream_color(id, 0.2)
	_pour_splash_entry_u = clampf(float(pour_info.get("entry_u", 0.5)), 0.15, 0.85)
	var target_flow := clampf(liquids_num / 0.0825, 0.25, 1.8)
	_pour_splash_flow_rate = lerpf(_pour_splash_flow_rate, target_flow, 0.5) if _pour_splash_timer > 0.0 else target_flow
	_pour_splash_timer = POUR_SPLASH_HOLD_TIME

func _update_pour_splash(delta: float) -> void:
	_ensure_pour_splash_stream()
	if _pour_splash_timer <= 0.0 or is_consumed or is_pouring_out:
		_pour_splash_timer = 0.0 
		_pour_splash_stream.set_splash_active(false)
		return

	_pour_splash_timer = maxf(0.0, _pour_splash_timer - delta)
	var sp := _get_container_sprite()
	if not is_instance_valid(sp):
		_pour_splash_stream.set_splash_active(false)
		return

	var fill_ratio := clampf(total_liquids / maxf(size, 0.001), 0.05, 0.96)
	var impact_pos := PourStreamVisual.get_sprite_surface_world_position(sp, fill_ratio)
	var edges: Dictionary = PourStreamVisual.get_sprite_rim_edges_world_positions(sp)
	var edge_left: Vector3 = edges.get("left", Vector3.ZERO)
	var edge_right: Vector3 = edges.get("right", Vector3.ZERO)
	var center_edge: Vector3 = edges.get("center", Vector3.ZERO)
	var cup_half_width: float = edge_left.distance_to(edge_right) * 0.35
	var rim_y: float = center_edge.y
	var active_cam := camera if is_instance_valid(camera) else get_viewport().get_camera_3d()
	var cam_dir := (active_cam.global_position - impact_pos).normalized() if is_instance_valid(active_cam) else -sp.global_transform.basis.z.normalized()
	var spawn_pos := impact_pos + cam_dir * 0.0015
	_pour_splash_stream.set_splash_active(true, spawn_pos, _pour_splash_color, _pour_splash_flow_rate, impact_pos.y, cup_half_width, rim_y)

func _ensure_overflow_streams() -> void:
	if not is_instance_valid(_overflow_stream_left):
		_overflow_stream_left = PourStreamVisual.new()
		add_child(_overflow_stream_left)
	if not is_instance_valid(_overflow_stream_right):
		_overflow_stream_right = PourStreamVisual.new()
		add_child(_overflow_stream_right)

func _stop_overflow_streams() -> void:
	_overflow_timer = 0.0
	_overflow_flow_rate = 0.0
	if is_instance_valid(_overflow_stream_left):
		_overflow_stream_left.set_stream_active(false)
	if is_instance_valid(_overflow_stream_right):
		_overflow_stream_right.set_stream_active(false)

func _trigger_overflow_spilling(id: String, overflow: float) -> void:
	_overflow_color = _get_blended_stream_color(id, 0.75)
	var tick_rate := overflow / 0.033
	var target_flow := clampf(tick_rate / 2.5, 0.28, 1.35)
	_overflow_flow_rate = lerpf(_overflow_flow_rate, target_flow, 0.5) if _overflow_timer > 0.0 else target_flow
	_overflow_timer = OVERFLOW_STREAM_HOLD_TIME

func _notify_spill_indicator(overflow_percent: float) -> void:
	_spill_accumulated_percent += overflow_percent
	if _spill_indicator_cooldown > 0.0:
		return
	var hud := HudIndicators.get_current()
	if hud:
		hud.show_cup_spill_indicator(self, _spill_accumulated_percent)
	_spill_accumulated_percent = 0.0
	_spill_indicator_cooldown = SPILL_INDICATOR_COOLDOWN

func _compute_edge_outward_dir(edge_pos: Vector3, center_pos: Vector3, up_axis: Vector3, fallback: Vector3) -> Vector3:
	var outward := edge_pos - center_pos
	outward -= up_axis * outward.dot(up_axis)
	outward.y = 0.0
	if outward.length_squared() > 0.000001:
		return outward.normalized()
	var flat_fallback := Vector3(fallback.x, 0.0, fallback.z)
	if flat_fallback.length_squared() > 0.000001:
		return flat_fallback.normalized()
	return Vector3.RIGHT

func _update_overflow_streams(delta: float) -> void:
	_ensure_overflow_streams()
	if _overflow_timer <= 0.0 or is_consumed or is_pouring_out or total_liquids <= 0.001:
		_overflow_timer = 0.0
		_overflow_stream_left.set_stream_active(false)
		_overflow_stream_right.set_stream_active(false)
		return

	_overflow_timer = maxf(0.0, _overflow_timer - delta)
	var sp := _get_container_sprite()
	if not is_instance_valid(sp):
		_overflow_stream_left.set_stream_active(false)
		_overflow_stream_right.set_stream_active(false)
		return

	var edges := PourStreamVisual.get_sprite_rim_edges_world_positions(sp)
	var center_pos: Vector3 = edges["center"]
	var left_edge: Vector3 = edges["left"]
	var right_edge: Vector3 = edges["right"]

	var is_on_counter := not in_game and absf(global_position.y - get_working_area_surface_y()) <= 0.08
	var floor_y := left_edge.y - 0.50
	if is_on_counter:
		var bounds = WorkingAreaService.get_working_area_bounds(self)
		floor_y = ((bounds as AABB).end.y + 0.002) if (bounds is AABB) else PourStreamVisual.get_sprite_surface_world_position(sp, 0.0).y

	var basis_x := sp.global_transform.basis.x.normalized()
	var basis_y := sp.global_transform.basis.y.normalized()
	var active_cam := camera if is_instance_valid(camera) else get_viewport().get_camera_3d()
	var cam_dir := (active_cam.global_position - center_pos).normalized() if is_instance_valid(active_cam) else -sp.global_transform.basis.z.normalized()

	var left_outward := _compute_edge_outward_dir(left_edge, center_pos, basis_y, -basis_x)
	var right_outward := _compute_edge_outward_dir(right_edge, center_pos, basis_y, basis_x)

	var left_spawn := left_edge + left_outward * 0.003 + cam_dir * 0.004
	var right_spawn := right_edge + right_outward * 0.003 + cam_dir * 0.004

	var cup_width := left_edge.distance_to(right_edge)
	var spill_out := clampf(cup_width * (0.38 if is_on_counter else 0.45), 0.015, 0.032)
	var left_target_y := floor_y if is_on_counter else (left_spawn.y - 0.50)
	var right_target_y := floor_y if is_on_counter else (right_spawn.y - 0.50)

	var left_end := Vector3(left_spawn.x + left_outward.x * spill_out, left_target_y, left_spawn.z + left_outward.z * spill_out)
	var right_end := Vector3(right_spawn.x + right_outward.x * spill_out, right_target_y, right_spawn.z + right_outward.z * spill_out)

	var left_dir := (left_outward * 0.48 + Vector3.DOWN * 0.88).normalized()
	var right_dir := (right_outward * 0.48 + Vector3.DOWN * 0.88).normalized()

	_overflow_stream_left.set_stream_active(true, left_spawn, left_end, _overflow_color, _overflow_flow_rate, left_dir, true, is_on_counter, null, true)
	_overflow_stream_right.set_stream_active(true, right_spawn, right_end, _overflow_color, _overflow_flow_rate, right_dir, true, is_on_counter, null, true)

func _update_pour_out_stream() -> void:
	_ensure_pour_out_stream()
	if is_pouring_out and _is_actively_pouring_out and can_pour_out_from_mouth():
		var spout_pos := get_pour_spout_world_position()
		var sp := _get_container_sprite()
		var outward_x := Vector3.RIGHT
		if is_instance_valid(sp):
			var sign_dir := -1.0 if pour_tilt_degrees >= 0.0 else 1.0
			outward_x = (sp.global_transform.basis.x * sign_dir).normalized()
		var eject_dir := (outward_x * 0.35 + Vector3(0.0, -0.92, 0.0)).normalized()
		var end_pos := Vector3(spout_pos.x, spout_pos.y - 2.2, spout_pos.z)
		var flow_rate := clampf(absf(pour_tilt_degrees) / 65.0, 0.25, 1.8)
		_pour_out_stream.set_stream_active(true, spout_pos, end_pos, get_top_liquid_color(), flow_rate, eject_dir, false, false)
	else:
		_pour_out_stream.set_stream_active(false)

func ready() -> void:
	rotation = Vector3.ZERO
	_sync_drink_mix_metadata()
	if sprite:
		_inside_base_scale = sprite.scale
		_inside_base_pos = sprite.position
	_ensure_pour_out_stream()
	_ensure_pour_splash_stream()
	_ensure_overflow_streams()
	_setup_liquid_shader()
	var host_sprite := sprite if is_instance_valid(sprite) else get_node_or_null("Inside") as Sprite3D
	var outside_sprite := get_node_or_null("Inside/Outside") as Sprite3D
	garnish_visuals.setup(self, host_sprite, outside_sprite)
	garnish_visuals.sync_from_mix(drink_mix)
	if highlight:
		highlight.modulate = Color(1.5, 1.5, 0.0, 5.0)
	if camera:
		_face_camera()
	if not _skip_initial_snap:
		_snap_to_working_area()
	else:
		base_y_position = get_working_area_surface_y()
	_last_counter_position = global_position
	_previous_counter_position = global_position
	visual_helper.last_global_pos = sprite.global_position if sprite else global_position

func _exit_tree() -> void:
	visual_helper.cleanup()
	garnish_visuals.clear()
	if is_instance_valid(_pour_out_stream):
		_pour_out_stream.set_stream_active(false)
	_stop_pour_splash()
	_stop_overflow_streams()
	var hud := HudIndicators.get_current()
	if hud:
		hud.hide_pouring_indicator(self)

func start_drag_from_spawn(press_screen_pos: Vector2, from_shelf: bool = false) -> void:
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

	visual_helper.last_global_pos = sprite.global_position if sprite else global_position
	visual_helper.last_velocity = Vector3.ZERO
	if camera:
		_face_camera()
	super.start_drag_from_spawn(press_screen_pos, from_shelf)

func _delete() -> void:
	_remove_displaying_list()
	if is_instance_valid(_pour_out_stream):
		_pour_out_stream.set_stream_active(false)
	_stop_pour_splash()
	_stop_overflow_streams()
	queue_free()

func _update_hand_position(delta: float) -> void:
	if not camera or not GameState.player:
		return
	if camera.is_position_behind(global_position):
		return
	var mouse := get_viewport().get_mouse_position()
	var glass_screen := camera.unproject_position(global_position)
	var gap := mouse.x - glass_screen.x
	var excess := maxf(absf(gap) - dead_zone, 0.0)
	var pull := clampf(excess / full_pull, 0.0, 1.0)
	var goal := mouse.lerp(glass_screen, pull)
	var hand = GameState.player.hand_sprite
	GameState.play_sfx("play_mugpickup")
	if hand:
		hand.global_position = hand.global_position.lerp(goal, 1.0 - exp(-30.0 * delta))

func _process(delta: float) -> void:
	super._process(delta)
	_update_snap(delta)
	if _spill_indicator_cooldown > 0.0:
		_spill_indicator_cooldown = maxf(0.0, _spill_indicator_cooldown - delta)

	if is_pouring_out and not (_pour_tilt_tween and _pour_tilt_tween.is_valid()):
		pour_tilt_degrees = lerpf(pour_tilt_degrees, _target_pour_tilt_degrees, 1.0 - exp(-18.0 * delta))

	if camera and not is_balls_dragging and _is_drag_blocked():
		_face_camera()

	_update_pour_out_stream()
	_update_pour_splash(delta)
	_update_overflow_streams(delta)

	var track_pos: Vector3 = sprite.global_position if sprite else global_position
	var outside_sprite := get_node_or_null("Inside/Outside") as Node3D
	visual_helper.update_physics_from_owner(delta, track_pos, camera, self, -1.0, outside_sprite)
	if not is_consumed:
		_update_shader_parameters()
		garnish_visuals.update(delta, total_liquids, size, visual_helper)

	if _is_drag_blocked():
		return

	if is_balls_dragging:
		_update_hand_position(delta)

func _on_working_area_step(delta: float) -> void:
	_apply_collision_push(delta)
	super._on_working_area_step(delta)

func _on_working_area_settled() -> void:
	if not is_instance_valid(_active_trash):
		_previous_counter_position = global_position

func _post_process_counter_constraints() -> void:
	if _snap_point and is_instance_valid(_snap_point) and not _snap_suppressed and _snap_blend > 0.0:
		return
	super._post_process_counter_constraints()

func enter_snap_zone(point: Node3D, pull_speed: float = 22.0, release_speed: float = 16.0, break_distance: float = 0.25) -> void:
	if _snap_point != point:
		_snap_blend = 0.0
		_snap_locked = false
	_snap_point = point
	_snap_pull_speed = pull_speed
	_snap_release_speed = release_speed
	_snap_break_distance = break_distance
	_snap_suppressed = false

func exit_snap_zone(point: Node3D) -> void:
	if _snap_point == point:
		_snap_point = null
		_snap_suppressed = false
		_snap_blend = 0.0
		if _snap_locked:
			_snap_locked = false
			snappedOut.emit(point)

func is_snapped() -> bool:
	return _snap_locked

func _update_snap(delta: float) -> void:
	if not _snap_point or not is_instance_valid(_snap_point):
		if _snap_point != null:
			_snap_point = null
		_snap_suppressed = false
		_snap_blend = 0.0
		if _snap_locked:
			_snap_locked = false
			snappedOut.emit(null)
		return

	_snap_pos = _snap_point.global_position
	var want: float = 0.0
	if is_balls_dragging:
		var drag_target := _get_counter_drag_target()
		var flat := Vector2(drag_target.x - _snap_pos.x, drag_target.z - _snap_pos.z)
		var dist := flat.length()
		if _snap_suppressed:
			if dist <= _snap_break_distance * 0.6:
				_snap_suppressed = false
		elif dist > _snap_break_distance:
			_snap_suppressed = true
		if not _snap_suppressed:
			want = 1.0
	elif not _snap_suppressed:
		want = 1.0

	var speed := _snap_pull_speed if want > _snap_blend else _snap_release_speed
	_snap_blend = lerpf(_snap_blend, want, 1.0 - exp(-speed * delta))
	if absf(_snap_blend - want) < 0.01:
		_snap_blend = want

	if _snap_blend > 0.0:
		var target := Vector3(_snap_pos.x, global_position.y, _snap_pos.z)
		global_position = global_position.lerp(target, _snap_blend)
		if _snap_blend >= 0.99:
			push_velocity = Vector3.ZERO
		if camera:
			_face_camera()

	var locked_now: bool = _snap_blend >= 0.95 and want >= 1.0
	if locked_now and not _snap_locked:
		_snap_locked = true
		_play_snap_bounce()
		snappedIn.emit(_snap_point)
	elif not locked_now and _snap_locked:
		_snap_locked = false
		snappedOut.emit(_snap_point)

func _play_snap_bounce() -> void:
	if not sprite:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", _inside_base_scale * Vector3(1.08, 0.92, 1.0), 0.05)
	tween.tween_property(sprite, "scale", _inside_base_scale, 0.12)

func _apply_collision_push(delta: float) -> void:
	var surface_y := get_working_area_surface_y()
	if absf(global_position.y - surface_y) > 0.15:
		return

	for area in get_overlapping_areas():
		if area == self or not (area is Glasses):
			continue
		var other := area as Glasses
		if other._is_drag_blocked() or other.get_drag_mode() != DragMode.COLLISION:
			continue
		if absf(other.global_position.y - surface_y) > 0.15:
			continue

		var diff := global_position - other.global_position
		diff.y = 0.0
		var dist := diff.length()
		if dist < 0.001:
			diff = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			dist = 0.001
		var overlap := INTERACTION_SEPARATION_DISTANCE - dist
		if overlap <= 0.0:
			continue

		var dir := diff.normalized()
		if is_balls_dragging:
			if not other.is_balls_dragging:
				global_position += dir * (overlap * 0.25)
		else:
			if other.is_balls_dragging:
				global_position += dir * (overlap * 0.75)
				push_velocity += dir * (overlap * 12.0 * delta)
			else:
				push_velocity += dir * (overlap * 8.0 * delta)

	if not is_balls_dragging and push_velocity.length_squared() > 0.0001:
		global_position += push_velocity * delta
		push_velocity = push_velocity.lerp(Vector3.ZERO, 1.0 - exp(-PUSH_FRICTION * delta))
		if camera:
			_face_camera()

func _face_camera() -> void:
	if not camera:
		return
	var visual: Node3D = sprite if sprite else get_node_or_null("Inside")
	if visual:
		var target_flat := camera.global_position
		target_flat.y = visual.global_position.y
		if target_flat.distance_squared_to(visual.global_position) > 0.0001:
			visual.look_at(target_flat, Vector3.UP)
			if not is_zero_approx(pour_tilt_degrees):
				visual.rotate_object_local(Vector3.BACK, deg_to_rad(pour_tilt_degrees))

func _setup_liquid_shader() -> void:
	var outside_sprite := get_node_or_null("Inside/Outside") as Sprite3D
	visual_helper.setup_shader(outside_sprite)
	_rebuild_liquid_gradient(false)

func _update_shader_parameters() -> void:
	var fill_ratio := clampf(total_liquids / maxf(size, 0.001), 0.0, 1.0)
	visual_helper.sync_shader_from_owner(fill_ratio, self)

func _rebuild_liquid_gradient(show_hud: bool = true) -> void:
	total_liquids = 0.0
	for l in liquids:
		total_liquids += float(l[1])
	visual_helper.rebuild_gradient(liquids, total_liquids, size, is_mixed())
	if show_hud and not liquids.is_empty() and total_liquids > 0.0:
		var hud := HudIndicators.get_current()
		if hud:
			hud.update_pouring_indicator(self, liquids, size, visual_helper)

func _pouring(id: String, liquids_num: float, pour_info: Dictionary = {}) -> float:
	if liquids_num <= 0.0:
		return 0.0

	_sync_drink_mix_metadata()

	var current_total: float = 0.0
	for l in liquids:
		current_total += float(l[1])

	var available_space := maxf(0.0, size - current_total)
	var added := minf(liquids_num, available_space)
	var overflow := maxf(0.0, liquids_num - added)

	if overflow > OVERFLOW_EPSILON:
		var overflow_percent := (overflow / maxf(size, 0.001)) * 100.0
		drink_mix.add_overfill(overflow_percent)
		_trigger_overflow_spilling(id, overflow)
		_notify_spill_indicator(overflow_percent)

	var col: Color = visual_helper.LIQUID_COLOR.get(id, Color.WHITE)

	if added > 0.0:
		# stack liquid onto matching top layer or append a new layer
		if not liquids.is_empty():
			var top_drink = liquids[liquids.size() - 1]
			if top_drink[0] is String and top_drink[0] == id:
				top_drink[1] += added
				if top_drink.size() > 3 and top_drink[3] is Dictionary:
					top_drink[3][id] = top_drink[1]
			else:
				liquids.push_back([id, added, col, {id: added}])
		else:
			liquids.push_back([id, added, col, {id: added}])

		# keep typed drink mix in sync
		drink_mix.add_liquid(id, added)

		var effective_pour := pour_info.duplicate()
		effective_pour["from_pour"] = true
		if not effective_pour.has("entry_u"):
			effective_pour["entry_u"] = 0.5
		if not effective_pour.has("stream_vy"):
			effective_pour["stream_vy"] = 34.0
		if visual_helper.has_method("set_next_pour_info"):
			visual_helper.call("set_next_pour_info", effective_pour)

		var vx_imp := float(effective_pour.get("stream_vx", 0.0)) * 0.25 + randf_range(-1.6, 1.6)
		visual_helper.add_agitation(Vector2(vx_imp, 3.8))
		visual_helper.slosh_vertical_velocity += randf_range(-0.12, 0.04)
		_rebuild_liquid_gradient(true)
	elif overflow > OVERFLOW_EPSILON:
		var vx_imp := float(pour_info.get("stream_vx", 0.0)) * 0.25 + randf_range(-1.6, 1.6)
		visual_helper.add_agitation(Vector2(vx_imp, 3.2))
		visual_helper.slosh_vertical_velocity += randf_range(-0.1, 0.04)
		var hud := HudIndicators.get_current()
		if hud and not liquids.is_empty():
			hud.update_pouring_indicator(self, liquids, size, visual_helper)

	if added > 0.0 or overflow > OVERFLOW_EPSILON:
		_trigger_pour_splash(id, liquids_num, pour_info)

	return liquids_num

func reset_cup(show_empty_indicator: bool = false) -> void:
	var had_spectral := drink_mix.has_processing("spectral")
	liquids.clear()
	total_liquids = 0.0
	drink_mix.reset()
	garnish_visuals.clear()
	_sync_drink_mix_metadata()
	if visual_helper:
		visual_helper.set_visual_override({})
		visual_helper.wave_amplitude = 0.0
		if not is_pouring_out:
			visual_helper.slosh_angle = 0.0
			visual_helper.slosh_velocity = 0.0
			visual_helper.slosh_vertical_offset = 0.0
			visual_helper.slosh_vertical_velocity = 0.0
	if had_spectral and sprite:
		SpectralEffect.clear_from_sprite(sprite, SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS)
	if not is_pouring_out:
		pour_tilt_degrees = 0.0
		_target_pour_tilt_degrees = 0.0
	if is_instance_valid(_pour_out_stream):
		_pour_out_stream.set_stream_active(false)
	_stop_pour_splash()
	_stop_overflow_streams()
	_spill_indicator_cooldown = 0.0
	_spill_accumulated_percent = 0.0
	_rebuild_liquid_gradient(false)
	_update_shader_parameters()
	_remove_displaying_list(true)
	if show_empty_indicator:
		var hud := HudIndicators.get_current()
		if hud:
			hud.show_cup_empty_indicator(self)

func _pour_out(liquids_num: float) -> float:
	if liquids_num <= 0.0 or liquids.is_empty():
		return 0.0

	for i in range(liquids.size() - 1, -1, -1):
		var l = liquids[i]
		if not (l is Array) or l.size() < 2 or float(l[1]) <= 0.0001:
			liquids.remove_at(i)

	if liquids.is_empty():
		reset_cup(is_pouring_out or is_instance_valid(_active_trash))
		return 0.0

	var remaining_to_remove := liquids_num
	var total_removed := 0.0

	while remaining_to_remove > 0.0001 and not liquids.is_empty():
		var top_idx := _get_top_buoyant_layer_index()
		if top_idx == -1:
			liquids.clear()
			break

		var top_layer = liquids[top_idx]
		var layer_amt := float(top_layer[1])
		var remove_amt := minf(remaining_to_remove, layer_amt)
		var new_layer_amt := layer_amt - remove_amt
		var remove_layer := new_layer_amt <= 0.001
		var actual_layer_remove := layer_amt if remove_layer else remove_amt
		var keep_ratio := 0.0 if remove_layer else clampf(new_layer_amt / layer_amt, 0.0, 1.0)
		top_layer[1] = 0.0 if remove_layer else new_layer_amt

		if top_layer.size() > 3 and top_layer[3] is Dictionary and not (top_layer[3] as Dictionary).is_empty():
			var ing_dict: Dictionary = top_layer[3]
			for ing_key in ing_dict.keys():
				var prev_ing := float(ing_dict[ing_key])
				var new_ing := prev_ing * keep_ratio
				ing_dict[ing_key] = new_ing
				_subtract_drink_mix_liquid(str(ing_key), prev_ing - new_ing)
		elif top_layer[0] is Array:
			var ing_arr: Array = top_layer[0]
			var per_ing_remove := actual_layer_remove / maxf(float(ing_arr.size()), 1.0)
			for ing_key in ing_arr:
				_subtract_drink_mix_liquid(str(ing_key), per_ing_remove)
		elif top_layer[0] is Dictionary:
			var ing_dict: Dictionary = top_layer[0]
			for ing_key in ing_dict.keys():
				var prev_ing := float(ing_dict[ing_key])
				var new_ing := prev_ing * keep_ratio
				ing_dict[ing_key] = new_ing
				_subtract_drink_mix_liquid(str(ing_key), prev_ing - new_ing)
		else:
			_subtract_drink_mix_liquid(str(top_layer[0]), actual_layer_remove)

		if remove_layer:
			liquids.remove_at(top_idx)

		remaining_to_remove -= remove_amt
		total_removed += remove_amt

	var leftover_total: float = 0.0
	for l in liquids:
		if l is Array and l.size() >= 2:
			leftover_total += float(l[1])
	if leftover_total <= 0.001:
		liquids.clear()

	if total_removed <= 0.0 and not liquids.is_empty():
		return 0.0

	visual_helper.add_agitation(Vector2(randf_range(-1.2, 1.2), -1.5))
	visual_helper.slosh_vertical_velocity += randf_range(-0.12, 0.04)

	if liquids.is_empty():
		reset_cup(is_pouring_out or is_instance_valid(_active_trash))
	else:
		_rebuild_liquid_gradient(true)
		if total_liquids < size:
			_stop_overflow_streams()

	return total_removed

func _subtract_drink_mix_liquid(id: String, amount: float) -> void:
	if amount <= 0.0 or not drink_mix.ingredients.has(id):
		return
	var updated := float(drink_mix.ingredients[id]) - amount
	if updated <= 0.0001:
		drink_mix.ingredients.erase(id)
	else:
		drink_mix.ingredients[id] = updated

func start_pour_out(tilt_degrees: float = 80.0) -> void:
	is_pouring_out = true
	_is_actively_pouring_out = true
	visual_helper.set_mouth_monitoring(true)
	_is_pointer_pressed = false
	is_balls_dragging = false
	push_velocity = Vector3.ZERO
	_stop_pour_splash()
	_target_pour_tilt_degrees = tilt_degrees
	if _pour_tilt_tween and _pour_tilt_tween.is_valid():
		_pour_tilt_tween.kill()

func set_pour_out_tilt(tilt_degrees: float) -> void:
	_target_pour_tilt_degrees = tilt_degrees

func stop_pour_out() -> void:
	_is_actively_pouring_out = false
	visual_helper.set_mouth_monitoring(is_instance_valid(_active_trash))
	_target_pour_tilt_degrees = 0.0
	if is_instance_valid(_pour_out_stream):
		_pour_out_stream.set_stream_active(false)
	if _pour_tilt_tween and _pour_tilt_tween.is_valid():
		_pour_tilt_tween.kill()
	_pour_tilt_tween = create_tween()
	_pour_tilt_tween.set_trans(Tween.TRANS_SINE)
	_pour_tilt_tween.set_ease(Tween.EASE_OUT)
	_pour_tilt_tween.tween_property(self, "pour_tilt_degrees", 0.0, 0.18)
	_pour_tilt_tween.finished.connect(func():
		is_pouring_out = false
	)

func is_full() -> bool:
	var current_total: float = 0.0
	for l in liquids:
		current_total += float(l[1])
	return current_total >= size

func _pushing_glass(other_glass: Area3D) -> void:
	var push_dir := global_position - other_glass.global_position
	push_dir.y = 0.0
	if push_dir.length() < 0.001:
		push_dir = Vector3(1.0, 0.0, 0.0)
	push_velocity += push_dir.normalized() * 0.1
	GameState.play_sfx("play_mugpickup")

func _in_game() -> void:
	_is_actively_pouring_out = false
	visual_helper.set_mouth_monitoring(false)
	_snap_point = null
	_snap_locked = false
	_snap_blend = 0.0
	push_velocity = Vector3.ZERO
	if is_instance_valid(_pour_out_stream):
		_pour_out_stream.set_stream_active(false)
	_stop_pour_splash()
	_stop_overflow_streams()
	super._in_game()

func return_to_location(target_raw_pos: Vector3, duration: float = 0.3, clear_snap: bool = false) -> void:
	if clear_snap:
		_snap_suppressed = true
		_snap_blend = 0.0
		if _snap_locked:
			_snap_locked = false
			snappedOut.emit(_snap_point)
		_snap_point = null
		_active_trash = null
		visual_helper.set_mouth_monitoring(false)
		_is_pointer_pressed = false
		is_balls_dragging = false
		push_velocity = Vector3.ZERO
	var target_pos := _get_saved_counter_position(target_raw_pos)
	_last_counter_position = target_pos
	if global_position.distance_to(target_pos) > 0.005:
		_return_to_counter_smoothly(target_pos, duration)
	else:
		global_position = target_pos
		base_y_position = target_pos.y
		_on_returned_to_counter(target_pos)

func return_to_previous_location(duration: float = 0.3) -> void:
	var fallback := _previous_counter_position if _previous_counter_position != Vector3.ZERO else _last_counter_position
	return_to_location(fallback, duration, true)

func _out_of_game() -> void:
	in_game = false
	_spill_indicator_cooldown = 0.0
	_spill_accumulated_percent = 0.0
	_stop_pour_splash()
	_stop_overflow_streams()
	if area_body:
		area_body.disabled = false
	_remove_displaying_list()
	return_to_location(_last_counter_position, 0.3, false)

func _on_hover(hovered: bool) -> void:
	set_highlight(hovered)

func _giving_drink() -> void:
	if input_event.is_connected(_on_area_3d_input_event):
		input_event.disconnect(_on_area_3d_input_event)
	is_balls_dragging = false

func _dranked() -> void:
	if is_consumed:
		return
	is_consumed = true
	_is_actively_pouring_out = false
	visual_helper.set_mouth_monitoring(false)
	if is_instance_valid(_pour_out_stream):
		_pour_out_stream.set_stream_active(false)
	_stop_pour_splash()
	_stop_overflow_streams()
	queue_free()

func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("glass") and get_drag_mode() == DragMode.COLLISION and not is_balls_dragging:
		_pushing_glass(area)

func can_interact_with(target: Ingredients) -> bool:
	if _is_drag_blocked() or not is_instance_valid(target) or target == self:
		return false
	if target is Glasses:
		return false
	if target is Shaker:
		return can_be_shaken()
	if target is Drinks:
		return target.can_interact_with(self)
	if target.has_method("_get_npc"):
		var npc = target._get_npc()
		if is_instance_valid(npc):
			return can_serve_npc(npc)
	return target.can_interact_with(self)

func execute_interaction(target: Ingredients) -> void:
	if not can_interact_with(target):
		return
	if target is Shaker and can_be_shaken():
		target.start_shake(self)
	elif target is Drinks and target.can_interact_with(self):
		target.execute_interaction(self)
	elif target.has_method("_get_npc"):
		var npc = target._get_npc()
		if is_instance_valid(npc) and can_serve_npc(npc):
			target.set_highlight(false)
			execute_npc_interaction(npc)
	else:
		target.execute_interaction(self)

func can_serve_npc(npc: Base_NPC) -> bool:
	if _is_drag_blocked():
		return false
	if not is_instance_valid(npc):
		return false
	return npc.can_accept_drink()

func execute_npc_interaction(npc: Base_NPC) -> void:
	if not can_serve_npc(npc):
		on_drop_failed()
		return
	is_being_served = true
	_snap_point = null
	_snap_locked = false
	_snap_blend = 0.0
	_is_pointer_pressed = false
	is_balls_dragging = false
	_remove_displaying_list()
	if has_method("_giving_drink"):
		call("_giving_drink")
	if GameState.seat_manager:
		GameState.seat_manager.serve_cup_to_npc(self, npc)

func on_drop_failed() -> void:
	if _snap_point and is_instance_valid(_snap_point) and not _snap_suppressed:
		_last_counter_position = Vector3(_snap_point.global_position.x, get_working_area_surface_y(), _snap_point.global_position.z)
		base_y_position = _last_counter_position.y
		return
	super.on_drop_failed()

func _on_returning_to_counter(target_pos: Vector3) -> void:
	super._on_returning_to_counter(target_pos)
	if not is_instance_valid(_active_trash):
		_previous_counter_position = target_pos

func _on_returned_to_counter(target_pos: Vector3) -> void:
	super._on_returned_to_counter(target_pos)
	if not is_instance_valid(_active_trash):
		_previous_counter_position = target_pos

func _remove_displaying_list(immediate: bool = false) -> void:
	var hud := HudIndicators.get_current()
	if hud:
		hud.hide_pouring_indicator(self, immediate)

func get_unique_liquids_ids() -> Array[String]:
	return drink_mix.get_unique_ingredient_ids()

func can_be_shaken() -> bool:
	if in_game or is_being_served:
		return false
	if liquids.is_empty():
		return false
	if get_unique_liquids_ids().size() < 2:
		return false
	return not is_mixed()

func is_mixed() -> bool:
	if liquids.size() != 1:
		return false
	var layer0 = liquids[0]
	return (layer0[0] is Array or layer0[0] is Dictionary) and layer0[0].size() >= 2

func mark_mixed() -> void:
	if get_unique_liquids_ids().size() < 2 or liquids.is_empty():
		return

	var combined_amounts: Dictionary = {}
	var color_weights: Array = []
	var total_amount: float = 0.0

	for layer in liquids:
		var layer_amt := float(layer[1])
		if layer_amt <= 0.0:
			continue
		total_amount += layer_amt
		if layer.size() > 3 and layer[3] is Dictionary:
			for ing in layer[3]:
				var a := float(layer[3][ing])
				combined_amounts[str(ing)] = combined_amounts.get(str(ing), 0.0) + a
				color_weights.append([visual_helper.LIQUID_COLOR.get(str(ing), Color.WHITE), a])
		elif layer[0] is Array:
			var split_a := layer_amt / maxf(float(layer[0].size()), 1.0)
			for ing in layer[0]:
				var s := str(ing)
				combined_amounts[s] = combined_amounts.get(s, 0.0) + split_a
				color_weights.append([visual_helper.LIQUID_COLOR.get(s, Color.WHITE), split_a])
		else:
			var s := str(layer[0])
			combined_amounts[s] = combined_amounts.get(s, 0.0) + layer_amt
			color_weights.append([visual_helper.LIQUID_COLOR.get(s, Color.WHITE), layer_amt])

	var mixed_color := visual_helper.average_hsv_color(color_weights)
	var mixed_names: Array[String] = []
	for k in combined_amounts.keys():
		mixed_names.append(str(k))
	mixed_names.sort()

	liquids.clear()
	liquids.push_back([mixed_names, total_amount, mixed_color, combined_amounts])
	drink_mix.add_processing("shaken")
	_rebuild_liquid_gradient(true)

func get_mixed_ingredients() -> Array[String]:
	return get_unique_liquids_ids()
