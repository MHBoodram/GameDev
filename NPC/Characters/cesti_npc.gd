class_name CestiNPC
extends NPCCharacterBase

func _init() -> void:
	npc_id = "cesti"
	display_name = "Cesti"
	species_id = "VAMPIRE"
	sort_order = 2
	is_named = true
	is_default_for_species = true
	can_spawn_randomly = true
	spawn_weight = 1.0

	can_be_ghost = false
	disallowed_modifiers = ["GHOST"]

	npc_resource_path = "res://NPC/Resources/cesti.tres"
	sprite_sheet_path = "res://Assets/NPC/Vampire/Cesti-Sheet.png"
	hframes = 10
	dialogue_path = "res://NPC/Dialogue/cesti.dialogue"
	patience_time = 90.0

	expressions = {
		"netural": 0,
		"neutral": 0,
		"happy": 2,
		"mad": 4,
		"surprised": 6,
		"alt": 8
	}