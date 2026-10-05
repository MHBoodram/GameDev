extends Camera3D

@export var max_offset := Vector2(0.15, 0.15)   
@export var max_roll := 0.05                    
@export var decay := 1.5                        
@export var noise_speed := 40.0

var trauma := 0.0
var noise := FastNoiseLite.new()
var time := 0.0

func _ready():
	noise.seed = randi()
	noise.frequency = 1.0

func add_shake(amount: float):
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta):
	if trauma > 0.0:
		trauma = max(trauma - decay * delta, 0.0)
		time += delta * noise_speed
		var shake := trauma * trauma  
		h_offset = max_offset.x * shake * noise.get_noise_2d(time, 0.0)
		v_offset = max_offset.y * shake * noise.get_noise_2d(0.0, time)
		rotation.z = max_roll * shake * noise.get_noise_2d(time, time)
	else:
		h_offset = 0.0
		v_offset = 0.0
		rotation.z = 0.0

func _force_set_camera(seat: int = 1) -> void:
	match seat:
		1:
			pass
		2:
			pass
		3:
			pass
		_:
			pass
