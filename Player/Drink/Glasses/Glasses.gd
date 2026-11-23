# Physical 3D drink container holding a typed DrinkMix instance
extends Ingredients
class_name Glasses

const MIN_POUR_OUT_TILT_DEGREES: float = 5.0
const SPILL_INDICATOR_COOLDOWN: float = 0.55
const OVERFLOW_EPSILON: float = 0.0005
const PUSH_FRICTION: float = 14.0
const INTERACTION_SEPARATION_DISTANCE: float = 0.14

@onready var tcmtd := preload("res://Player/Drink/Glasses/liquids_label.tscn")
@export var size: float = 1.0
@export var area_body: CollisionShape3D
@export var sprite: Sprite3D
@export var liquid_box: VBoxContainer = null
@export var customer_hold_distance: float = 1.0

var drink_mix: DrinkMix = DrinkMix.new()
var liquids: Array:
	get: return drink_mix.layers
	set(value): drink_mix.layers = value

var visual_helper: LiquidVisualHelper = LiquidVisualHelper.new()
var _snap_follower: SnapZoneFollower = SnapZoneFollower.new()
var _streams_vfx: GlassStreamsVfx = null

var drink_list_label: Label
var total_liquids: float = 0.0
var in_game: bool = false
var is_being_served: bool = false
var is_delivering: bool = false
var is_consumed: bool = false
var is_pouring_out: bool = false
var _is_actively_pouring_out: bool = false
var pour_tilt_degrees: float = 0.0
var _target_pour_tilt_degrees: float = 0.0
var _pour_tilt_tween: Tween = null
var _active_trash: Area3D = null
var _last_counter_position: Vector3 = Vector3.ZERO
var _previous_counter_position: Vector3 = Vector3.ZERO
var _skip_initial_snap: bool = false
var _spill_indicator_cooldown: float = 0.0
var _spill_accumulated_percent: float = 0.0

@export_group("Liquid Physics")
@export var viscosity: float = 0.0
@export var spring_stiffness: float = 75.0
@export var base_damping: float = 4.0
@export var slosh_sensitivity: float = 0.28
@export var max_slosh_angle: float = 0.85
@export var wave_frequency: float = 16.0
@export var vertical_spring: float = 90.0
@export var vertical_damping: float = 5.0
@export var vertical_sensitivity: float = 0.15

@export_group("Liquid Shading")
@export var pixel_resolution: float = 48.0
@export var surface_highlight_color: Color = Color(1.4, 1.4, 1.5, 1.0)
@export var secondary_highlight_color: Color = Color(0.9, 0.4, 0.95, 0.85)
@export var surface_highlight_pixels: float = 1.2
@export var bottom_darkening: float = 0.45
@export var liquid_transparency: float = 0.9
@export var caustic_beam_strength: float = 0.35
@export var sparkle_density: float = 0.7
@export var glass_reflection_strength: float = 0.28
@export var meniscus_curve: float = 0.03
@export var inner_margin_top: float = 0.12
@export var inner_margin_bottom: float = 0.88

var push_velocity: Vector3 = Vector3.ZERO
@export var dead_zone := 50.0
@export var full_pull := 150.0
@export var max_hand_distance := 20.0

signal snappedIn(point: Node3D)
signal snappedOut(point: Node3D)

var _inside_base_scale: Vector3 = Vector3.ONE
var _inside_base_pos: Vector3 = Vector3.ZERO
@onready var highlight = get_node_or_null("Inside/highlight")

func is_working_area_item() -> bool:
	return true

func _is_drag_blocked() -> bool:
	return in_game or is_being_served or is_consumed or is_pouring_out

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

func get_drink_mix() -> DrinkMix:
	return drink_mix

func get_resource_usage_multiplier(liquid_id: String = "") -> float:
	var sp_mult := SpeciesRegistry.get_glass_resource_multiplier(self, liquid_id)
	var mod_mult := ModifierRegistry.get_glass_resource_multiplier(self, liquid_id)
	return maxf(0.05, sp_mult * mod_mult)

