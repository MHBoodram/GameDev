extends Button

var type : String = "Weapon"
var id : String  = "NA"
var parent_node : Control
var not_just_item : bool = false

func setup(text: String, type_: String,own: Control,equip: bool):
	parent_node = own
	type = type_
	not_just_item = equip
	id = text
	$Label.text = text
	if(type != "Attachments"):
		var texture = load("res://Assets/Items/Drinks/" +text+".png")
		if(texture != null):
			$AspectRatioContainer/TextureRect.texture = texture
		else:
			$AspectRatioContainer/TextureRect.texture = null
	else:
		$AspectRatioContainer/TextureRect.texture =load("res://assets/Weapons/Menu/Attachments/"+text+"_badge.png")

func _ready() -> void:
	$SelectionRect.hide()
	$EquippedPanel.hide()

func _on_resized() -> void:
	custom_minimum_size.y = get_rect().size.x

func _on_selection_rect_focus_entered() -> void:
	$SelectionRect.show()

func _on_selection_rect_focus_exited() -> void:
	$SelectionRect.hide()

func _on_pressed() -> void:
	#if(parent_node)
	pass

func _equip():
	$EquippedPanel.show()

func unequip():
	$EquippedPanel.hide()

func _get_name() -> String:
	return id

func _get_type() -> String:
	return type

func _on_mouse_entered() -> void:
	pass
