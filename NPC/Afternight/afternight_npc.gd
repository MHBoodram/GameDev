extends Sprite3D
var emo : String = "netural"
var can_talk : bool = true:
	set(value):
		can_talk = value
		_sync_interactable()
var speaking_title = "afternight_1"
var dialogue_resource: DialogueResource
var _last_dialogue_end_ms: int = -1000
@onready var custom_balloon = load("res://addons/dialogue_manager/example_balloon/main_balloon.tscn")
@export var npc_resource: NPC

func _ready() -> void:
	if npc_resource:
		texture = npc_resource.sprite_sheet
		hframes = npc_resource.hframe
		dialogue_resource = npc_resource.dialogue_resource
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_sync_interactable()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_interactable()

func _sync_interactable() -> void:
	var col := get_node_or_null("Area3D/CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = not (can_talk and visible)

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_last_dialogue_end_ms = Time.get_ticks_msec()

func _is_dialogue_busy() -> bool:
	if GameState.is_dialogue_open:
		return true
	var tree := get_tree()
	if tree and tree.root:
		for balloon_name in ["Main_Ballon", "ExampleBalloon"]:
			var balloon := tree.root.find_child(balloon_name, true, false)
			if is_instance_valid(balloon) and not balloon.is_queued_for_deletion():
				return true
	return false

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
	if not is_visible_in_tree() or not can_talk or speaking_title == "" or speaking_title == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if abs(camera_node.global_position.x - global_position.x) < 2:
			talk()

func talk() -> void:
	if _is_dialogue_busy():
		return
	if not is_visible_in_tree() or not can_talk or speaking_title == "" or speaking_title == null:
		return
	if Time.get_ticks_msec() - _last_dialogue_end_ms < 200:
		return
	if GameState.main_node and "_is_advancing_shop" in GameState.main_node and GameState.main_node._is_advancing_shop:
		return
	if GameState.main_node and "upgrade_time" in GameState.main_node and GameState.main_node.upgrade_time and GameState.main_node.has_method("_get_shop_options_title"):
		speaking_title = GameState.main_node._get_shop_options_title()
	if dialogue_resource and dialogue_resource.get_titles().has(speaking_title):
		GameState.character_talking = self
		GameState.is_dialogue_open = true
		var balloon = DialogueManager.show_dialogue_balloon_scene(custom_balloon, dialogue_resource, speaking_title, [self])
		if balloon == null:
			GameState.is_dialogue_open = false

func force_dialogue(speaking: String) -> void:
	if not is_inside_tree() or not dialogue_resource:
		return
	if not dialogue_resource.get_titles().has(speaking):
		return
	while is_inside_tree() and _is_dialogue_busy():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	GameState.character_talking = self
	GameState.is_dialogue_open = true
	var balloon = DialogueManager.show_dialogue_balloon_scene(custom_balloon, dialogue_resource, speaking, [self])
	if balloon == null:
		GameState.is_dialogue_open = false

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
