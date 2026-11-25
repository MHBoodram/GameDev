class_name SnapZoneFollower
extends RefCounted

# all snapping in 3D

signal snapped_in(point: Node3D)
signal snapped_out(point: Node3D)

var snap_point: Node3D = null
var snap_pos: Vector3 = Vector3.ZERO
var snap_blend: float = 0.0
var snap_suppressed: bool = false
var snap_locked: bool = false
var snap_pull_speed: float = 22.0
var snap_release_speed: float = 16.0
var snap_break_distance: float = 0.25

func enter_snap_zone(point: Node3D, pull_speed: float = 22.0, release_speed: float = 16.0, break_distance: float = 0.25) -> void:
	if snap_point != point:
		snap_blend = 0.0
		snap_locked = false
	snap_point = point
	snap_pull_speed = pull_speed
	snap_release_speed = release_speed
	snap_break_distance = break_distance
	snap_suppressed = false

func exit_snap_zone(point: Node3D) -> void:
	if snap_point == point:
		snap_point = null
		snap_suppressed = false
		snap_blend = 0.0
		if snap_locked:
			snap_locked = false
			snapped_out.emit(point)

func clear_snap(suppress: bool = false) -> void:
	snap_suppressed = suppress
	snap_blend = 0.0
	if snap_locked:
		snap_locked = false
		snapped_out.emit(snap_point)
	snap_point = null

func is_snapped() -> bool:
	return snap_locked

func is_actively_holding() -> bool:
	return snap_point != null and is_instance_valid(snap_point) and not snap_suppressed and snap_blend > 0.0

func has_active_snap() -> bool:
	return snap_point != null and is_instance_valid(snap_point) and not snap_suppressed

func update_snap(glass: Glasses, delta: float, is_dragging: bool, drag_target: Vector3, camera: Camera3D, sprite: Sprite3D, base_scale: Vector3) -> void:
	if not snap_point or not is_instance_valid(snap_point):
		if snap_point != null:
			snap_point = null
		snap_suppressed = false
		snap_blend = 0.0
		if snap_locked:
			snap_locked = false
			snapped_out.emit(null)
		return

	snap_pos = snap_point.global_position
	var want: float = 0.0
	if is_dragging:
		var flat := Vector2(drag_target.x - snap_pos.x, drag_target.z - snap_pos.z)
		var dist := flat.length()
		if snap_suppressed:
			if dist <= snap_break_distance * 0.6:
				snap_suppressed = false
		elif dist > snap_break_distance:
			snap_suppressed = true
		if not snap_suppressed:
			want = 1.0
	elif not snap_suppressed:
		want = 1.0

	var speed := snap_pull_speed if want > snap_blend else snap_release_speed
	snap_blend = lerpf(snap_blend, want, 1.0 - exp(-speed * delta))
	if absf(snap_blend - want) < 0.01:
		snap_blend = want

	if snap_blend > 0.0:
		var target := Vector3(snap_pos.x, glass.global_position.y, snap_pos.z)
		glass.global_position = glass.global_position.lerp(target, snap_blend)
		if snap_blend >= 0.99:
			glass.push_velocity = Vector3.ZERO
		if camera:
			glass._look_at_sprite(camera.global_position)

	var locked_now: bool = snap_blend >= 0.95 and want >= 1.0
	if locked_now and not snap_locked:
		snap_locked = true
		play_snap_bounce(glass, sprite, base_scale)
		snapped_in.emit(snap_point)
	elif not locked_now and snap_locked:
		snap_locked = false
		snapped_out.emit(snap_point)

func play_snap_bounce(owner_node: Node, sprite: Sprite3D, base_scale: Vector3) -> void:
	if not is_instance_valid(sprite) or not is_instance_valid(owner_node):
		return
	var tween := owner_node.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base_scale * Vector3(1.08, 0.92, 1.0), 0.05)
	tween.tween_property(sprite, "scale", base_scale, 0.12)