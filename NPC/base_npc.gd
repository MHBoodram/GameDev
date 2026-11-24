# All customers are this class - has patience, ordering, payment, dialogue
#Provides DialogueManager mutation hooks (_tutorial_enabler, _check_tutorial, night_popup)
# Consumes DrinkMix instances from Glasses and
# Gives receipt and seat events to GameState.seat_manager.

extends Sprite3D
class_name Base_NPC

@export var npc_resource: NPC
enum State { SEAT, SIT, EXIT }
var current_state: State = State.SEAT
var seat_num: int
var camera: Camera3D = null
var drink_list: Array = []
var dialogue_resource: DialogueResource
var speaking_title: String = "start"
@export var drink_offset: float = 5.0
@onready var custom_balloon = load("res://addons/dialogue_manager/example_balloon/main_balloon.tscn")
@onready var patience_timer: Timer = $Patience_timer
@onready var patient_2d = $Sprite3D/SubViewport/Patience

var recipt_marker: Marker3D
var recipt_clicked: bool = true
var unique_talk: bool = false
var can_talk: bool = true
var has_receipt_spawned: bool = false
var emo: String = "netural"
var customer_satisfaction: float = 1.0
var _dialouge_paused_patience : float = -1.0
var max_patience: float = 90.0
var payment_global: float = 0.0
var is_leaving: bool = false
var _is_highlighted: bool = false
var _original_modulate: Color = Color.WHITE

var modifier: ModifierBase = ModifierBase.new()
var species_def: SpeciesBase = null
var species_state: Dictionary = {}
var base_scale: Vector3 = Vector3(0.5, 0.5, 0.5)
var visual_scale_multiplier: float = 1.0
var _bounce_factor: float = 1.0

const SATISFACTORY_THRESHOLD := 0.6
const POSITIVE_SCORE_THRESHOLD := 0.75
const MID_SCORE_THRESHOLD := 0.5
const REPLENISH_BASE_TIME := 30.0

const BASE_DRINK_PRICE := 10.0
const SCALE_BASE_PAYOUT_BY_SCORE := true
const SATISFACTORY_PAYOUT_MULTIPLIER := 1.0
const UNSATISFACTORY_PAYOUT_MULTIPLIER := 0.0
const TIP_OVERALL_REP_MULTIPLIER := 1.0
const TIP_SPECIES_REP_MULTIPLIER := 1.0
const SATISFACTORY_TIP_MULTIPLIER := 1.0
const UNSATISFACTORY_TIP_MULTIPLIER := 0.0
const PATIENCE_TIMEOUT_PAYOUT := 0.0

const LOW_PATIENCE_THRESHOLD_RATIO := 0.25
const LOW_PATIENCE_SATISFACTION_DRAIN_RATE := 0.05
const OVERALL_REP_GAIN_ON_SATISFACTORY := 1.0
const SPECIES_REP_GAIN_ON_SATISFACTORY := 1.0
const SPECIES_REP_LOSS_MULTIPLIER := 2.0

var _bounce_tween: Tween

func _ready() -> void:
	if npc_resource:
		max_patience = npc_resource.patience_time
		texture = npc_resource.sprite_sheet
		hframes = npc_resource.hframe
		dialogue_resource = npc_resource.dialogue_resource
		species_def = SpeciesRegistry.get_species_or_default(npc_resource.race)
	else:
		species_def = SpeciesRegistry.get_species_or_default("HUMAN")

	patience_timer.wait_time = max_patience
	patience_timer.start(max_patience)
	patient_2d._setup(max_patience, npc_resource.race if npc_resource else "HUMAN")
	patient_2d._change_max_progress(max_patience)
	patient_2d._change_curent(max_patience)
	camera = get_viewport().get_camera_3d()
	_apply_species_scale()
	_start_bounce()

	if not DialogueManager.dialogue_started.is_connected(_on_dialouge_started):
		DialogueManager.dialogue_started.connect(_on_dialouge_started)

	patience_timer.start()
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _apply_species_scale() -> void:
	base_scale = species_def.npc_scale if species_def else Vector3(0.5, 0.5, 0.5)
	visual_scale_multiplier = 1.0
	_refresh_visual_scale()
	var patience_sprite := get_node_or_null("Sprite3D") as Sprite3D
	if patience_sprite and base_scale.x > 0.01:
		var inv_factor := minf(1.8, 0.5 / base_scale.x)
		patience_sprite.scale = Vector3.ONE * inv_factor

