extends Glasses
var highlight_mat: StandardMaterial3D

func ready() -> void:
	highlight_mat = StandardMaterial3D.new()
	highlight_mat.albedo_color = Color(1, 1, 0, 0.3)
	highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_mat.emission_enabled = true
	highlight_mat.emission = Color(1, 1, 0)
	highlight_mat.emission_energy_multiplier = 1
	
	$Outside.material_overlay = $Outside.material_override.duplicate(true)
	$Outside.material_override = $Outside.material_overlay
	var material_overlay_x = $Outside.material_override
	var gradient_tex = material_overlay_x.get_shader_parameter("gradient_texture")
	gradient_tex.fill_to.x = 1

func _on_hover(hovered: bool):
	material_overlay = highlight_mat if hovered else null

func _visuals_change(liquids_num: float) -> void:
	total_liquids += liquids_num
	var material_overlay_x = $Outside.material_override
	if material_overlay_x:
		var gradient_tex = material_overlay_x.get_shader_parameter("gradient_texture")
		if gradient_tex is GradientTexture2D:
			var to_value = gradient_tex.fill_to
			to_value.x = 1- total_liquids/size
			#print("size" + str(size))
			#print("total_liquids: " + str(total_liquids))
			#print(to_value.x)
			gradient_tex.fill_to = to_value

func _on_area_3d_area_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		_pushing_glass(area)
