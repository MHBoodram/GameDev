extends Node

signal money_changed(new_value: float, delta: float)
signal overall_reputation_changed(new_value: float, delta: float)
signal species_reputation_changed(species_name: String, new_value: float, delta: float)

const MIN_INGREDIENT_UNLOCK_NIGHT: int = 3

const INGREDIENT_UNLOCK_NIGHTS := {
	"Hand": 1,
	"Knife": 2,
	"Blood": 2,
	"Garnishes": 3,
	"Ice": 3,
}

const INGREDIENT_BASE_COST: int = 40
const INGREDIENT_COST_OVERRIDES := {}
const INGREDIENT_COST_PER_NIGHT_ADD: float = 0.0
const INGREDIENT_COST_PER_NIGHT_MULT: float = 1.25

var previous_money : float = 0
var money : float = 500
var overall_reputation : float = 0.0
var reputation_species : Dictionary = {}
var night_species_delta : Dictionary = {}
var overall_marketing : float = 1.0
var species_marketing : Dictionary = {}
var species_banners : Dictionary = {}

var unlocks : Dictionary = {
	"Drinks" :{
		"gin" : true,
		"rum" : false,
		"vodka" : false,
		"spirit" : false,
		"tequila" : false,
		"whiskey" : false,
	},
	"Ingredients":{
		"Knife" : false,
		"Blood" : false,
		"Fishing_Rod" : false,
		"Mag" : false,
		"Garnishes" : false,
		"Ice" : false
	},
	"Tools":{
		"Hand" : true,
		"Knife" : false,
		"Mag" : false,
		"Fishing_Rod" : false
	},
	"Upgrades":{},
	"Recipes":{
		"BLOODY MARY" : false,
		"Classic Mojito" : false,
	}
}

var unlock_passive: Dictionary = {}



func _ready() -> void:
	sync_species_registry()
	sync_upgrade_registry()

func sync_species_registry() -> void:
	for sp in SpeciesRegistry.get_all_species():
		_ensure_species_entry(sp.display_name, sp.default_marketing_weight)

func sync_upgrade_registry() -> void:
	UpgradeRegistry.sync_with_player_stats(self)

func get_all_upgrades() -> Array[UpgradeDef]:
	return UpgradeRegistry.get_all_upgrades()

func get_upgrade_level(upgrade_id: String) -> int:
	return UpgradeRegistry.get_level(upgrade_id, self)

func unlock_upgrade(upgrade_id: String, levels: int = 1) -> bool:
	return UpgradeRegistry.unlock_upgrade(upgrade_id, self, levels)

func unlock_all_upgrades() -> void:
	sync_species_registry()
	UpgradeRegistry.unlock_all_upgrades(self)

func _ensure_species_entry(key: String, default_marketing: float = 0.0) -> void:
	if not reputation_species.has(key):
		reputation_species[key] = 0.0
	if not night_species_delta.has(key):
		night_species_delta[key] = 0.0
	if not species_marketing.has(key):
		species_marketing[key] = default_marketing
	if not species_banners.has(key):
		species_banners[key] = 0

func has_unlock(category: String, key: String) -> bool:
	if not unlocks.has(category):
		return false
	var cat_dict: Dictionary = unlocks[category]
	if cat_dict.has(key):
		return bool(cat_dict[key])
	var target_lower := key.to_lower()
	for k in cat_dict.keys():
		if str(k).to_lower() == target_lower:
			return bool(cat_dict[k])
	return false

func is_tool_ingredient(item_id: String) -> bool:
	var target_lower := item_id.to_lower().strip_edges()
	if target_lower == "knife" or target_lower == "mag" or target_lower == "fishing_rod" or target_lower == "hand":
		return true
	if unlocks.has("Tools"):
		for k in unlocks["Tools"].keys():
			if str(k).to_lower().strip_edges() == target_lower:
				return true
	return false

func get_ingredient_unlock_night(item_id: String) -> int:
	var target_lower := item_id.to_lower().strip_edges()
	for k in INGREDIENT_UNLOCK_NIGHTS.keys():
		if str(k).to_lower().strip_edges() == target_lower:
			return int(INGREDIENT_UNLOCK_NIGHTS[k])
	if is_tool_ingredient(item_id):
		return 0
	return MIN_INGREDIENT_UNLOCK_NIGHT

