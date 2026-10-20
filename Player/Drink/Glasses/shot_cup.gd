extends Glasses

# Disconnects input when drink is handed to customer
func _giving_drink() -> void:
	if has_node("Area3D"):
		$Area3D.disconnect("input_event", _on_area_3d_input_event)
	is_balls_dragging = false