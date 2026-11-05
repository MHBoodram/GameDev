extends Label

func _ready():
	material = material.duplicate()

func _change_bottom_text(temp_text : String) -> void:
	$Label.text = temp_text
