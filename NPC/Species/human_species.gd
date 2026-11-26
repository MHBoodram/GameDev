class_name HumanSpecies
extends SpeciesBase

const LIKED_DRINKS: Dictionary = {
	"cherry_bomb": 0.5,
}
const REQUIRED_INGREDIENTS: Array[String] = []

func _init() -> void:
	species_id = "HUMAN"
	display_name = "Human"
	sort_order = 1
	logo_frame = 10
	npc_resource_path = "res://NPC/Resources/scott.tres"
	fallback_texture_path = "res://Assets/NPC/Human/Scott-Sheet.png"
	fallback_hframes = 10
	base_spawn_weight = 5.0
	default_marketing_weight = 1.0
	spawn_randomly = true
	can_be_ghost = true