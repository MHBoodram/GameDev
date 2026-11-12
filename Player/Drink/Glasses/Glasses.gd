extends Ingredients
class_name Glasses
@onready var tcmtd = preload("res://Player/Drink/Glasses/liquids_label.tscn") #They call me the drink
@export var liquids : Array = []
@export var size : float = 1.0
@export var area_body : CollisionShape3D
@export var sprite : Sprite3D
@export var liquid_box : VBoxContainer
@export var customer_hold_distance : float = 1.0
var drink_list_label : Label
var total_liquids : float = 0
var in_game: bool = false
var is_being_served: bool = false
var is_consumed: bool = false
var _last_counter_position: Vector3 = Vector3.ZERO
const LIQUID_COLOR = {
	"gin" : Color(0.0, 0.953, 0.0, 1.0),
	"beer" : Color(0.98, 0.322, 0.051, 1.0),
	"spirit" : Color(0.542, 0.691, 1.0, 1.0),
	"vodka" : Color(0.137, 0.372, 1.0, 1.0),
	"rum" : Color(0.458, 0.154, 0.014, 1.0),
	"tequila" : Color(0.9, 0.85, 0.3, 1.0),
	"whiskey" : Color(0.78, 0.42, 0.1, 1.0),
	"blood" : Color(0.85, 0.05, 0.05, 1.0)
}

@export_group("Liquid Physics")
@export var viscosity : float = 0.25
@export var spring_stiffness : float = 75.0
@export var base_damping : float = 4.0
@export var slosh_sensitivity : float = 0.28
@export var max_slosh_angle : float = 0.85
@export var wave_frequency : float = 16.0
@export var vertical_spring : float = 90.0
@export var vertical_damping : float = 5.0
@export var vertical_sensitivity : float = 0.15

@export_group("Liquid Shading")
@export var pixel_resolution : float = 48.0
@export var surface_highlight_color : Color = Color(1.4, 1.4, 1.5, 1.0)
@export var secondary_highlight_color : Color = Color(0.9, 0.4, 0.95, 0.85)
@export var surface_highlight_pixels : float = 1.2
@export var bottom_darkening : float = 0.45
@export var liquid_transparency : float = 0.9
@export var caustic_beam_strength : float = 0.35
@export var sparkle_density : float = 0.7
@export var glass_reflection_strength : float = 0.28
@export var meniscus_curve : float = 0.03
@export var inner_margin_top : float = 0.12
@export var inner_margin_bottom : float = 0.88

var push_velocity : Vector3 = Vector3.ZERO
const PUSH_FRICTION : float = 14.0
const INTERACTION_SEPARATION_DISTANCE : float = 0.14

var liquid_shader_mat : ShaderMaterial
var gradient_texture : GradientTexture2D
var liquid_gradient : Gradient
var _last_global_pos : Vector3 = Vector3.ZERO
var _last_velocity : Vector3 = Vector3.ZERO
var slosh_angle : float = 0.0
var slosh_velocity : float = 0.0
var slosh_vertical_offset : float = 0.0
var slosh_vertical_velocity : float = 0.0
var wave_phase : float = 0.0
var wave_amplitude : float = 0.0
@onready var highlight = get_node_or_null("Inside/highlight")

func is_working_area_item() -> bool:
	return true

func _is_drag_blocked() -> bool:
	return in_game or is_being_served or is_consumed

func _get_free_drag_target(_delta: float) -> Vector3:
	if camera:
		return camera.project_position(get_viewport().get_mouse_position(), customer_hold_distance)
	return global_position

func ready() -> void:
	rotation = Vector3.ZERO
	_setup_liquid_shader()
	if highlight:
		highlight.modulate = Color(1.5, 1.5, 0.0, 5.0)
	if camera:
		_look_at_sprite(camera.global_position)
	_snap_to_working_area()
	_last_counter_position = global_position
	_last_global_pos = global_position

func start_drag_from_spawn(press_screen_pos: Vector2) -> void:
	_last_counter_position = _clamp_to_counter(global_position)
	_last_counter_position.y = get_working_area_surface_y()
	_last_global_pos = global_position
	super.start_drag_from_spawn(press_screen_pos)

func _delete():
	queue_free()

@export var dead_zone := 50.0
@export var full_pull := 150.0

@export var max_hand_distance := 20.0

