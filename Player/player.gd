extends Node3D

# manages player mouse/physical actions

@onready var shot_glass := preload("res://Player/Drink/Glasses/shot_cup.tscn")
@onready var beer_glass := preload("res://Player/Drink/Glasses/beer_cup.tscn")
@onready var gameplay_ui := get_node("GameplayUi")
@onready var hand_sprite := get_node("GameplayUi/Hand")
@onready var camera_rig: Camera = get_node_or_null("Camera3D") as Camera

@export var counter: Node3D
var summoning: bool = false
var in_game: bool = false
var _pour_tween: Tween = null

var tool_controller: ToolController = ToolController.new()

var in_game_drinks: Dictionary = {
	"Drink": {"Node": Node3D, "position": Vector3.ZERO},
	"Glass": {"Node": Node3D, "position": Vector3.ZERO}
}

@export var counter_min_x: float = -1.0
@export var counter_max_x: float = 1.184
@export var min_z: float = 0.28
@export var spawn_y: float = 5.0
@export var spawn_scale: Vector3 = Vector3(0.2, 0.2, 0.2)

var cup_offsets := {
	"shot_glass": Vector3.ZERO,
	"beer_glass": Vector3.ZERO,
}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_update_hand("idle")

func _process(_delta: float) -> void:
	if hand_sprite:
		hand_sprite.global_position = get_viewport().get_mouse_position()

func _force_cursor_image(move_to: Vector3) -> void:
	if hand_sprite and camera_rig:
		hand_sprite.global_position = camera_rig.unproject_position(move_to)

func _force_mouse(move_to: Vector3) -> void:
	if camera_rig:
		get_viewport().warp_mouse(camera_rig.unproject_position(move_to))

func _change_tool(change: String) -> void:
	tool_controller.set_tool(change)
	_update_hand("idle")

func return_tool() -> String:
	return tool_controller.get_tool()

func _update_hand(change: String) -> void:
	var anim_player: AnimationPlayer = $GameplayUi/Hand/AnimationPlayer
	tool_controller.update_hand_visual(anim_player, change)

func handle_counter_edge_action() -> bool:
	return tool_controller.handle_counter_edge_click(self, GameState.main_node)

func get_mouse_world_position(cam: Camera3D, plane_y: float) -> Vector3:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mouse_pos)
	var ray_dir := cam.project_ray_normal(mouse_pos)
	var hit = Plane(Vector3.UP, plane_y).intersects_ray(ray_origin, ray_dir)
	return hit if hit != null else global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("Up") or event.is_action_pressed("Down"):
			if gameplay_ui and gameplay_ui.has_method("bendover"):
				gameplay_ui.bendover()
		elif event.is_action_pressed("Left"):
			if gameplay_ui and not gameplay_ui.down and gameplay_ui.has_method("moving_around"):
				gameplay_ui.moving_around(false)
		elif event.is_action_pressed("Right"):
			if gameplay_ui and not gameplay_ui.down and gameplay_ui.has_method("moving_around"):
				gameplay_ui.moving_around(true)
		elif event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			_handle_dialogue_input()
		elif event.keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE:
			if GameState.main_node and GameState.main_node.has_method("toggle_debug_menu"):
				GameState.main_node.toggle_debug_menu()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if gameplay_ui and gameplay_ui.has_method("bendover"):
				gameplay_ui.bendover()

func _handle_dialogue_input() -> void:
	if GameState.is_dialogue_open or (gameplay_ui and gameplay_ui.down) or not GameState.seat_manager:
		return
	var seat_num: int = 4 - gameplay_ui.current_position
	var npc = GameState.seat_manager.get_customer_at_seat(seat_num)
	if npc and is_instance_valid(npc) and npc.has_method("talk"):
		npc.talk()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		summoning = false
		if in_game:
			_out_of_game()

