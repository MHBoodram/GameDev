class_name TinySpecies
extends SpeciesBase

const DIALOGUE_PATH := "res://NPC/Dialogue/Frederick.dialogue"
const IDEAL_FILL_RATIO := 0.25

func _init() -> void:
	species_id = "TINY"
	display_name = "Tiny"
	sort_order = 2
	logo_frame = 1
	npc_resource_path = "res://NPC/Resources/frederick.tres"
	fallback_texture_path = "res://Assets/NPC/Tiny/tiny.webp"
	fallback_hframes = 10
	npc_scale = Vector3(0.05, 0.05, 0.05)
	patience_scale = 0.7
	seat_offset = Vector3(0.0, -0.45, 0.35)
	patience_y_offset = 8.5
	base_spawn_weight = 2.0
	default_marketing_weight = 1.0
	spawn_randomly = false
	can_be_ghost = false
	disallowed_modifiers = ["GHOST"]

func get_npc_resource() -> NPC:
	var res := super.get_npc_resource()
	if res:
		if res.race.to_upper().strip_edges() != species_id:
			res = res.duplicate() as NPC
			res.race = species_id
		if res.dialogue_resource == null:
			if ResourceLoader.exists(DIALOGUE_PATH):
				res.dialogue_resource = load(DIALOGUE_PATH) as DialogueResource
			else:
				res.dialogue_resource = get_fallback_dialogue_resource_for_name("Frederick")
	return res

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

func generate_orders(npc: Sprite3D, modifier: RefCounted = null, _stats: Node = null) -> Array[DrinkOrder]:
	var orders: Array[DrinkOrder] = []
	var count := maxi(1, get_order_count(npc, modifier))
	if modifier and modifier.has_method("modify_order_count"):
		count = maxi(1, int(modifier.modify_order_count(npc, count)))
	for i in range(count):
		var order := DrinkOrder.new()
		order.species_id = species_id
		order.is_tiny = true
		order.ideal_fill_ratio = IDEAL_FILL_RATIO
		order.proportion_tolerance = 0.35
		order.penalty_scale = 0.05
		order.require_ingredient_match = false
		orders.append(order)
	return orders

func format_order_text(order: DrinkOrder, base_text: String) -> String:
	if order and not order.require_ingredient_match:
		var fill_ratio: float = order.ideal_fill_ratio if order.ideal_fill_ratio > 0.0 else IDEAL_FILL_RATIO
		var pct: int = int(round(fill_ratio * 100.0))
		return super.format_order_text(order, "Anything " + str(pct) + "%\n")
	return super.format_order_text(order, base_text)

func on_tool_world_click(tool_id: String, _player: Node3D) -> bool:
	if tool_id != "mag":
		return false
	if not GameState.seat_manager:
		return false
	if GameState.night_manager and GameState.night_manager.is_shift_ended:
		return false
	if GameState.seat_manager.get_empty_seat_count() <= 0:
		return false
	var spawned := GameState.seat_manager.spawn_customer_by_species(self)
	return is_instance_valid(spawned)