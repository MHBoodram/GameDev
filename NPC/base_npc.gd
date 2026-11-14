extends Sprite3D
class_name Base_NPC
@export var npc_resource : NPC
enum State { SEAT, SIT, EXIT }
var current_state : State = State.SEAT
var seat_num : int
var camera = null
var drink_list : Array = []
var dialogue_resource : DialogueResource
var speaking_title : String = "start"
@export var drink_offset : float = 5
@onready var custom_balloon = load("res://addons/dialogue_manager/example_balloon/main_balloon.tscn")
@onready var patience_timer = get_node("Patience_timer")
@onready var patient_2d = get_node("Sprite3D/SubViewport/Patience")
var recipt_marker : Marker3D
var recipt_clicked : bool = true
var unique_talk : bool = false
var emo: String = "netural"
var customer_satisfaction : float = 1.0
var max_patience : float = 90.0
var payment_global : float
var is_leaving : bool = false
var _is_highlighted : bool = false
var _original_modulate : Color = Color.WHITE
const SATISFACTORY_THRESHOLD := 0.6
const MAX_DIFF := 0.15
const FLAT_PENALTY_WRONG_INGREDIENT := 0.3
const FLAT_PENALTY_MISSING_INGREDIENT := 0.4
const REPLENISH_BASE_TIME := 30.0
const BASE_DRINK_PRICE := 10.0

func _ready() -> void:
	max_patience = npc_resource.patience_time
	patience_timer.wait_time = max_patience
	patient_2d._change_max_progress(max_patience)
	patient_2d._setup(max_patience, npc_resource.race)
	camera = get_viewport().get_camera_3d()
	self.texture = npc_resource.sprite_sheet
	hframes = npc_resource.hframe
	_tween_bounce()
	dialogue_resource = npc_resource.dialogue_resource
	patience_timer.start()

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	patient_2d._change_curent(patience_timer.time_left)
	if patience_timer.time_left < (max_patience * 0.25) and max_patience > 0.0:
		var drain_rate: float = (1.0 - (patience_timer.time_left / (max_patience * 0.25))) * 0.05 * delta
		customer_satisfaction = maxf(0.0, customer_satisfaction - drain_rate)

func talk() -> void:
	if dialogue_resource:
		GameState.character_talking = self
		DialogueManager.show_dialogue_balloon_scene(custom_balloon, dialogue_resource, speaking_title, [self])

func can_accept_drink() -> bool:
	return not is_leaving and drink_list.size() > 0

func set_highlight(enabled: bool) -> void:
	if _is_highlighted == enabled:
		return
	_is_highlighted = enabled
	if enabled:
		_original_modulate = modulate
		modulate = _original_modulate * Color(1.5, 1.5, 0.4, 1.0)
	else:
		modulate = _original_modulate

# Another initailization function
func _institate(npc_source : NPC,seat: int,rec_marker: Marker3D, patience: float = 90,starting_dialogue: String = "start") -> void:
	npc_resource = npc_source
	seat_num = seat
	recipt_marker = rec_marker
	if(patience != 0):
		max_patience = patience
		patience_timer.wait_time = patience
	speaking_title = starting_dialogue
	if(starting_dialogue != "start"):
		unique_talk = true
	_ready()

# Move customer sprite to seat
func _moving_to(to: Marker3D) -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"position",to.position,0.8)
	current_state = State.SIT

func _tween_bounce() -> void:
	var tween = get_tree().create_tween()
	var rand_time = randf_range(0.503,0.505)
	tween.tween_property(self, "scale", Vector3(0.505,rand_time,0.5), 0.5)
	tween.tween_property(self, "scale", Vector3(0.5,0.5,0.5), 0.4)
	await tween.finished
	await get_tree().create_timer(0.1).timeout
	_tween_bounce()

# Opens dialogue on click on customer
@warning_ignore("shadowed_variable", "unused_parameter")
func _on_interaction_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if Ingredients.active_dragging_item != null:
		return
	if(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and abs(camera.global_position.x - global_position.x) < 2):
		talk()

