extends Ingredients
class_name Drinks

const POUR_AMOUNT: float = 0.25
const POUR_INTERVAL: float = 0.1

@export var liquid_resource: Liquid
@export var size: float = 50.0
@export var hold_lift: float = 0.2
@export var snap_to_glass: bool = true
@export var snap_offset: Vector3 = Vector3(0, 0.5, 0)
@export var follow_speed: float = 30.0

var pouring_into: Node3D
var original_position: Marker3D
var is_pouring: bool = false
var in_game: bool = false

var color_liquid: Color = Color.WHITE
var current_liquid: float = 50.0

var liquid_gradient: Gradient
var liquid_shader_mat: ShaderMaterial
var gradient_texture: GradientTexture2D

var _grab_depth: float = 0.0
var _depth_now: float = 0.0
var _smooth_pos: Vector3 = Vector3.ZERO
var _return_tween: Tween


func setup(og_position: Marker3D, Counter: Node3D, _liquid: Liquid) -> void:
	liquid_resource = _liquid
	size = liquid_resource.liquid_size
	current_liquid = size  # start full (the old default was set before size changed)

	$Inside.texture = liquid_resource.sprite
	$Inside/Outside.texture = liquid_resource.outside_Sprite

	# Only touch albedo_texture if the overlay really is a StandardMaterial3D
	

	original_position = og_position
	counter_origin = Counter
	global_position = og_position.global_position
	rotation_degrees = Vector3.ZERO
	base_y_position = global_position.y

	var overlay := $Inside/Outside.material_overlay as StandardMaterial3D
	print(overlay)
	if overlay:
		overlay = overlay.duplicate() as StandardMaterial3D  # don't share between instances
		overlay.albedo_texture = liquid_resource.outside_Sprite
		
		$Inside/Outside.material_overlay = overlay
	# in setup(), replace the old overlay block with:
	_setup_liquid_shader()
	_apply_outside_texture()
	set_liquid_color(liquid_resource.liquid_color)

func _apply_outside_texture() -> void:
	var tex: Texture2D = liquid_resource.outside_Sprite
	if tex == null:
		push_warning("Drinks: liquid_resource.outside_Sprite is null")
		return

	var outside := $Inside/Outside as GeometryInstance3D
	if outside is Sprite3D:
		outside.texture = tex

	# Shader material (the one with the gradient): set the uniform directly
	if liquid_shader_mat:
		liquid_shader_mat.set_shader_parameter("texture_albedo", tex)  # <- must match your shader's uniform name

	# Standard material fallback
	var std := outside.material_overlay as StandardMaterial3D
	if std:
		std = std.duplicate() as StandardMaterial3D
		std.albedo_texture = tex
		outside.material_overlay = std



func _process(_delta: float) -> void:
	if in_game:
		return
	super._process(_delta)
	if is_balls_dragging:
		_follow_cursor(_delta)
	if camera:
		var target_flat: Vector3 = camera.global_position
		target_flat.y = $Inside.global_position.y
		$Inside.look_at(target_flat, Vector3.UP)


# Tracks the cursor / hovered glass while dragging
func _follow_cursor(delta: float) -> void:
	if not camera:
		return
	var target: Vector3
	var glass := current_hovered_target
	if snap_to_glass and is_instance_valid(glass) and can_interact_with(glass):
		var to_cam := (camera.global_position - glass.global_position).normalized()
		target = glass.global_position + snap_offset + to_cam * hold_lift
	else:
		var mouse_pos := get_viewport().get_mouse_position()
		_depth_now = lerpf(_depth_now, _grab_depth - hold_lift, 1.0 - exp(-12.0 * delta))
		target = camera.project_position(mouse_pos, _depth_now)
	_smooth_pos = _smooth_pos.lerp(target, 1.0 - exp(-follow_speed * delta))
	global_position = _smooth_pos


func _capture_grab_depth() -> void:
	_smooth_pos = global_position
	var cam := camera if camera else get_viewport().get_camera_3d()
	if cam == null:
		return
	var forward := -cam.global_transform.basis.z
	_grab_depth = (global_position - cam.global_position).dot(forward)
	_depth_now = _grab_depth


func _on_area_3d_input_event(camera_node: Node, event: InputEvent, event_pos: Vector3, normal: Vector3, shape_idx: int) -> void:
	var left_pressed: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

	if not in_game:
		if left_pressed:
			if _return_tween:
				_return_tween.kill()
			_capture_grab_depth()
		super._on_area_3d_input_event(camera_node, event, event_pos, normal, shape_idx)
		return

	if left_pressed and not is_pouring:
		await _pour()


