class_name ModifierBase
extends RefCounted

# Base class for all customer modifiers (ghost, etc.)

var modifier_id: String = "NONE"
var display_name: String = "None"
var sort_order: int = 100
var spawn_chance: float = 0.0

func create_instance() -> ModifierBase:
	var script_res: Script = get_script()
	if script_res and script_res.can_instantiate():
		return script_res.new() as ModifierBase
	return ModifierBase.new()

func can_apply_to_species(_species_id: String, is_unique: bool = false, _stats: Node = null) -> bool:
	return not is_unique

func get_spawn_chance(_species_id: String, _stats: Node = null) -> float:
	return spawn_chance

func on_npc_setup(_npc: Sprite3D) -> void:
	pass

func on_npc_clear(_npc: Sprite3D) -> void:
	pass

func on_npc_process(_npc: Sprite3D, _delta: float, _active_tool: String) -> void:
	pass

func modify_order_count(_npc: Sprite3D, current_count: int) -> int:
	return current_count

func on_generate_orders(_npc: Sprite3D, _orders: Array[DrinkOrder]) -> void:
	pass

func format_order_text(_order: DrinkOrder, base_text: String) -> String:
	return base_text

func modify_receipt_appearance(_receipt: Node, _receipt_2d: Control) -> void:
	pass

func on_score_drink(_npc: Sprite3D, _served: DrinkMix, _wanted: DrinkOrder, _score_data: Dictionary) -> void:
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

func modify_patience_replenish(_npc: Sprite3D, current_replenish: float, _drink_score: float) -> float:
	return current_replenish

func on_tool_interact_glass(_tool_id: String, _glass: Area3D, _player: Node3D) -> bool:
	return false

func should_consume_glass_click(_tool_id: String, _glass: Area3D) -> bool:
	return false

func can_highlight_glass(_tool_id: String, _glass: Area3D) -> int:
	# -1 = no opinion, 0 = force false, 1 = force true
	return -1

func can_interact_with_tool(_npc: Sprite3D, _tool_id: String, _interaction_type: String) -> bool:
	return true

func on_npc_tool_hover(_npc: Sprite3D, _tool_id: String, _is_hovered: bool) -> void:
	pass

func on_npc_tool_click(_npc: Sprite3D, _tool_id: String, _player: Node3D) -> bool:
	return false

func on_tool_counter_action(_tool_id: String, _player: Node3D, _main_node: Node3D) -> bool:
	return false