# Changes overall reputation and species reputation based on drink score
func _set_reputation(is_satisfactory: bool, drink_score: float) -> void:
	var race_name: String = npc_resource.race if npc_resource else "Human"
	if is_satisfactory:
		PlayerStats.add_overall_reputation(1.0)
		PlayerStats.change_species_reputation(race_name, 1.0)
	else:
		var penalty: float = (1.0 - drink_score) * 2.0
		PlayerStats.change_species_reputation(race_name, -penalty)

# Gets drink score then gives payment and reputation
func _obtain_drink(drink: Array) -> float:
	var want = drink_list.pop_front()
	if want == null:
		return 0.0
	var drink_score: float = 1.0

	var have_ingredients: Dictionary = {}
	var total_served_amount: float = 0.0
	for layer in drink:
		if layer is Array and layer.size() >= 2:
			if layer.size() > 3 and layer[3] is Dictionary:
				for ing in layer[3]:
					var amt: float = float(layer[3][ing])
					if amt > 0.0:
						have_ingredients[str(ing)] = have_ingredients.get(str(ing), 0.0) + amt
						total_served_amount += amt
			elif layer[0] is Array:
				var split_amt: float = float(layer[1]) / maxf(float(layer[0].size()), 1.0)
				if split_amt > 0.0:
					for ing in layer[0]:
						have_ingredients[str(ing)] = have_ingredients.get(str(ing), 0.0) + split_amt
						total_served_amount += split_amt
			elif layer[0] is Dictionary:
				for ing in layer[0]:
					var amt: float = float(layer[0][ing])
					if amt > 0.0:
						have_ingredients[str(ing)] = have_ingredients.get(str(ing), 0.0) + amt
						total_served_amount += amt
			else:
				var ing_name: String = str(layer[0])
				var amt: float = float(layer[1])
				if amt > 0.0:
					have_ingredients[ing_name] = have_ingredients.get(ing_name, 0.0) + amt
					total_served_amount += amt

	if total_served_amount > 0.0:
		for ing_name in have_ingredients.keys():
			have_ingredients[ing_name] = float(have_ingredients[ing_name]) / total_served_amount

	var total_want_amount: float = 0.0
	for check in want:
		total_want_amount += float(check[1])

	if want.size() > 0 and (have_ingredients.is_empty() or total_served_amount <= 0.0):
		drink_score = 0.0
	else:
		var want_count: float = maxf(float(want.size()), 1.0)
		var missing_penalty: float = maxf(FLAT_PENALTY_MISSING_INGREDIENT, 1.0 / want_count)
		for check in want:
			var check_name: String = check[0]
			var check_amount: float = float(check[1]) / total_want_amount if total_want_amount > 0.0 else float(check[1])
			if have_ingredients.has(check_name):
				var actual_amount: float = float(have_ingredients[check_name])
				var difference: float = abs(check_amount - actual_amount)
				var proportion_penalty: float = 0.0
				if difference <= MAX_DIFF:
					proportion_penalty = 0.3 * (difference / MAX_DIFF)
				else:
					proportion_penalty = 0.3 + 0.7 * clampf((difference - MAX_DIFF) / maxf(check_amount - MAX_DIFF, 0.45), 0.0, 1.0)
				drink_score -= proportion_penalty / want_count
			else:
				drink_score -= missing_penalty

		for have_name in have_ingredients.keys():
			var was_wanted: bool = false
			for check in want:
				if check[0] == have_name:
					was_wanted = true
					break
			if not was_wanted:
				drink_score -= FLAT_PENALTY_WRONG_INGREDIENT

	drink_score = clampf(drink_score, 0.0, 1.0)
	print("[drink_score]: ", drink_score)

	var is_satisfactory: bool = drink_score >= SATISFACTORY_THRESHOLD
	if not is_satisfactory:
		var satisfaction_loss: float = 1.0 - drink_score
		customer_satisfaction = maxf(0.0, customer_satisfaction - satisfaction_loss)
	print("[customer_satisfaction]: ", customer_satisfaction)

	var replenish_time: float = REPLENISH_BASE_TIME * drink_score
	if replenish_time > 0.0:
		var new_patience: float = minf(max_patience, patience_timer.time_left + replenish_time)
		patience_timer.start(maxf(0.01, new_patience))
	print("[patience_replenished]: ", replenish_time)

	_set_reputation(is_satisfactory, drink_score)

	var race_name: String = npc_resource.race if npc_resource else "Human"
	var group_rep: float = PlayerStats.get_species_reputation(race_name)
	var drink_cost: float = BASE_DRINK_PRICE
	var tip: float = 0.0
	var payment: float = drink_cost

	if race_name.to_upper() == "SLIME" and is_satisfactory:
		payment += drink_cost
		print("[slime_refund_payment]: ", payment)

	if drink_list.size() <= 0:
		tip = (PlayerStats.overall_reputation + group_rep) * customer_satisfaction
		payment += tip

	payment_global += payment

	print("[drink_cost]: ", drink_cost)
	print("[tip]: ", tip)
	print("[payment]: ", payment)
	print("[drink score]: ",drink_score)
	if(drink_list.size() <= 0):
		$Area3D/CollisionShape3D.disabled = false
		await get_tree().create_timer(1).timeout
		print("Unique talk: ", unique_talk)
		if(!unique_talk):
			if(drink_score >= 0.75):
				speaking_title = "Positive"
			elif(drink_score >= 0.5):
				speaking_title = "Mid"
			else:
				speaking_title = "Negative"
		else:
			$Area3D/CollisionShape3D.disabled = false
			patience_timer.wait_time = 100
			patience_timer.stop()
			if(drink_score >= 0.75):
				speaking_title = "introduction_mid_good"
			elif(drink_score >= 0.5):
				speaking_title = "introduction_mid_mid"
			else:
				speaking_title = "introduction_mid_bad"
		if is_instance_valid(patient_2d):
			patient_2d._recipt_obtain()
	return drink_score