func _pour() -> void:
	is_pouring = true
	if GameState.player:
		GameState.player._update_hand("holding")
	rotation_degrees.z = 80

	if pouring_into:
		$CPUParticles3D.emitting = true
		while _is_pour_button_held() and current_liquid > 0.0 and is_instance_valid(pouring_into):
			var amount := minf(POUR_AMOUNT, current_liquid)
			pouring_into._pouring(liquid_resource.id, amount)
			set_liquid_amount(current_liquid - amount)
			await get_tree().create_timer(POUR_INTERVAL).timeout
			if not is_inside_tree():
				return

	$CPUParticles3D.emitting = false
	rotation_degrees.z = 0
	if GameState.player:
		GameState.player._update_hand("idle")
	is_pouring = false

	await get_tree().create_timer(0.2).timeout
	if is_inside_tree() and in_game and GameState.player:
		GameState.player._out_of_game()


func _is_pour_button_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.get_action_strength("Left_click") > 0.0


func _look_at_sprite(looking_at: Vector3) -> void:
	if looking_at:
		var target_flat: Vector3 = looking_at
		target_flat.y = $Inside.global_position.y
		$Inside.look_at(target_flat, Vector3.UP)


func _return_original() -> void:
	var tween := get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", original_position.global_position, 0.5)
	tween.tween_property($Inside, "global_rotation", Vector3.ZERO, 0.5)
	rotation_degrees = Vector3.ZERO


func _in_game() -> void:
	in_game = true
	if pouring_into and pouring_into.has_method("_on_hover"):
		pouring_into._on_hover(false)


func _out_of_game() -> void:
	in_game = false
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
	return target is Glasses and not (target is Drinks)


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


# Targeting is handled by the base class (ray under the cursor + set_highlight).
# MATT NOTE: the bottles don't sit on the counter, so play around with this to
# make sure it looks good and doesn't feel cheap or janky.
func _on_interact_area_entered(_area: Area3D) -> void:
	pass


func _on_interact_area_exited(_area: Area3D) -> void:
	pass


# ---------- Liquid ----------

func set_liquid_color(new_color: Color) -> void:
	color_liquid = new_color
	_update_liquid_shader()


func set_liquid_amount(amount: float) -> void:
	current_liquid = clampf(amount, 0.0, size)
	_update_liquid_shader()


func _update_liquid_shader() -> void:
	if not liquid_shader_mat or size <= 0.0:
		return
	var fill := clampf(current_liquid / size, 0.0, 1.0)
	liquid_shader_mat.set_shader_parameter("fill_amount", fill)


func refill() -> void:
	set_liquid_amount(size)


var _tex_from: Vector2
var _tex_to_full: Vector2

func _setup_liquid_shader() -> void:
	if liquid_shader_mat:
		return

	var outside := get_node_or_null("Inside/Outside") as GeometryInstance3D
	if not outside:
		return

	var source: Material = null
	var use_override := false
	if outside.material_override is ShaderMaterial:
		source = outside.material_override
		use_override = true
	elif outside.material_overlay is ShaderMaterial:
		source = outside.material_overlay
	if not source:
		push_warning("Drinks: no ShaderMaterial found on Inside/Outside")
		return

	# Own material per bottle, so bottles don't share a fill level
	liquid_shader_mat = source.duplicate() as ShaderMaterial
	if use_override:
		outside.material_override = liquid_shader_mat
	else:
		outside.material_overlay = liquid_shader_mat

	_update_liquid_shader()

	# Own material per bottle
	liquid_shader_mat = source.duplicate() as ShaderMaterial
	if use_override:
		outside.material_override = liquid_shader_mat
	else:
		outside.material_overlay = liquid_shader_mat

	# Use the texture already set in the Inspector (keeps your from/to lines)
	var existing := liquid_shader_mat.get_shader_parameter("gradient_texture") as GradientTexture2D
	if existing:
		gradient_texture = existing.duplicate() as GradientTexture2D
	else:
		gradient_texture = GradientTexture2D.new()
		gradient_texture.width = 4
		gradient_texture.height = 64
		gradient_texture.fill_from = Vector2(0.5, 1.0)  # bottom
		gradient_texture.fill_to = Vector2(0.5, 0.0)    # top

	# Remember the full-range line from the Inspector
	_tex_from = gradient_texture.fill_from
	_tex_to_full = gradient_texture.fill_to

	liquid_gradient = Gradient.new()
	liquid_gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient_texture.gradient = liquid_gradient

	liquid_shader_mat.set_shader_parameter("gradient_texture", gradient_texture)
	_rebuild_liquid_gradient()


func _rebuild_liquid_gradient() -> void:
	if not liquid_gradient or not gradient_texture or size <= 0.0:
		return

	var fill := clampf(current_liquid / size, 0.0, 1.0)
	var empty_color := Color(color_liquid, 0.0)

	if fill <= 0.0:
		liquid_gradient.offsets = PackedFloat32Array([0.0, 1.0])
		liquid_gradient.colors = PackedColorArray([empty_color, empty_color])
		return

	# Liquid color up to just before the end of the line, empty color after it
	liquid_gradient.offsets = PackedFloat32Array([0.0, 0.999])
	liquid_gradient.colors = PackedColorArray([color_liquid, empty_color])

	# Slide the "to" point along the original from -> to line
	gradient_texture.fill_from = _tex_from
	gradient_texture.fill_to = _tex_from.lerp(_tex_to_full, fill)
