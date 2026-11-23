class_name StationFocusController
extends Node

# Camera focus switching, minigame UI lock, perfect pour transition

static var current: StationFocusController = null

var is_locked: bool = false
var _owner_player: Node3D = null
var _camera_rig: Camera3D = null
var _pour_tween: Tween = null
var _bottle_pour_active: bool = false
var _active_drink: Drinks = null
var _active_glass: Glasses = null
var _drink_return_pos: Vector3 = Vector3.ZERO
var _glass_return_pos: Vector3 = Vector3.ZERO

static func get_current(context: Node = null) -> StationFocusController:
	if is_instance_valid(current) and current.is_inside_tree():
		return current
	if is_instance_valid(GameState.player):
		var found := GameState.player.get_node_or_null("StationFocusController") as StationFocusController
		if is_instance_valid(found):
			return found
		if "station_focus" in GameState.player and is_instance_valid(GameState.player.station_focus):
			return GameState.player.station_focus as StationFocusController
	if is_instance_valid(context) and context.is_inside_tree():
		var root := context.get_tree().current_scene
		if is_instance_valid(root):
			var node := root.find_child("StationFocusController", true, false) as StationFocusController
			if is_instance_valid(node):
				return node
	return null

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null

func setup(player_node: Node3D, cam_rig: Camera3D = null) -> void:
	_owner_player = player_node
	_camera_rig = cam_rig

func is_bottle_pour_active() -> bool:
	return _bottle_pour_active

func _get_camera() -> Camera3D:
	if is_instance_valid(_camera_rig):
		return _camera_rig
	if is_inside_tree():
		return get_viewport().get_camera_3d()
	return null

func _set_player_lock(locked: bool) -> void:
	is_locked = locked
	var target_player: Node3D = _owner_player if is_instance_valid(_owner_player) else GameState.player
	if is_instance_valid(target_player) and "in_game" in target_player:
		target_player.in_game = locked

func begin_station(camera_marker: Node3D = null, duration: float = 0.55, lock_player: bool = true) -> void:
	if lock_player:
		_set_player_lock(true)
	GameEvents.minigame_lock_changed.emit(true)
	if is_instance_valid(camera_marker):
		GameEvents.camera_focus_requested.emit(camera_marker, duration)

func end_station(return_camera: bool = true, duration: float = 0.55) -> void:
	if return_camera:
		var cam := _get_camera()
		GameEvents.camera_return_requested.emit(duration)
		if is_instance_valid(cam) and cam.has_signal("marker_returned") and cam.get("_is_at_marker") == true:
			await cam.marker_returned
		if not is_inside_tree():
			return
	_set_player_lock(false)
	GameEvents.minigame_lock_changed.emit(false)

func begin_bottle_pour(drink: Drinks, glass: Glasses) -> void:
	if not is_instance_valid(drink) or not is_instance_valid(glass):
		return
	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()

	_bottle_pour_active = true
	_set_player_lock(true)
	GameEvents.minigame_lock_changed.emit(true)

	_active_drink = drink
	_active_glass = glass
	_drink_return_pos = drink.global_position
	_drink_return_pos.x = drink.global_position.x + 0.5

	var glass_home_pos: Vector3 = glass.global_position
	if glass.has_method("_get_saved_counter_position"):
		glass_home_pos = glass._get_saved_counter_position(glass._last_counter_position)
	_glass_return_pos = glass_home_pos

	drink._in_game()
	glass._in_game()

	var cam := _get_camera()
	var drink_mark := cam.get_node_or_null("drink_mark") as Node3D if is_instance_valid(cam) else null
	var glass_mark := cam.get_node_or_null("glass_mark") as Node3D if is_instance_valid(cam) else null
	var target_drink_pos := drink_mark.global_position if is_instance_valid(drink_mark) else drink.global_position
	var target_glass_pos := glass_mark.global_position if is_instance_valid(glass_mark) else glass.global_position

	_pour_tween = get_tree().create_tween().set_parallel(true)
	_pour_tween.tween_property(drink, "global_position", target_drink_pos, 0.5)
	_pour_tween.tween_property(glass, "global_position", target_glass_pos, 0.5)
	_pour_tween.tween_property(glass, "rotation_degrees:y", 0.0, 0.5)

	await _pour_tween.finished
	if not is_inside_tree() or not _bottle_pour_active or not is_instance_valid(drink):
		return
	await get_tree().process_frame
	if is_inside_tree() and _bottle_pour_active and is_instance_valid(drink) and is_instance_valid(cam):
		drink.look_at(cam.global_position)

func end_bottle_pour() -> void:
	if not _bottle_pour_active:
		return
	_bottle_pour_active = false
	_set_player_lock(false)

	if _pour_tween and _pour_tween.is_valid():
		_pour_tween.kill()

	var drink := _active_drink
	var glass := _active_glass
	_active_drink = null
	_active_glass = null

	_pour_tween = get_tree().create_tween().set_parallel(true)
	if is_instance_valid(drink):
		if "original_position" in drink and is_instance_valid(drink.original_position):
			_pour_tween.tween_property(drink, "global_position", drink.original_position.global_position, 0.5)
		else:
			_pour_tween.tween_property(drink, "global_position", _drink_return_pos, 0.5)
	if is_instance_valid(glass):
		_pour_tween.tween_property(glass, "global_position", _glass_return_pos, 0.5)

	await _pour_tween.finished
	if is_instance_valid(drink):
		drink._out_of_game()
	if is_instance_valid(glass):
		glass._out_of_game()
	GameEvents.minigame_lock_changed.emit(false)