extends Glasses

# Disconnects input when drink is handed to customer
func _giving_drink() -> void:
	if input_event.is_connected(_on_area_3d_input_event):
		input_event.disconnect(_on_area_3d_input_event)
	is_balls_dragging = false