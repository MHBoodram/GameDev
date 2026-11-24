extends Ingredients
class_name Drinks

# base controller script for all shelf liquor and blood bottles (liquid.tscn)

const POUR_AMOUNT: float = 0.0825
const POUR_INTERVAL: float = 0.033
const MIN_POUR_ANGLE_DEGREES: float = 5.0
const MAX_POUR_ANGLE_DEGREES: float = 150.0

@onready var liquid_refresh: Timer = get_node("Liquid_refresh")
@export var liquid_resource: Liquid
@export var size: float = 50.0

var pouring_into: Node3D
var original_position: Marker3D
var is_pouring: bool = false

var color_liquid: Color = Color.WHITE
var current_liquid: float = 50.0

var visual_helper: LiquidVisualHelper = LiquidVisualHelper.new()
var liquid_gradient: Gradient
var liquid_shader_mat: ShaderMaterial
var gradient_texture: GradientTexture2D
var _pour_stream: PourStreamVisual = null

func _init() -> void:
	hold_lift = 0.2
	snap_to_glass = true
	follow_speed = 30.0

func _ensure_pour_stream() -> void:
	if not is_instance_valid(_pour_stream):
		_pour_stream = PourStreamVisual.new()
		add_child(_pour_stream)

func _get_effective_viscosity() -> float:
	var id_str := liquid_resource.id if liquid_resource else "gin"
	var res_visc := liquid_resource.viscosity if (liquid_resource and liquid_resource.viscosity >= 0.0) else LiquidVisualHelper.get_liquid_viscosity(id_str)
	return clampf(maxf(visual_helper.viscosity, res_visc), 0.0, 1.0)

func ready() -> void:
	_ensure_pour_stream()
	if liquid_resource:
		size = liquid_resource.liquid_size
		current_liquid = size
		color_liquid = liquid_resource.liquid_color
		if liquid_resource.buoyancy > 0.0:
			LiquidVisualHelper.register_liquid_buoyancy(liquid_resource.id, liquid_resource.buoyancy)
		if liquid_resource.viscosity >= 0.0:
			LiquidVisualHelper.register_liquid_viscosity(liquid_resource.id, liquid_resource.viscosity)
		$Inside.texture = liquid_resource.sprite
		$Inside/Outside.texture = liquid_resource.outside_Sprite
		var inside_node := get_node_or_null("Inside") as Node3D
		visual_helper.last_global_pos = inside_node.global_position if inside_node else global_position
		_setup_liquid_shader()
		_apply_outside_texture()
		set_liquid_color(liquid_resource.liquid_color)

func setup(og_position: Marker3D, Counter: Node3D, _liquid: Liquid) -> void:
	_ensure_pour_stream()
	liquid_resource = _liquid
	size = liquid_resource.liquid_size
	current_liquid = size
	color_liquid = liquid_resource.liquid_color

	if liquid_resource.buoyancy > 0.0:
		LiquidVisualHelper.register_liquid_buoyancy(liquid_resource.id, liquid_resource.buoyancy)
	if liquid_resource.viscosity >= 0.0:
		LiquidVisualHelper.register_liquid_viscosity(liquid_resource.id, liquid_resource.viscosity)

	$Inside.texture = liquid_resource.sprite
	$Inside/Outside.texture = liquid_resource.outside_Sprite

	original_position = og_position
	counter_origin = Counter
	global_position = og_position.global_position
	rotation_degrees = Vector3.ZERO
	base_y_position = global_position.y
	var inside_node := get_node_or_null("Inside") as Node3D
	visual_helper.last_global_pos = inside_node.global_position if inside_node else global_position

	_setup_liquid_shader()
	_apply_outside_texture()
	set_liquid_color(liquid_resource.liquid_color)

func _exit_tree() -> void:
	visual_helper.cleanup()
	if is_instance_valid(_pour_stream):
		_pour_stream.set_stream_active(false)

func _apply_outside_texture() -> void:
	var tex: Texture2D = liquid_resource.outside_Sprite
	if tex == null:
		return

	var outside := $Inside/Outside as GeometryInstance3D
	if outside is Sprite3D:
		outside.texture = tex

	if liquid_shader_mat:
		liquid_shader_mat.set_shader_parameter("texture_albedo", tex)

func _get_spout_world_position() -> Vector3:
	var inside_sprite := get_node_or_null("Inside") as Sprite3D
	if inside_sprite:
		return PourStreamVisual.get_sprite_top_spout_world_position(inside_sprite)
	return global_position

func _get_target_pour_world_position() -> Vector3:
	if is_instance_valid(pouring_into):
		if pouring_into.has_method("get_liquid_surface_world_position"):
			return pouring_into.get_liquid_surface_world_position()
		return pouring_into.global_position
	return _get_spout_world_position() + Vector3(0.0, -0.45, 0.0)