func _apply_bounce_scale(factor: float) -> void:
	_bounce_factor = factor
	_refresh_visual_scale()

func _refresh_visual_scale() -> void:
	scale = base_scale * visual_scale_multiplier * Vector3(_bounce_factor, _bounce_factor * 0.998, 1.0)

func _get_active_tool() -> String:
	if GameState.player and GameState.player.has_method("return_tool"):
		return str(GameState.player.return_tool()).to_lower().strip_edges()
	return "hand"

func _get_tool_controller() -> ToolController:
	if GameState.player:
		return GameState.player.get("tool_controller") as ToolController
	return null

func _get_race_display_name() -> String:
	if species_def:
		return species_def.display_name
	var fallback_sp := SpeciesRegistry.get_species_or_default(npc_resource.race if npc_resource else "")
	return fallback_sp.display_name if fallback_sp else "Human"

func _process(delta: float) -> void:
	var active_tool := _get_active_tool()
	if species_def:
		species_def.on_npc_process(self, delta, active_tool)
	if modifier:
		modifier.on_npc_process(self, delta, active_tool)

	var patience_left: float = patience_timer.time_left
	if _dialouge_paused_patience >= 0.0:
		patience_left = _dialouge_paused_patience

	patient_2d._change_curent(patience_left)

	if _dialouge_paused_patience >= 0.0:
		return
	if max_patience > 0.0 and patience_left < max_patience * LOW_PATIENCE_THRESHOLD_RATIO:
		var drain_rate: float = (1.0 - patience_left / (max_patience * LOW_PATIENCE_THRESHOLD_RATIO)) * LOW_PATIENCE_SATISFACTION_DRAIN_RATE * delta
		customer_satisfaction = maxf(0.0, customer_satisfaction - drain_rate)

func setup_npc(npc_source: NPC, seat: int, rec_marker: Marker3D, patience: float = 90.0, starting_dialogue: String = "start", forced_modifier: String = "") -> void:
	npc_resource = npc_source
	seat_num = seat
	recipt_marker = rec_marker
	has_receipt_spawned = false
	species_state.clear()
	pixel_size = 0.01
	modulate = Color.WHITE
	_original_modulate = Color.WHITE
	_is_highlighted = false
	SpeciesRegistry.clear_npc_visuals(self)
	GameState.play_sfx("play_entranto")

	if patience > 0.0:
		max_patience = patience
	elif npc_source and npc_source.patience_time > 0.0:
		max_patience = npc_source.patience_time
	else:
		max_patience = 90.0

	patience_timer.wait_time = max_patience
	patience_timer.start(max_patience)

	speaking_title = starting_dialogue
	unique_talk = (starting_dialogue != "start")
	can_talk = (starting_dialogue != "tutorial_walk")

	species_def = SpeciesRegistry.get_species_or_default(npc_resource.race if npc_resource else "HUMAN")

	if npc_resource:
		texture = npc_resource.sprite_sheet
		hframes = npc_resource.hframe
		dialogue_resource = npc_resource.dialogue_resource
		patient_2d._setup(max_patience, npc_resource.race)

	_apply_species_scale()
	patient_2d._change_max_progress(max_patience)
	patient_2d._change_curent(max_patience)
	if is_instance_valid(patient_2d) and patient_2d.has_method("_recipt_hide"):
		patient_2d._recipt_hide()
	customer_satisfaction = 1.0

	var race_id := species_def.species_id if species_def else (npc_resource.race if npc_resource else "HUMAN")
	if forced_modifier != "":
		modifier = SpeciesRegistry.create_modifier_for_species(forced_modifier, race_id, unique_talk, PlayerStats)
	else:
		modifier = SpeciesRegistry.roll_modifier(race_id, unique_talk, PlayerStats)

	if modifier:
		modifier.on_npc_setup(self)
	if species_def:
		species_def.on_npc_setup(self)

func _institate(npc_source: NPC, seat: int, rec_marker: Marker3D, patience: float = 90.0, starting_dialogue: String = "start") -> void:
	setup_npc(npc_source, seat, rec_marker, patience, starting_dialogue)

