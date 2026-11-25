# Spawns random weighted customers and story patrons via SpeciesRegistry
# Does order receipts on the ReceiptBoard
# Cup delivery tweening and drink serving
class_name SeatManager
extends Node

const BASE_NPC_SCENE := preload("res://NPC/base npc.tscn")
const RECEIPT_SCENE := preload("res://NPC/Recipt/recipt_scene.tscn")

var seats: Array[Base_NPC] = [null, null, null]
var receipt_board: ReceiptBoard = ReceiptBoard.new()
var main_root: Node3D

var is_spawning_allowed: bool = false
var spawn_timer_acc: float = 0.0

func setup(host: Node3D) -> void:
	main_root = host
	receipt_board.setup(host)

func start_spawning() -> void:
	is_spawning_allowed = true
	spawn_timer_acc = 16.0

func stop_spawning() -> void:
	is_spawning_allowed = false

func _process(delta: float) -> void:
	if not is_spawning_allowed or GameState.special_state or GameState.night_paused:
		return
	if get_empty_seat_count() <= 0:
		return

	var spawn_interval := maxf(4.0, 16.0 / PlayerStats.get_spawn_rate())
	spawn_timer_acc += delta
	if spawn_timer_acc >= spawn_interval:
		spawn_timer_acc = 0.0
		spawn_random_customer()

func get_empty_seat_count() -> int:
	return seats.count(null)

func is_completely_empty() -> bool:
	return get_empty_seat_count() == seats.size()

func has_any_customers() -> bool:
	return get_empty_seat_count() < seats.size()

func has_special_story_customer() -> bool:
	for npc in seats:
		if npc and is_instance_valid(npc) and npc.unique_talk:
			return true
	return false

func get_customer_at_seat(seat_number: int) -> Base_NPC:
	var idx := seat_number - 1
	if idx >= 0 and idx < seats.size():
		return seats[idx]
	return null

func set_all_patience_paused(paused: bool) -> void:
	for npc in seats:
		if npc and is_instance_valid(npc) and npc.patience_timer:
			npc.patience_timer.paused = paused

func spawn_customer(npc_source: Variant, patience: float = 90.0, dialogue_title: String = "start", forced_modifier: String = "") -> Base_NPC:
	var free_seat := seats.find(null)
	if free_seat == -1 or not main_root:
		return null

	var resolved_resource: NPC = null
	if npc_source is NPC:
		resolved_resource = npc_source as NPC
	elif npc_source is String:
		resolved_resource = load(npc_source) as NPC

	var npc: Base_NPC = BASE_NPC_SCENE.instantiate()
	main_root.add_child(npc)

	var spawn_marker := main_root.get_node_or_null("Spawn") as Node3D
	if spawn_marker:
		npc.global_position = spawn_marker.global_position

	seats[free_seat] = npc
	npc.name = "seat%d_npc" % (free_seat + 1)

	var rec_marker := main_root.get_node_or_null("Recipt%d" % (free_seat + 1)) as Marker3D
	var effect: Dictionary = {
		"patience_multiplier" : 1.0,
		"payout_multiplier" : 1.0,
	}
	if is_instance_valid(GameState.jukebox_manager):
		effect = GameState.jukebox_manager.get_customer_effect()

	npc.jukebox_patience_multiplier = float(effect["patience_multiplier"])
	npc.jukebox_payout_multiplier = float(effect["payout_multiplier"])

	npc.setup_npc(resolved_resource, free_seat + 1, rec_marker, patience, dialogue_title, forced_modifier)

	var target_seat := main_root.get_node_or_null("Seat%d" % (free_seat + 1)) as Marker3D
	if target_seat:
		npc._moving_to(target_seat)

	npc._want_drink()

	return npc

func spawn_customer_by_species(sp: SpeciesBase, patience: float = -1.0, dialogue_title: String = "start", forced_modifier: String = "") -> Base_NPC:
	if sp == null:
		return null
	var effective_patience := patience if patience > 0.0 else sp.default_patience
	return spawn_customer(sp.get_npc_resource(), effective_patience, dialogue_title, forced_modifier)

func spawn_random_customer() -> Base_NPC:
	var weighted_entries := SpeciesRegistry.get_spawnable_species_weights(PlayerStats)
	if weighted_entries.is_empty():
		var fallback := SpeciesRegistry.get_species_or_default("HUMAN")
		return spawn_customer_by_species(fallback)

	var total_weight: float = 0.0
	for entry in weighted_entries:
		total_weight += float(entry["weight"])

	var roll := randf_range(0.0, total_weight)
	var acc: float = 0.0
	var chosen: SpeciesBase = weighted_entries[0]["species"]
	for entry in weighted_entries:
		acc += float(entry["weight"])
		if roll <= acc:
			chosen = entry["species"]
			break

	return spawn_customer_by_species(chosen)

func spawn_specific_species(species_name: String) -> Base_NPC:
	var sp := SpeciesRegistry.get_species_or_default(species_name)
	return spawn_customer_by_species(sp)

