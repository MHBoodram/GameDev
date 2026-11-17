extends CanvasLayer
var camera: Camera3D

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	if visible:
		$TextureRect/VBoxContainer/HBoxContainer/Fps.text = "FPS: " + str(Engine.get_frames_per_second())

func _on_serve_good_pressed() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.debug_serve_all("good")

func _on_serve_bad_pressed() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.debug_serve_all("bad")

func _on_add_rep_pressed() -> void:
	PlayerStats.add_overall_reputation(10.0)

func _on_end_night_pressed() -> void:
	if GameState.night_manager:
		GameState.night_manager.end_shift()
	if GameState.seat_manager:
		GameState.seat_manager.clear_all_customers()

func _on_add_npc_pressed() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.spawn_random_customer()

func _on_add_money_pressed() -> void:
	PlayerStats._change_money(PlayerStats.money + 1000.0)

func _on_remove_npc_pressed() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.remove_first_occupied_seat()

func _on_camera_shake_pressed() -> void:
	if camera and camera.has_method("add_shake"):
		camera.add_shake(5)

func _on_add_npc_specific_pressed() -> void:
	if GameState.seat_manager:
		var opt := $TextureRect/VBoxContainer/HBoxContainer/HBoxContainer/OptionButton as OptionButton
		if opt:
			var species_name: String = opt.get_item_text(opt.selected)
			GameState.seat_manager.spawn_specific_species(species_name)