func talk() -> void:
	if GameState.is_dialogue_open:
		return
	if not can_talk or speaking_title == "" or speaking_title == null:
		return
	if not unique_talk:
		var tool_ctrl := _get_tool_controller()
		var active_tool := _get_active_tool()
		var can_talk_with_tool: bool = tool_ctrl.can_npc_interact_with_tool(self, "talk") if tool_ctrl else ((not species_def or species_def.can_interact_with_tool(self, active_tool, "talk")) and (not modifier or modifier.can_interact_with_tool(self, active_tool, "talk")))
		if not can_talk_with_tool:
			if tool_ctrl:
				tool_ctrl.handle_npc_click(self, GameState.player)
			return
	if dialogue_resource:
		GameState.character_talking = self
		DialogueManager.show_dialogue_balloon_scene(custom_balloon, dialogue_resource, speaking_title, [self])

func _on_dialouge_started(_dialogue_resource: DialogueResource) -> void:
	if patience_timer.time_left > 0.0:
		_dialouge_paused_patience = patience_timer.time_left
		patience_timer.stop()

func _on_dialogue_ended(_dialogue_resource: DialogueResource) -> void:
	if _dialouge_paused_patience >= 0.0 and not is_leaving:
		patience_timer.start(maxf(0.01, _dialouge_paused_patience))
		_dialouge_paused_patience = -1.0

func can_accept_drink() -> bool:
	var base_ok := not is_leaving and drink_list.size() > 0 and has_receipt_spawned and not GameState.is_dialogue_open
	if not base_ok:
		return false
	if species_def and not species_def.can_accept_drink(self):
		return false
	if modifier and not modifier.can_accept_drink(self):
		return false
	return true

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled:
		return
	_is_highlighted = enabled
	if enabled:
		_original_modulate = modulate
		modulate = _original_modulate * Color(1.5, 1.5, 0.4, 1.0)
	else:
		modulate = _original_modulate

func show_floating_feedback(message: String) -> void:
	if not is_inside_tree():
		return
	var label3d := Label3D.new()
	label3d.text = message
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.no_depth_test = true
	label3d.font_size = 48
	label3d.outline_size = 12
	label3d.modulate = Color(1.0, 0.9, 0.35, 1.0)
	var inv := 0.5 / maxf(base_scale.x, 0.1)
	label3d.scale = Vector3.ONE * minf(1.8, inv)
	label3d.position = Vector3(0.0, 1.35, 0.1)
	add_child(label3d)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label3d, "position:y", label3d.position.y + 0.55, 1.0)
	tween.tween_property(label3d, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label3d.queue_free)

func _moving_to(to: Marker3D) -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var offset := Vector3(0.0, species_def.seat_y_offset, 0.0) if species_def else Vector3.ZERO
	tween.tween_property(self, "position", to.position + offset, 0.8)
	current_state = State.SIT

func _start_bounce() -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = get_tree().create_tween().set_loops()
	_bounce_tween.tween_method(_apply_bounce_scale, 1.0, 1.01, 0.5)
	_bounce_tween.tween_method(_apply_bounce_scale, 1.01, 1.0, 0.4)
	_bounce_tween.tween_interval(0.1)

# Serving and payouts
func deliver_cup(glass: Glasses) -> void:
	if not is_instance_valid(glass):
		return
	glass.drink_mix.cup_capacity = glass.size
	if glass.drink_mix.glass_type == "":
		var glass_hint := (glass.scene_file_path + " " + str(glass.name)).to_lower()
		if "shot" in glass_hint:
			glass.drink_mix.glass_type = "shot"
		elif "beer" in glass_hint:
			glass.drink_mix.glass_type = "beer"
	receive_drink(glass.drink_mix)
	var handled := false
	if modifier and modifier.consume_delivered_cup(self, glass):
		handled = true
	elif species_def and species_def.consume_delivered_cup(self, glass):
		handled = true
	if not handled:
		glass._dranked()

