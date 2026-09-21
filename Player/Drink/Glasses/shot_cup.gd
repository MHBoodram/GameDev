extends Glasses
var liquid_stack: Array = []

func ready() -> void:
	$Outside.material_overlay = $Outside.material_override.duplicate(true)
	$Outside.material_override = $Outside.material_overlay
	var material_overlay_x = $Outside.material_override
	var gradient_tex = material_overlay_x.get_shader_parameter("gradient_texture")
	gradient_tex.fill_to.x = 1
	pass

func _visuals_change(liquids_num: float) -> void:
	total_liquids += liquids_num
	var material_overlay_x = $Outside.material_override
	if material_overlay_x:
		var gradient_tex = material_overlay_x.get_shader_parameter("gradient_texture")
		if gradient_tex is GradientTexture2D:
			var to_value = gradient_tex.fill_to
			to_value.x = 1- total_liquids/size
			print("size" + str(size))
			print("total_liquids: " + str(total_liquids))
			print(to_value.x)
			gradient_tex.fill_to = to_value
