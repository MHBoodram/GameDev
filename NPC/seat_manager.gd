# Spawns random weighted cusotomers and story patrons
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
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

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

func _on_dialogue_started(_resource) -> void:
	GameState.is_dialogue_open = true

func _on_dialogue_ended(_resource) -> void:
	GameState.is_dialogue_open = false
	GameState.character_talking = null

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

func spawn_customer(res_path: String, patience: float = 90.0, dialogue_title: String = "start") -> Base_NPC:
	var free_seat := seats.find(null)
	if free_seat == -1 or not main_root:
		return null

	var npc: Base_NPC = BASE_NPC_SCENE.instantiate()
	main_root.add_child(npc)

	var spawn_marker := main_root.get_node_or_null("Spawn") as Node3D
	if spawn_marker:
		npc.global_position = spawn_marker.global_position

	seats[free_seat] = npc
	npc.name = "seat%d_npc" % (free_seat + 1)

	var target_seat := main_root.get_node_or_null("Seat%d" % (free_seat + 1)) as Marker3D
	if target_seat:
		npc._moving_to(target_seat)

	var rec_marker := main_root.get_node_or_null("Recipt%d" % (free_seat + 1)) as Marker3D
	npc.setup_npc(load(res_path), free_seat + 1, rec_marker, patience, dialogue_title)

	var order := npc._want_drink()
	match free_seat:
		0: GameState.seat1_order = order
		1: GameState.seat2_order = order
		2: GameState.seat3_order = order

	return npc

func spawn_random_customer() -> Base_NPC:
	var human_weight := PlayerStats.get_species_spawn_weight("Human")
	var slime_weight := PlayerStats.get_species_spawn_weight("Slime")
	var vampire_weight := PlayerStats.get_species_spawn_weight("Vampire")
	var total_weight := human_weight + slime_weight + vampire_weight
	var roll := randf_range(0.0, total_weight)

	var path := "res://NPC/Resources/scott.tres"
	if roll < slime_weight:
		path = "res://NPC/Resources/slime.tres"
	elif roll < slime_weight + vampire_weight:
		path = "res://NPC/Resources/cesti.tres"

	return spawn_customer(path)

func spawn_specific_species(species_name: String) -> Base_NPC:
	var path := "res://NPC/Resources/scott.tres"
	match species_name.capitalize():
		"Slime":
			path = "res://NPC/Resources/slime.tres"
		"Vampire":
			path = "res://NPC/Resources/cesti.tres"
		_:
			path = "res://NPC/Resources/scott.tres"
	return spawn_customer(path)

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

	if customer_race == "" and seat >= 1 and seat <= seats.size():
		var npc := seats[seat - 1]
		if npc and is_instance_valid(npc) and npc.npc_resource:
			customer_race = npc.npc_resource.race

	if recipt_node.has_method("_set_customer_info"):
		recipt_node._set_customer_info(seat, customer_race, customer_icon)
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

	var tween := main_root.get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(drink, "global_position", target_pos, 0.25)
	await tween.finished

	if is_instance_valid(drink) and not drink.is_consumed and is_instance_valid(npc):
		if npc.has_method("receive_drink"):
			npc.receive_drink(drink.drink_mix)
		else:
			npc._obtain_drink(drink._return_drink())
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
		if not npc:
			continue
		while npc.drink_list.size() > 0:
			var drink_data: Array = npc.drink_list[0].duplicate(true) if score_type == "good" else [["wrong_spirit", 0]]
			clear_receipt_for_seat(seat_idx + 1)
			npc._obtain_drink(drink_data)
			if npc.unique_talk:
				npc._leaving()