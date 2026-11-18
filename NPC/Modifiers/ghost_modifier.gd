class_name GhostModifier
extends ModifierBase

var ghost_fell_through: bool = false

func _init() -> void:
	modifier_id = "GHOST"
	display_name = "Ghost"
	sort_order = 1
	spawn_chance = 0.10
	is_ghost = true

func can_apply_to_species(species_id: String, is_unique: bool = false, stats: Node = null) -> bool:
	if is_unique:
		return false
	var sp := SpeciesRegistry.get_species(species_id)
	if sp == null or not sp.can_be_ghost:
		return false
	if stats and "unlocks" in stats:
		if stats.unlocks.has("Ingredients") and stats.unlocks["Ingredients"].has("Knife"):
			return stats.has_unlock("Ingredients", "Knife")
		if stats.unlocks.has("Tools") and stats.unlocks["Tools"].has("Knife"):
			return stats.has_unlock("Tools", "Knife")
	return true

func on_npc_setup(npc: Sprite3D) -> void:
	SpectralEffect.apply_to_sprite(npc, {
		"float_amplitude": 0.03,
		"sway_amplitude": 0.018,
		"use_vertex_color": 1.0,
		"bottom_fade_strength": 0.35
	})

func on_npc_clear(npc: Sprite3D) -> void:
	SpectralEffect.clear_from_sprite(npc, SpriteBase3D.ALPHA_CUT_HASH)

func on_generate_orders(_npc: Sprite3D, orders: Array[DrinkOrder]) -> void:
	for order in orders:
		if order and not order.required_processing.has("spectral"):
			order.required_processing.append("spectral")

func modify_receipt_appearance(_receipt: Node, receipt_2d: Control) -> void:
	if receipt_2d and receipt_2d.has_method("_set_customer_icon_modulate"):
		receipt_2d._set_customer_icon_modulate(Color(0.55, 0.95, 1.0, 0.72))

func on_score_drink_global(served: DrinkMix, wanted: DrinkOrder, score_data: Dictionary) -> void:
	if wanted == null or not wanted.required_processing.has("spectral"):
		return
	if served == null or not served.has_processing("spectral"):
		score_data["score"] = 0.0

func prepare_cup_delivery(npc: Sprite3D, drink: Area3D, default_target_pos: Vector3) -> Vector3:
	if _is_drink_rejected(drink):
		return Vector3(npc.global_position.x, default_target_pos.y, lerpf(npc.global_position.z, default_target_pos.z, 0.25))
	return default_target_pos

func evaluate_drink_attempt(_npc: Sprite3D, mix: DrinkMix, _wanted: DrinkOrder) -> Dictionary:
	if mix and mix.has_processing("spectral"):
		ghost_fell_through = false
		return {}
	ghost_fell_through = true
	return {
		"rejected": true,
		"score": 0.0,
		"clear_orders": true,
		"zero_satisfaction": true,
		"emo": "mad",
		"feedback": "Passed right through!"
	}

func consume_delivered_cup(_npc: Sprite3D, drink: Area3D) -> bool:
	if not _is_drink_rejected(drink):
		return false
	if not (drink is Glasses):
		return false

	var cup := drink as Glasses
	if cup.is_consumed:
		return true

	cup.is_consumed = true
	cup.is_delivering = false
	cup._is_pointer_pressed = false
	cup.is_balls_dragging = false
	if cup._drag_return_tween and cup._drag_return_tween.is_valid():
		cup._drag_return_tween.kill()
	if cup.area_body:
		cup.area_body.set_deferred("disabled", true)
	cup._remove_displaying_list()

	var fall_tween := cup.create_tween().set_parallel(true)
	fall_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(cup, "global_position:y", cup.global_position.y - 1.8, 0.65)
	fall_tween.tween_property(cup, "rotation_degrees:z", 35.0, 0.65)
	if cup.sprite:
		cup.sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		fall_tween.tween_property(cup.sprite, "modulate:a", 0.0, 0.55).set_delay(0.1)
	if cup.visual_helper and cup.visual_helper.liquid_shader_mat:
		fall_tween.tween_property(cup.visual_helper.liquid_shader_mat, "shader_parameter/liquid_transparency", 0.0, 0.55).set_delay(0.1)
	fall_tween.chain().tween_callback(cup.queue_free)
	return true

func on_drink_served(npc: Sprite3D, _mix: DrinkMix, _wanted: DrinkOrder, score_data: Dictionary) -> void:
	if score_data.get("is_satisfactory", false) and not ghost_fell_through:
		if is_instance_valid(npc) and npc.has_method("show_floating_feedback"):
			npc.show_floating_feedback("Spectral delight!")

func modify_species_reputation_delta(_npc: Sprite3D, _race_name: String, base_delta: float, is_satisfactory: bool, _drink_score: float) -> float:
	if is_satisfactory and not ghost_fell_through:
		return base_delta * 2.0
	return base_delta

func modify_tip(_npc: Sprite3D, current_tip: float, _is_satisfactory: bool, _drink_score: float) -> float:
	if ghost_fell_through:
		return 0.0
	return current_tip * 1.5

func can_highlight_glass(tool_id: String, glass: Area3D) -> int:
	if tool_id != "knife" or not (glass is Glasses):
		return -1
	var cup := glass as Glasses
	return 0 if cup.drink_mix.has_processing("spectral") else 1

func should_consume_glass_click(tool_id: String, glass: Area3D) -> bool:
	return tool_id == "knife" and glass is Glasses

func on_tool_interact_glass(tool_id: String, glass: Area3D, _player: Node3D) -> bool:
	if tool_id != "knife" or not (glass is Glasses):
		return false

	var cup := glass as Glasses
	if cup._is_drag_blocked() or cup.drink_mix.has_processing("spectral"):
		return false

	cup.drink_mix.add_processing("spectral")
	SpectralEffect.apply_to_glass(cup)

	var target_sprite := cup.sprite if cup.sprite else cup.get_node_or_null("Inside") as Sprite3D
	if target_sprite:
		var base_scale: Vector3 = cup.get("_inside_base_scale") if "_inside_base_scale" in cup else target_sprite.scale
		var base_pos: Vector3 = cup.get("_inside_base_pos") if "_inside_base_pos" in cup else target_sprite.position
		var stab_tween := cup.create_tween().set_parallel(true)
		target_sprite.scale = base_scale * Vector3(1.18, 0.82, 1.0)
		target_sprite.position.y = base_pos.y - 0.12
		stab_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		stab_tween.tween_property(target_sprite, "scale", base_scale, 0.22)
		stab_tween.tween_property(target_sprite, "position:y", base_pos.y, 0.22)

	cup.set_highlight(false)
	GameState.play_sfx("play_stab")
	if cup.camera and cup.camera.has_method("add_shake"):
		cup.camera.add_shake(0.15)
	return true

func _is_drink_rejected(drink: Area3D) -> bool:
	if not (drink is Glasses):
		return false
	var cup := drink as Glasses
	return cup.drink_mix == null or not cup.drink_mix.has_processing("spectral")