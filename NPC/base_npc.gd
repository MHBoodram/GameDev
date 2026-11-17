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

var modifier: CustomerModifier = CustomerModifier.new()

const SATISFACTORY_THRESHOLD := 0.6
const REPLENISH_BASE_TIME := 30.0
const BASE_DRINK_PRICE := 0.0

var _bounce_tween: Tween

func _ready() -> void:
	if npc_resource:
		max_patience = npc_resource.patience_time
		texture = npc_resource.sprite_sheet
		hframes = npc_resource.hframe
		dialogue_resource = npc_resource.dialogue_resource

	patience_timer.wait_time = max_patience
	patience_timer.start(max_patience)
	patient_2d._setup(max_patience, npc_resource.race if npc_resource else "HUMAN")
	patient_2d._change_max_progress(max_patience)
	patient_2d._change_curent(max_patience)
	camera = get_viewport().get_camera_3d()
	self.texture = npc_resource.sprite_sheet
	hframes = npc_resource.hframe
	_start_bounce()
	dialogue_resource = npc_resource.dialogue_resource

	if not DialogueManager.dialogue_started.is_connected(_on_dialouge_started):
		DialogueManager.dialogue_started.connect(_on_dialouge_started)


	patience_timer.start()
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	var patience_left: float = patience_timer.time_left
	if _dialouge_paused_patience >= 0.0:
		patience_left = _dialouge_paused_patience

	patient_2d._change_curent(patience_left)

	if _dialouge_paused_patience >= 0.0:
		return
	if max_patience > 0.0 and patience_left < max_patience * 0.25:
		var drain_rate: float = (1.0 - patience_left / (max_patience * 0.25)) * 0.05 * delta
		customer_satisfaction = maxf(0.0, customer_satisfaction - drain_rate)

	#if patience_timer.time_left < (max_patience * 0.25) and max_patience > 0.0:
		#var drain_rate: float = (1.0 - (patience_timer / (max_patience * 0.25))) * 0.05 * delta
		#customer_satisfaction = maxf(0.0, customer_satisfaction - drain_rate)

func setup_npc(npc_source: NPC, seat: int, rec_marker: Marker3D, patience: float = 90.0, starting_dialogue: String = "start") -> void:
	npc_resource = npc_source
	seat_num = seat
	recipt_marker = rec_marker
	has_receipt_spawned = false
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
	if starting_dialogue != "start":
		unique_talk = true
		if starting_dialogue == "tutorial_walk":
			can_talk = false

	if npc_resource:
		texture = npc_resource.sprite_sheet
		hframes = npc_resource.hframe
		dialogue_resource = npc_resource.dialogue_resource
		patient_2d._setup(max_patience, npc_resource.race)

	patient_2d._change_max_progress(max_patience)
	patient_2d._change_curent(max_patience)
	if is_instance_valid(patient_2d) and patient_2d.has_method("_recipt_hide"):
		patient_2d._recipt_hide()
	customer_satisfaction = 1.0
	modifier = CustomerModifier.roll_modifier(npc_resource.race if npc_resource else "HUMAN", unique_talk)
	modifier.apply_visuals(self)

func _institate(npc_source: NPC, seat: int, rec_marker: Marker3D, patience: float = 90.0, starting_dialogue: String = "start") -> void:
	setup_npc(npc_source, seat, rec_marker, patience, starting_dialogue)

func talk() -> void:
	if GameState.is_dialogue_open:
		return
	if not can_talk or speaking_title == "" or speaking_title == null:
		return
	if dialogue_resource:
		GameState.character_talking = self
		DialogueManager.show_dialogue_balloon_scene(custom_balloon, dialogue_resource, speaking_title, [self])

func _on_dialouge_started(dialogue_resource : DialogueResource) -> void:
	if patience_timer.time_left > 0.0:
		_dialouge_paused_patience = patience_timer.time_left
		patience_timer.stop()

func _on_dialogue_ended(dialogue_resource : DialogueResource) -> void:
	if _dialouge_paused_patience >= 0.0 and not is_leaving:
		patience_timer.start(maxf(0.01, _dialouge_paused_patience))
		_dialouge_paused_patience = -1.0

func can_accept_drink() -> bool:
	return not is_leaving and drink_list.size() > 0 and has_receipt_spawned and not GameState.is_dialogue_open

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled:
		return
	_is_highlighted = enabled
	if enabled:
		_original_modulate = modulate
		modulate = _original_modulate * Color(1.5, 1.5, 0.4, 1.0)
	else:
		modulate = _original_modulate

func _moving_to(to: Marker3D) -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", to.position, 0.8)
	current_state = State.SIT

func _start_bounce() -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = get_tree().create_tween().set_loops()
	_bounce_tween.tween_property(self, "scale", Vector3(0.505, 0.504, 0.5), 0.5)
	_bounce_tween.tween_property(self, "scale", Vector3(0.5, 0.5, 0.5), 0.4)
	_bounce_tween.tween_interval(0.1)