func receive_drink(mix: DrinkMix) -> float:
	var want = drink_list.pop_front()
	if want == null:
		return 0.0

	var wanted_order: DrinkOrder = want if want is DrinkOrder else DrinkOrder.from_legacy_want(want)
	var attempt_override: Dictionary = modifier.evaluate_drink_attempt(self, mix, wanted_order) if modifier else {}
	if not attempt_override.get("rejected", false) and species_def:
		var species_override := species_def.evaluate_drink_attempt(self, mix, wanted_order)
		if not species_override.is_empty():
			attempt_override = species_override

	if attempt_override.get("rejected", false):
		var override_score: float = float(attempt_override.get("score", 0.0))
		if attempt_override.get("zero_satisfaction", false):
			customer_satisfaction = 0.0
		if attempt_override.get("clear_orders", false):
			drink_list.clear()
		_apply_reputation_impact(false, override_score)
		_calculate_payout(override_score, false)
		has_receipt_spawned = false
		if attempt_override.has("emo"):
			emo = str(attempt_override["emo"])
			_talking(false)
		if attempt_override.has("feedback") and str(attempt_override["feedback"]) != "":
			show_floating_feedback(str(attempt_override["feedback"]))
		_on_all_orders_completed(override_score)
		return override_score

	var score_data := DrinkScorer.score_drink(mix, wanted_order)
	if modifier:
		modifier.on_score_drink(self, mix, wanted_order, score_data)
		score_data["score"] = clampf(float(score_data["score"]), 0.0, 1.0)
		score_data["is_satisfactory"] = float(score_data["score"]) >= DrinkScorer.SATISFACTORY_THRESHOLD
	var drink_score: float = score_data["score"]

	if species_def:
		species_def.on_drink_served(self, mix, wanted_order, score_data)
	if modifier:
		modifier.on_drink_served(self, mix, wanted_order, score_data)

	var is_satisfactory: bool = drink_score >= SATISFACTORY_THRESHOLD
	if not is_satisfactory:
		customer_satisfaction = maxf(0.0, customer_satisfaction - (1.0 - drink_score))

	_replenish_patience(drink_score)
	_apply_reputation_impact(is_satisfactory, drink_score)
	_calculate_payout(drink_score, is_satisfactory)

	has_receipt_spawned = false

	if drink_list.size() > 0:
		var col = get_node_or_null("Area3D/CollisionShape3D")
		if col:
			col.disabled = false
		can_talk = true
		speaking_title = _get_next_order_title()
		if is_instance_valid(patient_2d):
			patient_2d._recipt_obtain()
		return drink_score

	_on_all_orders_completed(drink_score)
	return drink_score

func _get_next_order_title() -> String:
	if dialogue_resource and dialogue_resource.get_titles().has("next_order"):
		return "next_order"
	return "start"

func _obtain_drink(drink: Variant) -> float:
	if drink is DrinkMix:
		return receive_drink(drink as DrinkMix)
	elif drink is Array:
		return receive_drink(DrinkMix.from_legacy_layers(drink as Array))
	return 0.0

func _replenish_patience(drink_score: float) -> void:
	var replenish_time := REPLENISH_BASE_TIME * drink_score
	if species_def:
		replenish_time = species_def.modify_patience_replenish(self, replenish_time, drink_score)
	if modifier:
		replenish_time = modifier.modify_patience_replenish(self, replenish_time, drink_score)
	if replenish_time > 0.0:
		var new_patience := minf(max_patience, patience_timer.time_left + replenish_time)
		patience_timer.start(maxf(0.01, new_patience))

func _apply_reputation_impact(is_satisfactory: bool, drink_score: float) -> void:
	var race_name := _get_race_display_name()
	if is_satisfactory:
		var overall_delta: float = OVERALL_REP_GAIN_ON_SATISFACTORY
		var species_delta: float = SPECIES_REP_GAIN_ON_SATISFACTORY
		if species_def:
			overall_delta = species_def.modify_overall_reputation_delta(self, overall_delta, true, drink_score)
			species_delta = species_def.modify_species_reputation_delta(self, race_name, species_delta, true, drink_score)
		if modifier:
			overall_delta = modifier.modify_overall_reputation_delta(self, overall_delta, true, drink_score)
			species_delta = modifier.modify_species_reputation_delta(self, race_name, species_delta, true, drink_score)
		PlayerStats.add_overall_reputation(overall_delta)
		PlayerStats.change_species_reputation(race_name, species_delta)
	else:
		var species_delta: float = -((1.0 - drink_score) * SPECIES_REP_LOSS_MULTIPLIER)
		if species_def:
			species_delta = species_def.modify_species_reputation_delta(self, race_name, species_delta, false, drink_score)
		if modifier:
			species_delta = modifier.modify_species_reputation_delta(self, race_name, species_delta, false, drink_score)
		PlayerStats.change_species_reputation(race_name, species_delta)

