extends Node3D
const BASE_NPC = preload("res://NPC/base npc.tscn")
var seats: Array[Base_NPC] = [null, null, null]
@onready var player = get_node("Player")

func _ready() -> void:
	GameState.player = $Player

func _print_reading_dialogue() -> void:
	print("Printing dialgoue or something")

func _input(event: InputEvent) -> void:
	#if(Input.is_action_just_pressed("ui_accept")):
		#get_tree().quit()
	if(Input.is_action_just_pressed("ui_accept")):
		_add_npc()
	if Input.is_action_just_pressed("ui_left"):
		for i in seats.size():
			if seats[i] != null:
				_remove_npc(i + 1)
				break

func _add_npc() -> void:
	var free_seat = seats.find(null)
	if free_seat == -1:
		print("Full")
		return

	var npc = BASE_NPC.instantiate()
	var paths = ["res://NPC/scott.tres", "res://NPC/slime.tres"]

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
	if npc == null:
		return
	seats[seat - 1] = null
	npc._leaving()

func _remove(seat: int) -> void:
	seats[seat -1] = null

func _add_recipt(seat: int) -> void:
	var string_recipt = "Recipt" + str(seat) + "Paper"
	var recipt_node = get_node(string_recipt)
	var marker_node = get_node("Recipt" + str(seat))
	var tween = get_tree().create_tween()
	recipt_node.global_position = player.global_position
	tween.tween_property(recipt_node,"global_position",marker_node.global_position,1)
