class_name LiquidVisualHelper
extends RefCounted

# handles glass and bottle fluid physics and shader

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

const LIQUID_COLOR = {
	"gin": Color(0.0, 0.953, 0.0, 1.0),
	"beer": Color(0.98, 0.322, 0.051, 1.0),
	"spirit": Color(0.542, 0.691, 1.0, 1.0),
	"vodka": Color(0.137, 0.372, 1.0, 1.0),
	"rum": Color(0.458, 0.154, 0.014, 1.0),
	"tequila": Color(0.9, 0.85, 0.3, 1.0),
	"whiskey": Color(0.78, 0.42, 0.1, 1.0),
	"blood": Color(0.85, 0.05, 0.05, 1.0)
}

func set_visual_override(override_data: Dictionary) -> void:
	_visual_override = override_data.duplicate()

func setup_shader(outside_sprite: Node) -> ShaderMaterial:
	if not outside_sprite:
		return null

	var source_mat: Material = null
	var is_override: bool = false
	if "material_override" in outside_sprite and outside_sprite.material_override is ShaderMaterial:
		source_mat = outside_sprite.material_override
		is_override = true
	elif "material_overlay" in outside_sprite and outside_sprite.material_overlay is ShaderMaterial:
		source_mat = outside_sprite.material_overlay

	if not source_mat:
		return null

	liquid_shader_mat = source_mat.duplicate() as ShaderMaterial
	if is_override:
		outside_sprite.material_override = liquid_shader_mat
	else:
		outside_sprite.material_overlay = liquid_shader_mat

	gradient_texture = GradientTexture2D.new()
	gradient_texture.width = 64
	gradient_texture.height = 4
	gradient_texture.fill_from = Vector2(0.0, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)

	liquid_gradient = Gradient.new()
	liquid_gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient_texture.gradient = liquid_gradient
	liquid_shader_mat.set_shader_parameter("gradient_texture", gradient_texture)
	return liquid_shader_mat

func update_physics(delta: float, current_pos: Vector3, camera: Camera3D, viscosity: float, spring_stiffness: float, base_damping: float, slosh_sens: float, max_slosh: float, wave_freq: float, vert_spring: float, vert_damping: float, vert_sens: float) -> void:
	if delta <= 0.0:
		return
	var frame_velocity := (current_pos - last_global_pos) / delta
	var frame_accel := (frame_velocity - last_velocity) / delta
	last_global_pos = current_pos
	last_velocity = frame_velocity

	var h_accel: float = frame_accel.dot(camera.global_transform.basis.x) if camera else frame_accel.x
	var clamped_visc := clampf(viscosity, 0.0, 1.0)
	var eff_damping := base_damping * (1.0 + clamped_visc * 2.0)
	var eff_spring := spring_stiffness / (1.0 + clamped_visc * 0.7)
	var current_max := lerpf(max_slosh, max_slosh * 0.35, clamped_visc)

	var slosh_force := -h_accel * slosh_sens
	var spring_force := -slosh_angle * eff_spring
	var damping_force := -slosh_velocity * eff_damping
	slosh_velocity += (spring_force + damping_force + slosh_force) * delta
	slosh_angle += slosh_velocity * delta
	slosh_angle = clampf(slosh_angle, -current_max, current_max)

	var lateral_agitation := absf(slosh_velocity) * 0.02
	var v_force := -frame_accel.y * vert_sens + lateral_agitation
	var v_spring_force := -slosh_vertical_offset * (vert_spring / (1.0 + clamped_visc))
	var v_damping_force := -slosh_vertical_velocity * (vert_damping * (1.0 + clamped_visc * 2.0))
	slosh_vertical_velocity += (v_spring_force + v_damping_force + v_force) * delta
	slosh_vertical_offset += slosh_vertical_velocity * delta
	slosh_vertical_offset = clampf(slosh_vertical_offset, -0.15, 0.15)

	wave_phase += delta * wave_freq * (1.0 - clamped_visc * 0.6)
	var agitation_energy := absf(slosh_velocity) * 0.025 + absf(frame_velocity.length()) * 0.015
	var target_wave := clampf(agitation_energy, 0.0, 0.06 * (1.0 - clamped_visc * 0.6))
	wave_amplitude = lerpf(wave_amplitude, target_wave, 1.0 - exp(-20.0 * delta))

func sync_shader_uniforms(fill_ratio: float, config: Dictionary) -> void:
	if not liquid_shader_mat:
		return
	liquid_shader_mat.set_shader_parameter("fill_amount", fill_ratio)
	liquid_shader_mat.set_shader_parameter("slosh_angle", slosh_angle)
	liquid_shader_mat.set_shader_parameter("slosh_vertical_offset", slosh_vertical_offset)
	liquid_shader_mat.set_shader_parameter("wave_phase", wave_phase)
	liquid_shader_mat.set_shader_parameter("wave_amplitude", wave_amplitude)
	liquid_shader_mat.set_shader_parameter("liquid_tint_color", _visual_override.get("liquid_tint_color", Color(0.45, 0.92, 1.0, 1.0)))
	liquid_shader_mat.set_shader_parameter("liquid_tint_strength", float(_visual_override.get("liquid_tint_strength", 0.0)))
	for uniform_name in config.keys():
		var val = _visual_override.get(uniform_name, config[uniform_name])
		liquid_shader_mat.set_shader_parameter(uniform_name, val)

