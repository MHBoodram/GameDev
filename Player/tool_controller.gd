# Tracks active tool held in hand ("hand", "knife", etc.)
# Loops through SpeciesRegistry to dispatch species and modifier tool actions
# Updates player hand animation states
class_name ToolController
extends RefCounted

var tool_in_hand: String = "hand"

func set_tool(new_tool: String) -> void:
	tool_in_hand = new_tool.to_lower().strip_edges()

func get_tool() -> String:
	return tool_in_hand

# triggers species/modifier-registered tool actions when clicking bottom screen edge
func handle_counter_edge_click(player: Node3D, main_node: Node3D = null) -> bool:
	return SpeciesRegistry.handle_counter_edge_tool(tool_in_hand, player, main_node)

# triggers species/modifier-registered tool actions when clicking a glass
func handle_glass_click(glass: Area3D, player: Node3D = null) -> bool:
	return SpeciesRegistry.handle_glass_tool_click(tool_in_hand, glass, player)

func can_highlight_glass(glass: Area3D) -> bool:
	return SpeciesRegistry.can_highlight_glass(tool_in_hand, glass)

func should_consume_glass_click(glass: Area3D) -> bool:
	return SpeciesRegistry.should_consume_glass_click(tool_in_hand, glass)

# triggers species/modifier-registered tool actions when clicking a customer NPC
func handle_npc_click(npc: Sprite3D, player: Node3D = null) -> bool:
	return SpeciesRegistry.handle_npc_tool_click(npc, tool_in_hand, player)

func handle_npc_hover(npc: Sprite3D, is_hovered: bool) -> void:
	if not is_instance_valid(npc):
		return
	var sp: SpeciesBase = npc.get("species_def") as SpeciesBase
	if sp:
		sp.on_npc_tool_hover(npc, tool_in_hand, is_hovered)
	var mod: ModifierBase = npc.get("modifier") as ModifierBase
	if mod:
		mod.on_npc_tool_hover(npc, tool_in_hand, is_hovered)

func can_npc_interact_with_tool(npc: Sprite3D, interaction_type: String) -> bool:
	if not is_instance_valid(npc):
		return true
	var sp: SpeciesBase = npc.get("species_def") as SpeciesBase
	if sp and not sp.can_interact_with_tool(npc, tool_in_hand, interaction_type):
		return false
	var mod: ModifierBase = npc.get("modifier") as ModifierBase
	if mod and not mod.can_interact_with_tool(npc, tool_in_hand, interaction_type):
		return false
	return true

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