func _spawn_and_begin_drag(scene: PackedScene, cup_name: String, spawn_world_pos: Variant = null) -> void:
	var new_instance = scene.instantiate()
	new_instance.scale = spawn_scale
	if new_instance.has_method("_instiate"):
		new_instance._instiate(counter)
	var offset: Vector3 = cup_offsets.get(cup_name, Vector3.ZERO)
	if spawn_world_pos is Vector3 and "_skip_initial_snap" in new_instance:
		new_instance._skip_initial_snap = true
	get_parent().add_child(new_instance)

	if spawn_world_pos is Vector3:
		new_instance.global_position = (spawn_world_pos as Vector3) + offset
	else:
		var working_area_bounds = WorkingAreaService.get_working_area_bounds(self)
		if working_area_bounds is AABB:
			var surface_center: Vector3 = (working_area_bounds as AABB).get_center()
			new_instance.global_position = Vector3(surface_center.x, (working_area_bounds as AABB).end.y, surface_center.z) + offset
			if new_instance.has_method("_snap_to_working_area"):
				new_instance._snap_to_working_area()
		else:
			var center_x: float = counter.global_position.x + 0.335 if counter else global_position.x
			var center_z: float = counter.global_position.z + 0.015 if counter else global_position.z
			new_instance.global_position = Vector3(center_x, 1.6, center_z) + offset

	if new_instance.has_method("start_drag_from_spawn"):
		new_instance.start_drag_from_spawn(get_viewport().get_mouse_position(), spawn_world_pos is Vector3)

# locks bottle and cup in front of camera marks to run pour minigame
func _perfect_pour(drink: Drinks, glass: Glasses) -> void:
	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()
	if gameplay_ui:
		gameplay_ui._in_down_minigame()
	in_game = true
	in_game_drinks["Drink"]["Node"] = drink
	in_game_drinks["Drink"]["position"] = drink.global_position
	in_game_drinks["Drink"]["position"].x = drink.global_position.x + 0.5
	in_game_drinks["Glass"]["Node"] = glass

	var glass_home_pos: Vector3 = glass.global_position
	if glass.has_method("_get_saved_counter_position"):
		glass_home_pos = glass._get_saved_counter_position(glass._last_counter_position)
	in_game_drinks["Glass"]["position"] = glass_home_pos
	drink._in_game()
	glass._in_game()

	_pour_tween = get_tree().create_tween().set_parallel(true)
	_pour_tween.tween_property(drink, "global_position", $Camera3D/drink_mark.global_position, 0.5)
	_pour_tween.tween_property(glass, "global_position", $Camera3D/glass_mark.global_position, 0.5)
	_pour_tween.tween_property(glass, "rotation_degrees:y", 0, 0.5)

	await _pour_tween.finished
	if not in_game or not is_instance_valid(drink):
		return
	await get_tree().process_frame
	if in_game and is_instance_valid(drink):
		drink.look_at($Camera3D.global_position)

# returns bottle to shelf and cup to counter when canceling or finishing pour
func _out_of_game() -> void:
	if not in_game:
		return
	in_game = false
	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()
	var drink = in_game_drinks["Drink"]["Node"]
	var glass = in_game_drinks["Glass"]["Node"]

	_pour_tween = get_tree().create_tween().set_parallel(true)
	if is_instance_valid(drink):
		if "original_position" in drink and drink.original_position:
			_pour_tween.tween_property(drink, "global_position", drink.original_position.global_position, 0.5)
		else:
			_pour_tween.tween_property(drink, "global_position", in_game_drinks["Drink"]["position"], 0.5)
	if is_instance_valid(glass):
		_pour_tween.tween_property(glass, "global_position", in_game_drinks["Glass"]["position"], 0.5)

	await _pour_tween.finished
	if is_instance_valid(drink):
		drink._out_of_game()
	if is_instance_valid(glass):
		glass._out_of_game()
	if gameplay_ui and gameplay_ui.has_method("_out_down_minigame"):
		gameplay_ui._out_down_minigame()

func _on_shot_glass_button_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var spawn_pos: Variant = null
		if counter:
			var btn := counter.get_node_or_null("ShotGlass Button") as Node3D
			if btn:
				spawn_pos = btn.global_position
		SFXAudio.play_mugpickup()
		_spawn_and_begin_drag(shot_glass, "shot_glass", spawn_pos)

func _on_beer_glass_button_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var glass_in_scene = get_tree().get_nodes_in_group("glass")
		if glass_in_scene.size() > 4:
			return
		var spawn_pos: Variant = null
		if counter:
			var btn := counter.get_node_or_null("BeerGlass Button") as Node3D
			if btn:
				spawn_pos = btn.global_position
		SFXAudio.play_mugpickup()
		_spawn_and_begin_drag(beer_glass, "beer_glass", spawn_pos)

func _on_trash_area_entered(_area: Area3D) -> void:
	pass
