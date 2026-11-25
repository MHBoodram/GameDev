class_name DrinkMix
extends RefCounted

# handles the actual contents of a cup

var layers: Array = []
var ingredients: Dictionary = {} # name -> amount (float)
var garnishes: Array[String] = []
var processing_tags: Array[String] = [] # ex. "shaken", "spectral"
var glass_type: String = ""
var is_tiny: bool = false
var overfill_percent: float = 0.0
var max_garnishes = 2
var has_ice = false

func reset() -> void:
	layers.clear()
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

func add_layer(id: String, amount: float, color: Color = Color.WHITE) -> void:
	if amount <= 0.0:
		return
	add_liquid(id, amount)
	if not layers.is_empty():
		var top_drink = layers[layers.size() - 1]
		if top_drink is Array and top_drink.size() >= 2 and top_drink[0] is String and top_drink[0] == id:
			top_drink[1] = float(top_drink[1]) + amount
			if top_drink.size() > 3 and top_drink[3] is Dictionary:
				top_drink[3][id] = top_drink[1]
			return
	layers.push_back([id, amount, color, {id: amount}])

func _subtract_liquid(id: String, amount: float) -> void:
	if amount <= 0.0 or not ingredients.has(id):
		return
	var updated := float(ingredients[id]) - amount
	if updated <= 0.0001:
		ingredients.erase(id)
	else:
		ingredients[id] = updated

func get_top_buoyant_layer_index() -> int:
	if layers.is_empty():
		return -1
	var best_idx: int = -1
	var best_buoyancy: float = -INF
	for i in layers.size():
		var layer = layers[i]
		if not (layer is Array) or layer.size() < 2:
			continue
		if float(layer[1]) <= 0.0001:
			continue
		var buoy := LiquidProperties.get_layer_buoyancy(layer)
		if buoy >= best_buoyancy:
			best_buoyancy = buoy
			best_idx = i
	return best_idx

func drain_top(amount: float) -> float:
	if amount <= 0.0 or layers.is_empty():
		return 0.0

	for i in range(layers.size() - 1, -1, -1):
		var l = layers[i]
		if not (l is Array) or l.size() < 2 or float(l[1]) <= 0.0001:
			layers.remove_at(i)

	if layers.is_empty():
		return 0.0

	var remaining_to_remove := amount
	var total_removed := 0.0

	while remaining_to_remove > 0.0001 and not layers.is_empty():
		var top_idx := get_top_buoyant_layer_index()
		if top_idx == -1:
			layers.clear()
			break

		var top_layer = layers[top_idx]
		var layer_amt := float(top_layer[1])
		var remove_amt := minf(remaining_to_remove, layer_amt)
		var keep_ratio := clampf((layer_amt - remove_amt) / layer_amt, 0.0, 1.0)
		top_layer[1] = layer_amt - remove_amt

		if top_layer.size() > 3 and top_layer[3] is Dictionary and not (top_layer[3] as Dictionary).is_empty():
			var ing_dict: Dictionary = top_layer[3]
			for ing_key in ing_dict.keys():
				var prev_ing := float(ing_dict[ing_key])
				var new_ing := prev_ing * keep_ratio
				ing_dict[ing_key] = new_ing
				_subtract_liquid(str(ing_key), prev_ing - new_ing)
		elif top_layer[0] is Array:
			var ing_arr: Array = top_layer[0]
			var per_ing_remove := remove_amt / maxf(float(ing_arr.size()), 1.0)
			for ing_key in ing_arr:
				_subtract_liquid(str(ing_key), per_ing_remove)
		elif top_layer[0] is Dictionary:
			var ing_dict: Dictionary = top_layer[0]
			for ing_key in ing_dict.keys():
				var prev_ing := float(ing_dict[ing_key])
				var new_ing := prev_ing * keep_ratio
				ing_dict[ing_key] = new_ing
				_subtract_liquid(str(ing_key), prev_ing - new_ing)
		else:
			_subtract_liquid(str(top_layer[0]), remove_amt)

		if float(top_layer[1]) <= 0.001:
			layers.remove_at(top_idx)

		remaining_to_remove -= remove_amt
		total_removed += remove_amt

	var leftover_total: float = 0.0
	for l in layers:
		if l is Array and l.size() >= 2:
			leftover_total += float(l[1])
	if leftover_total <= 0.001:
		layers.clear()
		ingredients.clear()

	return total_removed

