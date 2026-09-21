extends Glasses
var liquid_stack: Array = []



func _visuals_change(liquids_num: float) -> void:
	total_liquids += liquids_num
	var material_overlay = $Outside.material_override
	print(total_liquids/size)
	if material_overlay:
		material_overlay.set_shader_parameter("to.x", total_liquids/size)
	else:
		push_warning("No material_override set on Outside node")
	pass
