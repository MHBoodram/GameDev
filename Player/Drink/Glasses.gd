extends Ingredients
@export var liquids : Array = []
@export var size : float = 1.0 
var current_position = 0



func _pouring(name : String, liquids_num : float) -> void:
	var top_drink = liquids[len(liquids)]
	if(!top_drink[0] == name):
		top_drink[1] += liquids_num
	else:
		var temp_liquid = [name,liquids_num]
		liquids.push_back(temp_liquid)

func _visuals_change() -> void:
	
	pass
