class_name Drink
extends Resource


var name : String 
var DrinkSize_oz : float
var IngredientList : Array[String]
var quality : String
var is_alcoholic : bool

func _init(p_name: String, p_size: float, p_quality: String, p_ingredients: Array[String] = []) -> void:
	name = p_name
	DrinkSize_oz = p_size
	IngredientList = p_ingredients
	quality = p_quality