func _update_hand_position(delta: float) -> void:
	if not camera or not GameState.player:
		return
	if camera.is_position_behind(global_position):
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var glass_screen: Vector2 = camera.unproject_position(global_position)
	var gap: float = mouse.x - glass_screen.x
	var excess: float = maxf(absf(gap) - dead_zone, 0.0)
	var pull: float = clampf(excess / full_pull, 0.0, 1.0)
	var goal: Vector2 = mouse.lerp(glass_screen, pull)
	var hand = GameState.player.hand_sprite
	if hand:
		hand.global_position = hand.global_position.lerp(goal, 1.0 - exp(-30.0 * delta))

func _process(delta: float) -> void:
	super._process(delta)
	_update_liquid_physics(delta)
	_update_shader_parameters()
	if camera and not is_balls_dragging:
		_look_at_sprite(camera.global_position)
	if _is_drag_blocked():
		return

	if is_balls_dragging:
		_update_hand_position(delta)

	if get_drag_mode() == DragMode.COLLISION and not _is_returning_to_counter:
		_apply_collision_push(delta)
		if not is_balls_dragging:
			if not is_selected:
				var target_y: float = get_working_area_surface_y()
				base_y_position = target_y
				if absf(global_position.y - target_y) <= 0.002:
					global_position.y = target_y
				else:
					global_position.y = lerpf(global_position.y, target_y, 1.0 - exp(-20.0 * delta))
			_last_counter_position = global_position

func _apply_collision_push(delta: float) -> void:
	var surface_y: float = get_working_area_surface_y()
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

		var diff: Vector3 = global_position - other.global_position
		diff.y = 0.0
		var dist: float = diff.length()
		if dist < 0.001:
			diff = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			dist = 0.001
		var overlap: float = INTERACTION_SEPARATION_DISTANCE - dist
		if overlap <= 0.0:
			continue

		var dir: Vector3 = diff.normalized()
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
		var target_flat: Vector3 = looking_at
		target_flat.y = sprite.global_position.y
		if target_flat.distance_squared_to(sprite.global_position) > 0.0001:
			sprite.look_at(target_flat, Vector3.UP)

func _update_liquid_physics(delta: float) -> void:
	if delta <= 0.0:
		return

	var current_pos: Vector3 = global_position
	var frame_velocity: Vector3 = (current_pos - _last_global_pos) / delta
	var frame_acceleration: Vector3 = (frame_velocity - _last_velocity) / delta
	_last_global_pos = current_pos
	_last_velocity = frame_velocity

	var h_accel: float = 0.0
	if camera:
		var cam_right: Vector3 = camera.global_transform.basis.x
		h_accel = frame_acceleration.dot(cam_right)
	else:
		h_accel = frame_acceleration.x

	var clamped_viscosity: float = clampf(viscosity, 0.0, 1.0)
	var effective_damping: float = base_damping * (1.0 + clamped_viscosity * 2.0)
	var effective_spring: float = spring_stiffness / (1.0 + clamped_viscosity * 0.7)
	var current_max_slosh: float = lerpf(max_slosh_angle, max_slosh_angle * 0.35, clamped_viscosity)

	var slosh_force: float = -h_accel * slosh_sensitivity
	var spring_force: float = -slosh_angle * effective_spring
	var damping_force: float = -slosh_velocity * effective_damping
	var total_slosh_accel: float = spring_force + damping_force + slosh_force

	slosh_velocity += total_slosh_accel * delta
	slosh_angle += slosh_velocity * delta
	slosh_angle = clampf(slosh_angle, -current_max_slosh, current_max_slosh)

	var v_accel: float = frame_acceleration.y
	var lateral_agitation: float = absf(slosh_velocity) * 0.02
	var vertical_force: float = -v_accel * vertical_sensitivity + lateral_agitation
	var v_spring_force: float = -slosh_vertical_offset * (vertical_spring / (1.0 + clamped_viscosity))
	var v_damping_force: float = -slosh_vertical_velocity * (vertical_damping * (1.0 + clamped_viscosity * 2.0))
	slosh_vertical_velocity += (v_spring_force + v_damping_force + vertical_force) * delta
	slosh_vertical_offset += slosh_vertical_velocity * delta
	slosh_vertical_offset = clampf(slosh_vertical_offset, -0.15, 0.15)

	wave_phase += delta * wave_frequency * (1.0 - clamped_viscosity * 0.6)
	var shake_energy: float = absf(slosh_velocity) * 0.025 + absf(frame_velocity.length()) * 0.015
	var target_wave_amp: float = clampf(shake_energy, 0.0, 0.06 * (1.0 - clamped_viscosity * 0.6))
	wave_amplitude = lerpf(wave_amplitude, target_wave_amp, 1.0 - exp(-20.0 * delta))