func _give_payment()-> void:
	PlayerStats._change_money(PlayerStats.money + payment_global)
	payment_global = 0.0
	if(drink_list.size() <= 0):
		$Area3D/CollisionShape3D.disabled = true
	_leaving()
	#_leaving()

func _generate_proportions(ingredient_count: int, increment: float = 0.1) -> Array[float]:
	var proportions: Array[float] = []
	if ingredient_count <= 0:
		return proportions
	if ingredient_count == 1:
		proportions.append(1.0)
		return proportions

	var total_steps: int = maxi(1, int(round(1.0 / increment)))
	if ingredient_count >= total_steps:
		var even_prop: float = 1.0 / float(ingredient_count)
		for i in range(ingredient_count):
			proportions.append(even_prop)
		return proportions

	var available_cuts: Array[int] = []
	for step_idx in range(1, total_steps):
		available_cuts.append(step_idx)
	available_cuts.shuffle()

	var cuts: Array[int] = []
	for i in range(ingredient_count - 1):
		cuts.append(available_cuts[i])
	cuts.sort()

	var prev_cut: int = 0
	for cut in cuts:
		proportions.append(snappedf(float(cut - prev_cut) * increment, increment))
		prev_cut = cut
	proportions.append(snappedf(float(total_steps - prev_cut) * increment, increment))
	return proportions

# Generates random drink and adds it to order queue
func _want_drink() -> Array:
	var drink_list_want = ["beer","gin"]
		
	for drinks in PlayerStats["unlocks"]["Drinks"]:
		if(PlayerStats["unlocks"]["Drinks"][drinks]):
			if not drink_list_want.has(drinks):
				drink_list_want.push_back(drinks)
	
	

	var race_key: String = npc_resource.race.to_upper() if npc_resource else "HUMAN"
	var drink_count: int = 1
	#if race_key == "SLIME":
		#drink_count = randi_range(1, 2)
	if(PlayerStats["unlocks"]["Ingredients"]["Blood"] && race_key == "VAMPIRE"):
		if not drink_list_want.has("blood"):
			drink_list_want.push_back("blood")
	
	var total: Array = []
	if(speaking_title =="tutorial_walk"):
		var order_item = ["gin", 1.0]
		total.append(order_item)
		drink_list.push_front([order_item])
		return total
	
	for i in range(drink_count):
		var drink_name = drink_list_want.pick_random()
		var proportions: Array[float] = _generate_proportions(1)
		var order_item = [drink_name, proportions[0]]
		total.append(order_item)
		drink_list.push_front([order_item])

	print(drink_list)
	return total

# Returns identifier of first requested drink in order queue
func _get_drink() -> String:
	return drink_list[0][0][0] if drink_list.size() > 0 and drink_list[0].size() > 0 else ""