func can_highlight_on_hover() -> bool:
	if _is_drag_blocked():
		return false
	var tool_ctrl := ToolController.get_active()
	return tool_ctrl.can_highlight_glass(self) if tool_ctrl else true

func handle_immediate_tool_click() -> bool:
	if GameState.is_dialogue_open or ShakerMinigame.active or _is_drag_blocked():
		return false
	var tool_ctrl := ToolController.get_active()
	var active_tool := tool_ctrl.get_tool() if tool_ctrl else "hand"
	if tool_ctrl and active_tool != "hand":
		if tool_ctrl.handle_glass_click(self, GameState.player):
			return true
		if tool_ctrl.should_consume_glass_click(self):
			return true
	elif is_instance_valid(_active_trash) and _active_trash.has_method("can_pour_glass") and _active_trash.can_pour_glass(self):
		_active_trash.call("start_pour")
		return true
	return false

func handle_non_drag_click() -> bool:
	var tool_ctrl := ToolController.get_active()
	return tool_ctrl.handle_glass_click(self, GameState.player) if tool_ctrl else false

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
	return PourStreamVisual.get_sprite_top_spout_world_position(sp) if sp else (global_position + Vector3(0.0, 0.08, 0.0))

func get_liquid_surface_world_position() -> Vector3:
	var sp := _get_container_sprite()
	if sp:
		var fill_ratio := clampf(total_liquids / maxf(size, 0.001), 0.05, 0.96)
		return PourStreamVisual.get_sprite_surface_world_position(sp, fill_ratio)
	return global_position

func get_pour_spout_world_position() -> Vector3:
	var sp := _get_container_sprite()
	return PourStreamVisual.get_sprite_rim_spout_world_position(sp, pour_tilt_degrees) if sp else global_position

func get_top_liquid_color() -> Color:
	var top_idx := drink_mix.get_top_buoyant_layer_index()
	if top_idx == -1:
		return Color.WHITE
	var top_layer = liquids[top_idx]
	return visual_helper.get_layer_color(top_layer) if top_layer is Array else Color.WHITE

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

func _ensure_streams_vfx() -> void:
	if not is_instance_valid(_streams_vfx):
		_streams_vfx = GlassStreamsVfx.new()
		add_child(_streams_vfx)

func _apply_tint_override(base_col: Color) -> Color:
	if visual_helper and visual_helper._visual_override.has("liquid_tint_color"):
		var tint_col: Color = visual_helper._visual_override.get("liquid_tint_color", Color.WHITE)
		var tint_mix: float = float(visual_helper._visual_override.get("liquid_tint_strength", 0.35))
		return base_col.lerp(Color(tint_col.r, tint_col.g, tint_col.b, base_col.a), tint_mix)
	return base_col

func _notify_spill_indicator(overflow_percent: float) -> void:
	_spill_accumulated_percent += overflow_percent
	if _spill_indicator_cooldown > 0.0:
		return
	GameEvents.cup_spilled.emit(self, _spill_accumulated_percent)
	_spill_accumulated_percent = 0.0
	_spill_indicator_cooldown = SPILL_INDICATOR_COOLDOWN

func ready() -> void:
	rotation = Vector3.ZERO
	if sprite:
		_inside_base_scale = sprite.scale
		_inside_base_pos = sprite.position
	_ensure_streams_vfx()
	if not _snap_follower.snapped_in.is_connected(_on_snap_in):
		_snap_follower.snapped_in.connect(_on_snap_in)
	if not _snap_follower.snapped_out.is_connected(_on_snap_out):
		_snap_follower.snapped_out.connect(_on_snap_out)
	_setup_liquid_shader()
	if highlight:
		highlight.modulate = Color(1.5, 1.5, 0.0, 5.0)
	if camera:
		_look_at_sprite(camera.global_position)
	if not _skip_initial_snap:
		_snap_to_working_area()
	else:
		base_y_position = get_working_area_surface_y()
	_last_counter_position = global_position
	_previous_counter_position = global_position
	visual_helper.last_global_pos = sprite.global_position if sprite else global_position

