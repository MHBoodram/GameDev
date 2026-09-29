extends Control

@onready var timer : ProgressBar = get_node("HBoxContainer/Timer")
@onready var patience_face : Sprite2D = get_node("HBoxContainer/Timer/Patience_Face")
@onready var race_face : Sprite2D = get_node("HBoxContainer/Timer/Race_Face")

func _setup(max_value: float, type: String) -> void:
	_change_max_progress(max_value)
	match type:
		"HUMAN":
			race_face.frame = 10
		"SLIME":
			race_face.frame = 7
		"VAMPIRE":
			race_face.frame = 9
		"FISH":
			race_face.frame = 8
		"TINY":
			race_face.frame = 11

func _change_max_progress(change: float) -> void:
	timer.max_value = change
	timer.value = change

func _change_curent(change: float) -> void:
	timer.value = change
	if(timer.max_value/5 > change):
		patience_face.frame = 6
	elif(2*timer.max_value/5 > change):
		patience_face.frame = 5
	elif(3*timer.max_value/5 > change):
		patience_face.frame = 4
	elif(4*timer.max_value/5 > change):
		patience_face.frame = 3
	else:
		patience_face.frame = 2