func _calculate_payout(drink_score: float, is_satisfactory: bool) -> void:
	var race_name := _get_race_display_name()
	var group_rep: float = PlayerStats.get_species_reputation(race_name)
	var score_factor := drink_score if SCALE_BASE_PAYOUT_BY_SCORE else 1.0
	var quality_mult := SATISFACTORY_PAYOUT_MULTIPLIER if is_satisfactory else UNSATISFACTORY_PAYOUT_MULTIPLIER
	var base_payout := BASE_DRINK_PRICE * score_factor * quality_mult
	var payment := base_payout

	var after_species_payout := payment
	if species_def:
		after_species_payout = species_def.modify_payout(self, BASE_DRINK_PRICE, is_satisfactory, drink_score, payment)
	var species_payout_delta := after_species_payout - payment
	payment = after_species_payout

	var after_mod_payout := payment
	if modifier:
		after_mod_payout = modifier.modify_payout(self, BASE_DRINK_PRICE, is_satisfactory, drink_score, payment)
	var mod_payout_delta := after_mod_payout - payment
	payment = after_mod_payout

	var overall_tip_part := 0.0
	var species_tip_part := 0.0
	var tip_quality_mult := SATISFACTORY_TIP_MULTIPLIER if is_satisfactory else UNSATISFACTORY_TIP_MULTIPLIER
	var raw_tip := 0.0
	var mod_tip_delta := 0.0
	var species_tip_delta := 0.0
	var final_tip := 0.0

	if drink_list.size() <= 0:
		overall_tip_part = PlayerStats.overall_reputation * TIP_OVERALL_REP_MULTIPLIER
		species_tip_part = group_rep * TIP_SPECIES_REP_MULTIPLIER
		raw_tip = (overall_tip_part + species_tip_part) * customer_satisfaction * tip_quality_mult
		var tip := raw_tip
		if modifier:
			var after_mod_tip := modifier.modify_tip(self, tip, is_satisfactory, drink_score)
			mod_tip_delta = after_mod_tip - tip
			tip = after_mod_tip
		if species_def:
			var after_sp_tip := species_def.modify_tip(self, tip, is_satisfactory, drink_score)
			species_tip_delta = after_sp_tip - tip
			tip = after_sp_tip
		final_tip = tip
		payment += final_tip

	payment_global += payment

	print("Payout (%s, seat #%d)" % [race_name, seat_num])
	print("  options: BASE_DRINK_PRICE: $%.2f | SCALE_BY_SCORE: %s | SAT_MULT: %.2f | UNSAT_MULT: %.2f | TIMEOUT: $%.2f" % [BASE_DRINK_PRICE, str(SCALE_BASE_PAYOUT_BY_SCORE), SATISFACTORY_PAYOUT_MULTIPLIER, UNSATISFACTORY_PAYOUT_MULTIPLIER, PATIENCE_TIMEOUT_PAYOUT])
	print("  options: TIP_OVERALL_MULT: %.2f | TIP_SPECIES_MULT: %.2f | SAT_TIP_MULT: %.2f | UNSAT_TIP_MULT: %.2f" % [TIP_OVERALL_REP_MULTIPLIER, TIP_SPECIES_REP_MULTIPLIER, SATISFACTORY_TIP_MULTIPLIER, UNSATISFACTORY_TIP_MULTIPLIER])
	print("  base_payout: $%.2f (score=%.3f, score_factor=%.3f, quality_mult=%.2f, satisfactory=%s)" % [base_payout, drink_score, score_factor, quality_mult, str(is_satisfactory)])
	print("  species_payout_delta: %+.2f | modifier_payout_delta: %+.2f" % [species_payout_delta, mod_payout_delta])
	if drink_list.size() <= 0:
		print("  tip_raw: $%.2f (overall=%.2f -> %.2f, species=%.2f -> %.2f, satisfaction=%.2f, tip_mult=%.2f)" % [raw_tip, PlayerStats.overall_reputation, overall_tip_part, group_rep, species_tip_part, customer_satisfaction, tip_quality_mult])
		print("  modifier_tip_delta: %+.2f | species_tip_delta: %+.2f | final_tip: $%.2f" % [mod_tip_delta, species_tip_delta, final_tip])
	else:
		print("  tip: deferred (%d order(s) remaining)" % drink_list.size())
	print("  this_drink_payment: $%.2f | total_payment_global: $%.2f" % [payment, payment_global])

