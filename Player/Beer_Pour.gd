extends Area3D
@onready var keg_sprite = get_node("CHUGCHUGBEER")
@onready var keg_water_particle = get_node("CPUParticles3D")
@onready var pour_zone = get_node("PourArea/PourZone")
#var in_pour_zone : Area3D
@onready var snap_point: Node3D = get_node_or_null("PourArea/SnapPoint")

@export_group("Glass Snapping")
@export var snap_pull_speed: float = 22.0
@export var snap_release_speed: float = 16.0
@export var snap_break_distance: float = 0.25

const IDLE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HOVER_COLOR := Color(1.0, 0.0, 0.0, 0.9)
const LOCKED_COLOR := Color(0.3, 1.0, 0.3, .9)
const KEG_IDLE_ROT_X := -131.5
const KEG_MAX_POUR_ROT_X := 2.5

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

func _get_pour_height_ratio() -> float:
	var viewport := get_viewport()
	if not viewport:
		return 0.5
	var vp_height: float = viewport.get_visible_rect().size.y
	if vp_height <= 1.0:
		return 0.5
	var mouse_y: float = viewport.get_mouse_position().y
	var raw_height: float = 1.0 - clampf(mouse_y / vp_height, 0.0, 1.0)
	return clampf((raw_height - 0.1) / 0.8, 0.0, 1.0)

func _get_pour_rate_multiplier() -> float:
	return _get_pour_height_ratio() * 2.0

func _get_keg_pour_angle() -> float:
	return lerpf(KEG_IDLE_ROT_X, KEG_MAX_POUR_ROT_X, _get_pour_height_ratio())

@warning_ignore("unused_parameter")
func _on_beer_keg_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _is_pouring:
		_is_pouring = true
		var cam_rig: Camera3D = _get_camera_rig()
		var marker := _get_beer_camera_marker()
		if cam_rig and marker:
			if GameState.gameplay_ui and GameState.gameplay_ui.has_method("_in_down_minigame"):
				GameState.gameplay_ui._in_down_minigame()
			cam_rig.call("focus_on_marker", marker, 0.55)

		while _is_pour_button_held() and is_inside_tree():
			var rate_mult: float = _get_pour_rate_multiplier()
			if rate_mult > 0.0 and in_pour_zone and is_instance_valid(in_pour_zone):
				in_pour_zone._pouring("beer", 0.25 * rate_mult)
				SFXAudio.play_liquidpour()
			await get_tree().create_timer(0.1).timeout
			if not is_inside_tree():
				_is_pouring = false
				return
		keg_sprite.rotation_degrees.x = KEG_IDLE_ROT_X
		keg_water_particle.emitting = false
		_is_pouring = false

		if cam_rig and marker:
			await get_tree().create_timer(0.15).timeout
			if not is_inside_tree():
				return
			cam_rig.call("return_from_marker", 0.55)
			if cam_rig.has_signal("marker_returned"):
				await cam_rig.marker_returned
			if not is_inside_tree():
				return
			if GameState.gameplay_ui and GameState.gameplay_ui.has_method("_out_down_minigame"):
				GameState.gameplay_ui._out_down_minigame()

func _process(delta: float) -> void:
	if _is_pouring:
		var target_rot: float = _get_keg_pour_angle()
		keg_sprite.rotation_degrees.x = lerpf(keg_sprite.rotation_degrees.x, target_rot, 1.0 - exp(-18.0 * delta))
		keg_water_particle.emitting = _get_pour_rate_multiplier() > 0.0

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
	glass.enter_snap_zone(_snap_target(), snap_pull_speed, snap_release_speed, snap_break_distance)
	