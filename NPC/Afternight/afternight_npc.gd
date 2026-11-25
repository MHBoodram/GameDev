extends Sprite3D
var emo : String = "netural"
var can_talk = true
var speaking_title = "afternight_1"
var dialogue_resource: DialogueResource
@onready var custom_balloon = load("res://addons/dialogue_manager/example_balloon/main_balloon.tscn")
@export var npc_resource: NPC

func _ready() -> void:
	if npc_resource:
		texture = npc_resource.sprite_sheet
		hframes = npc_resource.hframe
		dialogue_resource = npc_resource.dialogue_resource
	_base_position = position
	_base_scale = scale
	if random_start_delay:
		await get_tree().create_timer(randf_range(0.0, bounce_duration)).timeout
	start_idle()

func _money_checking():
	print("Money: ",PlayerStats.money)
	print(PlayerStats.money>0)
	#if(PlayerStats.money > 0):

func _play_animation_knocking():
	$AnimationPlayer.play("knocking")
	
@export var bounce_height := 0.03      # world units
@export var bounce_duration := 1     # seconds for one full up-and-down
@export var squash_amount := 0.02      # 0 = no squash/stretch
@export var random_start_delay := true # desyncs multiple sprites

var _base_position: Vector3
var _base_scale: Vector3
var _idle_tween: Tween

	

func start_idle() -> void:
	stop_idle()
	var half := bounce_duration / 2.0

	_idle_tween = create_tween().set_loops()

	# Up (stretch tall)
	_idle_tween.tween_property(self, "position:y", _base_position.y + bounce_height, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_idle_tween.parallel().tween_property(self, "scale",
		_base_scale * Vector3(1.0 - squash_amount, 1.0 + squash_amount, 1.0), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Down (squash flat)
	_idle_tween.tween_property(self, "position:y", _base_position.y, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_idle_tween.parallel().tween_property(self, "scale",
		_base_scale * Vector3(1.0 + squash_amount, 1.0 - squash_amount, 1.0), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func stop_idle() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	position = _base_position
	scale = _base_scale

func _on_interaction_input_event(camera_node: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape: int) -> void:
	if not can_talk or speaking_title == "" or speaking_title == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.character_talking = self
		if abs(camera_node.global_position.x - global_position.x) < 2:
			talk()

func talk() -> void:
	if GameState.is_dialogue_open:
		return
	if not can_talk or speaking_title == "" or speaking_title == null:
		return
	if GameState.main_node and "upgrade_time" in GameState.main_node and GameState.main_node.upgrade_time and GameState.main_node.has_method("_get_shop_options_title"):
		speaking_title = GameState.main_node._get_shop_options_title()
	if dialogue_resource:
		DialogueManager.show_dialogue_balloon_scene(custom_balloon, dialogue_resource, speaking_title, [self])

func force_dialogue(speaking: String) -> void:
	if dialogue_resource:
		DialogueManager.show_dialogue_balloon_scene(custom_balloon, dialogue_resource, speaking, [self])

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

func _reset_night() -> void:
	if is_instance_valid(GameState.main_node) and GameState.main_node.has_method("_reset_night"):
		GameState.main_node._reset_night()
