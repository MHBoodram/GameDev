class_name Ingredients
extends Resource

	
@export var name : String = ""
@export var quality : String = ""
@export var amount : float = 0.0
@export var unit : String = "oz"
@export var is_alcoholic : bool = false

func _init(P_name, P_amount, P_unit, P_quality) -> void:
	name = P_name
	amount = P_amount
	unit = P_unit
	quality = P_quality
	