func _on_snap_in(point: Node3D) -> void:
	snappedIn.emit(point)

func _on_snap_out(point: Node3D) -> void:
	snappedOut.emit(point)

func _exit_tree() -> void:
	visual_helper.cleanup()
	if is_instance_valid(_streams_vfx):
		_streams_vfx.stop_all()
	if GameEvents._bus:
		GameEvents.cup_pouring_stopped.emit(self, false)

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
		_look_at_sprite(camera.global_position)
	super.start_drag_from_spawn(press_screen_pos, from_shelf)

func _delete() -> void:
	_remove_displaying_list()
	if is_instance_valid(_streams_vfx):
		_streams_vfx.stop_all()
	queue_free()

func _update_hand_position(delta: float) -> void:
	if not camera or not GameState.player or camera.is_position_behind(global_position):
		return
	var mouse := get_viewport().get_mouse_position()
	var glass_screen := camera.unproject_position(global_position)
	var gap := mouse.x - glass_screen.x
	var pull := clampf(maxf(absf(gap) - dead_zone, 0.0) / full_pull, 0.0, 1.0)
	var goal := mouse.lerp(glass_screen, pull)
	var hand = GameState.player.hand_sprite
	GameEvents.sfx_requested.emit("mugpickup")
	if hand:
		hand.global_position = hand.global_position.lerp(goal, 1.0 - exp(-30.0 * delta))

func _process(delta: float) -> void:
	super._process(delta)
	_snap_follower.update_snap(self, delta, is_balls_dragging, _get_counter_drag_target(), camera, sprite, _inside_base_scale)
	if _spill_indicator_cooldown > 0.0:
		_spill_indicator_cooldown = maxf(0.0, _spill_indicator_cooldown - delta)

	if is_pouring_out and not (_pour_tilt_tween and _pour_tilt_tween.is_valid()):
		pour_tilt_degrees = lerpf(pour_tilt_degrees, _target_pour_tilt_degrees, 1.0 - exp(-18.0 * delta))

	if camera and not is_balls_dragging:
		_look_at_sprite(camera.global_position)

	_ensure_streams_vfx()
	_streams_vfx.update_all(delta, self, _get_container_sprite(), camera)

	var track_pos: Vector3 = sprite.global_position if sprite else global_position
	var outside_sprite := get_node_or_null("Inside/Outside") as Node3D
	visual_helper.update_physics(delta, track_pos, camera, viscosity, spring_stiffness, base_damping, slosh_sensitivity, max_slosh_angle, wave_frequency, vertical_spring, vertical_damping, vertical_sensitivity, outside_sprite)
	if not is_consumed:
		_update_shader_parameters()

	if _is_drag_blocked():
		return

	if is_balls_dragging:
		_update_hand_position(delta)

	if get_drag_mode() == DragMode.COLLISION and not _is_returning_to_counter and not _is_mode_transitioning:
		_apply_collision_push(delta)
		if not is_balls_dragging:
			if not is_selected:
				var target_y := get_working_area_surface_y()
				base_y_position = target_y
				global_position.y = target_y if absf(global_position.y - target_y) <= 0.002 else lerpf(global_position.y, target_y, 1.0 - exp(-20.0 * delta))
			_last_counter_position = global_position
			if not is_instance_valid(_active_trash):
				_previous_counter_position = global_position

func _post_process_counter_constraints() -> void:
	if _snap_follower.is_actively_holding():
		return
	super._post_process_counter_constraints()

func enter_snap_zone(point: Node3D, pull_speed: float = 22.0, release_speed: float = 16.0, break_distance: float = 0.25) -> void:
	_snap_follower.enter_snap_zone(point, pull_speed, release_speed, break_distance)

