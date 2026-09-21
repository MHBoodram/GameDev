extends Sprite3D
class_name Ingredients
var is_balls_dragging : bool = false
var mouse_offset: Vector2 = Vector2.ZERO
var camera : Camera3D
var drag_z_depth: float = 0.0
@export var counter_origin : Node3D

func _instiate(counter: Node3D):
	counter_origin = counter

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	look_at(camera.global_position)


func _process(_delta: float) -> void:
	if is_balls_dragging:
		var mouse_pos = get_viewport().get_mouse_position()
		var new_projection = camera.project_position(mouse_pos, drag_z_depth)
		new_projection.y = global_position.y
		new_projection.x = clamp(new_projection.x, -1 + counter_origin.global_position.x,1.184+ counter_origin.global_position.x)
		new_projection.z = max(new_projection.z, 0.28)

		global_position = new_projection
		if(Input.is_action_just_released("Left_click")):
			is_balls_dragging = false
		look_at(camera.global_position)

func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_balls_dragging = true
			var to_object = global_position - camera.global_position
			var forward = -camera.global_transform.basis.z
			drag_z_depth = to_object.dot(forward)
		else:
			is_balls_dragging = false

func _return_original():
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	#tween.tween_property(self,"position",original_position,0.5)
	#tween.tween_property(self,"position",original_position,0.5)