func _setup_liquid_shader() -> void:
	var outside_sprite = get_node_or_null("Inside/Outside")
	if outside_sprite and outside_sprite.material_override is ShaderMaterial:
		liquid_shader_mat = outside_sprite.material_override.duplicate() as ShaderMaterial
		outside_sprite.material_override = liquid_shader_mat

		gradient_texture = GradientTexture2D.new()
		gradient_texture.width = 64
		gradient_texture.height = 4
		gradient_texture.fill_from = Vector2(0.0, 0.5)
		gradient_texture.fill_to = Vector2(1.0, 0.5)

		liquid_gradient = Gradient.new()
		liquid_gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		gradient_texture.gradient = liquid_gradient
		liquid_shader_mat.set_shader_parameter("gradient_texture", gradient_texture)
		_rebuild_liquid_gradient()

func _update_shader_parameters() -> void:
	if not liquid_shader_mat:
		return

	var fill_ratio: float = clampf(total_liquids / maxf(size, 0.001), 0.0, 1.0)
	liquid_shader_mat.set_shader_parameter("fill_amount", fill_ratio)
	liquid_shader_mat.set_shader_parameter("slosh_angle", slosh_angle)
	liquid_shader_mat.set_shader_parameter("slosh_vertical_offset", slosh_vertical_offset)
	liquid_shader_mat.set_shader_parameter("wave_phase", wave_phase)
	liquid_shader_mat.set_shader_parameter("wave_amplitude", wave_amplitude)
	liquid_shader_mat.set_shader_parameter("pixel_resolution", pixel_resolution)
	liquid_shader_mat.set_shader_parameter("surface_highlight_color", surface_highlight_color)
	liquid_shader_mat.set_shader_parameter("secondary_highlight_color", secondary_highlight_color)
	liquid_shader_mat.set_shader_parameter("surface_highlight_thickness", surface_highlight_pixels)
	liquid_shader_mat.set_shader_parameter("bottom_darkening", bottom_darkening)
	liquid_shader_mat.set_shader_parameter("liquid_transparency", liquid_transparency)
	liquid_shader_mat.set_shader_parameter("caustic_beam_strength", caustic_beam_strength)
	liquid_shader_mat.set_shader_parameter("sparkle_density", sparkle_density)
	liquid_shader_mat.set_shader_parameter("glass_reflection_strength", glass_reflection_strength)
	liquid_shader_mat.set_shader_parameter("meniscus_curve", meniscus_curve)
	liquid_shader_mat.set_shader_parameter("inner_margin_top", inner_margin_top)
	liquid_shader_mat.set_shader_parameter("inner_margin_bottom", inner_margin_bottom)



# Color functions just for mixing

func _format_layer_name(layer_id) -> String:
	if layer_id is Array:
		var names: Array = layer_id.duplicate()
		names.sort()
		return " + ".join(names)
	elif layer_id is Dictionary:
		var names: Array = layer_id.keys()
		names.sort()
		return " + ".join(names)
	return str(layer_id)

func _get_layer_color(layer: Array) -> Color:
	if layer.size() > 2 and layer[2] is Color:
		return layer[2]
	if layer[0] is Array or layer[0] is Dictionary:
		return _get_layer_hsv_color(layer)
	return LIQUID_COLOR.get(str(layer[0]), Color.WHITE)

func _get_layer_hsv_color(layer: Array) -> Color:
	if layer.size() > 2 and layer[2] is Color:
		return layer[2]
	var color_weights: Array = []
	if layer.size() > 3 and layer[3] is Dictionary:
		for ing_id in layer[3]:
			var ing_col: Color = LIQUID_COLOR.get(str(ing_id), Color.WHITE)
			color_weights.append([ing_col, float(layer[3][ing_id])])
	elif layer[0] is Array:
		for ing_id in layer[0]:
			var ing_col: Color = LIQUID_COLOR.get(str(ing_id), Color.WHITE)
			color_weights.append([ing_col, 1.0])
	elif layer[0] is Dictionary:
		for ing_id in layer[0]:
			var ing_col: Color = LIQUID_COLOR.get(str(ing_id), Color.WHITE)
			color_weights.append([ing_col, float(layer[0][ing_id])])
	else:
		return LIQUID_COLOR.get(str(layer[0]), Color.WHITE)
	return _average_hsv_color(color_weights)