func exit_snap_zone(point: Node3D) -> void:
	_snap_follower.exit_snap_zone(point)

func is_snapped() -> bool:
	return _snap_follower.is_snapped()

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
		elif other.is_balls_dragging:
			global_position += dir * (overlap * 0.75)
			push_velocity += dir * (overlap * 12.0 * delta)
		else:
			push_velocity += dir * (overlap * 8.0 * delta)

	if not is_balls_dragging and push_velocity.length_squared() > 0.0001:
		global_position += push_velocity * delta
		push_velocity = push_velocity.lerp(Vector3.ZERO, 1.0 - exp(-PUSH_FRICTION * delta))
		if camera:
			_look_at_sprite(camera.global_position)

func _look_at_sprite(looking_at: Vector3) -> void:
	if looking_at and sprite:
		var target_flat := looking_at
		target_flat.y = sprite.global_position.y
		if target_flat.distance_squared_to(sprite.global_position) > 0.0001:
			sprite.look_at(target_flat, Vector3.UP)
			if not is_zero_approx(pour_tilt_degrees):
				sprite.rotate_object_local(Vector3.BACK, deg_to_rad(pour_tilt_degrees))

func _setup_liquid_shader() -> void:
	var outside_sprite := get_node_or_null("Inside/Outside") as Sprite3D
	visual_helper.setup_shader(outside_sprite)
	_rebuild_liquid_gradient(false)

func _update_shader_parameters() -> void:
	var fill_ratio := clampf(total_liquids / maxf(size, 0.001), 0.0, 1.0)
	visual_helper.sync_shader_uniforms(fill_ratio, {
		"pixel_resolution": pixel_resolution,
		"surface_highlight_color": surface_highlight_color,
		"secondary_highlight_color": secondary_highlight_color,
		"surface_highlight_thickness": surface_highlight_pixels,
		"bottom_darkening": bottom_darkening,
		"liquid_transparency": liquid_transparency,
		"caustic_beam_strength": caustic_beam_strength,
		"sparkle_density": sparkle_density,
		"glass_reflection_strength": glass_reflection_strength,
		"meniscus_curve": meniscus_curve,
		"inner_margin_top": inner_margin_top,
		"inner_margin_bottom": inner_margin_bottom
	})

func _rebuild_liquid_gradient(show_hud: bool = true) -> void:
	total_liquids = 0.0
	for l in liquids:
		total_liquids += float(l[1])
	drink_list_label = visual_helper.rebuild_gradient(liquids, total_liquids, size, liquid_box, tcmtd, is_mixed())
	if show_hud and not liquids.is_empty() and total_liquids > 0.0:
		GameEvents.cup_pouring_updated.emit(self, liquids, size, visual_helper)

