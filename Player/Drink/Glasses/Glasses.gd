# Physical 3D drink container holding a typed DrinkMix instance
# Liquid pouring, liquid physics
extends Ingredients
class_name Glasses

@onready var tcmtd := preload("res://Player/Drink/Glasses/liquids_label.tscn")
@export var liquids: Array = []
@export var size: float = 1.0
@export var area_body: CollisionShape3D
@export var sprite: Sprite3D
@export var liquid_box: VBoxContainer
@export var customer_hold_distance: float = 1.0

var drink_mix: DrinkMix = DrinkMix.new()
var visual_helper: LiquidVisualHelper = LiquidVisualHelper.new()

var drink_list_label: Label
var total_liquids: float = 0.0
var in_game: bool = false
var is_being_served: bool = false
var is_delivering: bool = false
var is_consumed: bool = false
var _last_counter_position: Vector3 = Vector3.ZERO
var _skip_initial_snap: bool = false

@export_group("Liquid Physics")
@export var viscosity: float = 0.25
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
	return in_game or is_being_served or is_consumed

func get_drink_mix() -> DrinkMix:
	return drink_mix

func get_resource_usage_multiplier(liquid_id: String = "") -> float:
	var sp_mult := SpeciesRegistry.get_glass_resource_multiplier(self, liquid_id)
	var mod_mult := ModifierRegistry.get_glass_resource_multiplier(self, liquid_id)
	return maxf(0.05, sp_mult * mod_mult)

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
	return ModifierRegistry.can_highlight_glass(active_tool, self) and SpeciesRegistry.can_highlight_glass(active_tool, self)

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

func ready() -> void:
	rotation = Vector3.ZERO
	if sprite:
		_inside_base_scale = sprite.scale
		_inside_base_pos = sprite.position
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
	visual_helper.last_global_pos = global_position

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

	visual_helper.last_global_pos = global_position
	visual_helper.last_velocity = Vector3.ZERO
	if camera:
		_look_at_sprite(camera.global_position)
	super.start_drag_from_spawn(press_screen_pos, from_shelf)

func _delete() -> void:
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
	visual_helper.update_physics(delta, global_position, camera, viscosity, spring_stiffness, base_damping, slosh_sensitivity, max_slosh_angle, wave_frequency, vertical_spring, vertical_damping, vertical_sensitivity)
	if not is_consumed:
		_update_shader_parameters()

	if camera and not is_balls_dragging:
		_look_at_sprite(camera.global_position)
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
				if absf(global_position.y - target_y) <= 0.002:
					global_position.y = target_y
				else:
					global_position.y = lerpf(global_position.y, target_y, 1.0 - exp(-20.0 * delta))
			_last_counter_position = global_position

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

# snaps glass into keg pour zone when dragging nearby and releases when pulled beyond break distance
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
	# exponential ease
	_snap_blend = lerpf(_snap_blend, want, 1.0 - exp(-speed * delta))
	if absf(_snap_blend - want) < 0.01:
		_snap_blend = want

	if _snap_blend > 0.0:
		var target := Vector3(_snap_pos.x, global_position.y, _snap_pos.z)
		global_position = global_position.lerp(target, _snap_blend)
		if _snap_blend >= 0.99:
			push_velocity = Vector3.ZERO
		if camera:
			_look_at_sprite(camera.global_position)

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

# pushes nearby glasses apart when too close
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
			_look_at_sprite(camera.global_position)

func _look_at_sprite(looking_at: Vector3) -> void:
	if looking_at and sprite:
		var target_flat := looking_at
		target_flat.y = sprite.global_position.y
		if target_flat.distance_squared_to(sprite.global_position) > 0.0001:
			sprite.look_at(target_flat, Vector3.UP)

func _setup_liquid_shader() -> void:
	var outside_sprite = get_node_or_null("Inside/Outside")
	visual_helper.setup_shader(outside_sprite)
	_rebuild_liquid_gradient()

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

func _rebuild_liquid_gradient() -> void:
	total_liquids = 0.0
	for l in liquids:
		total_liquids += float(l[1])
	drink_list_label = visual_helper.rebuild_gradient(liquids, total_liquids, size, liquid_box, tcmtd)

