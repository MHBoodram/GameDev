class_name DrinkMix
extends RefCounted

# handles the actual contents of a cup

var ingredients: Dictionary = {} # name -> amount (float)
var garnishes: Array[String] = []
var processing_tags: Array[String] = [] # ex. "shaken", "spectral"
var glass_type: String = ""
var cup_capacity: float = 0.0 # <= 0.0 means capacity was not explicitly set
var is_tiny: bool = false
var overfill_percent: float = 0.0
var max_garnishes = 2
var has_ice = false

func reset() -> void:
	ingredients.clear()
	garnishes.clear()
	processing_tags.clear()
	is_tiny = false
	overfill_percent = 0.0
	has_ice = false

func add_liquid(id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	ingredients[id] = ingredients.get(id, 0.0) + amount

func add_overfill(percent: float) -> void:
	if percent > 0.0:
		overfill_percent += percent

func add_garnish(garnish_id: String) -> bool:
	var clean_id := garnish_id.to_lower().strip_edges()
	if clean_id.is_empty() or garnishes.has(clean_id) or garnishes.size() >= max_garnishes:
		return false
	garnishes.append(clean_id)
	return true

#func add_garnish(garnish_id: String) -> void: # Legacy code for future reference (sorry toby)
	#if not garnishes.has(garnish_id):
		#garnishes.append(garnish_id)

func add_ice() -> bool:
	if has_ice:
		return false
	has_ice = true
	return true

func add_processing(tag: String) -> void:
	var clean_tag = tag.to_lower().strip_edges()
	if not processing_tags.has(clean_tag):
		processing_tags.append(clean_tag)

func has_processing(tag: String) -> bool:
	return processing_tags.has(tag.to_lower().strip_edges())

func get_total_amount() -> float:
	var total: float = 0.0
	for amt in ingredients.values():
		var val := float(amt)
		if val > 0.001:
			total += val
	return total

func get_fill_ratio() -> float:
	var total := get_total_amount()
	if total <= 0.001:
		return 0.0
	var effective_capacity := cup_capacity if cup_capacity > 0.001 else maxf(1.0, total)
	return clampf(total / effective_capacity, 0.0, 1.0)

func is_empty() -> bool:
	return ingredients.is_empty() or get_total_amount() <= 0.001

# returns ratios scaled so everything adds up to 1.0
func get_normalized_ingredients() -> Dictionary:
	var total = get_total_amount()
	var result: Dictionary = {}
	if total <= 0.001:
		return result
	for id in ingredients.keys():
		var amt := float(ingredients[id])
		if amt > 0.001:
			result[id] = amt / total
	return result

func get_unique_ingredient_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in ingredients.keys():
		if float(ingredients[id]) > 0.001:
			ids.append(str(id))
	ids.sort()
	return ids

# parses the older nested array format from Glasses.gd / _return_drink() so existing cups and scenes work for now
static func from_legacy_layers(layers: Array, capacity: float = 0.0) -> DrinkMix:
	var mix := DrinkMix.new()
	if capacity > 0.0:
		mix.cup_capacity = capacity
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
