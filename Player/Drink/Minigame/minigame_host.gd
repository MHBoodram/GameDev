# Runs minigames (period game)
# Locking/unlocking normal gameplay UI/inputs
# Routes minigames outputs back into appropraite places
class_name MinigameHost
extends Node

signal minigame_started(game_name: String)
signal minigame_finished(game_name: String, result: Variant)

const BLOOD_GAME_SCENE := preload("res://Player/Drink/Minigame/Blood/BloodMinigame.tscn")

var is_minigame_active: bool = false
var current_minigame_instance: Node = null

func start_blood_minigame(host_parent: Node, player_node: Node3D) -> void:
	if is_minigame_active:
		return

	is_minigame_active = true
	_lock_player_and_ui(player_node, true)

	var game_instance := BLOOD_GAME_SCENE.instantiate()
	current_minigame_instance = game_instance
	host_parent.add_child(game_instance)
	minigame_started.emit("blood")

	game_instance.tree_exited.connect(func():
		is_minigame_active = false
		current_minigame_instance = null
		_lock_player_and_ui(player_node, false)
		minigame_finished.emit("blood", null)
	, CONNECT_ONE_SHOT)

func get_blood_bottle(search_root: Node = null) -> Node:
	if GameState.shelf_manager:
		var b = GameState.shelf_manager.get_bottle("blood")
		if b:
			return b
	if is_instance_valid(search_root):
		var direct = search_root.get_node_or_null("blood")
		if direct:
			return direct
	return null

func add_blood_to_bottle(search_root: Node, amount: float) -> void:
	if GameState.shelf_manager:
		GameState.shelf_manager.add_liquid_to_bottle("blood", amount)
		return
	var bottle := get_blood_bottle(search_root)
	if bottle and bottle.has_method("_add_liquid"):
		bottle._add_liquid(amount)

func _lock_player_and_ui(player_node: Node3D, lock: bool) -> void:
	if player_node and "in_game" in player_node:
		player_node.in_game = lock
	if GameState.gameplay_ui:
		if lock and GameState.gameplay_ui.has_method("_in_down_minigame"):
			GameState.gameplay_ui._in_down_minigame()
		elif not lock and GameState.gameplay_ui.has_method("_out_down_minigame"):
			GameState.gameplay_ui._out_down_minigame()