extends Area3D
@onready var keg_sprite = get_node("CHUGCHUGBEER")
@onready var keg_water_particle = get_node("CPUParticles3D")
@onready var pour_zone = get_node("PourArea/PourZone")
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
const POUR_AMOUNT := 0.0825
const POUR_INTERVAL := 0.033
const SFX_INTERVAL_MS := 100

var _snap_zone: PourStreamVisual.SnapZoneHelper = PourStreamVisual.SnapZoneHelper.new()
var in_pour_zone: Glasses:
	get:
		return _snap_zone.active_glass
var _is_pouring: bool = false
var _pour_stream: PourStreamVisual = null
var _last_sfx_ms: int = -1

func _ready() -> void:
	_pour_stream = PourStreamVisual.new()
	add_child(_pour_stream)
	if is_instance_valid(keg_water_particle):
		keg_water_particle.emitting = false

func _snap_target() -> Node3D:
	return snap_point if snap_point else pour_zone

func _get_nozzle_world_position() -> Vector3:
	var target := _snap_target()
	var base_pos: Vector3 = target.global_position if is_instance_valid(target) else global_position
	var keg_y: float = keg_sprite.global_position.y - 0.04 if is_instance_valid(keg_sprite) else (base_pos.y + 0.34)
	return Vector3(base_pos.x, maxf(keg_y, base_pos.y + 0.30), base_pos.z)

func _get_keg_pour_angle() -> float:
	return lerpf(KEG_IDLE_ROT_X, KEG_MAX_POUR_ROT_X, PourStreamVisual.get_pour_height_ratio(get_viewport()))

func _get_tap_nozzle_position() -> Vector3:
	if is_instance_valid(keg_water_particle):
		return keg_water_particle.global_position
	var snap := _snap_target()
	if is_instance_valid(snap):
		return snap.global_position + Vector3(0.0, 0.35, 0.0)
	return global_position

func _get_beer_stream_target() -> Vector3:
	if in_pour_zone and is_instance_valid(in_pour_zone):
		return in_pour_zone.get_liquid_surface_world_position()
	var snap := _snap_target()
	if is_instance_valid(snap):
		return snap.global_position
	return _get_tap_nozzle_position() + Vector3(0.0, -0.4, 0.0)

@warning_ignore("unused_parameter")
func _on_beer_keg_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _is_pouring:
		_is_pouring = true
		_last_sfx_ms = -1
		if is_instance_valid(keg_water_particle):
			keg_water_particle.emitting = false
		var cam_rig: Camera3D = PourStreamVisual.focus_station_camera(self, "beer_camera_marker", 0.55)

		while PourStreamVisual.is_pour_button_held() and is_inside_tree():
			var rate_mult: float = PourStreamVisual.get_pour_rate_multiplier(get_viewport())
			if rate_mult > 0.02 and in_pour_zone and is_instance_valid(in_pour_zone):
				var target_pos := _get_beer_stream_target()
				var arrival_vel := _pour_stream.get_arrival_velocity() if is_instance_valid(_pour_stream) else Vector3(0.0, -1.8, 0.0)
				var pour_info: Dictionary = in_pour_zone.compute_pour_info_from_world(target_pos, arrival_vel)
				in_pour_zone._pouring("beer", POUR_AMOUNT * rate_mult, pour_info)
				_last_sfx_ms = PourStreamVisual.play_throttled_pour_sfx(_last_sfx_ms, SFX_INTERVAL_MS)
			await get_tree().create_timer(POUR_INTERVAL).timeout
			if not is_inside_tree():
				_is_pouring = false
				return
		keg_sprite.rotation_degrees.x = KEG_IDLE_ROT_X
		if is_instance_valid(keg_water_particle):
			keg_water_particle.emitting = false
		if is_instance_valid(_pour_stream):
			_pour_stream.set_stream_active(false)
		_is_pouring = false

		if cam_rig:
			await get_tree().create_timer(0.15).timeout
			if not is_inside_tree():
				return
			await PourStreamVisual.return_station_camera(self, cam_rig, 0.55)

func _process(delta: float) -> void:
	if _is_pouring:
		var target_rot: float = _get_keg_pour_angle()
		keg_sprite.rotation_degrees.x = lerpf(keg_sprite.rotation_degrees.x, target_rot, 1.0 - exp(-18.0 * delta))
		var rate_mult: float = PourStreamVisual.get_pour_rate_multiplier(get_viewport())
		if is_instance_valid(keg_water_particle):
			keg_water_particle.emitting = false
		if is_instance_valid(_pour_stream):
			if rate_mult > 0.02:
				var beer_col: Color = AtomicFluidShaders.LIQUID_COLOR.get("beer", Color(0.98, 0.322, 0.051, 1.0))
				var rim_pos: Variant = in_pour_zone.get_rim_center_world_position() if (in_pour_zone and is_instance_valid(in_pour_zone)) else null
				_pour_stream.set_stream_active(
					true,
					_get_tap_nozzle_position(),
					_get_beer_stream_target(),
					beer_col,
					rate_mult,
					Vector3.DOWN,
					true,
					false,
					rim_pos
				)
			else:
				_pour_stream.set_stream_active(false)
	else:
		keg_sprite.rotation_degrees.x = lerpf(keg_sprite.rotation_degrees.x, KEG_IDLE_ROT_X, 1.0 - exp(-18.0 * delta))
		if is_instance_valid(_pour_stream):
			_pour_stream.set_stream_active(false)

	if in_pour_zone and is_instance_valid(in_pour_zone):
		pour_zone.modulate = LOCKED_COLOR if in_pour_zone.is_snapped() else HOVER_COLOR
	else:
		pour_zone.modulate = IDLE_COLOR

func _on_pour_area_area_entered(area: Area3D) -> void:
	_snap_zone.handle_area_entered(area, _snap_target(), snap_pull_speed, snap_release_speed, snap_break_distance)

func _on_pour_area_area_exited(area: Area3D) -> void:
	_snap_zone.handle_area_exited(area, _snap_target(), snap_pull_speed, snap_release_speed, snap_break_distance)