func _average_hsv_color(color_weights: Array) -> Color:
	if color_weights.is_empty():
		return Color.WHITE

	var total_weight: float = 0.0
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_s: float = 0.0
	var sum_v: float = 0.0
	var sum_a: float = 0.0

	for item in color_weights:
		var c: Color = item[0]
		var w: float = float(item[1])
		if w <= 0.0:
			continue
		total_weight += w
		var angle: float = c.h * TAU
		var sat_w: float = maxf(c.s, 0.01) * w
		sum_x += cos(angle) * sat_w
		sum_y += sin(angle) * sat_w
		sum_s += c.s * w
		sum_v += c.v * w
		sum_a += c.a * w

	if total_weight <= 0.0:
		return Color.WHITE

	var avg_h: float = 0.0
	if absf(sum_x) > 0.0001 or absf(sum_y) > 0.0001:
		var avg_angle: float = atan2(sum_y, sum_x)
		if avg_angle < 0.0:
			avg_angle += TAU
		avg_h = avg_angle / TAU
	else:
		avg_h = color_weights[0][0].h

	var avg_s: float = clampf(sum_s / total_weight, 0.0, 1.0)
	var avg_v: float = clampf(sum_v / total_weight, 0.0, 1.0)
	var avg_a: float = clampf(sum_a / total_weight, 0.0, 1.0)

	avg_s = clampf(avg_s, 0.35, 1.0)
	avg_v = clampf(avg_v, 0.5, 1.0)

	return Color.from_hsv(avg_h, avg_s, avg_v, avg_a)



func _rebuild_liquid_gradient() -> void:
	total_liquids = 0.0
	for l in liquids:
		total_liquids += float(l[1])

	if not liquid_gradient:
		return

	if liquids.is_empty() or total_liquids <= 0.0:
		liquid_gradient.offsets = PackedFloat32Array([0.0, 1.0])
		liquid_gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
		return

	if liquid_box and tcmtd:
		var children = liquid_box.get_children()
		if children.size() != liquids.size():
			for child in children:
				child.queue_free()
			for layer in liquids:
				var lbl = tcmtd.instantiate()
				liquid_box.add_child(lbl)
		children = liquid_box.get_children()
		for idx in range(min(children.size(), liquids.size())):
			var lbl = children[idx]
			var layer = liquids[idx]
			var col = _get_layer_color(layer)
			if lbl.material:
				lbl.material.set_shader_parameter("base_color", col)
			var layer_name: String = _format_layer_name(layer[0])
			var pct: float = (float(layer[1]) / maxf(size, 0.001)) * 100.0
			lbl.text = layer_name + ": " + str(snappedf(pct, 0.1)) + "%"
		if not children.is_empty():
			drink_list_label = children[children.size() - 1]
		liquid_box.modulate.a = 1.0

	var offsets := PackedFloat32Array([0.0])
	var colors := PackedColorArray()

	var current_pos: float = 0.0
	for i in range(liquids.size() - 1, -1, -1):
		var layer = liquids[i]
		var amount: float = float(layer[1])
		if amount <= 0.0:
			continue
		var col: Color = _get_layer_color(layer)

		colors.append(col)
		current_pos += amount / total_liquids
		if i > 0 and current_pos < 1.0:
			offsets.append(clampf(current_pos, 0.001, 0.999))

	while colors.size() < offsets.size():
		colors.append(colors[colors.size() - 1] if colors.size() > 0 else Color.WHITE)
	while offsets.size() < colors.size():
		offsets.append(1.0)

	liquid_gradient.offsets = offsets
	liquid_gradient.colors = colors

