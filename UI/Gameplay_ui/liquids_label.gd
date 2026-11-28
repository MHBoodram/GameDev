extends Label

func _ready():
	material = material.duplicate()

func change_text(temp_text : String) -> void:
	text = temp_text
	$Label.text = temp_text

func set_highlighted(enabled: bool, glow_color: Color = Color(1.0, 0.96, 0.55, 1.0)) -> void:
	if material is ShaderMaterial:
		var mat := material as ShaderMaterial
		mat.set_shader_parameter("highlight_amount", 1.0 if enabled else 0.0)
		mat.set_shader_parameter("highlight_glow_color", glow_color)