class_name SlimeNPC
extends NPCCharacterBase

func _init() -> void:
	npc_id = "slime"
	display_name = "Slime"
	species_id = "SLIME"
	sort_order = 3
	is_named = false
	is_default_for_species = true
	can_spawn_randomly = true
	spawn_weight = 1.0

	can_be_ghost = false
	disallowed_modifiers = ["GHOST"]

	npc_resource_path = "res://NPC/Resources/slime.tres"
	sprite_sheet_path = "res://Assets/NPC/Slime/slime1.png"
	hframes = 1
	dialogue_path = "res://NPC/Dialogue/Slime.dialogue"
	patience_time = 90.0

	expressions = {
		"netural": {"frame": 0, "mouth_offset": 0},
		"neutral": {"frame": 0, "mouth_offset": 0},
		"happy": {"frame": 0, "mouth_offset": 0},
		"mad": {"frame": 0, "mouth_offset": 0}
	}