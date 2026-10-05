extends Node3D
const PAUSE_MENU = preload("res://UI/PauseMenu.tscn")
const BASE_NPC = preload("res://NPC/base npc.tscn")
var seats: Array[Base_NPC] = [null, null, null]
@onready var player = get_node("Player")

func _ready() -> void:
	add_child(PAUSE_MENU.instantiate())
	GameState.player = $Player
	GameState.main_node = self
	_check_unlocks_drinks()
	if(GameState.gameplay_ui):
		GameState.gameplay_ui._night_title_popup()

func _check_upgrades() -> void:
	pass

func _check_unlocks_drinks() -> void:
	for i in PlayerStats.unlocks["Drinks"]:
		print(i)
		var temp_scene_check = "res://Player/Drink/Liquids/" + str(i) +".tscn"
		temp_scene_check = "res://Player/Drink/Liquids/Gin.tscn"
		print(temp_scene_check)
		add_scene_once_drink(temp_scene_check, str(i))

func add_scene_once_drink(path: String, node_name: String, parent: Node = self) -> Node:
	var existing = parent.get_node_or_null(node_name)
	if existing:
		return existing

	var instance = load(path).instantiate()
	existing = parent.get_node_or_null(node_name + "_marker")
	instance.name = node_name
	parent.add_child(instance)
	instance.setup(existing,$Coutner/Lower_counter)

	return instance

func _print_reading_dialogue() -> void:
	print("Printing dialgoue or something")

func _input(event: InputEvent) -> void:
	#if(Input.is_action_just_pressed("ui_accept")):
		#get_tree().quit()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.physical_keycode == KEY_P:
			$DebugMenu.visible = !$DebugMenu.visible



func _add_npc() -> void:
	var free_seat = seats.find(null)
	if free_seat == -1:
		print("Full")
		return

	var npc = BASE_NPC.instantiate()
	var paths = ["res://NPC/Resources/scott.tres", "res://NPC/Resources/slime.tres"]

	add_child(npc)
	npc.global_position = $Spawn.global_position
	seats[free_seat] = npc
	npc.name = "seat%d_npc" % (free_seat + 1)
	npc._moving_to(get_node("Seat%d" % (free_seat + 1)))
	var marker_grab = get_node("Recipt" + str(free_seat +1))
	npc._institate(load(paths.pick_random()),free_seat+1,marker_grab)
	var order = npc._want_drink()
	match free_seat:
		0: GameState.seat1_order = order
		1: GameState.seat2_order = order
		2: GameState.seat3_order = order

func get_seat_drink(seat: int) -> String:  # seat is 1-3
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
	seats[seat -1] = null

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
