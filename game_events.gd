class_name GameEvents
extends RefCounted
# Global static signal bus (no Autoload registration needed).

class _Bus extends RefCounted:
	# Shift / Night lifecycle
	signal shift_started(night: int, duration: float, quota: float)
	signal shift_time_updated(time_left: float)
	signal shift_ended()
	signal night_concluded()
	signal night_title_requested(text: String)
	signal shift_hud_toggled(is_visible: bool)
	signal quota_updated(quota: float)

	# Orders / NPC / Dialogue
	signal order_ready(seat_num: int, order_text: String, race: String, npc: Node)
	signal receipt_cleared(seat_num: int)
	signal customer_patience_ended(seat_num: int)
	signal dialogue_state_changed(is_open: bool, npc: Node)
	signal tutorial_step_requested(step_id: String)

	# Station / Camera / Cursor / Minigame locks
	signal minigame_lock_changed(locked: bool)
	signal camera_focus_requested(marker: Node3D, duration: float)
	signal camera_return_requested(duration: float)
	signal camera_shake_requested(amount: float)
	signal hand_cursor_changed(state: String)

	# Drink / Cup feedback
	signal cup_spilled(glass: Node3D, overflow_percent: float)
	signal cup_emptied(glass: Node3D)
	signal cup_pouring_updated(glass: Node, liquids: Array, capacity: float, visual_helper: RefCounted)
	signal cup_pouring_stopped(glass: Node, immediate: bool)
	signal drink_served(npc: Node, glass: Node, mix: RefCounted, score_data: Dictionary)

	# Audio
	signal sfx_requested(sfx_id: String)

static var _bus: _Bus

static var shift_started: Signal
static var shift_time_updated: Signal
static var shift_ended: Signal
static var night_concluded: Signal
static var night_title_requested: Signal
static var shift_hud_toggled: Signal
static var quota_updated: Signal

static var order_ready: Signal
static var receipt_cleared: Signal
static var customer_patience_ended: Signal
static var dialogue_state_changed: Signal
static var tutorial_step_requested: Signal

static var minigame_lock_changed: Signal
static var camera_focus_requested: Signal
static var camera_return_requested: Signal
static var camera_shake_requested: Signal
static var hand_cursor_changed: Signal

static var cup_spilled: Signal
static var cup_emptied: Signal
static var cup_pouring_updated: Signal
static var cup_pouring_stopped: Signal
static var drink_served: Signal

static var sfx_requested: Signal

static func _static_init() -> void:
	_bus = _Bus.new()
	shift_started = Signal(_bus, &"shift_started")
	shift_time_updated = Signal(_bus, &"shift_time_updated")
	shift_ended = Signal(_bus, &"shift_ended")
	night_concluded = Signal(_bus, &"night_concluded")
	night_title_requested = Signal(_bus, &"night_title_requested")
	shift_hud_toggled = Signal(_bus, &"shift_hud_toggled")
	quota_updated = Signal(_bus, &"quota_updated")

	order_ready = Signal(_bus, &"order_ready")
	receipt_cleared = Signal(_bus, &"receipt_cleared")
	customer_patience_ended = Signal(_bus, &"customer_patience_ended")
	dialogue_state_changed = Signal(_bus, &"dialogue_state_changed")
	tutorial_step_requested = Signal(_bus, &"tutorial_step_requested")

	minigame_lock_changed = Signal(_bus, &"minigame_lock_changed")
	camera_focus_requested = Signal(_bus, &"camera_focus_requested")
	camera_return_requested = Signal(_bus, &"camera_return_requested")
	camera_shake_requested = Signal(_bus, &"camera_shake_requested")
	hand_cursor_changed = Signal(_bus, &"hand_cursor_changed")

	cup_spilled = Signal(_bus, &"cup_spilled")
	cup_emptied = Signal(_bus, &"cup_emptied")
	cup_pouring_updated = Signal(_bus, &"cup_pouring_updated")
	cup_pouring_stopped = Signal(_bus, &"cup_pouring_stopped")
	drink_served = Signal(_bus, &"drink_served")

	sfx_requested = Signal(_bus, &"sfx_requested")
