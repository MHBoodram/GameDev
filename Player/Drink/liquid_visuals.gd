class_name LiquidVisualHelper
extends RefCounted

# Handles container liquid physics

const CONTAINER_SHADER := preload("res://Player/Drink/liquid_container.gdshader")
const LIQUID_COLOR := LiquidProperties.LIQUID_COLOR
const LIQUID_BUOYANCY := LiquidProperties.LIQUID_BUOYANCY
const LIQUID_VISCOSITY := LiquidProperties.LIQUID_VISCOSITY
const UNIFORM_PIXEL_DENSITY: float = 150.0
const REFERENCE_PIXEL_RESOLUTION: float = 48.0

var slosh_angle: float = 0.0
var slosh_velocity: float = 0.0
var slosh_vertical_offset: float = 0.0
var slosh_vertical_velocity: float = 0.0
var wave_phase: float = 0.0
var wave_amplitude: float = 0.0

var last_global_pos: Vector3 = Vector3.ZERO
var last_velocity: Vector3 = Vector3.ZERO

var liquid_shader_mat: ShaderMaterial
var gradient_texture: GradientTexture2D
var liquid_gradient: Gradient
var _visual_override: Dictionary = {}
var _pending_pour_info: Dictionary = {}

var fluid_sim: AtomicFluidSim = null
var _outside_sprite: Node = null
var _last_viscosity: float = 0.0

static func register_liquid_buoyancy(id: String, buoyancy_val: float) -> void:
	LiquidProperties.register_liquid_buoyancy(id, buoyancy_val)

static func get_liquid_buoyancy(id: String) -> float:
	return LiquidProperties.get_liquid_buoyancy(id)

static func get_layer_buoyancy(layer: Array) -> float:
	return LiquidProperties.get_layer_buoyancy(layer)

static func register_liquid_viscosity(id: String, viscosity_val: float) -> void:
	LiquidProperties.register_liquid_viscosity(id, viscosity_val)

static func get_liquid_viscosity(id: String) -> float:
	return LiquidProperties.get_liquid_viscosity(id)

func set_visual_override(override_data: Dictionary) -> void:
	_visual_override = override_data.duplicate()

func set_next_pour_info(pour_info: Dictionary) -> void:
	_pending_pour_info = pour_info.duplicate()

func set_mouth_monitoring(enabled: bool) -> void:
	if fluid_sim:
		fluid_sim.set_mouth_monitoring(enabled)

func is_liquid_touching_mouth() -> bool:
	return fluid_sim != null and fluid_sim.is_liquid_touching_mouth()

func get_mouth_contact_ratio() -> float:
	return fluid_sim.get_mouth_contact_ratio() if fluid_sim else 0.0

func setup_shader(outside_sprite: Node) -> ShaderMaterial:
	if not outside_sprite:
		return null
	_outside_sprite = outside_sprite

	var source_mat: Material = null
	var is_override: bool = false
	if "material_override" in outside_sprite and outside_sprite.material_override is ShaderMaterial:
		source_mat = outside_sprite.material_override
		is_override = true
	elif "material_overlay" in outside_sprite and outside_sprite.material_overlay is ShaderMaterial:
		source_mat = outside_sprite.material_overlay

	liquid_shader_mat = source_mat.duplicate() as ShaderMaterial if source_mat else ShaderMaterial.new()
	if not source_mat:
		is_override = true
	liquid_shader_mat.shader = CONTAINER_SHADER
	liquid_shader_mat.render_priority = 2

	if is_override:
		outside_sprite.material_override = liquid_shader_mat
	else:
		outside_sprite.material_overlay = liquid_shader_mat

	var mask_tex: Texture2D = null
	if outside_sprite is Sprite3D and (outside_sprite as Sprite3D).texture:
		mask_tex = (outside_sprite as Sprite3D).texture
	elif liquid_shader_mat.get_shader_parameter("texture_albedo") is Texture2D:
		mask_tex = liquid_shader_mat.get_shader_parameter("texture_albedo") as Texture2D
	if mask_tex:
		liquid_shader_mat.set_shader_parameter("texture_albedo", mask_tex)

	if fluid_sim:
		fluid_sim.cleanup()
	fluid_sim = AtomicFluidSim.new()
	var fluid_tex := fluid_sim.setup_from_texture(mask_tex)
	if fluid_tex:
		liquid_shader_mat.set_shader_parameter("fluid_texture", fluid_tex)

	var init_grid := _compute_pixel_grid(REFERENCE_PIXEL_RESOLUTION)
	liquid_shader_mat.set_shader_parameter("pixel_grid", init_grid)
	liquid_shader_mat.set_shader_parameter("pixel_resolution", (init_grid.x + init_grid.y) * 0.5)

	gradient_texture = GradientTexture2D.new()
	gradient_texture.width = 64
	gradient_texture.height = 4
	gradient_texture.fill_from = Vector2(0.0, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)
	liquid_gradient = Gradient.new()
	liquid_gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient_texture.gradient = liquid_gradient
	return liquid_shader_mat

