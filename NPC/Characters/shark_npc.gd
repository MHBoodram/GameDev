class_name SharkNPC
extends NPCCharacterBase

func _init() -> void:
	npc_id = "shark"
	display_name = "Shark"
	species_id = "HUMAN"
	sort_order = 10
	is_named = true
	can_spawn_randomly = false
	can_be_ghost = false
	disallowed_modifiers = ["GHOST"]

	npc_resource_path = "res://NPC/Resources/shark.tres"
	sprite_sheet_path = "res://Assets/NPC/Human/Loan-Sheet.png"
	hframes = 6
	dialogue_path = "res://NPC/Dialogue/shark.dialogue"
	patience_time = 180.0

	waiting_title = "introduction_mid_talk"
	positive_title = "introduction_mid_good"
	mid_title = "introduction_mid_mid"
	negative_title = "introduction_mid_bad"
	afternight_title = "afternight_1"

	expressions = {
		"netural": 0,
		"neutral": 0,
		"happy": 2,
		"mad": 4
	}

	add_appearance(NightPhase.BEFORE_NIGHT, 1, "tutorial_walk", 0.0, {
		"patience": 180.0,
		"can_talk": false,
		"start_tutorial": true,
		"blocks_shift_start": true,
		"waiting_title": "introduction_mid_talk",
		"positive_title": "introduction_mid_good",
		"mid_title": "introduction_mid_mid",
		"negative_title": "introduction_mid_bad"
	})

	add_appearance(NightPhase.BEFORE_NIGHT, 2, "night_2_introduction", 0.0, {
		"patience": 180.0,
		"blocks_shift_start": true,
		"waiting_title": "introduction_mid_talk",
		"positive_title": "introduction_mid_good",
		"mid_title": "introduction_mid_mid",
		"negative_title": "introduction_mid_bad"
	})

	add_appearance(NightPhase.AFTER_NIGHT, -1, "afternight_1", 0.0, {
		"role": "visitor",
		"priority": -10,
		"sort_order": 100
	})