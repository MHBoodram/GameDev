class_name VampireSpecies
extends SpeciesBase

const LIKED_DRINKS: Dictionary = {}
const REQUIRED_INGREDIENTS: Array[String] = [
	"blood",
]

func _init() -> void:
	species_id = "VAMPIRE"
	display_name = "Vampire"
	sort_order = 2
	logo_frame = 9
	npc_resource_path = "res://NPC/Resources/cesti.tres"
	fallback_texture_path = "res://Assets/NPC/Vampire/Cesti-Sheet.png"
	fallback_hframes = 10
	base_spawn_weight = 2.0
	default_marketing_weight = 1.0
	spawn_randomly = true
	can_be_ghost = false
	disallowed_modifiers = ["GHOST"]

func is_unlocked(stats: Node = null) -> bool:
	if stats == null:
		return false
	if stats.has_method("has_unlock") and not stats.has_unlock("Ingredients", "Blood"):
		return false
	if stats.has_method("has_knife_unlock"):
		return stats.has_knife_unlock(true)
	return true

func on_ingredient_unlocked(ingredient_key: String, stats: Node = null) -> void:
	if stats == null:
		return
	var lower := ingredient_key.to_lower().strip_edges()
	if lower == "blood" or lower == "knife":
		if stats.has_method("set_species_marketing"):
			stats.set_species_marketing(display_name, 1.0)

func get_drink_pool(stats: Node = null) -> Array[String]:
	var pool := super.get_drink_pool(stats)
	if stats and stats.has_method("has_unlock") and stats.has_unlock("Ingredients", "Blood"):
		if not pool.has("blood"):
			pool.append("blood")
	return pool

func on_tool_counter_action(tool_id: String, player: Node3D, main_node: Node3D) -> bool:
	if tool_id != "knife":
		return false
	if player == null or ("in_game" in player and player.in_game):
		return false
	if GameState.minigame_host:
		var host_node: Node = main_node if is_instance_valid(main_node) else GameState.main_node
		GameState.minigame_host.start_blood_minigame(host_node, player)
		return true
	return false