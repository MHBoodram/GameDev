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

var seat1_order: Array = []
var seat2_order: Array = []
var seat3_order: Array = []
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

var jukebox_manager: JukeboxManager


var story_flags: Dictionary = {}
var scheduled_npcs: Array[Dictionary] = []

func _ready() -> void:
	TextIcons.install(self)

func register_subsystems(main: Node3D, p_player: Node3D, timer: Timer, env: WorldEnvironment, sun_node: DirectionalLight3D, counter_ref: Node3D) -> void:
	main_node = main
	player = p_player

	night_manager = NightManager.new()
	seat_manager = SeatManager.new()
	shelf_manager = BarShelfManager.new()
	minigame_host = MinigameHost.new()
	jukebox_manager = JukeboxManager.new()


	main.add_child(night_manager)
	main.add_child(seat_manager)
	main.add_child(shelf_manager)
	main.add_child(minigame_host)
	main.add_child(jukebox_manager)

	seat_manager.setup(main)
	night_manager.setup(timer, env, sun_node)
	shelf_manager.refresh_shelf_bottles(main, counter_ref)

	MusicPlayer.play_game()
	SettingState.apply_world_environment()
	PlayerStats.previous_money = PlayerStats.money

func start_night() -> void:
	if night_manager:
		night_manager.setup_night_shift(main_node)

func play_sfx(method_name: String) -> void:
	var tree := get_tree()
	if not tree:
		return
	var sfx := tree.root.get_node_or_null("SFXAudio")
	if sfx and sfx.has_method(method_name):
		sfx.call(method_name)

func night_popup(_arg = null) -> void:
	if gameplay_ui and gameplay_ui.has_method("_night_title_popup"):
		gameplay_ui._night_title_popup()

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
	NightManager.unlock_tools_for_night(night)

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

# Branching story flags
func set_story_flag(flag_name: String, value: Variant = true) -> void:
	story_flags[flag_name] = value

func get_story_flag(flag_name: String, default_value: Variant = false) -> Variant:
	return story_flags.get(flag_name, default_value)

func has_story_flag(flag_name: String) -> bool:
	return bool(story_flags.get(flag_name, false))

func clear_story_flags() -> void:
	story_flags.clear()

# Schedule NPCs to appear before nights (trigger_time <= 0) or during nights (trigger_time > 0 in seconds)
func schedule_npc(npc_source: Variant, target_night: int, trigger_time: float = 0.0, dialogue_title: String = "start", patience: float = 90.0) -> void:
	scheduled_npcs.append({
		"source": npc_source,
		"night": target_night,
		"trigger_time": trigger_time,
		"dialogue_title": dialogue_title,
		"patience": patience
	})