func _pouring(id : String, liquids_num : float) -> void:
	var current_total: float = 0.0
	for l in liquids:
		current_total += float(l[1])

	var available_space: float = size - current_total
	if available_space <= 0.0:
		return

	liquids_num = minf(liquids_num, available_space)
	if liquids_num <= 0.0:
		return

	var col: Color = LIQUID_COLOR.get(id, Color.WHITE)

	if len(liquids) != 0:
		var top_drink = liquids[len(liquids) - 1]
		if top_drink[0] is String and top_drink[0] == id:
			top_drink[1] += liquids_num
			if top_drink.size() > 3 and top_drink[3] is Dictionary:
				top_drink[3][id] = top_drink[1]
			_visuals_change(liquids_num, id, false)
		else:
			print("new drink")
			var new_label = tcmtd.instantiate()
			liquid_box.add_child(new_label)
			drink_list_label = new_label
			var temp_liquid = [id, liquids_num, col, {id: liquids_num}]
			liquids.push_back(temp_liquid)
			_visuals_change(liquids_num, id, true)
	else:
		var new_label = tcmtd.instantiate()
		liquid_box.add_child(new_label)
		drink_list_label = new_label
		var temp_liquid = [id, liquids_num, col, {id: liquids_num}]
		liquids.push_back(temp_liquid)
		_visuals_change(liquids_num, id, true)

	slosh_velocity += randf_range(-0.35, 0.35) * (1.0 - clampf(viscosity, 0.0, 1.0))
	slosh_vertical_velocity += randf_range(-0.15, 0.05)
	wave_amplitude = minf(wave_amplitude + 0.035, 0.07)

func is_full() -> bool:
	var current_total: float = 0.0
	for l in liquids:
		current_total += float(l[1])
	return current_total >= size

func _pushing_glass(other_glass : Area3D) -> void:
	var push_dir: Vector3 = global_position - other_glass.global_position
	push_dir.y = 0.0
	if push_dir.length() < 0.001:
		push_dir = Vector3(1.0, 0.0, 0.0)
	push_velocity += push_dir.normalized() * 0.1

func _in_game():
	in_game = true
	area_body.disabled = true

func _out_of_game():
	in_game = false
	area_body.disabled = false
	_remove_displaying_list()
	_return_to_counter_smoothly(_get_counter_drop_position(_last_counter_position))

func _visuals_change(liquids_num: float,liquid_name: String,new: bool) -> void:
	_rebuild_liquid_gradient()

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

	var scale_to_proportion: float = 1.0 / current_total
	var normalized: Array = []
	for layer in liquids:
		if not (layer is Array and layer.size() >= 2):
			continue
		var new_layer: Array = layer.duplicate()
		new_layer[1] = float(layer[1]) * scale_to_proportion
		if new_layer.size() > 3 and new_layer[3] is Dictionary:
			var new_dict: Dictionary = {}
			for k in new_layer[3]:
				new_dict[k] = float(new_layer[3][k]) * scale_to_proportion
			new_layer[3] = new_dict
		elif new_layer[0] is Dictionary:
			var new_dict: Dictionary = {}
			for k in new_layer[0]:
				new_dict[k] = float(new_layer[0][k]) * scale_to_proportion
			new_layer[0] = new_dict
		normalized.append(new_layer)
	return normalized

func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("glass") and get_drag_mode() == DragMode.COLLISION and not is_balls_dragging:
		_pushing_glass(area)

func can_interact_with(target: Ingredients) -> bool:
	if target and target.is_in_group("trash"):
		return true
	if target is Shaker and can_be_shaken():
		return true
	return false

func execute_interaction(target: Ingredients) -> void:
	if target and target.is_in_group("trash"):
		_delete()
	elif target is Shaker and can_be_shaken():
		target.start_shake(self)

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
	_is_pointer_pressed = false
	is_balls_dragging = false
	_remove_displaying_list()
	if has_method("_giving_drink"):
		call("_giving_drink")
	if GameState.main_node and GameState.main_node.has_method("_serve_cup_to_npc"):
		GameState.main_node._serve_cup_to_npc(self, npc)

func on_drop_failed() -> void:
	var target_pos: Vector3 = _get_counter_drop_position(_last_counter_position)
	_return_to_counter_smoothly(target_pos)

func _on_returned_to_counter(target_pos: Vector3) -> void:
	_last_counter_position = target_pos

func _remove_displaying_list() -> void:
	if(liquid_box):
		var alpha: float = liquid_box.modulate.a
		if(alpha != 0):
			var tween = get_tree().create_tween().parallel()
			tween.tween_property(liquid_box,"modulate:a",0.0,1.0)



# ------- below is the shaker minigame stuff --------

var _mixed_signature : String = ""

func get_unique_liquids_ids() -> Array[String]:
	var ids: Array[String] = []
	for l in liquids:
		if l[0] is Array:
			for sub_id in l[0]:
				var s: String = str(sub_id)
				if not ids.has(s):
					ids.append(s)
		elif l[0] is Dictionary:
			for sub_id in l[0].keys():
				var s: String = str(sub_id)
				if not ids.has(s):
					ids.append(s)
		else:
			var s: String = str(l[0])
			if not ids.has(s):
				ids.append(s)
	ids.sort()
	return ids