func _can_pour_from_mouth() -> bool:
	return current_liquid > 0.0 and rotation_degrees.z > MIN_POUR_ANGLE_DEGREES and visual_helper.is_liquid_touching_mouth()

func _get_effective_pour_rate_multiplier() -> float:
	if not _can_pour_from_mouth():
		return 0.0
	return clampf(rotation_degrees.z / (MAX_POUR_ANGLE_DEGREES * 0.5), 0.15, 2.0)

func _update_pour_stream() -> void:
	_ensure_pour_stream()
	var rate_mult: float = _get_effective_pour_rate_multiplier()
	if in_game and is_pouring and rate_mult > 0.0 and is_instance_valid(pouring_into):
		var start_pos: Vector3 = _get_spout_world_position()
		var surface_pos: Vector3 = _get_target_pour_world_position()
		var rim_pos: Vector3 = surface_pos
		if pouring_into.has_method("get_rim_center_world_position"):
			rim_pos = pouring_into.call("get_rim_center_world_position") as Vector3
		_pour_stream.set_stream_active(true, start_pos, surface_pos, color_liquid, rate_mult, Vector3.DOWN, true, false, rim_pos)
	else:
		_pour_stream.set_stream_active(false)

func _process(delta: float) -> void:
	var inside_node := get_node_or_null("Inside") as Node3D
	if not in_game:
		super._process(delta)
		_face_camera()
		if is_instance_valid(_pour_stream):
			_pour_stream.set_stream_active(false)
	else:
		if inside_node:
			inside_node.rotation = inside_node.rotation.lerp(Vector3.ZERO, 1.0 - exp(-18.0 * delta))
		if is_pouring:
			var target_angle := _get_pour_angle_degrees()
			rotation_degrees.z = lerpf(rotation_degrees.z, target_angle, 1.0 - exp(-18.0 * delta))
			_update_pour_stream()
		else:
			rotation_degrees.z = lerpf(rotation_degrees.z, 0.0, 1.0 - exp(-18.0 * delta))
			if is_instance_valid(_pour_stream):
				_pour_stream.set_stream_active(false)

	var track_pos: Vector3 = inside_node.global_position if inside_node else global_position
	var outside_sprite := get_node_or_null("Inside/Outside") as Node3D
	visual_helper.update_physics_from_owner(delta, track_pos, camera, self, _get_effective_viscosity(), outside_sprite)
	_update_liquid_shader()

func _on_area_3d_input_event(camera_node: Node, event: InputEvent, event_pos: Vector3, normal: Vector3, shape_idx: int) -> void:
	var left_pressed: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

	if not in_game:
		super._on_area_3d_input_event(camera_node, event, event_pos, normal, shape_idx)
		return

	if left_pressed and not is_pouring:
		await _pour()

func _get_pour_angle_degrees() -> float:
	var ratio: float = PourStreamVisual.get_pour_height_ratio(get_viewport())
	if ratio <= 0.001:
		return 0.0
	return lerpf(32.0, MAX_POUR_ANGLE_DEGREES, ratio)

# tips bottle sideways and addds liquid pixels into the glass while left click is held
func _pour() -> void:
	is_pouring = true
	$CPUParticles3D.emitting = false
	if GameState.player:
		GameState.player._update_hand("holding")
	$CPUParticles3D.emitting = false

	var sfx_timer: float = 0.1
	if pouring_into:
		while PourStreamVisual.is_pour_button_held() and in_game and GameState.player and GameState.player.in_game and current_liquid > 0.0 and is_instance_valid(pouring_into):
			var rate_mult: float = _get_effective_pour_rate_multiplier()
			if rate_mult > 0.0:
				var cost_mult: float = pouring_into.get_resource_usage_multiplier(liquid_resource.id) if pouring_into.has_method("get_resource_usage_multiplier") else 1.0
				var max_bottle_pour: float = current_liquid / maxf(cost_mult, 0.001)
				var amount: float = minf(POUR_AMOUNT * rate_mult, max_bottle_pour)
				var target_pos: Vector3 = _get_target_pour_world_position()
				var arrival_vel: Vector3 = _pour_stream.get_arrival_velocity() if is_instance_valid(_pour_stream) else Vector3(0.0, -1.6, 0.0)
				var pour_info: Dictionary = pouring_into.compute_pour_info_from_world(target_pos, arrival_vel) if pouring_into.has_method("compute_pour_info_from_world") else {"from_pour": true}
				var poured_variant = pouring_into._pouring(liquid_resource.id, amount, pour_info)
				var actual_poured: float = float(poured_variant) if (poured_variant is float or poured_variant is int) else amount
				set_liquid_amount(current_liquid - actual_poured * cost_mult)
				sfx_timer += POUR_INTERVAL
				if sfx_timer >= 0.1:
					sfx_timer -= 0.1
					SFXAudio.play_liquidpour()
			else:
				sfx_timer = 0.1
			await get_tree().create_timer(POUR_INTERVAL).timeout
			if not is_inside_tree():
				return

	$CPUParticles3D.emitting = false
	is_pouring = false
	if is_instance_valid(_pour_stream):
		_pour_stream.set_stream_active(false)
	rotation_degrees.z = 0
	if GameState.player:
		GameState.player._update_hand("idle")

	await get_tree().create_timer(0.25).timeout
	if is_inside_tree() and in_game and GameState.player and GameState.player.in_game:
		GameState.player._out_of_game()

