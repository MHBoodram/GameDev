# Defines species-specific order sizes and drink preferences
# Species gimmicks ex. Slime slicing via GameState.seat_manager
class_name CustomerTraits
extends RefCounted

# determines how many drinks a customer will order in sequence
static func get_order_count(species: String, modifier: CustomerModifier) -> int:
	if modifier and modifier.is_wanted:
		return randi_range(2, 3)

	match species.to_upper():
		"SLIME":
			return randi_range(1, 3)
		"FISH":
			return randi_range(1, 2)
		_:
			return 1

# filters available drink options based on species quirks
static func get_species_drink_pool(species: String) -> Array[String]:
	var pool: Array[String] = ["beer", "gin"]
	if PlayerStats.unlocks.has("Drinks"):
		for d in PlayerStats["unlocks"]["Drinks"]:
			if PlayerStats["unlocks"]["Drinks"][d] and not pool.has(d):
				pool.append(d)

	var s := species.to_upper()
	if s == "VAMPIRE" and PlayerStats.unlocks.has("Ingredients") and PlayerStats["unlocks"]["Ingredients"].get("Blood", false):
		if not pool.has("blood"):
			pool.append("blood")

	return pool

# splits a slime customer into two patrons when hit with the knife tool
static func try_slice_slime(npc: Base_NPC, _main_node: Node3D = null) -> bool:
	if not is_instance_valid(npc) or npc.npc_resource == null:
		return false
	if npc.npc_resource.race.to_upper() != "SLIME" or npc.is_leaving:
		return false
	if not GameState.seat_manager:
		return false

	GameState.play_sfx("play_stab")
	GameState.seat_manager.spawn_specific_species("Slime")
	return true