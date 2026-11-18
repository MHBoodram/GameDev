# Tracks active tool held in hand ("hand", "knife", etc.)
# Loops through SpeciesRegistry to dispatch tool actions without species-specific branches
# Updates player hand animation states
class_name ToolController
extends RefCounted

var tool_in_hand: String = "hand"

func set_tool(new_tool: String) -> void:
	tool_in_hand = new_tool.to_lower().strip_edges()

func get_tool() -> String:
	return tool_in_hand

# triggers species-registered tool actions when clicking bottom screen edge
func handle_counter_edge_click(player: Node3D, main_node: Node3D = null) -> bool:
	return SpeciesRegistry.handle_counter_edge_tool(tool_in_hand, player, main_node)

# triggers species-registered tool actions when clicking a glass without dragging
func handle_glass_click(glass: Area3D, player: Node3D = null) -> bool:
	return SpeciesRegistry.handle_glass_tool_click(tool_in_hand, glass, player)

# triggers species-registered tool actions when clicking a customer NPC
func handle_npc_click(npc: Sprite3D, player: Node3D = null) -> bool:
	return SpeciesRegistry.handle_npc_tool_click(npc, tool_in_hand, player)

# updates the hand sprite animation based on selected tool and hovering state
func update_hand_visual(anim_player: AnimationPlayer, action_state: String) -> void:
	if not anim_player:
		return

	if tool_in_hand == "knife":
		if anim_player.has_animation("knife_idle") and anim_player.current_animation != "knife_idle":
			anim_player.play("knife_idle")
	else:
		match action_state:
			"interact":
				if anim_player.current_animation != "interact":
					anim_player.play("interact")
			"holding":
				if anim_player.current_animation != "hold":
					anim_player.play("hold")
			_:
				if anim_player.current_animation != "idle":
					anim_player.play("idle")