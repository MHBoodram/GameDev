extends Area3D
@export var base_object : Node3D
@export var method_calling : String = "interact"
var needs_player : bool = false

func interact() -> void:
	if(base_object.has_method(method_calling)):
		base_object.call(method_calling)
	else:
		print("Player doesn't have method: " + method_calling)