func _on_all_orders_completed(drink_score: float) -> void:
	var col = get_node_or_null("Area3D/CollisionShape3D")
	if col:
		col.disabled = false
	can_talk = true
	_update_speaking_title(drink_score)
	if is_instance_valid(patient_2d):
		patient_2d._recipt_obtain()

func _update_speaking_title(drink_score: float) -> void:
	if not unique_talk:
		if drink_score >= POSITIVE_SCORE_THRESHOLD:
			speaking_title = "Positive"
		elif drink_score >= MID_SCORE_THRESHOLD:
			speaking_title = "Mid"
		else:
			speaking_title = "Negative"
	else:
		patience_timer.wait_time = 100.0
		patience_timer.stop()
		if drink_score >= POSITIVE_SCORE_THRESHOLD:
			speaking_title = "introduction_mid_good"
		elif drink_score >= MID_SCORE_THRESHOLD:
			speaking_title = "introduction_mid_mid"
		else:
			speaking_title = "introduction_mid_bad"

func _give_payment() -> void:
	print("[Payout] Giving final payment: $%.2f" % payment_global)
	PlayerStats._change_money(PlayerStats.money + payment_global)
	payment_global = 0.0
	var col = get_node_or_null("Area3D/CollisionShape3D")
	if col and drink_list.size() <= 0:
		col.disabled = true
	_leaving()

# Orders
func _want_drink() -> Array:
	if speaking_title == "tutorial_walk":
		var tutorial_order := DrinkOrder.new()
		tutorial_order.species_id = species_def.species_id if species_def else "HUMAN"
		tutorial_order.ingredients["gin"] = 1.0
		drink_list.push_back(tutorial_order)
		return drink_list.duplicate()

	if species_def:
		var generated := species_def.generate_orders(self, modifier, PlayerStats)
		if modifier:
			modifier.on_generate_orders(self, generated)
		for order in generated:
			drink_list.push_back(order)
	else:
		var fallback_order := DrinkOrder.new()
		fallback_order.species_id = "HUMAN"
		fallback_order.ingredients["gin"] = 1.0
		var fallback_orders: Array[DrinkOrder] = [fallback_order]
		if modifier:
			modifier.on_generate_orders(self, fallback_orders)
		drink_list.push_back(fallback_order)

	return drink_list.duplicate()

func _item_print() -> String:
	if drink_list.is_empty():
		return ""
	var total: String = ""
	var cup = drink_list[0]
	if cup is DrinkOrder:
		var order := cup as DrinkOrder
		if order.recipe_name != "":
			total += order.recipe_name + "\n"
		var ing_dict: Dictionary = order.ingredients
		for ing_name in ing_dict:
			var pct: int = int(round(float(ing_dict[ing_name]) * 100.0))
			total += str(ing_name) + " " + str(pct) + "%\n"
		if species_def:
			total = species_def.format_order_text(order, total)
		if modifier:
			total = modifier.format_order_text(order, total)
	elif cup is Array:
		for item in cup:
			if item is Array and item.size() >= 2:
				var pct: int = int(round(float(item[1]) * 100.0))
				total += str(item[0]) + " " + str(pct) + "%\n"
	return total

func _current_order_text() -> String:
	return _item_print().strip_edges().replace("\n", ", ")

func _add_recipt() -> void:
	if has_receipt_spawned or drink_list.is_empty():
		return
	has_receipt_spawned = true
	if is_instance_valid(patient_2d) and patient_2d.has_method("_recipt_hide"):
		patient_2d._recipt_hide()
	var race_name: String = species_def.species_id if species_def else (npc_resource.race if npc_resource else "")
	if GameState.seat_manager:
		GameState.seat_manager.add_receipt(seat_num, str(_item_print()), race_name)

func _leaving() -> void:
	if is_leaving:
		return
	is_leaving = true
	set_highlight(false)
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:x", -7.0, 1.5)

	await tween.finished
	if GameState.seat_manager:
		GameState.seat_manager.free_seat(seat_num)
	queue_free()