func _pouring(id: String, liquids_num: float, pour_info: Dictionary = {}) -> float:
	if liquids_num <= 0.0:
		return 0.0

	_ensure_streams_vfx()
	var current_total := drink_mix.get_total_amount()
	var available_space := maxf(0.0, size - current_total)
	var added := minf(liquids_num, available_space)
	var overflow := maxf(0.0, liquids_num - added)

	var incoming_col: Color = visual_helper.LIQUID_COLOR.get(id, Color.WHITE)
	if overflow > OVERFLOW_EPSILON:
		var overflow_percent := (overflow / maxf(size, 0.001)) * 100.0
		drink_mix.add_overfill(overflow_percent)
		var ov_col := get_top_liquid_color().lerp(incoming_col, 0.25) if not liquids.is_empty() else incoming_col
		_streams_vfx.trigger_overflow_spilling(_apply_tint_override(ov_col), overflow)
		_notify_spill_indicator(overflow_percent)

	if added > 0.0:
		drink_mix.add_layer(id, added, incoming_col)
		var effective_pour := pour_info.duplicate()
		effective_pour["from_pour"] = true
		if not effective_pour.has("entry_u"):
			effective_pour["entry_u"] = 0.5
		if not effective_pour.has("stream_vy"):
			effective_pour["stream_vy"] = 34.0
		visual_helper.set_next_pour_info(effective_pour)

		var vx_imp := float(effective_pour.get("stream_vx", 0.0)) * 0.25 + randf_range(-1.6, 1.6)
		visual_helper.add_agitation(Vector2(vx_imp, 3.8))
		visual_helper.slosh_vertical_velocity += randf_range(-0.12, 0.04)
		_rebuild_liquid_gradient(true)
	elif overflow > OVERFLOW_EPSILON:
		var vx_imp := float(pour_info.get("stream_vx", 0.0)) * 0.25 + randf_range(-1.6, 1.6)
		visual_helper.add_agitation(Vector2(vx_imp, 3.2))
		visual_helper.slosh_vertical_velocity += randf_range(-0.1, 0.04)
		if not liquids.is_empty():
			GameEvents.cup_pouring_updated.emit(self, liquids, size, visual_helper)

	if added > 0.0 or overflow > OVERFLOW_EPSILON:
		var sp_col := incoming_col.lerp(get_top_liquid_color(), 0.2) if not liquids.is_empty() else incoming_col
		_streams_vfx.trigger_pour_splash(_apply_tint_override(sp_col), liquids_num, pour_info)

	return liquids_num

func reset_cup(show_empty_indicator: bool = false) -> void:
	var had_spectral := drink_mix.has_processing("spectral")
	total_liquids = 0.0
	drink_mix.reset()
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
	if is_instance_valid(_streams_vfx):
		_streams_vfx.stop_all()
	_spill_indicator_cooldown = 0.0
	_spill_accumulated_percent = 0.0
	_rebuild_liquid_gradient(false)
	_update_shader_parameters()
	_remove_displaying_list(true)
	if show_empty_indicator:
		GameEvents.cup_emptied.emit(self)

func _pour_out(liquids_num: float) -> float:
	if liquids_num <= 0.0 or liquids.is_empty():
		return 0.0

	var total_removed := drink_mix.drain_top(liquids_num)
	if total_removed <= 0.0 and not liquids.is_empty():
		return 0.0

	visual_helper.add_agitation(Vector2(randf_range(-1.2, 1.2), -1.5))
	visual_helper.slosh_vertical_velocity += randf_range(-0.12, 0.04)

	if liquids.is_empty():
		reset_cup(is_pouring_out or is_instance_valid(_active_trash))
	else:
		_rebuild_liquid_gradient(true)
		if total_liquids < size and is_instance_valid(_streams_vfx):
			_streams_vfx.stop_overflow_streams()

	return total_removed

func start_pour_out(tilt_degrees: float = 80.0) -> void:
	is_pouring_out = true
	_is_actively_pouring_out = true
	visual_helper.set_mouth_monitoring(true)
	_is_pointer_pressed = false
	is_balls_dragging = false
	push_velocity = Vector3.ZERO
	if is_instance_valid(_streams_vfx):
		_streams_vfx.stop_pour_splash()
	_target_pour_tilt_degrees = tilt_degrees
	if _pour_tilt_tween and _pour_tilt_tween.is_valid():
		_pour_tilt_tween.kill()

func set_pour_out_tilt(tilt_degrees: float) -> void:
	_target_pour_tilt_degrees = tilt_degrees

func stop_pour_out() -> void:
	_is_actively_pouring_out = false
	visual_helper.set_mouth_monitoring(is_instance_valid(_active_trash))
	_target_pour_tilt_degrees = 0.0
	if is_instance_valid(_streams_vfx):
		_streams_vfx.stop_pour_out()
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
	return drink_mix.get_total_amount() >= size

func _pushing_glass(other_glass: Area3D) -> void:
	var push_dir := global_position - other_glass.global_position
	push_dir.y = 0.0
	if push_dir.length() < 0.001:
		push_dir = Vector3(1.0, 0.0, 0.0)
	push_velocity += push_dir.normalized() * 0.1
	GameEvents.sfx_requested.emit("mugpickup")

