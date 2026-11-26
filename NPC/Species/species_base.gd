class_name SpeciesBase
extends RefCounted

# Base class for all customer species definitions, preferences, and gimmicks

var species_id: String = "BASE"
var display_name: String = "Base"
var sort_order: int = 100

var logo_frame: int = 10
var npc_resource_path: String = ""
var fallback_texture_path: String = ""
var fallback_hframes: int = 1
var default_patience: float = 90.0
var npc_scale: Vector3 = Vector3(0.5, 0.5, 0.5)
var patience_scale: float = 1.0
var seat_y_offset: float = 0.0
var seat_offset: Vector3 = Vector3.ZERO
var patience_y_offset: float = 0.0
var patience_offset: Vector3 = Vector3.ZERO

var base_spawn_weight: float = 5.0
var default_marketing_weight: float = 0.0
var spawn_randomly: bool = true
var can_be_ghost: bool = true
var can_be_wanted: bool = true
var disallowed_modifiers: Array[String] = []

func get_seat_offset() -> Vector3:
	return Vector3(seat_offset.x, seat_offset.y + seat_y_offset, seat_offset.z)

func get_patience_offset() -> Vector3:
	return Vector3(patience_offset.x, patience_offset.y + patience_y_offset, patience_offset.z)

func get_npc_resource() -> NPC:
	if npc_resource_path != "" and ResourceLoader.exists(npc_resource_path):
		var loaded = load(npc_resource_path)
		if loaded is NPC:
			return loaded

	var fallback := NPC.new()
	fallback.race = species_id
	fallback.patience_time = default_patience
	fallback.hframe = fallback_hframes
	if fallback_texture_path != "" and ResourceLoader.exists(fallback_texture_path):
		fallback.sprite_sheet = load(fallback_texture_path) as Texture2D
	fallback.dialogue_resource = get_fallback_dialogue_resource()
	return fallback

func get_fallback_dialogue_resource() -> DialogueResource:
	return get_fallback_dialogue_resource_for_name(display_name)

func get_fallback_dialogue_resource_for_name(speaker_name: String) -> DialogueResource:
	var text := get_fallback_dialogue_text_for_name(speaker_name)
	if text == "":
		return null
	return DialogueManager.create_resource_from_text(text)

func get_fallback_dialogue_text() -> String:
	return get_fallback_dialogue_text_for_name(display_name)

func get_fallback_dialogue_text_for_name(speaker_name: String) -> String:
	var s := speaker_name if speaker_name.strip_edges() != "" else display_name
	return """~ start
%s: [[Hi|Hello|Evening]], I want {{_current_order_text()}}
do _add_recipt()
set speaking_title = "mid"
=> END
~ next_order
%s: [[Another one|One more]], I want {{_current_order_text()}}
do _add_recipt()
set speaking_title = "mid"
=> END
~ mid
%s: Still waiting on my drink!
=> END
~ Positive
set emo = "happy"
%s: Great drink, thanks!
do _give_payment()
=> END
~ Mid
%s: Not bad.
do _give_payment()
=> END
~ Negative
set emo = "mad"
%s: This tastes awful.
do _give_payment()
=> END
~ TimeWarning1
%s: How much longer on that drink?
=> END
~ afternight_1
%s: Good evening.
=> END
""" % [s, s, s, s, s, s, s, s]

func can_accept_modifier(modifier_id: String) -> bool:
	var normalized := modifier_id.to_upper().strip_edges()
	for blocked in disallowed_modifiers:
		if blocked.to_upper().strip_edges() == normalized:
			return false
	if normalized == "GHOST" and not can_be_ghost:
		return false
	if normalized == "WANTED" and not can_be_wanted:
		return false
	return true

func is_unlocked(_stats: Node = null) -> bool:
	return true

func is_unlocked_for_marketing(stats: Node = null) -> bool:
	return is_unlocked(stats)

func can_spawn_randomly(stats: Node = null) -> bool:
	return spawn_randomly and is_unlocked(stats)

func get_spawn_weight(stats: Node = null) -> float:
	if stats and stats.has_method("get_species_spawn_weight"):
		return float(stats.get_species_spawn_weight(species_id))
	return base_spawn_weight

func on_ingredient_unlocked(_ingredient_key: String, _stats: Node = null) -> void:
	pass

func get_drink_pool(stats: Node = null) -> Array[String]:
	var pool: Array[String] = ["beer", "gin"]
	if stats and "unlocks" in stats and stats.unlocks.has("Drinks"):
		for d in stats.unlocks["Drinks"]:
			var key := str(d)
			if stats.unlocks["Drinks"][d] and not pool.has(key):
				pool.append(key)
	return pool

func get_order_count(_npc: Sprite3D, _modifier: RefCounted = null) -> int:
	return 1

