class_name TinySpecies
extends SpeciesBase

func _init() -> void:
	species_id = "TINY"
	display_name = "Tiny"
	sort_order = 2
	logo_frame = 1
	npc_resource_path = "res://NPC/Resources/frederick.tres"
	fallback_texture_path = "res://Assets/NPC/Tiny/tiny.webp"
	fallback_hframes = 10
	base_spawn_weight = 2.0
	default_marketing_weight = 1.0
	spawn_randomly = true
	can_be_ghost = false
	disallowed_modifiers = ["GHOST"]

func is_unlocked(stats: Node = null) -> bool:
	if stats == null:
		return false
	if stats.has_method("has_unlock"):
		if "unlocks" in stats and stats.unlocks.has("Ingredients") and stats.unlocks["Ingredients"].has("Mag"):
			return stats.has_unlock("Ingredients", "Mag")
		if "unlocks" in stats and stats.unlocks.has("Tools") and stats.unlocks["Tools"].has("Mag"):
			return stats.has_unlock("Tools", "Mag")
	return true

func on_ingredient_unlocked(ingredient_key: String, stats: Node = null) -> void:
	if stats == null:
		return
	var lower := ingredient_key.to_lower().strip_edges()
	if lower == "mag":
		if stats.has_method("set_species_marketing"):
			stats.set_species_marketing(display_name, 1.0)

func get_drink_pool(stats: Node = null) -> Array[String]:
	return super.get_drink_pool(stats)

#func on_tool_counter_action(tool_id: String, player: Node3D, main_node: Node3D) -> bool:
	#if tool_id != "mag":
		#return false
	#if player == null or ("in_game" in player and player.in_game):
		#return false
	#if GameState.minigame_host:
		#var host_node: Node = main_node if is_instance_valid(main_node) else GameState.main_node
		#GameState.minigame_host.start_blood_minigame(host_node, player)
		#return true
	#return false
