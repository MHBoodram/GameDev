extends Control

@onready var timer : ProgressBar = get_node("Timer")


func _change_max_progress(change: float) -> void:
	timer.max_value = change
	timer.value = change

func _change_curent(change: float) -> void:
	timer.value = change