func generate_orders(npc: Sprite3D, modifier: RefCounted = null, stats: Node = null) -> Array[DrinkOrder]:
	var orders: Array[DrinkOrder] = []
	var count := maxi(1, get_order_count(npc, modifier))
	if modifier and modifier.has_method("modify_order_count"):
		count = maxi(1, int(modifier.modify_order_count(npc, count)))

	for i in range(count):
		var recipe := DrinkRegistry.pick_random_recipe(stats, species_id)
		if recipe:
			orders.append(DrinkRegistry.create_order_from_recipe(recipe, species_id, true))
		else:
			var fallback := DrinkOrder.new()
			fallback.species_id = species_id
			fallback.ingredients["gin"] = 1.0
			fallback.ice_preference = DrinkRegistry.roll_ice_preference(DrinkRecipe.IcePreference.DONT_CARE)
			orders.append(fallback)
	return orders

func format_order_text(order: DrinkOrder, base_text: String) -> String:
	if order == null:
		return base_text
	var out := base_text
	if order.required_glass != "":
		out += order.required_glass.capitalize() + " Glass\n"
	if not order.garnishes.is_empty():
		var garnish_names := PackedStringArray()
		for g in order.garnishes:
			garnish_names.append(str(g).replace("_", " ").capitalize())
		out += "Garnish: " + ", ".join(garnish_names) + "\n"
	if order.ice_preference == DrinkRecipe.IcePreference.REQUIRED:
		out += "Ice\n"
	elif order.ice_preference == DrinkRecipe.IcePreference.FORBIDDEN:
		out += "No Ice\n"
	if not order.required_processing.is_empty():
		var tags := PackedStringArray()
		for tag in order.required_processing:
			tags.append(str(tag).capitalize())
		out += "(" + ", ".join(tags) + ")\n"
	return out

func modify_receipt_appearance(_receipt: Node, _receipt_2d: Control) -> void:
	pass

func on_score_drink(_served: DrinkMix, _wanted: DrinkOrder, _score_data: Dictionary) -> void:
	pass

func on_score_drink_global(_served: DrinkMix, _wanted: DrinkOrder, _score_data: Dictionary) -> void:
	pass

func get_glass_resource_multiplier(_glass: Area3D, _liquid_id: String = "") -> float:
	return 1.0

func can_accept_drink(_npc: Sprite3D) -> bool:
	return true

func prepare_cup_delivery(_npc: Sprite3D, _drink: Area3D, default_target_pos: Vector3) -> Vector3:
	return default_target_pos

func evaluate_drink_attempt(_npc: Sprite3D, _mix: DrinkMix, _wanted: DrinkOrder) -> Dictionary:
	return {}

func consume_delivered_cup(_npc: Sprite3D, _drink: Area3D) -> bool:
	return false

func on_drink_served(_npc: Sprite3D, _mix: DrinkMix, _wanted: DrinkOrder, _score_data: Dictionary) -> void:
	pass

func modify_overall_reputation_delta(_npc: Sprite3D, base_delta: float, _is_satisfactory: bool, _drink_score: float) -> float:
	return base_delta

func modify_species_reputation_delta(_npc: Sprite3D, _race_name: String, base_delta: float, _is_satisfactory: bool, _drink_score: float) -> float:
	return base_delta

func modify_payout(_npc: Sprite3D, _base_price: float, _is_satisfactory: bool, _drink_score: float, current_payment: float) -> float:
	return current_payment

func modify_tip(_npc: Sprite3D, current_tip: float, _is_satisfactory: bool, _drink_score: float) -> float:
	return current_tip

func modify_patience_replenish(_npc: Sprite3D, base_replenish: float, _drink_score: float) -> float:
	return base_replenish

func on_npc_setup(_npc: Sprite3D) -> void:
	pass

func on_npc_clear(_npc: Sprite3D) -> void:
	pass

func on_npc_process(_npc: Sprite3D, _delta: float, _active_tool: String) -> void:
	pass

func can_interact_with_tool(_npc: Sprite3D, _tool_id: String, _interaction_type: String) -> bool:
	return true

func on_npc_tool_click(_npc: Sprite3D, _tool_id: String, _player: Node3D) -> bool:
	return false

func on_npc_tool_hover(_npc: Sprite3D, _tool_id: String, _is_hovered: bool) -> void:
	pass

func on_tool_interact_glass(_tool_id: String, _glass: Area3D, _player: Node3D) -> bool:
	return false

func should_consume_glass_click(_tool_id: String, _glass: Area3D) -> bool:
	return false

func can_highlight_glass(_tool_id: String, _glass: Area3D) -> int:
	# -1 = no opinion, 0 = force false, 1 = force true
	return -1

func on_tool_counter_action(_tool_id: String, _player: Node3D, _main_node: Node3D) -> bool:
	return false

func on_tool_world_click(_tool_id: String, _player: Node3D) -> bool:
	return false