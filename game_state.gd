extends Node

var seat1_order : Array = []
var seat2_order : Array = []
var seat3_order : Array = []
var night : int = 1
var max_nights : int = 7
var night_duration : float = 300.0
var restarts_left : int = 3
const MAX_RESTARTS : int = 3
const BASE_QUOTA : float = 150.0
var current_quota : float = 150.0

var player : Node3D
var main_node : Node3D
var gameplay_ui : CanvasLayer
var special_state : bool = true
var night_paused : bool = false
var can_end_night : bool = true
var is_dialogue_open : bool = false

func get_night_quota(night_number: int) -> float:
	current_quota = BASE_QUOTA * float(night_number * night_number)
	print("[night_quota]: ", current_quota)
	return current_quota

# Night restart
func use_restart() -> bool:
	if restarts_left > 0:
		restarts_left -= 1
		print("[night_restarts_remaining]: ", restarts_left)
		return true
	print("[night_restarts_remaining]: ", restarts_left)
	return false

# Resets available restarts
func reset_night_restarts() -> void:
	restarts_left = MAX_RESTARTS
	print("[night_restarts_remaining]: ", restarts_left)

func advance_night() -> void:
	night += 1
	reset_night_restarts()
	get_night_quota(night)
	print("[current_night]: ", night)

func pause_night() -> void:
	night_paused = true
	if main_node and main_node.has_method("pause_night"):
		main_node.pause_night()
	print("[night_paused]: true")

func resume_night() -> void:
	night_paused = false
	if main_node and main_node.has_method("resume_night"):
		main_node.resume_night()
	print("[night_paused]: false")

func hold_night_end(hold: bool = true) -> void:
	can_end_night = !hold
	print("[can_end_night]: ", can_end_night)

# Placeholder method for adding receipts
func _add_recipit(seat: int):
	pass
