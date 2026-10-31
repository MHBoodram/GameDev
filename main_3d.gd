extends Node3D
const PAUSE_MENU = preload("res://UI/Gameplay_ui/PauseMenu.tscn")
const BASE_NPC = preload("res://NPC/base npc.tscn")
var seats: Array[Base_NPC] = [null, null, null]
@onready var player = get_node("Player")
var frame_count = 0
var is_dialogue_open: bool = false
var is_spawning_allowed: bool = true
var spawn_timer_acc: float = 0.0

@onready var world_environment: WorldEnvironment = get_node("WorldEnvironment")
@onready var sun: DirectionalLight3D = get_node("WorldEnvironment/Sun")
@onready var night_timer: Timer = get_node("Night_Time")

var initial_sun_transform: Transform3D
var initial_sun_energy: float = 1.5
var initial_hdri_energy: float = 0.5
var initial_fog_albedo: Color = Color(0.9843137, 0.7411765, 0.0, 1.0)
var sky_material: PanoramaSkyMaterial

@export var dusk_start_seconds: float = 0.0
@export var dusk_end_seconds: float = 40.0
@export var night_hdri_energy: float = 0.025
@export var night_sun_pitch_degrees: float = 45.0
@export var night_fog_albedo: Color = Color(0.04, 0.06, 0.12, 1.0)

func _ready() -> void:
	add_child(PAUSE_MENU.instantiate())
	GameState.player = $Player
	GameState.main_node = self
	DialogueManager.dialogue_started.connect(func(_resource): is_dialogue_open = true; GameState.is_dialogue_open = true)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_check_unlocks_drinks()
	_setup_environment_day_night()
	night_timer.timeout.connect(_on_night_time_timeout)
	PlayerStats.previous_money = PlayerStats.money
	_setup_shift()

# Setup night timer and show initial quota and night count
func _setup_shift() -> void:
	is_spawning_allowed = true
	if GameState.gameplay_ui:
		GameState.gameplay_ui.set_shift_hud_visible(false)
	start_night()

# Night title banner popup on hud
func night_popup() -> void:
	if(GameState.gameplay_ui):
		GameState.gameplay_ui._night_title_popup()

# Starts night timer and initial customer setup
func start_night() -> void:
	$Night_Time.wait_time = GameState.night_duration
	_night_select()
	if not GameState.special_state and not GameState.night_paused:
		start_night_shift()

func start_night_shift() -> void:
	GameState.night_paused = false
	GameState.special_state = false
	is_spawning_allowed = true
	var active_quota: float = GameState.get_night_quota(GameState.night)
	if GameState.gameplay_ui:
		GameState.gameplay_ui.set_shift_hud_visible(true)
		GameState.gameplay_ui._update_quota(active_quota)
		GameState.gameplay_ui._update_night_display(GameState.night)
		GameState.gameplay_ui._night_title_popup()
	if $Night_Time.is_stopped():
		$Night_Time.start()
	else:
		$Night_Time.paused = false
	print("[shift_started]: ", GameState.night)

func pause_night() -> void:
	GameState.night_paused = true
	if night_timer and not night_timer.is_stopped():
		night_timer.paused = true
	for npc in seats:
		if npc and is_instance_valid(npc) and npc.patience_timer:
			npc.patience_timer.paused = true

func resume_night() -> void:
	GameState.night_paused = false
	if night_timer:
		if night_timer.is_stopped() and is_spawning_allowed:
			night_timer.start()
		else:
			night_timer.paused = false
	for npc in seats:
		if npc and is_instance_valid(npc) and npc.patience_timer:
			npc.patience_timer.paused = false

func hold_night_end(hold: bool = true) -> void:
	GameState.hold_night_end(hold)

func _setup_environment_day_night() -> void:
	initial_sun_transform = sun.transform
	initial_sun_energy = sun.light_energy
	if world_environment and world_environment.environment:
		world_environment.environment = world_environment.environment.duplicate()
		initial_fog_albedo = world_environment.environment.volumetric_fog_albedo
		if world_environment.environment.sky:
			world_environment.environment.sky = world_environment.environment.sky.duplicate()
			var mat = world_environment.environment.sky.sky_material
			if mat is PanoramaSkyMaterial:
				sky_material = mat.duplicate()
				world_environment.environment.sky.sky_material = sky_material
				initial_hdri_energy = sky_material.energy_multiplier

