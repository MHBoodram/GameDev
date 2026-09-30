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
@onready var recipt = get_node("ReciptPaper")
var recipt_marker : Marker3D
var recipt_clicked : bool = true


func _ready() -> void:
	patience_timer.wait_time = npc_resource.patience_time
	patient_2d._change_max_progress(npc_resource.patience_time)
	patient_2d._setup(npc_resource.patience_time, npc_resource.race)
	camera = get_viewport().get_camera_3d()
	self.texture = npc_resource.sprite_sheet
	hframes = npc_resource.hframe
	_tween_bounce()
	dialogue_resource = npc_resource.dialogue_resource
	patience_timer.start()

func _institate(npc_source : NPC,seat: int,rec_marker: Marker3D) -> void:
	npc_resource = npc_source
	seat_num = seat
	recipt_marker = rec_marker
	_ready()

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	patient_2d._change_curent(patience_timer.time_left)

func _moving_to(to: Marker3D) -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"position",to.position,0.8)
	current_state = State.SIT

func _add_recipt() -> void:
	$ReciptPaper/recipt_area.recipt_spawned = true
	recipt.global_position = camera.global_position
	$ReciptPaper/Base_viewport/SubViewport/Recipt._label_change(_item_print())
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(recipt,"global_position", recipt_marker.global_position,1.5)
	
func _tween_bounce() -> void:
	var tween = get_tree().create_tween()
	var rand_time = randf_range(0.503,0.505)
	tween.tween_property(self, "scale", Vector3(0.505,rand_time,0.5), 0.5)
	tween.tween_property(self, "scale", Vector3(0.5,0.5,0.5), 0.4)
	await tween.finished
	await get_tree().create_timer(0.1).timeout
	_tween_bounce()

func _talking() -> void:
	if(dialogue_resource):
		DialogueManager.show_dialogue_balloon_scene(custom_balloon,dialogue_resource,speaking_title,[self])


# Drink calculation returns
const NAME_POINTS := 2.0	# max from matching ingredients
const AMOUNT_POINTS := 3.0	# max from matching amounts
const MAX_DIFF := 15.0	# difference at which amount points hit 0

func _obtain_drink(drink: Array) -> float:
	var want = drink_list.pop_front()
	var ranking :float = 0.0
	print(want)
	var per_item : float = 1.0 / want.size()
	#print(want)
	#print(drink)
	for check in want:
		var check_name = check[0]
		var check_liquid_number = check[1]
		#print(check_name)
		#print(check_liquid_number)
		for have in drink:
			if check_name != have[0]:
				continue

			var difference = abs(check_liquid_number - have[1])
			var closeness = 1.0 - clamp(difference / MAX_DIFF, 0.0, 1.0)

			ranking += NAME_POINTS * per_item	# right ingredient
			ranking += AMOUNT_POINTS * closeness * per_item	# right amount
			break
	print(ranking)
	if(drink_list.size() <= 0):
		$Obtain_drink/Area3D/CollisionShape3D.disabled = true
		await get_tree().create_timer(1).timeout
		_leaving()
	return ranking	# always between 0 and 5
	
func _want_drink() -> Array:
	var drink_list_want = ["beer"]
	var liquid_num = randi_range(80,100)
	var drink_name = drink_list_want.pick_random()
	var total = [[drink_name,liquid_num]]
	drink_list.push_front(total)
	print(drink_list)
	return total

func _get_drink() -> String:
	return drink_list[0][0]

func _on_patience_timer_timeout() -> void:
	_leaving()
	
func _leaving() -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"global_position:x", -7,1.5)
	
	await $VisibleOnScreenNotifier3D.screen_exited
	get_parent()._remove(seat_num)
	queue_free()


func _on_area_Obtain_drink_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		_obtain_drink(area.get_parent()._return_drink())
		area.get_parent()._dranked()

func _item_print() -> String:
	var total = ""
	for x in drink_list:
		for y in x:
			for z in y:
				total += str(str(z) + " ")
		total += "\n"
	return total

#Unused Functions

#func _on_recipt_area_mouse_exited() -> void:
	#var tween = get_tree().create_tween()
	#tween.set_trans(Tween.TRANS_SINE)
	#tween.set_ease(Tween.EASE_OUT)
	#tween.tween_property(recipt,"global_position", recipt_marker.global_position,0.5)

#@warning_ignore("shadowed_variable", "unused_parameter")
#func _on_interaction_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	#if(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and abs(camera.global_position.x - global_position.x) < 2):
		##print("Camera Global_position - self: " + str(camera.global_position - global_position))
		#if(dialogue_resource):
			#DialogueManager.show_dialogue_balloon_scene(custom_balloon,dialogue_resource,speaking_title,[self])
