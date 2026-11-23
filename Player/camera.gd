class_name Camera
extends Camera3D

# handles camera movement

signal marker_returned

@export var seat_markers: Array[NodePath] = []
@export var max_offset := Vector2(0.15, 0.15)
@export var max_roll := 0.05
@export var decay := 1.5
@export var noise_speed := 40.0

var trauma := 0.0
var noise := FastNoiseLite.new()
var noise_time := 0.0

var current_position: int = 3
var match_position_counter: Dictionary = {1: 3.17, 2: 0.17, 3: -2.83}
var down: bool = false
var is_transitioning: bool = false
var is_moving: bool = false
var default_camera_local_pos: Vector3 = Vector3.ZERO

var _marker_tween: Tween = null
var _is_at_marker: bool = false
var _has_saved_marker_return: bool = false
var _saved_marker_return_pos: Vector3 = Vector3.ZERO
var _saved_marker_return_rot: Vector3 = Vector3.ZERO

const CAMERA_Y_OFFSET: float = 0.3
const CAMERA_TILT_OFFSET: float = 5.0
const BASE_FRONT_CAMERA_ROTATION: Vector3 = Vector3(-16.3, 0.0, 0.0)
const BASE_BACK_CAMERA_ROTATION: Vector3 = Vector3(-21.0, 180.0, 0.0)

var base_camera_rotation: Vector3 = BASE_FRONT_CAMERA_ROTATION + Vector3(CAMERA_TILT_OFFSET, 0.0, 0.0)
var current_tilt_yaw: float = 0.0
var current_tilt_pitch: float = 0.0
const MAX_TILT_YAW: float = 3.0
const MAX_TILT_PITCH: float = 2.0

@onready var player_node: Node3D = get_parent() as Node3D

func _ready() -> void:
	noise.seed = randi()
	noise.frequency = 1.0
	position.y += CAMERA_Y_OFFSET
	default_camera_local_pos = position
	_connect_game_events()
	call_deferred("_setup_stool_markers")

func _exit_tree() -> void:
	if GameEvents._bus:
		if GameEvents.camera_shake_requested.is_connected(_on_camera_shake_requested):
			GameEvents.camera_shake_requested.disconnect(_on_camera_shake_requested)
		if GameEvents.camera_focus_requested.is_connected(_on_camera_focus_requested):
			GameEvents.camera_focus_requested.disconnect(_on_camera_focus_requested)
		if GameEvents.camera_return_requested.is_connected(_on_camera_return_requested):
			GameEvents.camera_return_requested.disconnect(_on_camera_return_requested)

func _connect_game_events() -> void:
	if not GameEvents.camera_shake_requested.is_connected(_on_camera_shake_requested):
		GameEvents.camera_shake_requested.connect(_on_camera_shake_requested)
	if not GameEvents.camera_focus_requested.is_connected(_on_camera_focus_requested):
		GameEvents.camera_focus_requested.connect(_on_camera_focus_requested)
	if not GameEvents.camera_return_requested.is_connected(_on_camera_return_requested):
		GameEvents.camera_return_requested.connect(_on_camera_return_requested)

func _on_camera_shake_requested(amount: float) -> void:
	if current:
		add_shake(amount)

func _on_camera_focus_requested(marker: Node3D, duration: float) -> void:
	if current:
		focus_on_marker(marker, duration)

func _on_camera_return_requested(duration: float) -> void:
	if current:
		return_from_marker(duration)

func _resolve_seat_markers() -> Array[Node3D]:
	var resolved: Array[Node3D] = []
	for path in seat_markers:
		if not path.is_empty():
			var node := get_node_or_null(path) as Node3D
			if is_instance_valid(node):
				resolved.append(node)
	if resolved.size() >= 3:
		return resolved

	if is_inside_tree():
		var grouped := get_tree().get_nodes_in_group("seat_markers")
		if grouped.size() >= 3:
			var sorted_group: Array[Node3D] = []
			for n in grouped:
				if n is Node3D:
					sorted_group.append(n as Node3D)
			sorted_group.sort_custom(func(a: Node3D, b: Node3D) -> bool:
				return a.name.naturalnocasecmp_to(b.name) < 0
			)
			if sorted_group.size() >= 3:
				return sorted_group

	var scene_root: Node = get_tree().current_scene
	if is_instance_valid(scene_root):
		for seat_name in ["Seat1", "Seat2", "Seat3"]:
			var seat_node := scene_root.get_node_or_null(seat_name) as Node3D
			if is_instance_valid(seat_node):
				resolved.append(seat_node)
	return resolved

# aligns stool movement offsets to match the 3D scene seat markers
func _setup_stool_markers() -> void:
	var seats := _resolve_seat_markers()
	if seats.is_empty():
		return
	var seat1: Node3D = seats[0] if seats.size() > 0 else null
	var seat2: Node3D = seats[1] if seats.size() > 1 else null
	var seat3: Node3D = seats[2] if seats.size() > 2 else null
	var cam_x_offset: float = position.x

	if seat3:
		match_position_counter[1] = seat3.global_position.x - cam_x_offset
	if seat2:
		match_position_counter[2] = seat2.global_position.x - cam_x_offset
	if seat1:
		match_position_counter[3] = seat1.global_position.x - cam_x_offset
		if player_node:
			position.z = (seat1.global_position.z + 1.6) - player_node.global_position.z
			default_camera_local_pos = position

	if player_node and match_position_counter.has(current_position):
		player_node.position.x = match_position_counter[current_position]

