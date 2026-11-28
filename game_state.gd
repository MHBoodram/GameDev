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

const PAUSE_MENU_SCENE := preload("res://UI/Gameplay_ui/PauseMenu.tscn")
const DEBUG_MENU_SCENE := preload("res://UI/Gameplay_ui/Debug_Menu.tscn")

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
var pause_menu: CanvasLayer
var debug_menu: CanvasLayer

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	TextIcons.install(self)
	FastForward.install(self)
	CooldownManager.install(self)
	_setup_global_menus()

func _setup_global_menus() -> void:
	if not is_instance_valid(debug_menu):
		debug_menu = DEBUG_MENU_SCENE.instantiate()
		debug_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		debug_menu.layer = 205
		debug_menu.visible = false
		add_child(debug_menu)

	if not is_instance_valid(pause_menu):
		pause_menu = PAUSE_MENU_SCENE.instantiate()
		pause_menu.layer = 200
		var pause_hand := pause_menu.get_node_or_null("Hand") as CanvasLayer
		if pause_hand:
			pause_hand.layer = 201
		add_child(pause_menu)

func _input(event: InputEvent) -> void:
	if SettingState.waiting_keybind:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE:
			toggle_debug_menu()
			get_viewport().set_input_as_handled()

func toggle_debug_menu() -> void:
	if not is_instance_valid(debug_menu):
		return
	debug_menu.visible = not debug_menu.visible

func reset_game() -> void:
	Engine.time_scale = 1.0

	seat1_order = []
	seat2_order = []
	seat3_order = []
	night = 1
	restarts_left = MAX_RESTARTS
	current_quota = BASE_QUOTA

	special_state = true
	night_paused = false
	can_end_night = true
	is_dialogue_open = false
	character_talking = null

	story_flags.clear()
	scheduled_npcs.clear()

	player = null
	main_node = null
	gameplay_ui = null
	night_manager = null
	seat_manager = null
	shelf_manager = null
	minigame_host = null
	jukebox_manager = null

	var tree := get_tree()
	if tree and tree.root:
		for balloon_name in ["Main_Ballon", "ExampleBalloon"]:
			var balloon := tree.root.find_child(balloon_name, true, false)
			if is_instance_valid(balloon) and not balloon.is_queued_for_deletion():
				balloon.queue_free()

	ShakerMinigame.active = false
	FastForward.reset_all()
	CooldownManager.clear_all()
	Ingredients.reset_interaction_state()
	PlayerStats.reset_for_new_game()

	if is_instance_valid(debug_menu):
		if debug_menu.has_method("reset_state"):
			debug_menu.reset_state()
		else:
			debug_menu.visible = false

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