# Tweens customer to exit and frees seat
func _leaving() -> void:
	is_leaving = true
	set_highlight(false)
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"global_position:x", -7,1.5)

	await tween.finished
	get_parent()._remove(seat_num)
	queue_free()

func _add_recipt() -> void:
	var race_name: String = npc_resource.race if npc_resource else ""
	GameState.main_node._add_recipt(seat_num, str(_item_print()), race_name)

# Gets drink from overlapping glass area and triggers empty glass state
func _on_area_Obtain_drink_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		if "is_balls_dragging" in area and area.is_balls_dragging:
			return
		if "is_being_served" in area and not area.is_being_served:
			return
		if "is_consumed" in area and area.is_consumed:
			return
		if not can_accept_drink():
			return
		_obtain_drink(area._return_drink())
		area._dranked()

# Formats current drink order list into text
func _item_print() -> String:
	var total: String = ""
	var show_cup_headers: bool = drink_list.size() > 1
	for drink_idx in range(drink_list.size()):
		var cup_order = drink_list[drink_idx]
		if not (cup_order is Array):
			continue
		if show_cup_headers:
			total += "Drink " + str(drink_idx + 1) + ":\n"
		var items: Array = []
		var raw_sum: float = 0.0
		for y in cup_order:
			if y is Array and y.size() >= 2:
				var amt: float = maxf(0.0, float(y[1]))
				items.append([str(y[0]), amt])
				raw_sum += amt
		if items.is_empty():
			continue
		var percentages: Array[int] = []
		if raw_sum <= 0.0:
			for _i in items.size():
				percentages.append(0)
		else:
			var remainders: Array = []
			var floor_sum: int = 0
			for i in items.size():
				var exact_pct: float = (float(items[i][1]) / raw_sum) * 100.0
				var floored: int = int(floor(exact_pct))
				percentages.append(floored)
				floor_sum += floored
				remainders.append([exact_pct - float(floored), i])
			remainders.sort_custom(func(a, b): return a[0] > b[0])
			var leftover: int = 100 - floor_sum
			for k in range(mini(leftover, remainders.size())):
				var idx: int = int(remainders[k][1])
				percentages[idx] += 1
		for i in items.size():
			total += items[i][0] + " " + str(percentages[i]) + "%\n"
	return total

# Customer leaves when patience timer expires paying only base drink cost
func _on_patience_timer_timeout() -> void:
	if is_leaving:
		return
	patience_timer.stop()
	var drink_cost: float = BASE_DRINK_PRICE
	var tip: float = 0.0
	var payment: float = drink_cost
	print("[drink_cost]: ", drink_cost)
	print("[tip]: ", tip)
	print("[payment]: ", payment)
	PlayerStats._change_money(PlayerStats.money + payment)
	GameState.main_node._npc_patience_end(seat_num)
	if(!unique_talk):
		_leaving()

# Changes cursor to interact on hover
func _on_area_3d_mouse_entered() -> void:
	if Ingredients.active_dragging_item != null:
		return
	GameState.player._update_hand("interact")

# Changes cursor to idle on unhover
func _on_area_3d_mouse_exited() -> void:
	if Ingredients.active_dragging_item != null:
		return
	GameState.player._update_hand("idle")

func _tutorial_enabler(scene_string: String) -> void:
	var tutorial_scene = load("res://UI/Tutorial/" + scene_string + ".tscn").instantiate()
	$CanvasLayer.add_child(tutorial_scene)


func _check_tutorial() -> bool:
	var tutorial_single = $CanvasLayer.get_children()
	if tutorial_single.is_empty() or tutorial_single[0].is_queued_for_deletion():
		return true
	var truth = tutorial_single[0]._tutorial_finished()
	if(truth):
		tutorial_single[0]._bye_bye()
	return truth

func _talking(open_mouth: bool = false):
	var frame_check = 0
	match emo:
		"netural":
			frame_check = 0
		"happy":
			frame_check = 2
		#"sad":
			#frame_check = 0
		"mad":
			frame_check = 4
		_:
			push_warning("CAN'T FIND EMOTION")
			frame_check = 0
	if(open_mouth):
		frame_check += 1
	var total_frames = hframes * vframes
	if(frame_check >= total_frames):
		frame_check = 0
		push_warning("TOO FAR")
	frame = frame_check