func _liquid_signature() -> String:
	var parts: PackedStringArray = []
	for l in liquids:
		if l[0] is Array:
			var sorted_names = l[0].duplicate()
			sorted_names.sort()
			parts.append("[%s]:%.3f" % [",".join(sorted_names), float(l[1])])
		elif l[0] is Dictionary:
			var keys = l[0].keys()
			keys.sort()
			var dict_parts: PackedStringArray = []
			for k in keys:
				dict_parts.append("%s:%.3f" % [k, float(l[0][k])])
			parts.append("{%s}:%.3f" % [",".join(dict_parts), float(l[1])])
		else:
			parts.append("%s:%.3f" % [str(l[0]), float(l[1])])
	return ",".join(parts)

func can_be_shaken() -> bool:
	if in_game or is_being_served:
		return false
	if liquids.is_empty():
		return false
	if get_unique_liquids_ids().size() < 2:
		return false
	if is_mixed():
		return false
	return true

func is_mixed() -> bool:
	if liquids.is_empty():
		return false
	if liquids.size() > 1:
		return false
	var layer0 = liquids[0]
	if layer0[0] is Array and layer0[0].size() >= 2:
		return true
	if layer0[0] is Dictionary and layer0[0].size() >= 2:
		return true
	return false

func mark_mixed() -> void:
	if get_unique_liquids_ids().size() < 2 or liquids.is_empty():
		return

	var combined_amounts: Dictionary = {}
	var color_weights: Array = []
	var total_amount: float = 0.0

	for layer in liquids:
		var layer_amt: float = float(layer[1])
		if layer_amt <= 0.0:
			continue
		total_amount += layer_amt
		if layer.size() > 3 and layer[3] is Dictionary:
			for ing_id in layer[3]:
				var a: float = float(layer[3][ing_id])
				combined_amounts[str(ing_id)] = combined_amounts.get(str(ing_id), 0.0) + a
				var c: Color = LIQUID_COLOR.get(str(ing_id), Color.WHITE)
				color_weights.append([c, a])
		elif layer[0] is Array:
			var split_a: float = layer_amt / maxf(float(layer[0].size()), 1.0)
			for ing_id in layer[0]:
				var s: String = str(ing_id)
				combined_amounts[s] = combined_amounts.get(s, 0.0) + split_a
				var c: Color = LIQUID_COLOR.get(s, Color.WHITE)
				color_weights.append([c, split_a])
		elif layer[0] is Dictionary:
			for ing_id in layer[0]:
				var a: float = float(layer[0][ing_id])
				combined_amounts[str(ing_id)] = combined_amounts.get(str(ing_id), 0.0) + a
				var c: Color = LIQUID_COLOR.get(str(ing_id), Color.WHITE)
				color_weights.append([c, a])
		else:
			var s: String = str(layer[0])
			combined_amounts[s] = combined_amounts.get(s, 0.0) + layer_amt
			var c: Color = LIQUID_COLOR.get(s, Color.WHITE)
			color_weights.append([c, layer_amt])

	var mixed_color: Color = _average_hsv_color(color_weights)

	var mixed_names: Array[String] = []
	for ing_id in combined_amounts.keys():
		mixed_names.append(str(ing_id))
	mixed_names.sort()

	liquids.clear()
	var new_mixed_layer = [mixed_names, total_amount, mixed_color, combined_amounts]
	liquids.push_back(new_mixed_layer)

	_mixed_signature = _liquid_signature()
	_rebuild_liquid_gradient()

func get_mixed_ingredients() -> Array[String]:
	var result: Array[String] = []
	for layer in liquids:
		if layer[0] is Array:
			for ing in layer[0]:
				var s: String = str(ing)
				if not result.has(s):
					result.append(s)
		elif layer[0] is Dictionary:
			for ing in layer[0].keys():
				var s: String = str(ing)
				if not result.has(s):
					result.append(s)
	result.sort()
	return result

func _mixed_color() -> Color:
	var color_weights: Array = []
	for l in liquids:
		var amount: float = float(l[1])
		if l.size() > 2 and l[2] is Color:
			color_weights.append([l[2], amount])
		elif l[0] is Array or l[0] is Dictionary:
			color_weights.append([_get_layer_hsv_color(l), amount])
		else:
			var col: Color = LIQUID_COLOR.get(str(l[0]), Color.WHITE)
			color_weights.append([col, amount])
	return _average_hsv_color(color_weights)