func _on_patience_timer_timeout() -> void:
	if is_leaving:
		return
	patience_timer.stop()
	print("[Payout] Patience timed out (seat #%d) -> PATIENCE_TIMEOUT_PAYOUT: $%.2f" % [seat_num, PATIENCE_TIMEOUT_PAYOUT])
	PlayerStats._change_money(PlayerStats.money + PATIENCE_TIMEOUT_PAYOUT)
	if GameState.seat_manager:
		GameState.seat_manager.on_patience_ended(seat_num)
	if not unique_talk:
		_leaving()

# Dialogue manager hooks
func _tutorial_enabler(scene_string: String) -> void:
	if scene_string == "Keys":
		return
	var scene_path := "res://UI/Tutorial/" + scene_string + ".tscn"
	if not ResourceLoader.exists(scene_path):
		return
	var tutorial_scene = load(scene_path).instantiate()
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		canvas.add_child(tutorial_scene)
	else:
		add_child(tutorial_scene)

func _check_tutorial() -> bool:
	var canvas = get_node_or_null("CanvasLayer")
	var children = canvas.get_children() if canvas else []
	if children.is_empty() or children[0].is_queued_for_deletion():
		return true
	if children[0].has_method("_tutorial_finished"):
		var finished: bool = children[0]._tutorial_finished()
		if finished and children[0].has_method("_bye_bye"):
			children[0]._bye_bye()
		return finished
	return true

func night_popup(_arg = null) -> void:
	if GameState.gameplay_ui and GameState.gameplay_ui.has_method("_night_title_popup"):
		GameState.gameplay_ui._night_title_popup()

func hold_night_end(hold: bool = true) -> void:
	GameState.hold_night_end(hold)

# Input and hover interactions
func _on_interaction_input_event(camera_node: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape: int) -> void:
	if Ingredients.active_dragging_item != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if abs(camera_node.global_position.x - global_position.x) < 2 or unique_talk:
			var tool_ctrl := _get_tool_controller()
			if not unique_talk and tool_ctrl:
				if tool_ctrl.handle_npc_click(self, GameState.player):
					return
			if can_talk and speaking_title != "" and speaking_title != null:
				talk()

func _on_area_3d_mouse_entered() -> void:
	if Ingredients.active_dragging_item != null:
		return
	var tool_ctrl := _get_tool_controller()
	var active_tool := _get_active_tool()
	if tool_ctrl:
		tool_ctrl.handle_npc_hover(self, true)
	else:
		if species_def:
			species_def.on_npc_tool_hover(self, active_tool, true)
		if modifier:
			modifier.on_npc_tool_hover(self, active_tool, true)
	if not can_talk or speaking_title == "" or speaking_title == null:
		return
	if not unique_talk:
		var can_hover: bool = tool_ctrl.can_npc_interact_with_tool(self, "hover") if tool_ctrl else ((not species_def or species_def.can_interact_with_tool(self, active_tool, "hover")) and (not modifier or modifier.can_interact_with_tool(self, active_tool, "hover")))
		if not can_hover:
			return
	if GameState.player:
		GameState.player._update_hand("interact")

func _on_area_3d_mouse_exited() -> void:
	if Ingredients.active_dragging_item != null:
		return
	var tool_ctrl := _get_tool_controller()
	var active_tool := _get_active_tool()
	if tool_ctrl:
		tool_ctrl.handle_npc_hover(self, false)
	else:
		if species_def:
			species_def.on_npc_tool_hover(self, active_tool, false)
		if modifier:
			modifier.on_npc_tool_hover(self, active_tool, false)
	if GameState.player:
		GameState.player._update_hand("idle")

func _on_area_Obtain_drink_entered(area: Area3D) -> void:
	if area is Glasses and area.is_in_group("glass"):
		var glass := area as Glasses
		if glass.is_balls_dragging or not glass.is_being_served or glass.is_delivering or glass.is_consumed:
			return
		if not can_accept_drink():
			return
		deliver_cup(glass)

func _talking(open_mouth: bool = false) -> void:
	var frame_check := 0
	match emo:
		"netural": frame_check = 0
		"happy": frame_check = 2
		"mad": frame_check = 4
		_: frame_check = 0
	if open_mouth:
		frame_check += 1
	var total_frames := hframes * vframes
	if frame_check < total_frames:
		frame = frame_check