func cleanup() -> void:
	if fluid_sim:
		fluid_sim.cleanup()
		fluid_sim = null

func add_agitation(impulse_grid_vel: Vector2) -> void:
	if fluid_sim:
		fluid_sim.add_agitation(impulse_grid_vel)
	slosh_velocity += randf_range(-0.35, 0.35)
	wave_amplitude = minf(wave_amplitude + 0.035, 0.07)

func sync_container_liquids(liquids: Array, glass_size: float, is_mixed_flag: bool) -> void:
	var pour_info := _pending_pour_info
	_pending_pour_info = {}
	if fluid_sim:
		fluid_sim.sync_container_liquids(liquids, glass_size, is_mixed_flag, {}, pour_info, {})

func sync_bottle_liquid(id: String, current_amount: float, bottle_size: float, color: Color, buoyancy: float = -1.0, viscosity_val: float = -1.0) -> void:
	if buoyancy > 0.0:
		LiquidProperties.register_liquid_buoyancy(id, buoyancy)
	if viscosity_val >= 0.0:
		LiquidProperties.register_liquid_viscosity(id, viscosity_val)
	var eff_buoy := buoyancy if buoyancy > 0.0 else LiquidProperties.get_liquid_buoyancy(id)
	var eff_visc := clampf(viscosity_val, 0.0, 1.0) if viscosity_val >= 0.0 else LiquidProperties.get_liquid_viscosity(id)
	if fluid_sim:
		fluid_sim.sync_bottle_liquid(id, current_amount, bottle_size, color, eff_buoy, eff_visc)

func update_physics(delta: float, current_pos: Vector3, camera: Camera3D, viscosity: float, spring_stiffness: float, base_damping: float, slosh_sens: float, max_slosh: float, wave_freq: float, vert_spring: float, vert_damping: float, vert_sens: float, container_sprite: Node3D = null) -> void:
	if delta <= 0.0:
		return
	_last_viscosity = viscosity

	var pos_delta := current_pos - last_global_pos
	if pos_delta.length() > 0.4:
		last_global_pos = current_pos
		last_velocity = Vector3.ZERO
		pos_delta = Vector3.ZERO

	var frame_velocity := pos_delta / delta
	var frame_accel := (frame_velocity - last_velocity) / delta
	last_global_pos = current_pos
	last_velocity = frame_velocity
	if frame_accel.length() > 50.0:
		frame_accel = frame_accel.normalized() * 50.0

	var h_accel: float = frame_accel.dot(camera.global_transform.basis.x) if camera else frame_accel.x
	var clamped_visc := clampf(viscosity, 0.0, 1.0)
	var eff_damping := base_damping * (1.0 + clamped_visc * 2.0)
	var eff_spring := spring_stiffness / (1.0 + clamped_visc * 0.7)
	var current_max := lerpf(max_slosh, max_slosh * 0.35, clamped_visc)

	slosh_velocity += (-slosh_angle * eff_spring - slosh_velocity * eff_damping - h_accel * slosh_sens) * delta
	slosh_angle = clampf(slosh_angle + slosh_velocity * delta, -current_max, current_max)

	var v_force := -frame_accel.y * vert_sens + absf(slosh_velocity) * 0.02
	slosh_vertical_velocity += (-slosh_vertical_offset * (vert_spring / (1.0 + clamped_visc)) - slosh_vertical_velocity * (vert_damping * (1.0 + clamped_visc * 2.0)) + v_force) * delta
	slosh_vertical_offset = clampf(slosh_vertical_offset + slosh_vertical_velocity * delta, -0.15, 0.15)

	wave_phase += delta * wave_freq * (1.0 - clamped_visc * 0.6)
	var target_wave := clampf(absf(slosh_velocity) * 0.025 + absf(frame_velocity.length()) * 0.015, 0.0, 0.06 * (1.0 - clamped_visc * 0.6))
	wave_amplitude = lerpf(wave_amplitude, target_wave, 1.0 - exp(-20.0 * delta))

	if fluid_sim:
		var sprite_node: Node3D = container_sprite if is_instance_valid(container_sprite) else (_outside_sprite as Node3D)
		var world_accel := Vector3(0.0, -9.8, 0.0) - frame_accel
		var local_accel := Vector2(0.0, -9.8)
		if is_instance_valid(sprite_node) and sprite_node.is_inside_tree():
			var b := sprite_node.global_transform.basis
			var axis_x := -b.x.normalized() if (sprite_node is Sprite3D and (sprite_node as Sprite3D).flip_h) else b.x.normalized()
			var axis_y := -b.y.normalized() if (sprite_node is Sprite3D and (sprite_node as Sprite3D).flip_v) else b.y.normalized()
			local_accel = Vector2(world_accel.dot(axis_x), world_accel.dot(axis_y))
		fluid_sim.step(delta, local_accel, viscosity)