func can_offer_ingredient_free_pick(item_id: String, night_number: int) -> bool:
	var target_lower := item_id.to_lower().strip_edges()
	if night_number == 1:
		return target_lower == "knife"
	if is_tool_ingredient(item_id):
		return true
	if target_lower == "garnishes" or target_lower == "ice":
		return night_number >= MIN_INGREDIENT_UNLOCK_NIGHT
	return true

func can_buy_ingredient_in_shop(item_id: String, night_number: int) -> bool:
	var target_lower := item_id.to_lower().strip_edges()
	if night_number == 1:
		return target_lower == "knife"
	if is_tool_ingredient(item_id):
		return true
	if target_lower == "garnishes" or target_lower == "ice":
		return night_number >= MIN_INGREDIENT_UNLOCK_NIGHT
	return true

func get_ingredient_shop_cost(item_id: String, night_number: int) -> int:
	var base_cost := INGREDIENT_BASE_COST
	var target_lower := item_id.to_lower().strip_edges()
	for k in INGREDIENT_COST_OVERRIDES.keys():
		if str(k).to_lower().strip_edges() == target_lower:
			base_cost = int(INGREDIENT_COST_OVERRIDES[k])
			break
	var night_idx := float(maxi(0, night_number - 1))
	var cost := (float(base_cost) + INGREDIENT_COST_PER_NIGHT_ADD * night_idx) * pow(maxf(INGREDIENT_COST_PER_NIGHT_MULT, 0.01), night_idx)
	return maxi(1, roundi(cost))

func has_knife_unlock(fallback_when_missing: bool = true) -> bool:
	if unlocks.has("Ingredients") and unlocks["Ingredients"].has("Knife"):
		return has_unlock("Ingredients", "Knife")
	if unlocks.has("Tools") and unlocks["Tools"].has("Knife"):
		return has_unlock("Tools", "Knife")
	return fallback_when_missing

func is_tool_unlocked(tool_id: String) -> bool:
	var clean_id := tool_id.to_lower().strip_edges()
	if clean_id == "" or clean_id == "hand":
		return true
	return has_unlock("Tools", clean_id) or has_unlock("Ingredients", clean_id)

func unlock_tool(tool_id: String) -> void:
	var clean_id := tool_id.to_lower().strip_edges()
	if clean_id == "":
		return
	if not unlocks.has("Tools"):
		unlocks["Tools"] = {}
	var tools_dict: Dictionary = unlocks["Tools"]
	var matched_key := ""
	for k in tools_dict.keys():
		if str(k).to_lower() == clean_id:
			matched_key = str(k)
			break
	if matched_key == "":
		matched_key = tool_id
	tools_dict[matched_key] = true

	if unlocks.has("Ingredients"):
		var ing_dict: Dictionary = unlocks["Ingredients"]
		for k in ing_dict.keys():
			if str(k).to_lower() == clean_id:
				var was_unlocked := bool(ing_dict[k])
				ing_dict[k] = true
				if not was_unlocked:
					SpeciesRegistry.on_ingredient_unlocked(str(k), self)
		if clean_id == "knife" and ing_dict.has("Blood"):
			var had_blood := bool(ing_dict["Blood"])
			ing_dict["Blood"] = true
			if not had_blood:
				SpeciesRegistry.on_ingredient_unlocked("Blood", self)

func reset_tool_unlocks() -> void:
	if unlocks.has("Tools"):
		for k in unlocks["Tools"].keys():
			unlocks["Tools"][k] = (str(k).to_lower() == "hand")
	if unlocks.has("Ingredients"):
		for tool_key in ["Knife", "Mag", "Fishing_Rod"]:
			for k in unlocks["Ingredients"].keys():
				if str(k).to_lower() == tool_key.to_lower():
					unlocks["Ingredients"][k] = false

func set_species_marketing(species: String, value: float) -> void:
	var key := _find_species_key(species)
	species_marketing[key] = value

func _change_money(new_value: float) -> void:
	var old_money: float = money
	var delta: float = new_value - old_money
	money = new_value
	print("[money]: ", money)
	if GameState.gameplay_ui:
		GameState.gameplay_ui._change_money(new_value)
	if not is_zero_approx(delta):
		money_changed.emit(money, delta)

