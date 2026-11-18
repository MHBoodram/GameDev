class_name SlimeSpecies
extends SpeciesBase

func _init() -> void:
	species_id = "SLIME"
	display_name = "Slime"
	sort_order = 3
	logo_frame = 7
	npc_resource_path = "res://NPC/Resources/slime.tres"
	fallback_texture_path = "res://Assets/NPC/Slime/slime1.png"
	fallback_hframes = 1
	base_spawn_weight = 2.0
	default_marketing_weight = 1.0
	spawn_randomly = true
	can_be_ghost = false

func is_unlocked(stats: Node = null) -> bool:
	# Appears rarely once another random-spawning species besides Human is unlocked
	for sp in SpeciesRegistry.get_all_species():
		if sp.species_id == species_id or sp.species_id == "HUMAN":
			continue
		if sp.spawn_randomly and sp.is_unlocked(stats):
			return true
	return false

func get_order_count(_npc: Sprite3D, modifier: RefCounted = null) -> int:
	if modifier and "is_wanted" in modifier and modifier.is_wanted:
		return randi_range(2, 3)
	return randi_range(1, 3)

func get_drink_pool(stats: Node = null) -> Array[String]:
	return super.get_drink_pool(stats)

func modify_payout(_npc: Sprite3D, base_price: float, is_satisfactory: bool, _drink_score: float, current_payment: float) -> float:
	if is_satisfactory:
		return current_payment + base_price
	return current_payment

func on_npc_tool_click(npc: Sprite3D, tool_id: String, _player: Node3D) -> bool:
	if tool_id != "knife":
		return false
	var target_sp: SpeciesBase = npc.get("species_def") as SpeciesBase if npc else null
	if target_sp == null or target_sp.species_id != species_id:
		return false
	if "is_leaving" in npc and npc.is_leaving:
		return true
	if not GameState.seat_manager:
		return false
	if GameState.seat_manager.get_empty_seat_count() <= 0:
		if npc.has_method("show_floating_feedback"):
			npc.show_floating_feedback("No empty seats!")
		return true

	GameState.play_sfx("play_stab")
	GameState.seat_manager.spawn_specific_species(display_name)
	return true