extends Node3D

func _ready() -> void:
	$NPC._moving_to($Seat1)

func _input(event: InputEvent) -> void:
	if(Input.is_action_just_pressed("ui_accept")):
		get_tree().quit()
