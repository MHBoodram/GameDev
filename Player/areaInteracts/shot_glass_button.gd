extends Area3D
@export var player : Node3D


func interact() -> void:
	print("working")
	player._summon_shotglass()
