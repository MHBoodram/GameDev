extends Node3D
@onready var shot_glass = preload("res://Player/Drink/Glasses/shot_cup.tscn")
@onready var beer_glass = preload("res://Player/Drink/Glasses/beer_cup.tscn")
@onready var gameplay_ui = get_node("GameplayUi")
@onready var hand_sprite = get_node("GameplayUi/Hand")
@export var counter : Node3D
var summoning : bool = false
var icup_spawn : String = "shot_glass"
var in_pour_zone : Area3D
var in_game : bool = false
var tool_in_hand : String = "hand"
var in_game_drinks : Dictionary = \
{
	"Drink" : {"Node" : Node3D, "position" : Vector3.ZERO},
	"Glass" : {"Node" : Node3D, "position" : Vector3.ZERO}
}
@export var counter_min_x: float = -1.0
@export var counter_max_x: float = 1.184
@export var min_z: float = 0.28
@export var spawn_y: float = 5
@export var spawn_scale: Vector3 = Vector3(0.2, 0.2, 0.2)

var cup_offsets := {
	"shot_glass": Vector3(0, 0, 0),
	"beer_glass": Vector3(0, 0, 0),
}

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_update_hand("idle")

func _process(delta: float) -> void:
	$GameplayUi/Hand.global_position = get_viewport().get_mouse_position()

func _force_cursor_image(move_to: Vector3) -> void:
	$GameplayUi/Hand.global_position = $Camera3D.unproject_position(move_to)

func _force_mouse(move_to: Vector3) -> void:
	get_viewport().warp_mouse($Camera3D.unproject_position(move_to))

func _change_tool(change: String) -> void:
	tool_in_hand = change
	_update_hand("idle")

func return_tool() -> String:
	return tool_in_hand

func _update_hand(change: String) -> void:
	match tool_in_hand:
		"hand":
			match change:
				"interact":
					if($GameplayUi/Hand/AnimationPlayer.current_animation != "interact"):
						$GameplayUi/Hand/AnimationPlayer.play("interact")
					return
				"holding":
					if($GameplayUi/Hand/AnimationPlayer.current_animation != "hold"):
						$GameplayUi/Hand/AnimationPlayer.play("hold")
					return
				_:
					if($GameplayUi/Hand/AnimationPlayer.current_animation != "idle"):
						$GameplayUi/Hand/AnimationPlayer.play("idle")
					return
		"knife":
			match change:
				_:
					if($GameplayUi/Hand/AnimationPlayer.current_animation != "knife_idle"):
						$GameplayUi/Hand/AnimationPlayer.play("knife_idle")
					return

func get_mouse_world_position(camera: Camera3D, plane_y: float) -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, plane_y)
	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		return hit
	return global_position

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
	if GameState.is_dialogue_open:
		return
	if gameplay_ui and gameplay_ui.down:
		return
	if not GameState.main_node:
		return
	var seat_idx: int = 3 - gameplay_ui.current_position
	if seat_idx >= 0 and seat_idx < GameState.main_node.seats.size():
		var npc = GameState.main_node.seats[seat_idx]
		if npc and is_instance_valid(npc) and npc.has_method("talk"):
			npc.talk()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		summoning = false
		if in_game:
			_out_of_game()

func _spawn_cup(scene: PackedScene, cup_name: String) -> void:
	var new_instance = scene.instantiate()
	new_instance.scale = spawn_scale
	if new_instance.has_method("_instiate"):
		new_instance._instiate(counter)
	get_parent().add_child(new_instance)

	var offset: Vector3 = cup_offsets.get(cup_name, Vector3.ZERO)
	var working_area_bounds = Ingredients.get_working_area_bounds(self)
	if working_area_bounds is AABB:
		var counter_boundary: AABB = working_area_bounds
		var spawn_position: Vector3 = get_mouse_world_position($Camera3D, counter_boundary.end.y) + offset
		new_instance.global_position = spawn_position
		if new_instance.has_method("_snap_to_working_area"):
			new_instance._snap_to_working_area()
	else:
		var spawn_position: Vector3 = get_mouse_world_position($Camera3D, spawn_y)
		var min_x : float = counter.global_position.x + counter_min_x
		var max_x : float = counter.global_position.x + counter_max_x
		spawn_position.x = clamp(spawn_position.x , min_x, max_x)
		spawn_position.z = max(spawn_position.z, min_z)
		spawn_position += offset
		new_instance.global_position = spawn_position

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
		var working_area_bounds = Ingredients.get_working_area_bounds(self)
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

func _perfect_pour(drink : Drinks, glass : Glasses) -> void:
	var tween = get_tree().create_tween().set_parallel(true)
	gameplay_ui._in_down_minigame()
	in_game = true
	in_game_drinks["Drink"]["Node"] = drink
	in_game_drinks["Drink"]["position"] = drink.global_position
	in_game_drinks["Drink"]["position"].x = drink.global_position.x + 0.5
	in_game_drinks["Glass"]["Node"] = glass
	in_game_drinks["Glass"]["position"] = glass.global_position
	drink._in_game()
	glass._in_game()
	tween.tween_property(drink,"global_position",$Camera3D/drink_mark.global_position,0.5)
	tween.tween_property(glass,"global_position",$Camera3D/glass_mark.global_position,0.5)
	tween.tween_property(glass,"rotation_degrees:y",0,0.5)
	await tween.finished
	await get_tree().process_frame
	drink.look_at($Camera3D.global_position)

	

func _out_of_game() -> void:
	in_game = false
	var drink = in_game_drinks["Drink"]["Node"]
	var glass = in_game_drinks["Glass"]["Node"]
	var tween = get_tree().create_tween().set_parallel(true)
	if is_instance_valid(drink):
		if "original_position" in drink and drink.original_position:
			tween.tween_property(drink, "global_position", drink.original_position.global_position, 0.5)
		else:
			tween.tween_property(drink, "global_position", in_game_drinks["Drink"]["position"], 0.5)
	if is_instance_valid(glass):
		tween.tween_property(glass, "global_position", in_game_drinks["Glass"]["position"], 0.5)
	await tween.finished
	if is_instance_valid(drink):
		drink._out_of_game()
	if is_instance_valid(glass):
		glass._out_of_game()
	if gameplay_ui and gameplay_ui.has_method("_out_down_minigame"):
		gameplay_ui._out_down_minigame()

func _on_shot_glass_button_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var spawn_pos: Variant = null
		if counter:
			var btn := counter.get_node_or_null("ShotGlass Button") as Node3D
			if btn:
				spawn_pos = btn.global_position
		SFXAudio.play_mugpickup()
		_spawn_and_begin_drag(shot_glass, "shot_glass", spawn_pos)

func _on_beer_glass_button_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var spawn_pos: Variant = null
		if counter:
			var btn := counter.get_node_or_null("BeerGlass Button") as Node3D
			if btn:
				spawn_pos = btn.global_position
		SFXAudio.play_mugpickup()
		_spawn_and_begin_drag(beer_glass, "beer_glass", spawn_pos)

func _on_trash_area_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		area._delete()

		
