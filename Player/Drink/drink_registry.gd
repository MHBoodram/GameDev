class_name DrinkRegistry
extends RefCounted

static var _initialized: bool = false
static var _recipes_by_id: Dictionary = {}
static var _ordered_recipes: Array[DrinkRecipe] = []

static func get_all_garnishes() -> Array[String]:
	var list: Array[String] = []
	list.assign(DrinkDefinitions.GARNISHES)
	return list

static func is_valid_garnish(garnish_id: String) -> bool:
	return DrinkMix.is_valid_garnish(garnish_id)

static func ensure_loaded() -> void:
	if _initialized:
		return
	_initialized = true
	_recipes_by_id.clear()
	_ordered_recipes.clear()

	for raw_def in DrinkDefinitions.DEFINITIONS:
		var recipe := _build_recipe(raw_def)
		var key := recipe.recipe_id.to_lower().strip_edges()
		if key == "" or _recipes_by_id.has(key):
			continue
		_recipes_by_id[key] = recipe
		_ordered_recipes.append(recipe)

static func reload() -> void:
	_initialized = false
	ensure_loaded()

static func _build_recipe(data: Dictionary) -> DrinkRecipe:
	var recipe := DrinkRecipe.new()
	recipe.recipe_id = str(data.get("id", data.get("recipe_id", ""))).to_lower().strip_edges()
	recipe.display_name = str(data.get("display_name", recipe.recipe_id.capitalize()))
	recipe.required_glass = str(data.get("required_glass", "")).to_lower().strip_edges()
	recipe.is_alcoholic = bool(data.get("is_alcoholic", true))
	recipe.ice_preference = int(data.get("ice_preference", DrinkRecipe.IcePreference.DONT_CARE)) as DrinkRecipe.IcePreference

	var raw_ings: Variant = data.get("ingredients", {})
	if raw_ings is Dictionary:
		for k in (raw_ings as Dictionary).keys():
			var amt := float(raw_ings[k])
			if amt > 0.0:
				recipe.ingredients[str(k).to_lower().strip_edges()] = amt

	var raw_garnishes: Variant = data.get("garnishes", [])
	if raw_garnishes is Array:
		for g in raw_garnishes:
			var clean_g := str(g).to_lower().strip_edges()
			if is_valid_garnish(clean_g):
				recipe.garnishes.append(clean_g)
	elif raw_garnishes is Dictionary:
		for g in (raw_garnishes as Dictionary).keys():
			var clean_g := str(g).to_lower().strip_edges()
			var count := int(raw_garnishes[g])
			if is_valid_garnish(clean_g) and count >= 1:
				for _i in range(count):
					recipe.garnishes.append(clean_g)

	var raw_accepted: Variant = data.get("accepted_garnishes", [])
	if raw_accepted is Array:
		for g in raw_accepted:
			var clean_g := str(g).to_lower().strip_edges()
			if is_valid_garnish(clean_g) and not recipe.accepted_garnishes.has(clean_g):
				recipe.accepted_garnishes.append(clean_g)

	var raw_tags: Variant = data.get("processing_tags", data.get("processing", []))
	if raw_tags is Array:
		for tag in raw_tags:
			var clean_tag := str(tag).to_lower().strip_edges()
			if clean_tag != "" and not recipe.processing.has(clean_tag):
				recipe.processing.append(clean_tag)

	return recipe

static func get_all_recipes() -> Array[DrinkRecipe]:
	ensure_loaded()
	var list: Array[DrinkRecipe] = []
	list.assign(_ordered_recipes)
	return list

static func get_recipe(id_or_name: String) -> DrinkRecipe:
	ensure_loaded()
	var key := id_or_name.to_lower().strip_edges()
	if key == "":
		return null
	if _recipes_by_id.has(key):
		return _recipes_by_id[key] as DrinkRecipe
	for recipe in _ordered_recipes:
		if recipe.display_name.to_lower().strip_edges() == key:
			return recipe
	return null

