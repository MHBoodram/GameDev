extends Sprite3D
class_name Base_NPC
@export var npc_resource : NPC
enum State { SEAT, SIT, EXIT }
var current_state : State = State.SEAT
var camera = null
var dialogue_resource : DialogueResource
@onready var custom_balloon = load("res://addons/dialogue_manager/example_balloon/main_balloon.tscn")
#var dialogue_line = await npc_resource.dialogue_resource.get_next_dialogue_line("start")

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	self.texture = npc_resource.sprite_sheet
	_tween_bounce()
	dialogue_resource = npc_resource.dialogue_resource

#func _making_dialogue() -> void:
	#DialogueManager.create_dialogue_line()

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
	#await tween.finished
	#tween.stop()
	tween.tween_property(self, "scale", Vector3(0.5,0.5,0.5), 0.4)
	await tween.finished
	await get_tree().create_timer(0.1).timeout
	_tween_bounce()


func _on_interaction_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and abs(camera.global_position.x - global_position.x) < 2):
		print("Camera Global_position - self: " + str(camera.global_position - global_position))
		if(dialogue_resource):
			DialogueManager.show_dialogue_balloon_scene(custom_balloon,dialogue_resource,"start")
