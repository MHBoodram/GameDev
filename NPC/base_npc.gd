extends Sprite3D
class_name Base_NPC
@export var npc_resource : NPC
enum State { SEAT, SIT, EXIT }
var current_state : State = State.SEAT
var camera = null
var drink : String = "Beer"
var liquid_number : float = 0.0
var dialogue_resource : DialogueResource
@onready var custom_balloon = load("res://addons/dialogue_manager/example_balloon/main_balloon.tscn")
@onready var patience_timer = get_node("Patience_timer")
@onready var patient_2d = get_node("Sprite3D/SubViewport/Patience")

func _ready() -> void:
	patience_timer.wait_time = npc_resource.patience_time
	patient_2d._change_max_progress(npc_resource.patience_time)
	camera = get_viewport().get_camera_3d()
	self.texture = npc_resource.sprite_sheet
	hframes = npc_resource.hframe
	_tween_bounce()
	dialogue_resource = npc_resource.dialogue_resource
	patience_timer.start()

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	patient_2d._change_curent(patience_timer.time_left)

func _institate(npc_source : NPC) -> void:
	npc_resource = npc_source

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

@warning_ignore("shadowed_variable", "unused_parameter")
func _on_interaction_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and abs(camera.global_position.x - global_position.x) < 2):
		print("Camera Global_position - self: " + str(camera.global_position - global_position))
		if(dialogue_resource):
			DialogueManager.show_dialogue_balloon_scene(custom_balloon,dialogue_resource,"start")

func _want_drink(seat: int) -> Array:
	var drink_list = ["beer","tea"]
	var liquid_num = randf_range(80,100)
	drink = drink_list.pick_random()
	liquid_number = liquid_num
	var total = [drink,liquid_num]
	return total

func _get_drink() -> String:
	return drink

func _leaving() -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"global_position:x", -7,1.5)
	await $VisibleOnScreenNotifier3D.screen_exited
	queue_free()