func spawn_specific_with_modifier(modifier_name: String, species_name: String = "") -> Base_NPC:
	var mod_proto := ModifierRegistry.get_modifier(modifier_name)
	var chosen: SpeciesBase = null

	if species_name != "":
		var candidate := SpeciesRegistry.get_species_or_default(species_name)
		if candidate and (mod_proto == null or mod_proto.can_apply_to_species(candidate.species_id, false, PlayerStats)):
			chosen = candidate

	if chosen == null:
		var eligible_entries: Array[Dictionary] = []
		var total_weight: float = 0.0
		for entry in SpeciesRegistry.get_spawnable_species_weights(PlayerStats):
			var sp: SpeciesBase = entry["species"]
			if sp and (mod_proto == null or mod_proto.can_apply_to_species(sp.species_id, false, PlayerStats)):
				eligible_entries.append(entry)
				total_weight += float(entry["weight"])

		if not eligible_entries.is_empty():
			var roll := randf_range(0.0, total_weight)
			var acc: float = 0.0
			chosen = eligible_entries[0]["species"]
			for entry in eligible_entries:
				acc += float(entry["weight"])
				if roll <= acc:
					chosen = entry["species"]
					break

	if chosen == null:
		for sp in SpeciesRegistry.get_all_species():
			if mod_proto == null or mod_proto.can_apply_to_species(sp.species_id, false, PlayerStats):
				chosen = sp
				break

	if chosen == null:
		chosen = SpeciesRegistry.get_species_or_default("HUMAN")

	return spawn_customer_by_species(chosen, -1.0, "start", modifier_name)

func spawn_custom_customer(species_id: String = "", modifier_id: String = "__NATURAL__") -> Base_NPC:
	if get_empty_seat_count() <= 0:
		return null
	var clean_sp := species_id.strip_edges()
	var clean_mod := modifier_id.strip_edges()

	if clean_mod == "" or clean_mod == "__NATURAL__":
		if clean_sp == "":
			return spawn_random_customer()
		return spawn_specific_species(clean_sp)

	if clean_mod == "__NONE__" or clean_mod.to_upper() == "NONE":
		var chosen: SpeciesBase = null
		if clean_sp != "":
			chosen = SpeciesRegistry.get_species_or_default(clean_sp)
		else:
			var weighted_entries := SpeciesRegistry.get_spawnable_species_weights(PlayerStats)
			if not weighted_entries.is_empty():
				var total_weight: float = 0.0
				for entry in weighted_entries:
					total_weight += float(entry["weight"])
				var roll := randf_range(0.0, total_weight)
				var acc: float = 0.0
				chosen = weighted_entries[0]["species"]
				for entry in weighted_entries:
					acc += float(entry["weight"])
					if roll <= acc:
						chosen = entry["species"]
						break
			else:
				chosen = SpeciesRegistry.get_species_or_default("HUMAN")
		return spawn_customer_by_species(chosen, -1.0, "start", "NONE")

	return spawn_specific_with_modifier(clean_mod, clean_sp)

func take_all_pending_orders() -> int:
	var count := 0
	for npc in seats:
		if not is_instance_valid(npc) or npc.is_leaving:
			continue
		if npc.has_receipt_spawned or npc.drink_list.is_empty():
			continue
		if npc.unique_talk:
			if npc.speaking_title == "tutorial_walk" or npc.speaking_title == "tutorial_walk_finished":
				npc.can_talk = true
				npc.speaking_title = "introduction_mid_talk"
		else:
			npc.speaking_title = "mid"
		npc._add_recipt()
		count += 1
	return count

func remove_customer_at_seat(seat_number: int) -> void:
	var idx := seat_number - 1
	if idx >= 0 and idx < seats.size():
		var npc := seats[idx]
		if npc:
			seats[idx] = null
			clear_receipt_for_seat(seat_number)
			npc._leaving()

func remove_first_occupied_seat() -> void:
	for i in seats.size():
		if seats[i] != null:
			remove_customer_at_seat(i + 1)
			break

func free_seat(seat_number: int) -> void:
	var idx := seat_number - 1
	if idx >= 0 and idx < seats.size():
		seats[idx] = null

	if GameState.special_state and not has_special_story_customer():
		if GameState.night_manager:
			GameState.night_manager.start_night_shift()

	if is_completely_empty() and GameState.night_manager:
		GameState.night_manager.check_night_concluded(true)

func clear_all_customers() -> void:
	for seat_idx in seats.size():
		var npc := seats[seat_idx]
		if npc:
			seats[seat_idx] = null
			clear_receipt_for_seat(seat_idx + 1)
			npc._leaving()