func rebuild_gradient(liquids: Array, total_liquids: float, glass_size: float, liquid_box: VBoxContainer = null, label_scene: PackedScene = null) -> Label:
	var last_label: Label = null
	if not liquid_gradient:
		return last_label

	if liquids.is_empty() or total_liquids <= 0.0:
		liquid_gradient.offsets = PackedFloat32Array([0.0, 1.0])
		liquid_gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
		return last_label

	var has_tint := _visual_override.has("liquid_tint_color")
	var tint_col: Color = _visual_override.get("liquid_tint_color", Color.WHITE)
	var tint_mix: float = float(_visual_override.get("liquid_tint_strength", 0.35))

	if liquid_box and label_scene:
		var children := liquid_box.get_children()
		if children.size() != liquids.size():
			for c in children:
				liquid_box.remove_child(c)
				c.queue_free()
			for layer in liquids:
				liquid_box.add_child(label_scene.instantiate())
		children = liquid_box.get_children()
		for i in range(mini(children.size(), liquids.size())):
			var lbl = children[i]
			var layer: Array = liquids[i]
			var col := get_layer_color(layer)
			if has_tint:
				col = col.lerp(tint_col, tint_mix)
			if lbl.material:
				lbl.material.set_shader_parameter("base_color", col)
			var layer_name := format_layer_name(layer[0])
			var pct: float = (float(layer[1]) / maxf(glass_size, 0.001)) * 100.0
			var text_str := layer_name + ": " + str(snappedf(pct, 0.1)) + "%"
			if lbl.has_method("change_text"):
				lbl.change_text(text_str)
			else:
				lbl.text = text_str
		if not children.is_empty():
			last_label = children[children.size() - 1] as Label
		liquid_box.modulate.a = 1.0

	var offsets := PackedFloat32Array([0.0])
	var colors := PackedColorArray()
	var current_pos: float = 0.0

	for i in range(liquids.size() - 1, -1, -1):
		var layer = liquids[i]
		var amount: float = float(layer[1])
		if amount <= 0.0:
			continue
		var layer_col := get_layer_color(layer)
		if has_tint:
			layer_col = layer_col.lerp(Color(tint_col.r, tint_col.g, tint_col.b, layer_col.a), tint_mix)
		colors.append(layer_col)
		current_pos += amount / total_liquids
		if i > 0 and current_pos < 1.0:
			offsets.append(clampf(current_pos, 0.001, 0.999))

	while colors.size() < offsets.size():
		colors.append(colors[colors.size() - 1] if colors.size() > 0 else Color.WHITE)
	while offsets.size() < colors.size():
		offsets.append(1.0)

	liquid_gradient.offsets = offsets
	liquid_gradient.colors = colors
	return last_label

func format_layer_name(layer_id) -> String:
	if layer_id is Array:
		var names: Array = layer_id.duplicate()
		names.sort()
		return " + ".join(names)
	elif layer_id is Dictionary:
		var names: Array = layer_id.keys()
		names.sort()
		return " + ".join(names)
	return str(layer_id)

func get_layer_color(layer: Array) -> Color:
	if layer.size() > 2 and layer[2] is Color:
		return layer[2]
	if layer[0] is Array or layer[0] is Dictionary:
		return get_layer_hsv_color(layer)
	return LIQUID_COLOR.get(str(layer[0]), Color.WHITE)

func get_layer_hsv_color(layer: Array) -> Color:
	if layer.size() > 2 and layer[2] is Color:
		return layer[2]
	var weights: Array = []
	if layer.size() > 3 and layer[3] is Dictionary:
		for ing in layer[3]:
			weights.append([LIQUID_COLOR.get(str(ing), Color.WHITE), float(layer[3][ing])])
	elif layer[0] is Array:
		for ing in layer[0]:
			weights.append([LIQUID_COLOR.get(str(ing), Color.WHITE), 1.0])
	elif layer[0] is Dictionary:
		for ing in layer[0]:
			weights.append([LIQUID_COLOR.get(str(ing), Color.WHITE), float(layer[0][ing])])
	else:
		return LIQUID_COLOR.get(str(layer[0]), Color.WHITE)
	return average_hsv_color(weights)

func average_hsv_color(color_weights: Array) -> Color:
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
		var angle := c.h * TAU
		var sat_w := maxf(c.s, 0.01) * w
		sum_x += cos(angle) * sat_w
		sum_y += sin(angle) * sat_w
		sum_s += c.s * w
		sum_v += c.v * w
		sum_a += c.a * w

	if total_weight <= 0.0:
		return Color.WHITE

	var avg_h: float = 0.0
	if absf(sum_x) > 0.0001 or absf(sum_y) > 0.0001:
		var avg_angle := atan2(sum_y, sum_x)
		if avg_angle < 0.0:
			avg_angle += TAU
		avg_h = avg_angle / TAU
	else:
		avg_h = color_weights[0][0].h

	var avg_s := clampf(sum_s / total_weight, 0.35, 1.0)
	var avg_v := clampf(sum_v / total_weight, 0.5, 1.0)
	var avg_a := clampf(sum_a / total_weight, 0.0, 1.0)
	return Color.from_hsv(avg_h, avg_s, avg_v, avg_a)