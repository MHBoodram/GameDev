extends Node

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
	
}

var unlocks : Dictionary = {
	"Drinks" :{
		"Gin" : true,
		"Rum" : true,
		"Vodka" : true,
		"Spirit" : true
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