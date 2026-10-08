extends Node3D

func _ready() -> void:
	$AnimationPlayer.speed_scale = 0.5
	$AnimationPlayer.play("movement")
