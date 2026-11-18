# Backward-compatible for species preferences and gimmicks to SpeciesRegistry
class_name CustomerTraits
extends RefCounted

# determines how many drinks a customer will order in sequence
static func get_order_count(species: String, modifier: CustomerModifier) -> int:
	var sp := SpeciesRegistry.get_species_or_default(species)
	if sp:
		return sp.get_order_count(null, modifier)
	if modifier and modifier.is_wanted:
		return randi_range(2, 3)
	return 1

# filters available drink options based on species quirks
static func get_species_drink_pool(species: String) -> Array[String]:
	var sp := SpeciesRegistry.get_species_or_default(species)
	if sp:
		return sp.get_drink_pool(PlayerStats)
	return ["beer", "gin"]

# splits a slime customer into two patrons when hit with the knife tool
static func try_slice_slime(npc: Base_NPC, _main_node: Node3D = null) -> bool:
	if not is_instance_valid(npc):
		return false
	var sp: SpeciesBase = npc.species_def if npc.species_def else SpeciesRegistry.get_species(npc.npc_resource.race if npc.npc_resource else "")
	if sp:
		return sp.on_npc_tool_click(npc, "knife", GameState.player)
	return false