func _resolve_ingredient_color(id: String, color_map: Dictionary) -> Color:
	if not color_map.is_empty() and color_map != LiquidProperties.LIQUID_COLOR and color_map.has(id):
		return color_map[id]
	return LiquidProperties.get_liquid_color(id)

func mix_all(average_color_fn: Callable = Callable(), color_map: Dictionary = {}) -> bool:
	if get_unique_ingredient_ids().size() < 2 or layers.is_empty():
		return false

	var combined_amounts: Dictionary = {}
	var color_weights: Array = []
	var total_amount: float = 0.0

	for layer in layers:
		if not (layer is Array) or layer.size() < 2:
			continue
		var layer_amt := float(layer[1])
		if layer_amt <= 0.0:
			continue
		total_amount += layer_amt
		if layer.size() > 3 and layer[3] is Dictionary:
			for ing in layer[3]:
				var a := float(layer[3][ing])
				combined_amounts[str(ing)] = combined_amounts.get(str(ing), 0.0) + a
				color_weights.append([_resolve_ingredient_color(str(ing), color_map), a])
		elif layer[0] is Array:
			var split_a := layer_amt / maxf(float(layer[0].size()), 1.0)
			for ing in layer[0]:
				var s := str(ing)
				combined_amounts[s] = combined_amounts.get(s, 0.0) + split_a
				color_weights.append([_resolve_ingredient_color(s, color_map), split_a])
		else:
			var s := str(layer[0])
			combined_amounts[s] = combined_amounts.get(s, 0.0) + layer_amt
			color_weights.append([_resolve_ingredient_color(s, color_map), layer_amt])

	var mixed_color: Color = average_color_fn.call(color_weights) if average_color_fn.is_valid() else Color.WHITE
	var mixed_names: Array[String] = []
	for k in combined_amounts.keys():
		mixed_names.append(str(k))
	mixed_names.sort()

	layers.clear()
	layers.push_back([mixed_names, total_amount, mixed_color, combined_amounts])
	add_processing("shaken")
	return true

func is_mixed() -> bool:
	if layers.size() != 1:
		return false
	var layer0 = layers[0]
	return layer0 is Array and layer0.size() > 0 and (layer0[0] is Array or layer0[0] is Dictionary) and layer0[0].size() >= 2

func can_be_shaken() -> bool:
	if layers.is_empty():
		return false
	if get_unique_ingredient_ids().size() < 2:
		return false
	return not is_mixed()

func to_legacy_layers() -> Array:
	var current_total: float = 0.0
	for layer in layers:
		if layer is Array and layer.size() >= 2:
			current_total += float(layer[1])
	if current_total <= 0.0:
		return []

	var scale_to_prop := 1.0 / current_total
	var normalized: Array = []
	for layer in layers:
		if not (layer is Array and layer.size() >= 2):
			continue
		var new_layer: Array = layer.duplicate()
		new_layer[1] = float(layer[1]) * scale_to_prop
		if new_layer.size() > 3 and new_layer[3] is Dictionary:
			var new_dict: Dictionary = {}
			for k in new_layer[3]:
				new_dict[k] = float(new_layer[3][k]) * scale_to_prop
			new_layer[3] = new_dict
		elif new_layer[0] is Dictionary:
			var new_dict: Dictionary = {}
			for k in new_layer[0]:
				new_dict[k] = float(new_layer[0][k]) * scale_to_prop
			new_layer[0] = new_dict
		normalized.append(new_layer)
	return normalized

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
static func from_legacy_layers(legacy_layers: Array) -> DrinkMix:
	var mix := DrinkMix.new()
	if legacy_layers.is_empty():
		return mix

	for layer in legacy_layers:
		if not (layer is Array) or layer.size() < 2:
			continue

		if layer.size() > 3 and layer[3] is Dictionary:
			for ing in layer[3]:
				var amt = float(layer[3][ing])
				mix.add_liquid(str(ing), amt)
		elif layer[0] is Array:
			var split_amt = float(layer[1]) / maxf(float(layer[0].size()), 1.0)
			for ing in layer[0]:
				mix.add_liquid(str(ing), split_amt)
			mix.add_processing("shaken")
		elif layer[0] is Dictionary:
			for ing in layer[0]:
				var amt = float(layer[0][ing])
				mix.add_liquid(str(ing), amt)
		else:
			var ing_name = str(layer[0])
			var amt = float(layer[1])
			mix.add_liquid(ing_name, amt)

	return mix
