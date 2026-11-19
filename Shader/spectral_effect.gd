class_name SpectralEffect
extends RefCounted

const SPECTRAL_SHADER := preload("res://Shader/spectral.gdshader")

static func apply_to_sprite(sprite: Sprite3D, params: Dictionary = {}) -> ShaderMaterial:
	if not is_instance_valid(sprite):
		return null

	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED

	var mat: ShaderMaterial = null
	if sprite.material_override is ShaderMaterial and (sprite.material_override as ShaderMaterial).shader == SPECTRAL_SHADER:
		mat = sprite.material_override as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = SPECTRAL_SHADER
		sprite.material_override = mat

	if sprite.texture:
		mat.set_shader_parameter("texture_albedo", sprite.texture)

	for param_name in params.keys():
		mat.set_shader_parameter(str(param_name), params[param_name])

	return mat

static func apply_to_glass(glass: Glasses) -> void:
	if not is_instance_valid(glass):
		return

	var target_sprite := glass.sprite if glass.sprite else glass.get_node_or_null("Inside") as Sprite3D
	if target_sprite:
		apply_to_sprite(target_sprite, {
			"float_amplitude": 0.0,
			"sway_amplitude": 0.0,
			"use_vertex_color": 0.0,
			"bottom_fade_strength": 0.12
		})

	if glass.visual_helper:
		glass.visual_helper.set_visual_override({
			"liquid_tint_color": Color(0.45, 0.92, 1.0, 1.0),
			"liquid_tint_strength": 0.35,
			"liquid_transparency": 0.5,
			"surface_highlight_color": Color(0.55, 1.45, 1.65, 1.0),
			"secondary_highlight_color": Color(0.45, 0.85, 1.5, 0.9),
			"caustic_beam_strength": maxf(glass.caustic_beam_strength, 0.65),
			"sparkle_density": maxf(glass.sparkle_density, 1.2),
			"glass_reflection_strength": maxf(glass.glass_reflection_strength, 0.5)
		})

	glass._rebuild_liquid_gradient(false)
	glass._update_shader_parameters()

static func clear_from_sprite(sprite: Sprite3D, restore_alpha_cut: SpriteBase3D.AlphaCutMode = SpriteBase3D.ALPHA_CUT_HASH) -> void:
	if not is_instance_valid(sprite):
		return
	if sprite.material_override is ShaderMaterial and (sprite.material_override as ShaderMaterial).shader == SPECTRAL_SHADER:
		sprite.material_override = null
	sprite.alpha_cut = restore_alpha_cut