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

var customer_satisfaction : float = 1.0
var max_patience : float = 90.0
const SATISFACTORY_THRESHOLD := 0.6
const MAX_DIFF := 15.0
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
	if(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and abs(camera.global_position.x - global_position.x) < 2):
		if(dialogue_resource):
			DialogueManager.show_dialogue_balloon_scene(custom_balloon,dialogue_resource,speaking_title,[self])

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
	var drink_score: float = 1.0

	for check in want:
		var check_name: String = check[0]
		var check_amount: float = float(check[1])
		var found_match: bool = false
		for have in drink:
			if check_name == have[0]:
				found_match = true
				var difference: float = abs(check_amount - float(have[1]))
				var proportion_penalty: float = 0.3 * clampf(difference / MAX_DIFF, 0.0, 1.0)
				drink_score -= proportion_penalty
				break
		if not found_match:
			drink_score -= FLAT_PENALTY_MISSING_INGREDIENT

	for have in drink:
		var have_name: String = have[0]
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
		var satisfaction_loss: float = (1.0 - drink_score) * 0.5
		customer_satisfaction = maxf(0.0, customer_satisfaction - satisfaction_loss)
	print("[customer_satisfaction]: ", customer_satisfaction)

	var replenish_time: float = REPLENISH_BASE_TIME * drink_score
	var new_patience: float = minf(max_patience, patience_timer.time_left + replenish_time)
	patience_timer.start(new_patience)
	print("[patience_replenished]: ", replenish_time)

	_set_reputation(is_satisfactory, drink_score)

	var race_name: String = npc_resource.race if npc_resource else "Human"
	var group_rep: float = PlayerStats.get_species_reputation(race_name)
	var drink_cost: float = BASE_DRINK_PRICE
	var tip: float = (PlayerStats.overall_reputation + group_rep) * customer_satisfaction
	var payment: float = drink_cost + tip
	print("[drink_cost]: ", drink_cost)
	print("[tip]: ", tip)
	print("[payment]: ", payment)

	if(drink_list.size() <= 0):
		$Area3D/CollisionShape3D.disabled = true
		await get_tree().create_timer(1).timeout
		if(!unique_talk):
			_leaving()
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

	PlayerStats._change_money(PlayerStats.money + payment)
	return drink_score

# Generates random drink and adds it to order queue
func _want_drink() -> Array:
	var drink_list_want = ["beer","gin","vodka"]
	var liquid_num = randi_range(80,100)
	var drink_name = drink_list_want.pick_random()
	var total = [[drink_name,liquid_num]]
	drink_list.push_front(total)
	print(drink_list)
	return total

# Returns identifier of first requested drink in order queue
func _get_drink() -> String:
	return drink_list[0][0]

# Tweens customer to exit and frees seat
func _leaving() -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"global_position:x", -7,1.5)

	await tween.finished
	get_parent()._remove(seat_num)
	queue_free()

func _add_recipt() -> void:
	GameState.main_node._add_recipt(seat_num,str(_item_print()))

# Gets drink from overlapping glass area and triggers empty glass state
func _on_area_Obtain_drink_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		_obtain_drink(area._return_drink())
		area._dranked()

# Formats current drink order list into text
func _item_print() -> String:
	var total = ""
	for x in drink_list:
		for y in x:
			for z in y:
				total += str(str(z) + " ")
		total += "\n"
	return total

# Customer leaves when patience timer expires paying only base drink cost
func _on_patience_timer_timeout() -> void:
	var drink_cost: float = BASE_DRINK_PRICE
	var tip: float = 0.0
	var payment: float = drink_cost
	print("[drink_cost]: ", drink_cost)
	print("[tip]: ", tip)
	print("[payment]: ", payment)
	PlayerStats._change_money(PlayerStats.money + payment)
	_leaving()

# Changes cursor to interact on hover
func _on_area_3d_mouse_entered() -> void:
	GameState.player._update_hand("interact")

# Changes cursor to idle on unhover
func _on_area_3d_mouse_exited() -> void:
	GameState.player._update_hand("idle")
