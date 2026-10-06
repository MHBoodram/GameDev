extends CanvasLayer
var camera : Camera3D

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

func _process(delta: float) -> void:
	if(visible):
		$TextureRect/VBoxContainer/HBoxContainer/Fps.text = "FPS: " + str(Engine.get_frames_per_second())

func _on_add_npc_pressed() -> void:
	GameState.main_node._add_npc()

func _on_remove_npc_pressed() -> void:
	for i in GameState.main_node.seats.size():
		if GameState.main_node.seats[i] != null:
			GameState.main_node._remove_npc(i +1)
			break

func _on_camera_shake_pressed() -> void:
	camera.add_shake(5)