func _pouring(id: String, liquids_num: float) -> float:
	var current_total: float = 0.0
	for l in liquids:
		current_total += float(l[1])

	var available_space := size - current_total
	if available_space <= 0.0:
		return 0.0

	liquids_num = minf(liquids_num, available_space)
	if liquids_num <= 0.0:
		return 0.0

	var col: Color = visual_helper.LIQUID_COLOR.get(id, Color.WHITE)

	# stack liquid onto matching top layer or append a new layer
	if not liquids.is_empty():
		var top_drink = liquids[liquids.size() - 1]
		if top_drink[0] is String and top_drink[0] == id:
			top_drink[1] += liquids_num
			if top_drink.size() > 3 and top_drink[3] is Dictionary:
				top_drink[3][id] = top_drink[1]
		else:
			liquids.push_back([id, liquids_num, col, {id: liquids_num}])
	else:
		liquids.push_back([id, liquids_num, col, {id: liquids_num}])

	# keep typed drink mix in sync
	drink_mix.add_liquid(id, liquids_num)

	visual_helper.slosh_velocity += randf_range(-0.35, 0.35) * (1.0 - clampf(viscosity, 0.0, 1.0))
	visual_helper.slosh_vertical_velocity += randf_range(-0.15, 0.05)
	visual_helper.wave_amplitude = minf(visual_helper.wave_amplitude + 0.035, 0.07)
	_rebuild_liquid_gradient()
	return liquids_num

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
	in_game = true
	_snap_point = null
	_snap_locked = false
	_snap_blend = 0.0
	_is_pointer_pressed = false
	is_balls_dragging = false
	_is_returning_to_counter = false
	_is_mode_transitioning = false
	push_velocity = Vector3.ZERO
	if _drag_return_tween and _drag_return_tween.is_valid():
		_drag_return_tween.kill()
	if area_body:
		area_body.disabled = true

func _out_of_game() -> void:
	in_game = false
	if area_body:
		area_body.disabled = false
	_remove_displaying_list()
	var target_pos := _get_saved_counter_position(_last_counter_position)
	if global_position.distance_to(target_pos) > 0.005:
		_return_to_counter_smoothly(target_pos)
	else:
		global_position = target_pos
		base_y_position = target_pos.y
		_last_counter_position = target_pos

func _on_hover(hovered: bool) -> void:
	set_highlight(hovered)

func _dranked() -> void:
	if is_consumed:
		return
	is_consumed = true
	queue_free()

func _return_drink() -> Array:
	var current_total: float = 0.0
	for layer in liquids:
		if layer is Array and layer.size() >= 2:
			current_total += float(layer[1])
	if current_total <= 0.0:
		return []

	# normalizes layers so ratios sum to 1.0 for the customer scoring system
	var scale_to_prop := 1.0 / current_total
	var normalized: Array = []
	for layer in liquids:
		if not (layer is Array and layer.size() >= 2):
			continue
		var new_layer: Array = layer.duplicate()
		new_layer[1] = float(layer[1]) * scale_to_prop
		if new_layer.size() > 3 and new_layer[3] is Dictionary:
			var new_dict: Dictionary = {}
			for k in new_layer[3]:
				new_dict[k] = float(new_layer[3][k]) * scale_to_prop
			new_layer[3] = new_dict
		elif new_layer[0] is Dictionary:
			var new_dict: Dictionary = {}
			for k in new_layer[0]:
				new_dict[k] = float(new_layer[0][k]) * scale_to_prop
			new_layer[0] = new_dict
		normalized.append(new_layer)
	return normalized

func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("glass") and get_drag_mode() == DragMode.COLLISION and not is_balls_dragging:
		_pushing_glass(area)

func can_interact_with(target: Ingredients) -> bool:
	if _is_drag_blocked() or not is_instance_valid(target) or target == self:
		return false
	if target.is_in_group("trash"):
		return true
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
	if target.is_in_group("trash"):
		_delete()
	elif target is Shaker and can_be_shaken():
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
	var target_pos := _get_counter_drop_position(_last_counter_position) if _has_dragged else _get_saved_counter_position(_last_counter_position)
	_return_to_counter_smoothly(target_pos)

func _on_returning_to_counter(target_pos: Vector3) -> void:
	_last_counter_position = target_pos

func _on_returned_to_counter(target_pos: Vector3) -> void:
	_last_counter_position = target_pos

func _remove_displaying_list() -> void:
	if liquid_box and liquid_box.modulate.a != 0.0:
		var tween := get_tree().create_tween().parallel()
		tween.tween_property(liquid_box, "modulate:a", 0.0, 1.0)

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

# collapses separate layers into one blended liquid and tags drink mix as shaken
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
	_rebuild_liquid_gradient()

func get_mixed_ingredients() -> Array[String]:
	return get_unique_liquids_ids()