func _compute_pixel_grid(base_resolution: float) -> Vector2:
	if _visual_override.has("pixel_resolution"):
		var ov := maxf(float(_visual_override["pixel_resolution"]), 8.0)
		return Vector2(ov, ov)
	var res_scale := maxf(base_resolution, 8.0) / REFERENCE_PIXEL_RESOLUTION
	var sp := _outside_sprite as Sprite3D
	if is_instance_valid(sp) and sp.texture != null and sp.is_inside_tree():
		var rect := sp.get_item_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			var b := sp.global_transform.basis
			var world_w := rect.size.x * sp.pixel_size * b.x.length()
			var world_h := rect.size.y * sp.pixel_size * b.y.length()
			if world_w > 0.0001 and world_h > 0.0001:
				var density := UNIFORM_PIXEL_DENSITY * res_scale
				return Vector2(maxf(world_w * density, 8.0), maxf(world_h * density, 8.0))
	var fallback := maxf(base_resolution, 8.0)
	return Vector2(fallback, fallback)

func sync_shader_uniforms(_fill_ratio: float, config: Dictionary) -> void:
	if not liquid_shader_mat:
		return
	for uniform_name in config.keys():
		if uniform_name == "pixel_resolution":
			continue
		liquid_shader_mat.set_shader_parameter(uniform_name, _visual_override.get(uniform_name, config[uniform_name]))
	var grid := _compute_pixel_grid(float(config.get("pixel_resolution", REFERENCE_PIXEL_RESOLUTION)))
	liquid_shader_mat.set_shader_parameter("pixel_grid", grid)
	liquid_shader_mat.set_shader_parameter("pixel_resolution", (grid.x + grid.y) * 0.5)

func rebuild_gradient(liquids: Array, total_liquids: float, glass_size: float, is_mixed_flag: bool = false) -> void:
	sync_container_liquids(liquids, glass_size, is_mixed_flag)
	if not liquid_gradient:
		return
	if liquids.is_empty() or total_liquids <= 0.0:
		liquid_gradient.offsets = PackedFloat32Array([0.0, 1.0])
		liquid_gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
		return

	var has_tint := _visual_override.has("liquid_tint_color")
	var tint_col: Color = _visual_override.get("liquid_tint_color", Color.WHITE)
	var tint_mix: float = float(_visual_override.get("liquid_tint_strength", 0.35))

	var sorted_indices: Array[int] = []
	for i in liquids.size():
		var l = liquids[i]
		if l is Array and l.size() >= 2 and float(l[1]) > 0.0:
			sorted_indices.append(i)
	sorted_indices.sort_custom(func(a: int, b: int) -> bool:
		var ba := LiquidProperties.get_layer_buoyancy(liquids[a])
		var bb := LiquidProperties.get_layer_buoyancy(liquids[b])
		return a < b if is_equal_approx(ba, bb) else ba < bb
	)

	var offsets := PackedFloat32Array([0.0])
	var colors := PackedColorArray()
	var current_pos: float = 0.0
	for idx_pos in range(sorted_indices.size() - 1, -1, -1):
		var layer = liquids[sorted_indices[idx_pos]]
		var layer_col := LiquidColorUtils.get_layer_color(layer)
		if has_tint:
			layer_col = layer_col.lerp(Color(tint_col.r, tint_col.g, tint_col.b, layer_col.a), tint_mix)
		colors.append(layer_col)
		current_pos += float(layer[1]) / total_liquids
		if idx_pos > 0 and current_pos < 1.0:
			offsets.append(clampf(current_pos, 0.001, 0.999))

	while colors.size() < offsets.size():
		colors.append(colors[colors.size() - 1] if colors.size() > 0 else Color.WHITE)
	while offsets.size() < colors.size():
		offsets.append(1.0)
	liquid_gradient.offsets = offsets
	liquid_gradient.colors = colors

func format_layer_name(layer_id) -> String:
	return LiquidColorUtils.format_layer_name(layer_id)

func get_layer_color(layer: Array) -> Color:
	return LiquidColorUtils.get_layer_color(layer)

func get_layer_hsv_color(layer: Array) -> Color:
	return LiquidColorUtils.get_layer_hsv_color(layer)

func average_hsv_color(color_weights: Array) -> Color:
	return LiquidColorUtils.average_hsv_color(color_weights)
