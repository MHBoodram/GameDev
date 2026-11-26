class_name DrinkOrder
extends RefCounted

# what the customer actually asked for
var species_id: String = ""
var recipe_name: String = ""
var ingredients: Dictionary = {} # name -> desired proportion (0.0 to 1.0)
var garnishes: Array[String] = []
var accepted_garnishes: Array[String] = [] # list of garnishes that a customer would want with their drink
var ice_preference: int = DrinkRecipe.IcePreference.DONT_CARE
var required_processing: Array[String] = [] # "shaken", "spectral", etc
var required_glass: String = ""
var is_tiny: bool = false
var ideal_fill_ratio: float = -1.0 # < 0.0 falls back to DrinkScorer.IDEAL_FILL_RATIO
var underfill_exponent: float = -1.0 # < 0.0 falls back to DrinkScorer.UNDERFILL_EXPONENT
var proportion_tolerance: float = -1.0 # < 0.0 falls back to DrinkScorer.MAX_DIFF
var penalty_scale: float = 1.0
var require_ingredient_match: bool = true
var extra_requirements: Dictionary = {}

func get_normalized_ingredients() -> Dictionary:
	var total: float = 0.0
	for amt in ingredients.values():
		total += float(amt)
	var result: Dictionary = {}
	if total <= 0.0001:
		return result
	for id in ingredients.keys():
		result[id] = float(ingredients[id]) / total
	return result

func get_garnish_counts() -> Dictionary:
	var counts: Dictionary = {}
	for g in garnishes:
		var clean_id := str(g).to_lower().strip_edges()
		if clean_id != "":
			counts[clean_id] = int(counts.get(clean_id, 0)) + 1
	return counts

# converts the older [["beer", 1.0]] or [["gin", 0.5], ["vermouth", 0.5]] format
static func from_legacy_want(want: Array) -> DrinkOrder:
	var order := DrinkOrder.new()
	if want.is_empty():
		return order

	var raw_sum: float = 0.0
	for item in want:
		if item is Array and item.size() >= 2:
			var ing_name = str(item[0])
			var amt = float(item[1])
			order.ingredients[ing_name] = order.ingredients.get(ing_name, 0.0) + amt
			raw_sum += amt

	# normalize to 1.0 ratios
	if raw_sum > 0.0:
		for id in order.ingredients.keys():
			order.ingredients[id] = float(order.ingredients[id]) / raw_sum

	return order

static func from_recipe(recipe: DrinkRecipe) -> DrinkOrder:
	var order := DrinkOrder.new()
	order.recipe_name = recipe.display_name
	order.required_glass = recipe.required_glass
	order.garnishes = recipe.garnishes.duplicate()
	order.required_processing = recipe.processing.duplicate()
	order.accepted_garnishes = recipe.accepted_garnishes.duplicate()
	order.ice_preference = recipe.ice_preference

	# normalize recipe ingredients
	var raw_sum: float = 0.0
	for amt in recipe.ingredients.values():
		raw_sum += float(amt)
	if raw_sum > 0.0:
		for id in recipe.ingredients.keys():
			order.ingredients[id] = float(recipe.ingredients[id]) / raw_sum

	return order