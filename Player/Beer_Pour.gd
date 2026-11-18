extends Area3D
@onready var keg_sprite = get_node("CHUGCHUGBEER")
@onready var keg_water_particle = get_node("CPUParticles3D")
@onready var pour_zone = get_node("PourArea/PourZone")
#var in_pour_zone : Area3D
@onready var snap_point: Node3D = get_node_or_null("PourArea/SnapPoint")

@export_group("Glass Snapping")
@export var snap_pull_speed: float = 22.0
@export var snap_release_speed: float = 16.0
@export var snap_break_distance: float = 0.35

const IDLE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HOVER_COLOR := Color(1.0, 0.0, 0.0, 0.9)
const LOCKED_COLOR := Color(0.3, 1.0, 0.3, .9)

var in_pour_zone: Glasses = null
var _glasses_in_area: Array[Glasses] = []
var _is_pouring: bool = false

func _snap_target() -> Node3D:
	return snap_point if snap_point else pour_zone

func _get_camera_rig() -> Camera3D:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam and cam.has_method("focus_on_marker") and cam.has_method("return_from_marker"):
		return cam
	return null

func _get_beer_camera_marker() -> Node3D:
	var scene_root := get_tree().current_scene
	if is_instance_valid(scene_root):
		var marker := scene_root.get_node_or_null("beer_camera_marker") as Node3D
		if marker:
			return marker
	if is_instance_valid(GameState.main_node):
		return GameState.main_node.get_node_or_null("beer_camera_marker") as Node3D
	return null

func _is_pour_button_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.get_action_strength("Left_click") > 0.0

@warning_ignore("unused_parameter")
func _on_beer_keg_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _is_pouring:
		_is_pouring = true
		var cam_rig: Camera3D = _get_camera_rig()
		var marker := _get_beer_camera_marker()
		if cam_rig and marker:
			if GameState.gameplay_ui and GameState.gameplay_ui.has_method("_in_down_minigame"):
				GameState.gameplay_ui._in_down_minigame()
			cam_rig.call("focus_on_marker", marker, 0.5)

		keg_sprite.rotation_degrees.x = -64.5
		keg_water_particle.emitting = true
		while _is_pour_button_held() and is_inside_tree():
			if in_pour_zone and is_instance_valid(in_pour_zone):
				in_pour_zone._pouring("beer", 0.25)
				SFXAudio.play_liquidpour()
			await get_tree().create_timer(0.1).timeout
			if not is_inside_tree():
				_is_pouring = false
				return
		keg_sprite.rotation_degrees.x = -131.5
		keg_water_particle.emitting = false

		if cam_rig and marker:
			await get_tree().create_timer(0.15).timeout
			if not is_inside_tree():
				_is_pouring = false
				return
			cam_rig.call("return_from_marker", 0.5)
			if GameState.gameplay_ui and GameState.gameplay_ui.has_method("_out_down_minigame"):
				GameState.gameplay_ui._out_down_minigame()
		_is_pouring = false

func _process(_delta: float) -> void:
	if in_pour_zone and is_instance_valid(in_pour_zone):
		pour_zone.modulate = LOCKED_COLOR if in_pour_zone.is_snapped() else HOVER_COLOR
	else:
		pour_zone.modulate = IDLE_COLOR

func _on_pour_area_area_entered(area: Area3D) -> void:
	#if(area.is_in_group("glass") && !in_pour_zone):
		#var temp_global_position = Vector3($PourArea/CollisionShape3D.global_position.x,area.global_position.y,$PourArea/CollisionShape3D.global_position.z)
		#area.global_position = temp_global_position
		#in_pour_zone = area
		#pour_zone.modulate = Color(1, 0, 0)
	if not (area is Glasses) or not area.is_in_group("glass"):
		return
	if not _glasses_in_area.has(area):
		_glasses_in_area.append(area)
	if not in_pour_zone:
		_set_active_glass(area)


func _on_pour_area_area_exited(area: Area3D) -> void:
	#if(area == in_pour_zone):
		#area._remove_displaying_list()
		#in_pour_zone = null
		#pour_zone.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if(_glasses_in_area.size() > 0):
		_glasses_in_area.erase(area)
	if area == in_pour_zone:
		if is_instance_valid(area):
			area.exit_snap_zone(_snap_target())
			area._remove_displaying_list()
		in_pour_zone = null
		for g in _glasses_in_area:
			if is_instance_valid(g):
				_set_active_glass(g)
				break

func _set_active_glass(glass: Glasses) -> void:
	in_pour_zone = glass
	glass.enter_snap_zone(_snap_target(), snap_pull_speed, snap_release_speed - 1, snap_break_distance)
	