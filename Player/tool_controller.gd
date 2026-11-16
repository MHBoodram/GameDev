# Tracks active tool held in hand ("hand", "knife", "mag", "rod", "phone")
# Does tool actions via GameState.minigame_host
# Updates player hand animation states
class_name ToolController
extends RefCounted

var tool_in_hand: String = "hand"

func set_tool(new_tool: String) -> void:
	tool_in_hand = new_tool

func get_tool() -> String:
	return tool_in_hand

# triggers tool action when clicking bottom screen edge while looking down at counter
func handle_counter_edge_click(player: Node3D, _main_node: Node3D = null) -> bool:
	if tool_in_hand == "knife" and GameState.minigame_host:
		if not player.in_game:
			GameState.minigame_host.start_blood_minigame(GameState.main_node, player)
			return true
	return false

# updates the hand sprite animation based on selected tool and hovering state
func update_hand_visual(anim_player: AnimationPlayer, action_state: String) -> void:
	if not anim_player:
		return
	match tool_in_hand:
		"hand":
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
		"knife":
			if anim_player.current_animation != "knife_idle":
				anim_player.play("knife_idle")