func _update_day_night_cycle() -> void:
	if night_timer.is_stopped() or night_timer.paused:
		return
	var elapsed_seconds: float = night_timer.wait_time - night_timer.time_left
	var raw_progress: float = (elapsed_seconds - dusk_start_seconds) / (dusk_end_seconds - dusk_start_seconds)
	var transition_weight: float = clampf(raw_progress, 0.0, 1.0)
	var smooth_weight: float = smoothstep(0.0, 1.0, transition_weight)
	var pitch_offset: Basis = Basis(Vector3.RIGHT, deg_to_rad(night_sun_pitch_degrees * smooth_weight))
	sun.transform.basis = initial_sun_transform.basis * pitch_offset
	sun.light_energy = lerpf(initial_sun_energy, 0.0, smooth_weight)
	sun.visible = sun.light_energy > 0.001
	if sky_material:
		sky_material.energy_multiplier = lerpf(initial_hdri_energy, night_hdri_energy, smooth_weight)
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_albedo = initial_fog_albedo.lerp(night_fog_albedo, smooth_weight)

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	GameState.gameplay_ui._change_time($Night_Time.time_left)
	_update_day_night_cycle()

	if !GameState.special_state && is_spawning_allowed && !GameState.night_paused:
		var current_rate: float = PlayerStats.get_spawn_rate()
		var spawn_interval: float = maxf(4.0, 16.0 / current_rate)
		spawn_timer_acc += delta
		if spawn_timer_acc >= spawn_interval:
			spawn_timer_acc = 0.0
			_add_npc()

func _on_night_time_timeout() -> void:
	is_spawning_allowed = false
	print("[shift_timer_ended]: 0.0")
	_check_night_concluded()

# Transitions to intermission menu if timer expired and all seats are cleared
func _check_night_concluded() -> void:
	if not is_spawning_allowed and seats.count(null) == seats.size() and GameState.can_end_night and not GameState.night_paused:
		Transition._changing_scene("res://UI/After_night/after_night_menu.tscn")

func _check_upgrades() -> void:
	pass

func _check_unlocks_drinks() -> void:
	for i in PlayerStats.unlocks["Drinks"]:
		if(!PlayerStats.unlocks["Drinks"][i]):
			return
		var temp_scene_check = "res://Player/Drink/Liquids/liquid.tscn"
		add_scene_once_drink(temp_scene_check, str(i))

func _night_select() -> void:
	match GameState.night:
		1:
			_set_shit("shark",180)
			GameState.special_state = true
			pause_night()

func _on_dialogue_ended(_resource) -> void:
	is_dialogue_open = false
	GameState.is_dialogue_open = false
	if GameState.special_state:
		for seat_idx in seats.size():
			var npc = seats[seat_idx]
			if npc and is_instance_valid(npc) and npc.unique_talk and npc.drink_list.size() <= 0:
				npc._leaving()
				break

func _is_debug_menu_blocked() -> bool:
	if get_tree().paused:
		return true
	if is_dialogue_open:
		return true
	var main_balloon = get_tree().root.find_child("Main_Ballon", true, false)
	if main_balloon and main_balloon.visible:
		return true
	var example_balloon = get_tree().root.find_child("ExampleBalloon", true, false)
	if example_balloon and example_balloon.visible:
		return true
	return false

func toggle_debug_menu() -> void:
	if $DebugMenu.visible:
		$DebugMenu.visible = false
	elif not _is_debug_menu_blocked():
		$DebugMenu.visible = true

func _clear_receipt_for_seat(seat_number: int) -> void:
	var recipt_node = get_node_or_null("ReciptPaper" + str(seat_number))
	if recipt_node:
		recipt_node.ordered = false
		recipt_node.global_position = $HiddenRecipt.global_position

func _serve_seat(seat_index: int, drink_data: Array) -> void:
	var npc: Base_NPC = seats[seat_index]
	if npc == null:
		return
	_clear_receipt_for_seat(seat_index + 1)
	npc._obtain_drink(drink_data)
	if npc.unique_talk:
		npc._leaving()

func _serve_all_customers_scored(score_type: String = "good") -> void:
	for seat_index in seats.size():
		var npc: Base_NPC = seats[seat_index]
		if npc == null:
			continue
		while npc.drink_list.size() > 0:
			var drink_data: Array = []
			if score_type == "good":
				var target_item = npc.drink_list[0][0]
				drink_data = [[target_item[0], target_item[1]]]
			else:
				drink_data = [["garbage_water", 0], ["spoiled_milk", 0], ["wrong_spirit", 0]]
			_serve_seat(seat_index, drink_data)

func _serve_all_customers() -> void:
	_serve_all_customers_scored("good")

func end_night_early() -> void:
	$Night_Time.stop()
	is_spawning_allowed = false
	GameState.night_paused = false
	GameState.special_state = false
	for seat_index in seats.size():
		var npc: Base_NPC = seats[seat_index]
		if npc:
			_clear_receipt_for_seat(seat_index + 1)
			npc._leaving()
	_check_night_concluded()

