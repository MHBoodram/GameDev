extends Node

var previous_money : float
var money : float = 500
var overall_reputation : float = 0.0
var reputation_species : Dictionary = {
	"Slime" : 0.0,
	"Human" : 0.0,
	"Vampire" : 0.0,
	"Fish" : 0.0,
	"Tiny" : 0.0,
}
var night_species_delta : Dictionary = {
	"Slime" : 0.0,
	"Human" : 0.0,
	"Vampire" : 0.0,
	"Fish" : 0.0,
	"Tiny" : 0.0,
}

var upgrades : Dictionary = {
	"Drinks":
		{
			
		},
	"Ingredients":
		{
			
		},
	"Tools":
		{
			
		}
}

var overall_marketing : float = 1.0
var species_marketing : Dictionary = {
	"Human": 1.0,
	"Slime": 1.0,
}
var species_banners : Dictionary = {
	"Human": false,
	"Slime": false,
}

var unlocks : Dictionary = {
	"Drinks" :{
		"gin" : true,
		"rum" : false,
		"vodka" : false,
		"spirit" : false
	},
	"Ingredients":{
		"Blood" : false,
	},
	"Tools":{
		"Knife" : false,
		"Fishing_Rod" : false
	}
}

func _change_money(new_value: float) -> void:
	money = new_value
	print("[money]: ", money)
	if GameState.gameplay_ui:
		GameState.gameplay_ui._change_money(new_value)

func _find_species_key(species: String) -> String:
	for key: String in reputation_species.keys():
		if key.to_lower() == species.to_lower():
			return key
	return "Human"

func add_overall_reputation(amount: float) -> void:
	if amount > 0.0:
		overall_reputation += amount
	print("[overall_reputation]: ", overall_reputation)

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

# Returns species with largest reputation gain during current night
func get_highest_gaining_species() -> String:
	var highest_species: String = "Human"
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
	print("[spawn_rate]: ", rate)
	return rate

func get_species_spawn_weight(species: String) -> float:
	var key: String = _find_species_key(species)
	var base_weight: float = 10.0
	match key:
		"Slime":
			base_weight = 2.0
		_:
			base_weight = 10.0
	var marketing_multiplier: float = species_marketing.get(key, 1.0)
	var banner_multiplier: float = 2.0 if species_banners.get(key, false) else 1.0
	var final_weight: float = base_weight * marketing_multiplier * banner_multiplier
	print("[species_weight]: ", key, " = ", final_weight)
	return final_weight

func _check_upgrades() -> void:
	pass 
