# Tracks overall run (night, quotas, restarts)
# Calls:
# player - Node3D player controller
# main_node - Root Main3D scene
# gameplay_ui - HUD CanvasLayer
# night_manager - Night backend ex. lighting
# seat_manager - Customer seating, receipts, drink serving
# shelf_manager - Unlocked ingredients on shelves
# minigame_host - Minigames and rewards
extends Node

var night: int = 1
var max_nights: int = 7
var night_duration: float = 150.0
var restarts_left: int = 3
const MAX_RESTARTS: int = 3
const BASE_QUOTA: float = 150.0
var current_quota: float = 150.0

var player: Node3D
var main_node: Node3D
var gameplay_ui: CanvasLayer

# Subsystems
var night_manager: NightManager
var seat_manager: SeatManager
var shelf_manager: BarShelfManager
var minigame_host: MinigameHost

var special_state: bool = true
var night_paused: bool = false
var can_end_night: bool = true
var is_dialogue_open: bool = false
var character_talking: Node3D #Changed for Afternight


func _ready() -> void:
	call_deferred("_connect_dialogue_signals")

func _connect_dialogue_signals() -> void:
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_started(_resource) -> void:
	is_dialogue_open = true
	GameEvents.dialogue_state_changed.emit(true, character_talking)

func _on_dialogue_ended(_resource) -> void:
	is_dialogue_open = false
	character_talking = null
	GameEvents.dialogue_state_changed.emit(false, null)

func register_gameplay_subsystems(main: Node3D, p_player: Node3D, timer: Timer, env: WorldEnvironment, sun_node: DirectionalLight3D, counter_ref: Node3D) -> void:
	main_node = main
	player = p_player
	is_dialogue_open = false
	character_talking = null

	night_manager = NightManager.new()
	seat_manager = SeatManager.new()
	shelf_manager = BarShelfManager.new()
	minigame_host = MinigameHost.new()

	main.add_child(night_manager)
	main.add_child(seat_manager)
	main.add_child(shelf_manager)
	main.add_child(minigame_host)

	seat_manager.setup(main)
	night_manager.setup(timer, env, sun_node)
	shelf_manager.refresh_shelf_bottles(main, counter_ref)

	MusicPlayer.play_game()
	SettingState.apply_world_environment()
	PlayerStats.previous_money = PlayerStats.money

func register_shop_subsystems(main: Node3D, p_player: Node3D, counter_ref: Node3D) -> void:
	main_node = main
	player = p_player
	is_dialogue_open = false
	character_talking = null

	night_manager = null
	seat_manager = null
	minigame_host = null

	shelf_manager = BarShelfManager.new()
	main.add_child(shelf_manager)
	shelf_manager.refresh_shelf_bottles(main, counter_ref)

	SettingState.apply_world_environment()
	PlayerStats.previous_money = PlayerStats.money

func register_subsystems(main: Node3D, p_player: Node3D, timer: Timer, env: WorldEnvironment, sun_node: DirectionalLight3D, counter_ref: Node3D) -> void:
	register_gameplay_subsystems(main, p_player, timer, env, sun_node, counter_ref)

func start_night() -> void:
	if night_manager:
		night_manager.setup_night_shift(main_node)

func get_night_quota(night_number: int) -> float:
	current_quota = BASE_QUOTA * float(night_number * night_number)
	return current_quota

func use_restart() -> bool:
	if restarts_left > 0:
		restarts_left -= 1
		return true
	return false

func reset_night_restarts() -> void:
	restarts_left = MAX_RESTARTS

func advance_night() -> void:
	night += 1
	reset_night_restarts()
	get_night_quota(night)

func pause_night() -> void:
	night_paused = true
	if night_manager:
		night_manager.pause_shift()
	if seat_manager:
		seat_manager.set_all_patience_paused(true)

func resume_night() -> void:
	night_paused = false
	if night_manager:
		night_manager.resume_shift()
	if seat_manager:
		seat_manager.set_all_patience_paused(false)

func hold_night_end(hold: bool = true) -> void:
	can_end_night = !hold
