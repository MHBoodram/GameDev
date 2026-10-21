extends Ingredients
class_name Glasses
@export var liquids : Array = []
@export var size : float = 1.0
@export var area_body : CollisionShape3D
@export var sprite : Sprite3D
var total_liquids : float = 0
var current_position = 0
var in_game: bool = false
var is_being_served: bool = false
const LIQUID_COLOR = {
	"gin" : Color(0.0, 0.953, 0.0, 1.0),
	"beer" : Color(0.98, 0.322, 0.051, 1.0),
	"spirit" : Color(0.542, 0.691, 1.0, 1.0),
	"vodka" : Color(0.137, 0.372, 1.0, 1.0),
	"rum" : Color(0.458, 0.154, 0.014, 1.0)
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

func ready() -> void:
	rotation = Vector3.ZERO
	_last_global_pos = global_position
	_setup_liquid_shader()
	if highlight:
		highlight.modulate = Color(1.5, 1.5, 0.0, 5.0)
	if camera:
		_look_at_sprite(camera.global_position)

func _delete():
	queue_free()

@export var dead_zone := 50.0
@export var full_pull := 150.0

@export var max_hand_distance := 20.0

func _update_hand_position(delta: float) -> void:
	if not camera or not GameState.player:
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

func _process(_delta: float) -> void:
	super._process(_delta)
	_update_liquid_physics(_delta)
	_update_shader_parameters()
	if is_being_served:
		return
	_apply_collision_push(_delta)
	if is_balls_dragging:
		_update_hand_position(_delta)
	elif counter_origin:
		global_position = _clamp_to_counter(global_position)

func _apply_collision_push(delta: float) -> void:
	if not is_balls_dragging:
		for area in get_overlapping_areas():
			if area != self and area is Glasses:
				var diff: Vector3 = global_position - area.global_position
				diff.y = 0.0
				var dist: float = diff.length()
				if dist < 0.001:
					diff = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
					dist = 0.001
				var overlap: float = INTERACTION_SEPARATION_DISTANCE - dist
				if overlap > 0.0:
					push_velocity += diff.normalized() * (overlap * 6.0 * delta)

		if push_velocity.length_squared() > 0.0001:
			global_position += push_velocity * delta
			if counter_origin:
				global_position = _clamp_to_counter(global_position)
			push_velocity = push_velocity.lerp(Vector3.ZERO, 1.0 - exp(-PUSH_FRICTION * delta))
			if camera:
				_look_at_sprite(camera.global_position)

func _look_at_sprite(looking_at: Vector3) -> void:
	if looking_at and sprite:
		var target_flat: Vector3 = looking_at
		target_flat.y = sprite.global_position.y
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

func _rebuild_liquid_gradient() -> void:
	total_liquids = 0.0
	for l in liquids:
		total_liquids += l[1]

	if not liquid_gradient:
		return

	if liquids.is_empty() or total_liquids <= 0.0:
		liquid_gradient.offsets = PackedFloat32Array([0.0, 1.0])
		liquid_gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
		return

	var offsets := PackedFloat32Array([0.0])
	var colors := PackedColorArray()

	var current_pos: float = 0.0
	for i in range(liquids.size() - 1, -1, -1):
		var liquid_id: String = liquids[i][0]
		var amount: float = liquids[i][1]
		if amount <= 0.0:
			continue
		var col: Color = LIQUID_COLOR.get(liquid_id, Color.WHITE)
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
	if(len(liquids) != 0):
		var top_drink = liquids[len(liquids)-1]
		if(top_drink[0] == id):
			top_drink[1] += liquids_num
			_visuals_change(liquids_num,id,false)
		else:
			var temp_liquid = [id,liquids_num]
			liquids.push_back(temp_liquid)
			_visuals_change(liquids_num,id,true)
	else:
		var temp_liquid = [id,liquids_num]
		liquids.push_back(temp_liquid)
		_visuals_change(liquids_num,id,true)

	slosh_velocity += randf_range(-0.35, 0.35) * (1.0 - clampf(viscosity, 0.0, 1.0))
	slosh_vertical_velocity += randf_range(-0.15, 0.05)
	wave_amplitude = minf(wave_amplitude + 0.035, 0.07)

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

func _visuals_change(liquids_num: float,liquid_name: String,new: bool) -> void:
	_rebuild_liquid_gradient()

func _on_hover(hovered: bool) -> void:
	set_highlight(hovered)

func _dranked() -> void:
	queue_free()

func _return_drink() -> Array:
	return liquids

func _on_area_3d_area_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		_pushing_glass(area)

func can_interact_with(target: Ingredients) -> bool:
	if target and target.is_in_group("trash"):
		return true
	return false

func execute_interaction(target: Ingredients) -> void:
	if target and target.is_in_group("trash"):
		_delete()