func add_receipt(seat: int, order_text: String, customer_race: String = "", customer_icon: Texture2D = null) -> void:
	if not main_root:
		return
	var string_name := "ReciptPaper" + str(seat)
	var recipt_node := main_root.get_node_or_null(string_name)
	if not recipt_node:
		recipt_node = RECEIPT_SCENE.instantiate()
		recipt_node.name = string_name
		recipt_node.seat_num = seat
		recipt_node.counter_origin = main_root.get_node_or_null("Coutner")
		main_root.add_child(recipt_node)

	var npc: Base_NPC = null
	if seat >= 1 and seat <= seats.size():
		npc = seats[seat - 1]
		if npc and is_instance_valid(npc) and customer_race == "" and npc.npc_resource:
			customer_race = npc.npc_resource.race

	if recipt_node.has_method("_set_customer_info"):
		recipt_node._set_customer_info(seat, customer_race, customer_icon)
	if recipt_node.has_method("apply_customer_visuals"):
		recipt_node.apply_customer_visuals(
			npc.species_def if is_instance_valid(npc) else null,
			npc.modifier if is_instance_valid(npc) else null
		)
	elif recipt_node.has_method("apply_modifier_visuals"):
		recipt_node.apply_modifier_visuals(npc.modifier if is_instance_valid(npc) else null)
	recipt_node._write(order_text)
	recipt_node.ordered = true

	var player = GameState.player
	if player:
		recipt_node.global_position = player.global_position

	if not receipt_board.mount_receipt(recipt_node):
		var marker_node := main_root.get_node_or_null("Recipt" + str(seat))
		if marker_node:
			var tween := main_root.get_tree().create_tween()
			tween.tween_property(recipt_node, "global_position", marker_node.global_position, 0.5)

func clear_receipt_for_seat(seat_number: int) -> void:
	if not main_root:
		return
	var recipt_node := main_root.get_node_or_null("ReciptPaper" + str(seat_number))
	if recipt_node:
		receipt_board.release_receipt(recipt_node)
		var hidden := main_root.get_node_or_null("HiddenRecipt") as Node3D
		if hidden:
			recipt_node.global_position = hidden.global_position

func serve_cup_to_npc(drink: Glasses, npc: Base_NPC) -> void:
	var seat := npc.seat_num
	clear_receipt_for_seat(seat)
	var seat_marker := main_root.get_node_or_null("SeatDrink" + str(seat)) as Node3D
	var target_pos := seat_marker.global_position if seat_marker else npc.global_position
	if npc.species_def:
		target_pos = npc.species_def.prepare_cup_delivery(npc, drink, target_pos)
	if npc.modifier:
		target_pos = npc.modifier.prepare_cup_delivery(npc, drink, target_pos)

	drink.is_delivering = true
	var tween := main_root.get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(drink, "global_position", target_pos, 0.25)
	await tween.finished

	if is_instance_valid(drink):
		drink.is_delivering = false

	if is_instance_valid(drink) and not drink.is_consumed and is_instance_valid(npc):
		if npc.has_method("receive_drink"):
			npc.receive_drink(drink.drink_mix)
		else:
			npc._obtain_drink(drink._return_drink())
		var handled := false
		if npc.modifier and npc.modifier.consume_delivered_cup(npc, drink):
			handled = true
		elif npc.species_def and npc.species_def.consume_delivered_cup(npc, drink):
			handled = true
		if not handled:
			drink._dranked()

func on_patience_ended(seat_num: int) -> void:
	if not main_root:
		return
	var recipt_node := main_root.get_node_or_null("ReciptPaper" + str(seat_num))
	if not recipt_node:
		return
	receipt_board.release_receipt(recipt_node)
	if recipt_node.is_balls_dragging:
		recipt_node._finish_drag_or_click()
	var hidden := main_root.get_node_or_null("HiddenRecipt") as Node3D
	if hidden:
		var tween := main_root.get_tree().create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(recipt_node, "global_position", hidden.global_position, 0.1)

func debug_serve_all(score_type: String = "good") -> void:
	for seat_idx in seats.size():
		var npc := seats[seat_idx]
		if not is_instance_valid(npc) or npc.is_leaving:
			continue
		if npc.unique_talk and GameState.gameplay_ui and "tutorial_director" in GameState.gameplay_ui:
			var td = GameState.gameplay_ui.tutorial_director
			if td and td.has_method("cancel_tutorial"):
				td.cancel_tutorial(GameState.gameplay_ui)
		while npc.drink_list.size() > 0:
			var want = npc.drink_list[0]
			clear_receipt_for_seat(seat_idx + 1)
			if score_type == "good":
				if want is DrinkOrder:
					var order := want as DrinkOrder
					var mix := DrinkMix.new()
					for ing_id in order.ingredients:
						mix.add_liquid(str(ing_id), float(order.ingredients[ing_id]))
					for tag in order.required_processing:
						mix.add_processing(str(tag))
					for g in order.garnishes:
						mix.add_garnish(str(g))
					mix.glass_type = order.required_glass
					mix.is_tiny = order.is_tiny
					npc.receive_drink(mix)
				elif want is Array:
					npc._obtain_drink((want as Array).duplicate(true))
			else:
				var bad_mix := DrinkMix.new()
				bad_mix.add_liquid("wrong_spirit", 1.0)
				npc.receive_drink(bad_mix)
		if is_instance_valid(npc) and not npc.is_leaving:
			if npc.unique_talk and npc.has_method("night_popup"):
				npc.night_popup()
			npc._give_payment()