func _return_original() -> void:
	if _drag_return_tween and _drag_return_tween.is_valid():
		_drag_return_tween.kill()
	_drag_return_tween = get_tree().create_tween().set_parallel(true)
	_drag_return_tween.set_trans(Tween.TRANS_SINE)
	_drag_return_tween.set_ease(Tween.EASE_OUT)
	if original_position:
		_drag_return_tween.tween_property(self, "global_position", original_position.global_position, 0.5)
	_drag_return_tween.tween_property($Inside, "global_rotation", Vector3.ZERO, 0.5)
	rotation_degrees = Vector3.ZERO

func _in_game() -> void:
	in_game = true
	visual_helper.set_mouth_monitoring(true)
	_is_pointer_pressed = false
	is_balls_dragging = false
	if is_instance_valid(_pour_stream):
		_pour_stream.set_stream_active(false)
	if _drag_return_tween and _drag_return_tween.is_valid():
		_drag_return_tween.kill()
	if pouring_into and pouring_into.has_method("_on_hover"):
		pouring_into._on_hover(false)

func _out_of_game() -> void:
	in_game = false
	visual_helper.set_mouth_monitoring(false)
	is_pouring = false
	rotation_degrees.z = 0.0
	$CPUParticles3D.emitting = false
	if is_instance_valid(_pour_stream):
		_pour_stream.set_stream_active(false)
	_return_original()
	pouring_into = null

func _pouring_game() -> void:
	if not pouring_into:
		return
	pouring_into.in_game = true
	in_game = true
	GameState.player._perfect_pour(self, pouring_into)
	$CollisionShape3D.disabled = true
	await get_tree().create_timer(0.2).timeout
	$CollisionShape3D.disabled = false
	is_balls_dragging = false

func can_interact_with(target: Ingredients) -> bool:
	if _is_drag_blocked() or not is_instance_valid(target):
		return false
	return target is Glasses and not (target is Drinks) and not target._is_drag_blocked()

func execute_interaction(target: Ingredients) -> void:
	if can_interact_with(target) and target.is_in_group("glass"):
		pouring_into = target
		target.set_highlight(false)
		_pouring_game()

func on_drop_failed() -> void:
	_return_original()

func _on_interact_mouse_entered() -> void:
	_on_area_3d_mouse_entered()

func _on_interact_mouse_exited() -> void:
	_on_area_3d_mouse_exited()

func _on_interact_area_entered(_area: Area3D) -> void:
	pass

func _on_interact_area_exited(_area: Area3D) -> void:
	pass

func set_liquid_color(new_color: Color) -> void:
	color_liquid = new_color
	_rebuild_liquid_gradient()
	_update_liquid_shader()

func set_liquid_amount(amount: float) -> void:
	current_liquid = clampf(amount, 0.0, size)
	_rebuild_liquid_gradient()
	_update_liquid_shader()

func _update_liquid_shader() -> void:
	if size <= 0.0:
		return
	var fill := clampf(current_liquid / size, 0.0, 1.0)
	visual_helper.sync_shader_from_owner(fill, self)

func refill() -> void:
	set_liquid_amount(size)

func _setup_liquid_shader() -> void:
	if liquid_shader_mat:
		return
	var outside := get_node_or_null("Inside/Outside")
	if not outside:
		return
	liquid_shader_mat = visual_helper.setup_shader(outside)
	liquid_gradient = visual_helper.liquid_gradient
	gradient_texture = visual_helper.gradient_texture
	_rebuild_liquid_gradient()
	_update_liquid_shader()

func _rebuild_liquid_gradient() -> void:
	var id_str := liquid_resource.id if liquid_resource else "gin"
	var buoy := liquid_resource.buoyancy if liquid_resource else -1.0
	var visc := _get_effective_viscosity()
	visual_helper.sync_bottle_liquid(id_str, current_liquid, size, color_liquid, buoy, visc)

func _add_liquid(amount: float) -> void:
	current_liquid = clampf(current_liquid + amount, 0.0, size)
	_rebuild_liquid_gradient()
	_update_liquid_shader()

func _on_liquid_refresh_timeout() -> void:
	_add_liquid(0.25)
