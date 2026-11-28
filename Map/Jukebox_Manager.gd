class_name JukeboxManager
extends Node

enum Mode {OFF, EASY_LISTENING, UPBEAT}

const COOLDOWN_ID := "jukebox"
const COST := 30
const EFFECT_SECONDS := 30
const COOLDOWN_SECONDS := 45.0

var active_mode: int = Mode.OFF
var effect_time_left := 0.0
var cooldown_time_left: float:
	get:
		return CooldownManager.get_time_left(COOLDOWN_ID)
	set(value):
		if value <= 0.0:
			CooldownManager.clear(COOLDOWN_ID)
		else:
			CooldownManager.start(COOLDOWN_ID, value, {
				"group": "shift",
				"respect_night_pause": true,
			})

func _process(delta: float) -> void:
	if GameState.night_paused:
		return

	effect_time_left = maxf(0.0, effect_time_left - delta)

	if effect_time_left == 0.0:
		active_mode = Mode.OFF

func activate_easy_listening() -> String:
	return _activate(Mode.EASY_LISTENING)

func activate_upbeat() -> String:
	return _activate(Mode.UPBEAT)

func _activate(mode: int) -> String:
	if CooldownManager.is_on_cooldown(COOLDOWN_ID):
		return "cooldown"
	if PlayerStats.money < COST:
		return "insufficient_funds"

	PlayerStats._change_money(PlayerStats.money - COST)
	active_mode = mode
	effect_time_left = EFFECT_SECONDS
	CooldownManager.start(COOLDOWN_ID, COOLDOWN_SECONDS, {
		"group": "shift",
		"respect_night_pause": true,
	})
	return "activated"

func get_customer_effect() -> Dictionary:
	if effect_time_left <= 0.0:
		return {"patience_multiplier" : 1.0, "payout_multiplier" : 1.0}

	if active_mode == Mode.EASY_LISTENING:
		return {"patience_multiplier" : 1.2, "payout_multiplier" : 1.0}
	if active_mode == Mode.UPBEAT:
		return {"patience_multiplier" : 0.8, "payout_multiplier" : 2.0}

	return {"patience_multiplier" : 1.0, "payout_multiplier" : 1.0}

func reset_for_shift() -> void:
	active_mode = Mode.OFF
	effect_time_left = 0.0
	CooldownManager.clear(COOLDOWN_ID)