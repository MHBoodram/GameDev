extends Glasses

var gradient: Gradient

func ready() -> void:
	var mat := $Outside.material_override.duplicate() as ShaderMaterial
	var tex := GradientTexture2D.new()
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 256
	tex.height = 4
	gradient = Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	tex.gradient = gradient
	mat.set_shader_parameter("gradient_texture", tex)
	_rebuild_gradient()
	$Outside.material_override = mat
	var material_overlay_x = $Outside.material_override
	var gradient_tex = material_overlay_x.get_shader_parameter("gradient_texture")
	gradient_tex.fill_to.x = 1
	$highlight.modulate = Color(1.5, 1.5, 0.0, 5.0)   # brighter than normal
	
func _on_hover(hovered: bool):
	$highlight.visible = hovered

func _visuals_change(liquids_num: float, liquid_name: String, new: bool) -> void:
	_rebuild_gradient()

func _rebuild_gradient() -> void:
	total_liquids = 0.0
	for l in liquids:
		total_liquids += l[1]

	var offsets := PackedFloat32Array([0.0])
	var colors := PackedColorArray([Color(0, 0, 0, 0)])   # clear above the liquid

	if size > 0.0:
		var pos := clampf(1.0 - total_liquids / size, 0.001, 1.0)
		# last entry = top layer, so walk from the end down to the bottom
		for i in range(liquids.size() - 1, -1, -1):
			var amount: float = liquids[i][1]
			if amount <= 0.0:
				continue   # skip empty layers to avoid duplicate offsets
			offsets.append(pos)
			colors.append(LIQUID_COLOR.get(liquids[i][0], Color.WHITE))
			pos += amount / size

	gradient.offsets = offsets
	gradient.colors = colors



func _giving_drink() -> void:
	$Area3D.disconnect("input_event",_on_area_3d_input_event)
	is_balls_dragging = false

func _on_area_3d_area_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		_pushing_glass(area)