# Serving and payouts
func receive_drink(mix: DrinkMix) -> float:
	var want = drink_list.pop_front()
	if want == null:
		return 0.0

	var wanted_order: DrinkOrder = want if want is DrinkOrder else DrinkOrder.from_legacy_want(want)
	var score_data := DrinkScorer.score_drink(mix, wanted_order)
	var drink_score: float = score_data["score"]

	#if modifier.is_ghost and not modifier.check_ghost_drink(mix):
	#	drink_score = 0.0
	#	customer_satisfaction = 0.0

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
	if replenish_time > 0.0:
		var new_patience := minf(max_patience, patience_timer.time_left + replenish_time)
		patience_timer.start(maxf(0.01, new_patience))

func _apply_reputation_impact(is_satisfactory: bool, drink_score: float) -> void:
	var race_name: String = npc_resource.race if npc_resource else "Human"
	if is_satisfactory:
		PlayerStats.add_overall_reputation(1.0)
		PlayerStats.change_species_reputation(race_name, 1.0)
	else:
		var penalty: float = (1.0 - drink_score) * 2.0
		PlayerStats.change_species_reputation(race_name, -penalty)

func _calculate_payout(drink_score: float, is_satisfactory: bool) -> void:
	var race_name: String = npc_resource.race if npc_resource else "Human"
	var group_rep: float = PlayerStats.get_species_reputation(race_name)
	var payment: float = BASE_DRINK_PRICE

	if race_name.to_upper() == "SLIME" and is_satisfactory:
		payment += BASE_DRINK_PRICE

	if drink_list.size() <= 0:
		var tip := (PlayerStats.overall_reputation + group_rep) * customer_satisfaction
		tip = modifier.calculate_tip_modifier(tip)
		payment += tip

	payment_global += payment

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
		if drink_score >= 0.75:
			speaking_title = "Positive"
		elif drink_score >= 0.5:
			speaking_title = "Mid"
		else:
			speaking_title = "Negative"
	else:
		patience_timer.wait_time = 100.0
		patience_timer.stop()
		if drink_score >= 0.75:
			speaking_title = "introduction_mid_good"
		elif drink_score >= 0.5:
			speaking_title = "introduction_mid_mid"
		else:
			speaking_title = "introduction_mid_bad"

func _give_payment() -> void:
	PlayerStats._change_money(PlayerStats.money + payment_global)
	payment_global = 0.0
	var col = get_node_or_null("Area3D/CollisionShape3D")
	if col and drink_list.size() <= 0:
		col.disabled = true
	_leaving()

# Orders
func _want_drink() -> Array:
	var race_key: String = npc_resource.race.to_upper() if npc_resource else "HUMAN"
	var drink_pool := CustomerTraits.get_species_drink_pool(race_key)
	var drink_count := CustomerTraits.get_order_count(race_key, modifier)

	var total: Array = []
	if speaking_title == "tutorial_walk":
		var order_item := ["gin", 1.0]
		total.append(order_item)
		drink_list.push_back([order_item])
		return total

	for i in range(drink_count):
		if race_key == "VAMPIRE": # this if statement is if the customer is a vamp,
			var non_blood_pool : Array[String] = [] #  they always order a shaken drink with blood as an ingredient
			for candidate in drink_pool:
				if candidate != "blood":
					non_blood_pool.append(candidate)
			var second_drink : String = str(non_blood_pool.pick_random())
			var order := DrinkOrder.new()
			order.ingredients["blood"] = 0.5
			order.ingredients[second_drink] = 0.5
			order.required_processing.append("shaken")

			drink_list.push_back(order)
			total.append([["blood",0.5],[second_drink,0.5]])
			continue

		var drink_name = drink_pool.pick_random()
		var order_item := [drink_name, 1.0]
		total.append(order_item)
		drink_list.push_back([order_item])

	return total

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
	var race_name: String = npc_resource.race if npc_resource else ""
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
	PlayerStats._change_money(PlayerStats.money + BASE_DRINK_PRICE)
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
	if not can_talk or speaking_title == "" or speaking_title == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if abs(camera_node.global_position.x - global_position.x) < 2 or unique_talk:
			talk()

func _on_area_3d_mouse_entered() -> void:
	if Ingredients.active_dragging_item != null:
		return
	if not can_talk or speaking_title == "" or speaking_title == null:
		return
	if GameState.player:
		GameState.player._update_hand("interact")

func _on_area_3d_mouse_exited() -> void:
	if Ingredients.active_dragging_item != null:
		return
	if GameState.player:
		GameState.player._update_hand("idle")

func _on_area_Obtain_drink_entered(area: Area3D) -> void:
	if area is Glasses and area.is_in_group("glass"):
		var glass := area as Glasses
		if glass.is_balls_dragging or not glass.is_being_served or glass.is_consumed:
			return
		if not can_accept_drink():
			return
		receive_drink(glass.drink_mix)
		glass._dranked()

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
