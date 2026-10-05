extends MeshInstance3D
@onready var recipt_2d = get_node("Base_viewport/SubViewport/Recipt")
@export var recipt_marker : Marker3D
var recipt_clicked : bool = false
var put_on : Area3D
var drag_z_depth
@export var counter_origin : Node3D
@export var seat_num : int = 1
var base_y_position = 1.6
var is_balls_dragging : bool = false
var camera : Camera3D
var ordered : bool = false

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if(is_balls_dragging):
		var mouse_pos = get_viewport().get_mouse_position()
		var new_projection = camera.project_position(mouse_pos, drag_z_depth)
		new_projection.x = clamp(new_projection.x, -1.2 + counter_origin.global_position.x,1.4+ counter_origin.global_position.x)
		new_projection.z = clamp(new_projection.z, counter_origin.global_position.z - 0.4,counter_origin.global_position.z + 0.4)
		if(new_projection.z < 0.28):
			new_projection.y = base_y_position + 0.2
		else:
			new_projection.y = base_y_position
		global_position = new_projection
		if(Input.is_action_just_released("Left_click")):
			is_balls_dragging = false
			if(put_on):
				ordered = false
				get_parent()._give_drink(self,put_on.get_parent(),seat_num)
	elif(ordered):
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(self,"global_position", recipt_marker.global_position,0.5)

func _moving_to(to: Marker3D) -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"global_position",to.global_position,0.5)

func _write(words: String) -> void:
	recipt_2d._label_change(words)

@warning_ignore("unused_parameter", "shadowed_variable")
func _on_recipt_area_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		is_balls_dragging = true
		var to_object = global_position - camera.global_position
		var forward = -camera.global_transform.basis.z
		drag_z_depth = to_object.dot(forward)

func _on_recipt_area_area_entered(area: Area3D) -> void:
	if is_balls_dragging && area.is_in_group("glass"):
		put_on = area
		area.get_parent()._on_hover(true)
		

func _on_recipt_area_area_exited(area: Area3D) -> void:
	if is_balls_dragging && put_on == area:
		put_on = null
		area.get_parent()._on_hover(false)