func _in_game() -> void:
	in_game = true
	_is_actively_pouring_out = false
	visual_helper.set_mouth_monitoring(false)
	_snap_follower.clear_snap(false)
	_is_pointer_pressed = false
	is_balls_dragging = false
	_is_returning_to_counter = false
	_is_mode_transitioning = false
	push_velocity = Vector3.ZERO
	if is_instance_valid(_streams_vfx):
		_streams_vfx.stop_all()
	_drag_controller.kill_return_tween()
	if area_body:
		area_body.disabled = true

func return_to_location(target_raw_pos: Vector3, duration: float = 0.3, clear_snap: bool = false) -> void:
	if clear_snap:
		_snap_follower.clear_snap(true)
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
	if is_instance_valid(_streams_vfx):
		_streams_vfx.stop_pour_splash()
		_streams_vfx.stop_overflow_streams()
	if area_body:
		area_body.disabled = false
	_remove_displaying_list()
	return_to_location(_last_counter_position, 0.3, false)

func _on_hover(hovered: bool) -> void:
	set_highlight(hovered)

func _dranked() -> void:
	if is_consumed:
		return
	is_consumed = true
	_is_actively_pouring_out = false
	visual_helper.set_mouth_monitoring(false)
	if is_instance_valid(_streams_vfx):
		_streams_vfx.stop_all()
	queue_free()

func _return_drink() -> Array:
	return drink_mix.to_legacy_layers()

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
	if _is_drag_blocked() or not is_instance_valid(npc):
		return false
	return npc.can_accept_drink()

func execute_npc_interaction(npc: Base_NPC) -> void:
	if not can_serve_npc(npc):
		on_drop_failed()
		return
	is_being_served = true
	_snap_follower.clear_snap(false)
	_is_pointer_pressed = false
	is_balls_dragging = false
	_remove_displaying_list()
	if has_method("_giving_drink"):
		call("_giving_drink")
	if GameState.seat_manager:
		GameState.seat_manager.serve_cup_to_npc(self, npc)

func on_drop_failed() -> void:
	if _snap_follower.has_active_snap():
		var pt := _snap_follower.snap_point
		_last_counter_position = Vector3(pt.global_position.x, get_working_area_surface_y(), pt.global_position.z)
		base_y_position = _last_counter_position.y
		return
	var target_pos := _get_counter_drop_position(_last_counter_position) if _has_dragged else _get_saved_counter_position(_last_counter_position)
	_return_to_counter_smoothly(target_pos)

func _on_returning_to_counter(target_pos: Vector3) -> void:
	_last_counter_position = target_pos
	if not is_instance_valid(_active_trash):
		_previous_counter_position = target_pos

func _on_returned_to_counter(target_pos: Vector3) -> void:
	_last_counter_position = target_pos
	if not is_instance_valid(_active_trash):
		_previous_counter_position = target_pos

func _remove_displaying_list(immediate: bool = false) -> void:
	GameEvents.cup_pouring_stopped.emit(self, immediate)
	if liquid_box and liquid_box.modulate.a != 0.0:
		if immediate or not is_inside_tree():
			liquid_box.modulate.a = 0.0
		else:
			var tween := get_tree().create_tween().parallel()
			tween.tween_property(liquid_box, "modulate:a", 0.0, 1.0)

func get_unique_liquids_ids() -> Array[String]:
	return drink_mix.get_unique_ingredient_ids()

func can_be_shaken() -> bool:
	return not in_game and not is_being_served and drink_mix.can_be_shaken()

func is_mixed() -> bool:
	return drink_mix.is_mixed()

func mark_mixed() -> void:
	if drink_mix.mix_all(visual_helper.average_hsv_color, visual_helper.LIQUID_COLOR):
		_rebuild_liquid_gradient(true)

func get_mixed_ingredients() -> Array[String]:
	return get_unique_liquids_ids()
