extends Label

func _ready():
	material = material.duplicate()

func change_text(temp_text : String) -> void:
	text = temp_text
	$Label.text = temp_text
