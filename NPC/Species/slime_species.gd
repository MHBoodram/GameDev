class_name SlimeSpecies
extends SpeciesBase

const SPLIT_SCALE_MULTIPLIER := 0.75

func _init() -> void:
	species_id = "SLIME"
	display_name = "Slime"
	sort_order = 3
	logo_frame = 7
	npc_resource_path = "res://NPC/Resources/slime.tres"
	fallback_texture_path = "res://Assets/NPC/Slime/slime1.png"
	fallback_hframes = 1
	base_spawn_weight = 2.0
	default_marketing_weight = 1.0
	spawn_randomly = true
	can_be_ghost = false
	disallowed_modifiers = ["GHOST"]

func is_unlocked(stats: Node = null) -> bool:
	# Appears rarely once another random-spawning species besides Human is unlocked
	for sp in SpeciesRegistry.get_all_species():
		if sp.species_id == species_id or sp.species_id == "HUMAN":
			continue
		if sp.spawn_randomly and sp.is_unlocked(stats):
			return true
	return false

func get_order_count(_npc: Sprite3D, _modifier: RefCounted = null) -> int:
	return randi_range(1, 3)

func get_drink_pool(stats: Node = null) -> Array[String]:
	return super.get_drink_pool(stats)

func modify_payout(_npc: Sprite3D, base_price: float, is_satisfactory: bool, _drink_score: float, current_payment: float) -> float:
	if is_satisfactory:
		return current_payment + base_price
	return current_payment

func on_npc_setup(npc: Sprite3D) -> void:
	if not is_instance_valid(npc):
		return
	var raw_state: Variant = npc.get("species_state")
	if raw_state is Dictionary:
		raw_state["sliced"] = false
		raw_state["is_split_child"] = false

func on_npc_tool_hover(npc: Sprite3D, tool_id: String, is_hovered: bool) -> void:
	if not is_instance_valid(npc) or not npc.has_method("set_highlight"):
		return
	if is_hovered and tool_id == "knife" and _can_slice(npc):
		npc.set_highlight(true)
	elif not is_hovered:
		npc.set_highlight(false)

func on_npc_tool_click(npc: Sprite3D, tool_id: String, player: Node3D) -> bool:
	if tool_id != "knife":
		return false
	if not _is_slime_npc(npc):
		return false
	if "is_leaving" in npc and npc.is_leaving:
		return true
	if "unique_talk" in npc and npc.unique_talk:
		return false
	if GameState.is_dialogue_open:
		return true
	if player and "in_game" in player and player.in_game:
		return true
	if GameState.gameplay_ui and "down" in GameState.gameplay_ui and GameState.gameplay_ui.down:
		return true
	if ShakerMinigame.active:
		return true

	var raw_state: Variant = npc.get("species_state")
	if not (raw_state is Dictionary):
		return false
	var state: Dictionary = raw_state

	if state.get("is_split_child", false):
		if npc.has_method("show_floating_feedback"):
			npc.show_floating_feedback("Too small to slice!")
		return true
	if state.get("sliced", false):
		if npc.has_method("show_floating_feedback"):
			npc.show_floating_feedback("Already sliced!")
		return true

	if not GameState.seat_manager:
		return false
	if GameState.seat_manager.get_empty_seat_count() <= 0:
		if npc.has_method("show_floating_feedback"):
			npc.show_floating_feedback("No empty seats!")
		return true

	state["sliced"] = true
	if npc.has_method("set_highlight"):
		npc.set_highlight(false)

	var child_npc: Base_NPC = GameState.seat_manager.spawn_customer_by_species(self)
	if not is_instance_valid(child_npc):
		state["sliced"] = false
		return true

	child_npc.species_state["sliced"] = true
	child_npc.species_state["is_split_child"] = true

	_play_slime_sfx(npc)
	_animate_split(npc, child_npc)
	return true

func _is_slime_npc(npc: Sprite3D) -> bool:
	if not is_instance_valid(npc):
		return false
	var target_sp: SpeciesBase = npc.get("species_def") as SpeciesBase
	return target_sp != null and target_sp.species_id == species_id

func _can_slice(npc: Sprite3D) -> bool:
	if not _is_slime_npc(npc):
		return false
	if "is_leaving" in npc and npc.is_leaving:
		return false
	if "unique_talk" in npc and npc.unique_talk:
		return false
	var raw_state: Variant = npc.get("species_state")
	if not (raw_state is Dictionary):
		return false
	var state: Dictionary = raw_state
	return not state.get("sliced", false) and not state.get("is_split_child", false)

func _play_slime_sfx(_context_node: Node = null) -> void:
	GameState.play_sfx("play_stab")
	GameState.play_sfx("play_slime")

func _animate_split(parent_npc: Sprite3D, child_npc: Base_NPC) -> void:
	if is_instance_valid(parent_npc):
		_keep_patience_readable(parent_npc, SPLIT_SCALE_MULTIPLIER)
		var p_tween := parent_npc.create_tween()
		p_tween.tween_method(func(v: float) -> void:
			if is_instance_valid(parent_npc):
				parent_npc.set("visual_scale_multiplier", v)
				if parent_npc.has_method("_refresh_visual_scale"):
					parent_npc._refresh_visual_scale()
		, 1.0, 1.15, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_tween.tween_method(func(v: float) -> void:
			if is_instance_valid(parent_npc):
				parent_npc.set("visual_scale_multiplier", v)
				if parent_npc.has_method("_refresh_visual_scale"):
					parent_npc._refresh_visual_scale()
		, 1.15, SPLIT_SCALE_MULTIPLIER, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if is_instance_valid(child_npc):
		child_npc.global_position = parent_npc.global_position + Vector3(0.0, 0.0, 0.02)
		child_npc.visual_scale_multiplier = 0.25
		child_npc._refresh_visual_scale()
		_keep_patience_readable(child_npc, SPLIT_SCALE_MULTIPLIER)
		var c_tween := child_npc.create_tween()
		c_tween.tween_method(func(v: float) -> void:
			if is_instance_valid(child_npc):
				child_npc.visual_scale_multiplier = v
				child_npc._refresh_visual_scale()
		, 0.25, SPLIT_SCALE_MULTIPLIER, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _keep_patience_readable(target_npc: Sprite3D, target_mult: float) -> void:
	var patience_sprite := target_npc.get_node_or_null("Sprite3D") as Sprite3D
	if patience_sprite == null:
		return
	var b_scale: Variant = target_npc.get("base_scale")
	if b_scale is Vector3 and b_scale.x > 0.01:
		var effective_x: float = b_scale.x * target_mult
		var inv_factor: float = minf(2.2, 0.5 / maxf(effective_x, 0.01))
		patience_sprite.scale = Vector3.ONE * inv_factor