func add_shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_update_shake(delta)
	_update_mouse_tilt(delta)

# screenshake
func _update_shake(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(trauma - decay * delta, 0.0)
		noise_time += delta * noise_speed
		var shake := trauma * trauma
		h_offset = max_offset.x * shake * noise.get_noise_2d(noise_time, 0.0)
		v_offset = max_offset.y * shake * noise.get_noise_2d(0.0, noise_time)
		rotation.z = max_roll * shake * noise.get_noise_2d(noise_time, noise_time)
	else:
		h_offset = 0.0
		v_offset = 0.0
		rotation.z = 0.0

# tilts camera angles towards cursor
func _update_mouse_tilt(delta: float) -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	var center := viewport_rect.size * 0.5
	if center.x <= 0.0 or center.y <= 0.0:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var norm_x := clampf((mouse_pos.x - center.x) / center.x, -1.0, 1.0)
	var norm_y := clampf((mouse_pos.y - center.y) / center.y, -1.0, 1.0)
	var target_yaw := -norm_x * MAX_TILT_YAW
	var target_pitch := -norm_y * MAX_TILT_PITCH
	current_tilt_yaw = lerpf(current_tilt_yaw, target_yaw, 1.0 - exp(-10.0 * delta))
	current_tilt_pitch = lerpf(current_tilt_pitch, target_pitch, 1.0 - exp(-10.0 * delta))
	rotation_degrees.x = base_camera_rotation.x + current_tilt_pitch
	rotation_degrees.y = base_camera_rotation.y + current_tilt_yaw

# slides the player between the 3 stools
func moving_around(right: bool) -> void:
	if down or is_transitioning or is_moving or not player_node:
		return
	if right:
		if current_position > 1:
			current_position -= 1
			_tween_to_stool(match_position_counter[current_position])
	else:
		if current_position < 3:
			current_position += 1
			_tween_to_stool(match_position_counter[current_position])

func _tween_to_stool(target_x: float) -> void:
	is_moving = true
	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(player_node, "position:x", target_x, 0.15)
	tween.finished.connect(_on_stool_move_finished)

func _on_stool_move_finished() -> void:
	is_moving = false

# toggles between facing front or back counter
func bendover() -> void:
	if is_transitioning or is_moving or _is_at_marker:
		return
	is_transitioning = true
	if down:
		_look_forward()
	else:
		_look_behind()
	down = !down

func _look_behind() -> void:
	var tween := get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var back_pos := Vector3(3.28, 2.75, 0.85)
	var camera_mark := get_tree().get_first_node_in_group("counter_mark") as Node3D
	if not camera_mark and player_node and "counter" in player_node and player_node.counter:
		camera_mark = player_node.counter.get_node_or_null("Camera mark") as Node3D
	if camera_mark:
		back_pos = camera_mark.global_position
	back_pos.y += CAMERA_Y_OFFSET

	var target_rot := BASE_BACK_CAMERA_ROTATION + Vector3(CAMERA_TILT_OFFSET, 0.0, 0.0)
	tween.tween_property(self, "base_camera_rotation", target_rot, 0.5)
	tween.tween_property(self, "global_position", back_pos, 0.5)
	tween.chain().tween_callback(_on_bendover_finished)

func _look_forward() -> void:
	var tween := get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var target_rot := BASE_FRONT_CAMERA_ROTATION + Vector3(CAMERA_TILT_OFFSET, 0.0, 0.0)
	tween.tween_property(self, "base_camera_rotation", target_rot, 0.5)
	tween.tween_property(self, "position", default_camera_local_pos, 0.5)
	tween.chain().tween_callback(_on_bendover_finished)

func _on_bendover_finished() -> void:
	is_transitioning = false

func focus_on_marker(marker: Node3D, duration: float = 0.5) -> void:
	if not is_instance_valid(marker):
		return
	if _marker_tween and _marker_tween.is_valid():
		_marker_tween.kill()
	if not _has_saved_marker_return:
		_saved_marker_return_pos = global_position
		_saved_marker_return_rot = base_camera_rotation
		_has_saved_marker_return = true
	_is_at_marker = true

	var target_rot := BASE_BACK_CAMERA_ROTATION + Vector3(CAMERA_TILT_OFFSET, 0.0, 0.0)
	_marker_tween = get_tree().create_tween().set_parallel(true)
	_marker_tween.set_trans(Tween.TRANS_CUBIC)
	_marker_tween.set_ease(Tween.EASE_IN_OUT)
	_marker_tween.tween_property(self, "global_position", marker.global_position, duration)
	_marker_tween.tween_property(self, "base_camera_rotation", target_rot, duration)

func return_from_marker(duration: float = 0.5) -> void:
	if not _is_at_marker:
		marker_returned.emit()
		return
	if _marker_tween and _marker_tween.is_valid():
		_marker_tween.kill()
	var target_pos := _saved_marker_return_pos
	var target_rot := _saved_marker_return_rot
	_marker_tween = get_tree().create_tween().set_parallel(true)
	_marker_tween.set_trans(Tween.TRANS_CUBIC)
	_marker_tween.set_ease(Tween.EASE_IN_OUT)
	_marker_tween.tween_property(self, "global_position", target_pos, duration)
	_marker_tween.tween_property(self, "base_camera_rotation", target_rot, duration)
	_marker_tween.chain().tween_callback(_on_marker_return_finished)

func _on_marker_return_finished() -> void:
	_is_at_marker = false
	_has_saved_marker_return = false
	marker_returned.emit()
