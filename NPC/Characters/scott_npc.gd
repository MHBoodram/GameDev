class_name ScottNPC
extends NPCCharacterBase

func _init() -> void:
	npc_id = "scott"
	display_name = "Scott"
	species_id = "HUMAN"
	sort_order = 1
	is_named = true
	is_default_for_species = true
	can_spawn_randomly = true
	spawn_weight = 1.0

	npc_resource_path = "res://NPC/Resources/scott.tres"
	sprite_sheet_path = "res://Assets/NPC/Human/Scott-Sheet.png"
	hframes = 10
	dialogue_path = "res://NPC/Dialogue/Scott.dialogue"
	patience_time = 90.0

	expressions = {
		"netural": 0,
		"neutral": 0,
		"happy": 2,
		"mad": 4,
		"surprised": 6,
		"alt": 8
	}