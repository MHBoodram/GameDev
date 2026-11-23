class_name PourController
extends Node

# Perfect pour

@export var pour_interval: float = 0.033
@export var sfx_interval_ms: int = 100

var is_pouring: bool = false
var _tick_accum: float = 0.0
var _last_sfx_ms: int = 0
var _tick_cb: Callable = Callable()
var _can_continue_cb: Callable = Callable()
var _finish_cb: Callable = Callable()

static func is_pour_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.get_action_strength("Left_click") > 0.0

static func get_pour_height_ratio(viewport: Viewport) -> float:
	if not viewport:
		return 0.5
	var vp_height: float = viewport.get_visible_rect().size.y
	if vp_height <= 1.0:
		return 0.5
	var mouse_y: float = viewport.get_mouse_position().y
	var raw_height: float = 1.0 - clampf(mouse_y / vp_height, 0.0, 1.0)
	return clampf((raw_height - 0.1) / 0.8, 0.0, 1.0)

static func get_pour_rate_multiplier(viewport: Viewport) -> float:
	return get_pour_height_ratio(viewport) * 2.0

static func get_pour_tilt_angle(viewport: Viewport, min_deg: float, max_deg: float, zero_threshold: float = 0.001) -> float:
	var ratio: float = get_pour_height_ratio(viewport)
	if zero_threshold >= 0.0 and ratio <= zero_threshold:
		return 0.0
	return lerpf(min_deg, max_deg, ratio)

func start(tick_cb: Callable, can_continue_cb: Callable = Callable(), finish_cb: Callable = Callable(), tick_immediately: bool = true) -> void:
	is_pouring = true
	_tick_accum = 0.0
	_last_sfx_ms = 0
	_tick_cb = tick_cb
	_can_continue_cb = can_continue_cb
	_finish_cb = finish_cb

	if tick_immediately:
		if not is_pour_held() or (_can_continue_cb.is_valid() and not _can_continue_cb.call()):
			stop(true)
			return
		_step_tick()

func stop(invoke_finish: bool = true) -> void:
	if not is_pouring:
		return
	is_pouring = false
	_tick_accum = 0.0
	var cb := _finish_cb
	_tick_cb = Callable()
	_can_continue_cb = Callable()
	_finish_cb = Callable()
	if invoke_finish and cb.is_valid():
		cb.call()

func _process(delta: float) -> void:
	if not is_pouring:
		return
	if not is_pour_held() or (_can_continue_cb.is_valid() and not _can_continue_cb.call()):
		stop(true)
		return

	_tick_accum += minf(delta, 0.1)
	while is_pouring and _tick_accum >= pour_interval:
		_tick_accum -= pour_interval
		if not is_pour_held() or (_can_continue_cb.is_valid() and not _can_continue_cb.call()):
			stop(true)
			return
		_step_tick()

func _step_tick() -> void:
	if _tick_cb.is_valid():
		var did_pour := bool(_tick_cb.call(pour_interval))
		if did_pour:
			var now_ms := Time.get_ticks_msec()
			if now_ms - _last_sfx_ms >= sfx_interval_ms:
				_last_sfx_ms = now_ms
				GameEvents.sfx_requested.emit("liquidpour")