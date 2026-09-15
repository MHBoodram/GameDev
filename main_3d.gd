extends Node3D
const BASE_NPC = preload("res://NPC/base npc.tscn")
var seat1_npc : Base_NPC = null
var seat2_npc : Base_NPC = null
var seat3_npc : Base_NPC = null


#func _ready() -> void:

func _input(event: InputEvent) -> void:
	#if(Input.is_action_just_pressed("ui_accept")):
		#get_tree().quit()
	if(Input.is_action_just_pressed("ui_accept")):
		_add_npc()
	if(Input.is_action_just_pressed("ui_left")):
		if(seat1_npc != null):
			_remove_npc(1)
			return
		elif(seat2_npc != null):
			_remove_npc(2)
			return
		elif(seat3_npc != null):
			_remove_npc(3)
			return

func _add_npc() -> void:
	var npc = BASE_NPC.instantiate()
	npc._institate(load("res://NPC/scott.tres"))
	add_child(npc)
	npc.global_position = $Spawn.global_position
	if(seat1_npc == null):
		seat1_npc = npc
		npc.name = "seat1_npc"
		npc._moving_to($Seat1)
		GameState.seat1_order = npc._want_drink(1)
		return
	elif(seat2_npc == null):
		seat2_npc = npc
		npc.name = "seat2_npc"
		npc._moving_to($Seat2)
		GameState.seat2_order = npc._want_drink(2)

		return
	elif(seat3_npc == null):
		seat3_npc = npc
		npc.name = "seat3_npc"
		npc._moving_to($Seat3)
		GameState.seat3_order = npc._want_drink(3)

		return
	else:
		npc.queue_free()
	print("Full")
	
	
func _remove_npc(seat: int) -> void:
	var seat_delete = get_node("seat" + str(seat) + "_npc")
	seat_delete._leaving()
	#seat_delete.queue_free()
