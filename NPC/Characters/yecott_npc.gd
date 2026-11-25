class_name YecottNPC
extends NPCCharacterBase

func _init() -> void:
	npc_id = "yecott"
	display_name = "Yecott"
	species_id = "HUMAN"
	sort_order = 20
	is_named = true
	can_spawn_randomly = false
	can_be_ghost = false
	disallowed_modifiers = ["GHOST"]

	npc_resource_path = "res://NPC/Resources/yecott.tres"
	sprite_sheet_path = "res://Assets/NPC/Human/Yecott-Sheet.png"
	dialogue_path = "res://NPC/Dialogue/yecott.dialogue"
	afternight_title = "afternight_1"

	expressions = {
		"netural": 0,
		"neutral": 0,
		"happy": 2,
		"mad": 4
	}

	add_appearance(NightPhase.AFTER_NIGHT, -1, "afternight_1", 0.0, {
		"role": "shopkeeper"
	})