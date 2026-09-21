extends Ingredients
class_name Glasses
@export var liquids : Array = []
@export var size : float = 1.0 
var total_liquids : float = 0
var current_position = 0



func _pouring(id : String, liquids_num : float) -> void:
	if(len(liquids) != 0):
		var top_drink = liquids[len(liquids)-1]
		if(!top_drink[0] == id):
			top_drink[1] += liquids_num
			_visuals_change(liquids_num)

		else:
			var temp_liquid = [id,liquids_num]
			liquids.push_back(temp_liquid)
			_visuals_change(liquids_num)

	else:
		var temp_liquid = [id,liquids_num]
		liquids.push_back(temp_liquid)
		_visuals_change(liquids_num)

func _visuals_change(liquids_num: float) -> void:
	print(liquids_num)
	pass
