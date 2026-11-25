class_name VampireSpecies
extends SpeciesBase

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
	if stats.has_method("has_unlock"):
		if "unlocks" in stats and stats.unlocks.has("Ingredients") and stats.unlocks["Ingredients"].has("Knife"):
			return stats.has_unlock("Ingredients", "Knife")
		if "unlocks" in stats and stats.unlocks.has("Tools") and stats.unlocks["Tools"].has("Knife"):
			return stats.has_unlock("Tools", "Knife")
		return stats.has_unlock("Ingredients", "Blood")
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

func generate_orders(npc: Sprite3D, modifier: RefCounted = null, stats: Node = null) -> Array[DrinkOrder]:
	var orders: Array[DrinkOrder] = []
	var pool := get_drink_pool(stats)
	var non_blood_pool: Array[String] = []
	for candidate in pool:
		if candidate != "blood":
			non_blood_pool.append(candidate)

	var count := maxi(1, get_order_count(npc, modifier))
	if modifier and modifier.has_method("modify_order_count"):
		count = maxi(1, int(modifier.modify_order_count(npc, count)))
	for i in range(count):
		var order := DrinkOrder.new()
		order.species_id = species_id
		# Vampires always order blood at least once, and may order other drinks afterwards
		if i == 0 or (pool.has("blood") and randf() < 0.5):
			if not non_blood_pool.is_empty():
				var second_drink := str(non_blood_pool.pick_random())
				order.ingredients["blood"] = 0.5
				order.ingredients[second_drink] = 0.5
				order.required_processing.append("shaken")
			else:
				order.ingredients["blood"] = 1.0
		else:
			var other_drink := str(non_blood_pool.pick_random()) if not non_blood_pool.is_empty() else str(pool.pick_random())
			order.ingredients[other_drink] = 1.0
		orders.append(order)
	return orders

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
