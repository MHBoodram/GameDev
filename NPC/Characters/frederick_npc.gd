class_name FrederickNPC
extends NPCCharacterBase

func _init() -> void:
	npc_id = "frederick"
	display_name = "Frederick"
	species_id = "TINY"
	sort_order = 4
	is_named = true
	is_default_for_species = true
	can_spawn_randomly = false
	spawn_weight = 1.0

	can_be_ghost = false
	disallowed_modifiers = ["GHOST"]

	npc_resource_path = "res://NPC/Resources/frederick.tres"
	sprite_sheet_path = "res://Assets/NPC/Tiny/tiny.webp"
	hframes = 10
	npc_scale = Vector3(0.05, 0.05, 0.05)
	seat_offset = Vector3(0.0, -0.45, 0.35)
	patience_y_offset = 8.5
	logo_frame = 1
	dialogue_path = "res://NPC/Dialogue/Frederick.dialogue"
	patience_time = 90.0

	expressions = {
		"netural": 0,
		"neutral": 0,
		"happy": 2,
		"mad": 4
	}