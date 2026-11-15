class_name DrinkMix
extends RefCounted

# handles the actual contents of a cup

var ingredients: Dictionary = {} # name -> amount (float)
var garnishes: Array[String] = []
var processing_tags: Array[String] = [] # ex. "shaken", "spectral"
var glass_type: String = ""
var is_tiny: bool = false

func add_liquid(id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	ingredients[id] = ingredients.get(id, 0.0) + amount

func add_garnish(garnish_id: String) -> void:
	if not garnishes.has(garnish_id):
		garnishes.append(garnish_id)

func add_processing(tag: String) -> void:
	var clean_tag = tag.to_lower().strip_edges()
	if not processing_tags.has(clean_tag):
		processing_tags.append(clean_tag)

func has_processing(tag: String) -> bool:
	return processing_tags.has(tag.to_lower().strip_edges())

func get_total_amount() -> float:
	var total: float = 0.0
	for amt in ingredients.values():
		total += float(amt)
	return total

func is_empty() -> bool:
	return ingredients.is_empty() or get_total_amount() <= 0.001

# returns ratios scaled so everything adds up to 1.0
func get_normalized_ingredients() -> Dictionary:
	var total = get_total_amount()
	var result: Dictionary = {}
	if total <= 0.0001:
		return result
	for id in ingredients.keys():
		result[id] = float(ingredients[id]) / total
	return result

func get_unique_ingredient_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in ingredients.keys():
		ids.append(str(id))
	ids.sort()
	return ids

# parses the older nested array format from Glasses.gd / _return_drink() so existing cups and scenes work for now
static func from_legacy_layers(layers: Array) -> DrinkMix:
	var mix := DrinkMix.new()
	if layers.is_empty():
		return mix

	for layer in layers:
		if not (layer is Array) or layer.size() < 2:
			continue

		# check if layer has a sub-dictionary of ingredients
		if layer.size() > 3 and layer[3] is Dictionary:
			for ing in layer[3]:
				var amt = float(layer[3][ing])
				mix.add_liquid(str(ing), amt)
		# shaken/mixed array of ingredient names
		elif layer[0] is Array:
			var split_amt = float(layer[1]) / maxf(float(layer[0].size()), 1.0)
			for ing in layer[0]:
				mix.add_liquid(str(ing), split_amt)
			mix.add_processing("shaken")
		# dictionary in layer[0]
		elif layer[0] is Dictionary:
			for ing in layer[0]:
				var amt = float(layer[0][ing])
				mix.add_liquid(str(ing), amt)
		else:
			var ing_name = str(layer[0])
			var amt = float(layer[1])
			mix.add_liquid(ing_name, amt)

	return mix