extends Camera3D
const SENSITIVITY: float = 0.1

var twist_input: float = 0.0
var pitch_input: float = 0.0
var current_position : int = 3
var match_position_counter : Dictionary ={"1" : -0.2,"2":2.8,"3": 5.8}
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
			moving_around(false)
		elif event.physical_keycode == KEY_A:
			moving_around(true)
			
				
func moving_around(right : bool) -> void:
	if(right):
		if(current_position > 1):
			current_position -= 1
			var new_position = match_position_counter[str(current_position)]
			 #= get_parent().position.x + 3
			#new_position = clamp(new_position,-0.2,9)
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(get_parent(),"position:x",new_position,0.15)
			
	else:
		if(current_position < 3):
			current_position += 1
			var new_position = match_position_counter[str(current_position)]

			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(get_parent(),"position:x",new_position,0.15)
			

func try_interact() -> void:
	var collider
	if ray_cast.is_colliding():
		collider = ray_cast.get_collider()
	print(collider)
	if collider is Area3D:
		if(collider.has_method("interact")):
			collider.interact()

func _process(delta: float) -> void:
	var current_q = basis.get_rotation_quaternion()
	var twist_q = Quaternion(Vector3.UP, deg_to_rad(twist_input))
	var pitch_q = Quaternion(Vector3.RIGHT, deg_to_rad(pitch_input))
	var smoothed_q = current_q.slerp(twist_q * pitch_q, delta * 20.0)
	basis = Basis(smoothed_q)
