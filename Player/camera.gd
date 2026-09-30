extends Camera3D
const SENSITIVITY: float = 0.1

var twist_input: float = 0.0
var pitch_input: float = 0.0
var current_position : int = 3

@onready var ray_cast = get_node("RayCast3D")

#func _ready() -> void:
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		twist_input -= event.screen_relative.x * SENSITIVITY
		pitch_input -= event.screen_relative.y * SENSITIVITY
		twist_input = clamp(twist_input, -75, 75)
		pitch_input = clamp(pitch_input, -85, 85)
		
	if event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			try_interact()
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_D:
			moving_around(true)
		elif event.physical_keycode == KEY_A:
			moving_around(false)
			
				
func moving_around(right : bool) -> void:
	if(right):
		print(right)
		if(current_position > 1):
			var new_position = get_parent().position.x + 3
			new_position = clamp(new_position,0,9)
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(get_parent(),"position:x",new_position,0.15)
			current_position -= 1
	else:
		if(current_position < 3):
			var new_position = get_parent().position.x - 3
			new_position = clamp(new_position,0,9)

			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(get_parent(),"position:x",new_position,0.15)
			current_position += 1
			

func try_interact() -> void:
	var collider
	if ray_cast.is_colliding():
		collider = ray_cast.get_collider()
	print(collider)
	if collider is Area3D:
		if(collider.has_method("interact") && collider.is_in_group("interactable")):
			collider.interact()

func _process(delta: float) -> void:
	var current_q = basis.get_rotation_quaternion()
	var twist_q = Quaternion(Vector3.UP, deg_to_rad(twist_input))
	var pitch_q = Quaternion(Vector3.RIGHT, deg_to_rad(pitch_input))
	var smoothed_q = current_q.slerp(twist_q * pitch_q, delta * 20.0)
	basis = Basis(smoothed_q)