static func is_recipe_unlocked(recipe: DrinkRecipe, stats: Node = null) -> bool:
	if recipe == null:
		return false
	if stats == null:
		return true

	for ing_key in recipe.ingredients.keys():
		var clean_ing := str(ing_key).to_lower().strip_edges()
		if clean_ing == "" or clean_ing == "beer":
			continue
		if clean_ing == "blood":
			if stats.has_method("has_unlock") and not stats.has_unlock("Ingredients", "Blood"):
				return false
			continue
		if "unlocks" in stats and stats.unlocks.has("Drinks"):
			var drinks_dict: Dictionary = stats.unlocks["Drinks"]
			var found_drink := false
			var is_unlocked := false
			for d in drinks_dict.keys():
				if str(d).to_lower().strip_edges() == clean_ing:
					found_drink = true
					is_unlocked = bool(drinks_dict[d])
					break
			if found_drink and not is_unlocked:
				return false

	for tag in recipe.processing:
		var clean_tag := str(tag).to_lower().strip_edges()
		if clean_tag == "spectral" and stats.has_method("has_knife_unlock"):
			if not stats.has_knife_unlock(true):
				return false

	if "unlocks" in stats and stats.unlocks.has("Ingredients"):
		var ing_dict: Dictionary = stats.unlocks["Ingredients"]
		for g in recipe.garnishes:
			var clean_g := str(g).to_lower().strip_edges()
			for k in ing_dict.keys():
				if str(k).to_lower().strip_edges() == clean_g and not bool(ing_dict[k]):
					return false

	return true

static func get_available_recipes(stats: Node = null, _species_id: String = "") -> Array[DrinkRecipe]:
	ensure_loaded()
	var available: Array[DrinkRecipe] = []
	for recipe in _ordered_recipes:
		if is_recipe_unlocked(recipe, stats):
			available.append(recipe)
	if available.is_empty():
		available.assign(_ordered_recipes)
	return available

static func recipe_matches_ingredients(recipe: DrinkRecipe, required_ingredients: Array[String]) -> bool:
	if recipe == null:
		return false
	for req_ing in required_ingredients:
		var clean_req := str(req_ing).to_lower().strip_edges()
		if clean_req == "":
			continue
		if not recipe.ingredients.has(clean_req) or float(recipe.ingredients[clean_req]) <= 0.0:
			return false
	return true

static func get_matching_recipes(required_ingredients: Array[String], stats: Node = null, include_locked_fallback: bool = false) -> Array[DrinkRecipe]:
	ensure_loaded()
	var pool := get_available_recipes(stats)
	if required_ingredients.is_empty():
		return pool

	var matches: Array[DrinkRecipe] = []
	for recipe in pool:
		if recipe_matches_ingredients(recipe, required_ingredients):
			matches.append(recipe)

	if matches.is_empty() and include_locked_fallback:
		for recipe in _ordered_recipes:
			if recipe_matches_ingredients(recipe, required_ingredients):
				matches.append(recipe)

	return matches

static func pick_random_recipe(stats: Node = null, species_id: String = "") -> DrinkRecipe:
	if species_id.strip_edges() != "":
		var sp := SpeciesRegistry.get_species(species_id)
		if sp:
			return sp.pick_recipe_for_order(stats)

	var pool := get_available_recipes(stats, species_id)
	if pool.is_empty():
		return null
	return pool.pick_random() as DrinkRecipe

static func roll_ice_preference(base_preference: int = DrinkRecipe.IcePreference.DONT_CARE) -> int:
	if base_preference != DrinkRecipe.IcePreference.DONT_CARE:
		return base_preference
	return DrinkRecipe.IcePreference.REQUIRED if randf() < 0.5 else DrinkRecipe.IcePreference.FORBIDDEN

static func create_order_from_recipe(recipe: DrinkRecipe, species_id: String = "", roll_ice: bool = true) -> DrinkOrder:
	if recipe == null:
		return DrinkOrder.new()
	var order := DrinkOrder.from_recipe(recipe)
	order.species_id = species_id
	order.accepted_garnishes = recipe.accepted_garnishes.duplicate()
	if roll_ice:
		order.ice_preference = roll_ice_preference(recipe.ice_preference)
	return order