func _find_species_key(species: String) -> String:
	var sp := SpeciesRegistry.get_species(species)
	if sp:
		_ensure_species_entry(sp.display_name, sp.default_marketing_weight)
		return sp.display_name
	for key: String in reputation_species.keys():
		if key.to_lower() == species.to_lower():
			return key
	var fallback_sp := SpeciesRegistry.get_species_or_default("")
	if fallback_sp:
		_ensure_species_entry(fallback_sp.display_name, fallback_sp.default_marketing_weight)
		return fallback_sp.display_name
	return "Human"

func add_overall_reputation(amount: float) -> void:
	var old_rep: float = overall_reputation
	if amount > 0.0:
		overall_reputation += amount
	var applied_delta: float = overall_reputation - old_rep
	print("[overall_reputation]: ", overall_reputation)
	if not is_zero_approx(applied_delta):
		overall_reputation_changed.emit(overall_reputation, applied_delta)

func change_overall_reputation(delta: float) -> void:
	var old_rep: float = overall_reputation
	var updated_rep: float = maxf(0.0, old_rep + delta)
	var applied_delta: float = updated_rep - old_rep
	overall_reputation = updated_rep
	print("[overall_reputation]: ", overall_reputation)
	var display_delta: float = applied_delta if not is_zero_approx(applied_delta) else delta
	if not is_zero_approx(display_delta):
		overall_reputation_changed.emit(overall_reputation, display_delta)

func get_species_reputation(species: String) -> float:
	var key: String = _find_species_key(species)
	return reputation_species[key]

func change_species_reputation(species: String, delta: float) -> void:
	var key: String = _find_species_key(species)
	var current_rep: float = reputation_species[key]
	var updated_rep: float = maxf(0.0, current_rep + delta)
	var applied_delta: float = updated_rep - current_rep
	reputation_species[key] = updated_rep
	night_species_delta[key] += applied_delta
	print("[species_reputation]: ", reputation_species[key])
	print("[night_species_delta]: ", night_species_delta[key])
	var display_delta: float = applied_delta if not is_zero_approx(applied_delta) else delta
	if not is_zero_approx(display_delta):
		species_reputation_changed.emit(key, updated_rep, display_delta)

# Returns species with largest reputation gain during current night
func get_highest_gaining_species() -> String:
	sync_species_registry()
	var default_sp := SpeciesRegistry.get_species_or_default("")
	var highest_species: String = default_sp.display_name if default_sp else "Human"
	var highest_gain: float = -INF
	for species_key: String in night_species_delta.keys():
		var gain: float = night_species_delta[species_key]
		if gain > highest_gain:
			highest_gain = gain
			highest_species = species_key
	return highest_species

func reset_night_reputation_gains() -> void:
	for species_key: String in night_species_delta.keys():
		night_species_delta[species_key] = 0.0

func get_spawn_rate() -> float:
	var rate: float = 1.0 * overall_marketing
	return rate

func get_species_spawn_weight(species: String) -> float:
	var sp := SpeciesRegistry.get_species(species)
	var key: String = sp.display_name if sp else _find_species_key(species)
	if sp:
		_ensure_species_entry(sp.display_name, sp.default_marketing_weight)
	var base_weight: float = sp.base_spawn_weight if sp else 5.0

	var marketing_multiplier: float = float(species_marketing.get(key, 1.0))
	var banner_val: Variant = species_banners.get(key, 0)
	var banner_level: int = 0
	if banner_val is bool:
		banner_level = 1 if (banner_val as bool) else 0
	elif banner_val is int or banner_val is float:
		banner_level = int(banner_val)

	var banner_step: float = 1.0
	var banner_upgrade_id := key + " Banner"
	if UpgradeRegistry.get_upgrade(banner_upgrade_id) != null:
		banner_step = UpgradeRegistry.get_effect_step(banner_upgrade_id, 1.0)

	var banner_multiplier: float = 1.0 + float(banner_level) * banner_step
	var final_weight: float = base_weight * marketing_multiplier * banner_multiplier
	print("[species_weight]: ", key, " = ", final_weight)
	return final_weight

func _check_upgrades(id: String, type: String):
	if type == "Upgrades":
		return has_unlock("Upgrades", id)
	return unlocks[type][id]