func _set_shit(specific_id: String, patience: float = 90) -> void:
	var free_seat = seats.find(null)
	if free_seat == -1:
		print("Full")
		return

	var npc = BASE_NPC.instantiate()
	var path = "res://NPC/Resources/"+ specific_id+".tres"

	add_child(npc)
	npc.global_position = $Spawn.global_position
	seats[free_seat] = npc
	npc.name = "seat%d_npc" % (free_seat + 1)
	npc._moving_to(get_node("Seat%d" % (free_seat + 1)))
	var marker_grab = get_node("Recipt" + str(free_seat +1))
	npc._institate(load(path),free_seat+1,marker_grab,patience,"introduction_game")
	var order = npc._want_drink()
	match free_seat:
		0: GameState.seat1_order = order
		1: GameState.seat2_order = order
		2: GameState.seat3_order = order

func add_scene_once_drink(path: String, node_name: String, parent: Node = self) -> Node:
	var existing = parent.get_node_or_null(node_name)
	if existing:
		return existing
	var resource_found = load("res://Player/Drink/Liquids/resource/"+ node_name +".tres")
	var instance = load(path).instantiate()
	existing = parent.get_node_or_null(node_name + "_marker")
	if(!existing):
		push_warning("Doesn't exist: " + node_name)
		return
	instance.name = node_name
	parent.add_child(instance)
	instance.setup(existing,$Coutner/Lower_counter,resource_found)
	return instance

func _print_reading_dialogue() -> void:
	print("Printing dialgoue or something")

func _add_npc() -> void:
	if not is_spawning_allowed or GameState.night_paused:
		return
	var free_seat = seats.find(null)
	if free_seat == -1:
		print("Full")
		return

	var human_weight: float = PlayerStats.get_species_spawn_weight("Human")
	var slime_weight: float = PlayerStats.get_species_spawn_weight("Slime")
	var total_weight: float = human_weight + slime_weight
	var roll: float = randf_range(0.0, total_weight)

	var chosen_species: String = "Human"
	var path: String = "res://NPC/Resources/scott.tres"
	if roll <= slime_weight:
		chosen_species = "Slime"
		path = "res://NPC/Resources/slime.tres"

	print("[customer_spawned]: ", chosen_species)

	var npc = BASE_NPC.instantiate()
	add_child(npc)
	npc.global_position = $Spawn.global_position
	seats[free_seat] = npc
	npc.name = "seat%d_npc" % (free_seat + 1)
	npc._moving_to(get_node("Seat%d" % (free_seat + 1)))
	var marker_grab = get_node("Recipt" + str(free_seat +1))
	npc._institate(load(path),free_seat+1,marker_grab)
	var order = npc._want_drink()
	match free_seat:
		0: GameState.seat1_order = order
		1: GameState.seat2_order = order
		2: GameState.seat3_order = order

func get_seat_drink(seat: int) -> String:
	var npc = seats[seat - 1]
	return npc._get_drink() if npc else ""

func seats_wanting(drink_name: String) -> Array:
	var result = []
	for i in seats.size():
		if seats[i] and seats[i]._get_drink() == drink_name:
			result.append(i + 1)
	return result

func _remove_npc(seat: int) -> void:
	var npc = seats[seat - 1]
	print("REMOVE NPC")
	if npc == null:
		return
	seats[seat - 1] = null
	npc._leaving()

func _remove(seat: int) -> void:
	seats[seat - 1] = null
	if GameState.special_state:
		var has_special: bool = false
		for npc in seats:
			if npc and is_instance_valid(npc) and npc.unique_talk:
				has_special = true
				break
		if not has_special:
			start_night_shift()
	_check_night_concluded()

func _add_recipt(seat: int,change_words: String) -> void:
	var string_recipt = "ReciptPaper" + str(seat)
	var recipt_node = get_node(string_recipt)
	var marker_node = get_node("Recipt" + str(seat))
	var tween = get_tree().create_tween()
	recipt_node._write(change_words)
	recipt_node.ordered = true
	recipt_node.global_position = player.global_position
	tween.tween_property(recipt_node,"global_position",marker_node.global_position,0.5)

func _give_drink(recipt: Node3D, drink:Glasses, seat: int) -> void:
	var seat_marker = get_node_or_null("SeatDrink" + str(seat))
	if(!seat_marker):
		push_warning("Can't find seat marker")
		return
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(recipt,"global_position",seat_marker.global_position,0.5)
	tween.tween_property(drink,"global_position",seat_marker.global_position,0.5)
	tween.tween_property(recipt,"global_position",$HiddenRecipt.global_position,0.5)
