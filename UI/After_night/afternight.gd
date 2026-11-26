extends Node3D

enum ShopPhase {
	NONE,
	INTRO,
	TRANSITIONING,
	CHOOSING,
	UPGRADES,
	FINISHING
}

const BASE_SHOP_SLOTS := 4
const SLOTS_PER_UPGRADE := 2
const MAX_SHOP_SLOTS := 8
const SUMMARY_FF_SCOPE := "afternight_summary"
const SHOP_FF_SCOPE := "afternight_shop"

@export var summary_fast_forward_duration: float = FastForward.DEFAULT_DURATION
@export var shop_fast_forward_duration: float = FastForward.DEFAULT_DURATION

@onready var choices = preload("res://UI/After_night/ChoiceButton.tscn")

@onready var player: Node3D = $Player
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $WorldEnvironment/Sun
@onready var night_timer: Timer = $Night_Time
@onready var counter: Node3D = $Coutner
@onready var shopkeeper = $ShopKeeper
var shop_phase : ShopPhase = ShopPhase.NONE
var ingredient_picked : bool = false
var drink_picked : bool = false
var upgrade_time : bool = false
var _is_advancing_shop : bool = false
var _is_finishing_night : bool = false
var _pending_choices : Array = []
var _used_shop_slots : int = 0
var _is_expanding_slots : bool = false
var upgrades


func _ready() -> void:
	GameState.register_subsystems(self, player, night_timer, world_environment, sun, counter)
	shop_phase = ShopPhase.NONE
	if is_instance_valid(shopkeeper):
		shopkeeper.can_talk = false
	$Viewport.modulate.a = 0
	await get_tree().create_timer(0.5).timeout
	$new_bar._open_light()
	var tween = get_tree().create_tween()
	tween.tween_property($Viewport,"modulate:a",1,0)
	if GameState.night == 1:
		shopkeeper.speaking_title = "firstIntro"
	else:
		shopkeeper.speaking_title = "Comingback"

func _exit_tree() -> void:
	FastForward.end_scope(SUMMARY_FF_SCOPE)
	FastForward.end_scope(SHOP_FF_SCOPE)

func _check_money() -> void:
	FastForward.begin_scope(SUMMARY_FF_SCOPE, {
		"duration": summary_fast_forward_duration,
		"allow_when_dialogue_open": true,
		"priority": 50,
	})
	#$Player/Secondary.current = true
	$AnimationPlayer.play("check_money")
	FastForward.track_animation($AnimationPlayer, SUMMARY_FF_SCOPE)
	await $Viewport/SubViewport/AfterNightMenu._display_recipt()
	FastForward.end_scope(SUMMARY_FF_SCOPE)
	#$Player/Secondary.current = true
	#$Player/Camera3D.current = false
	
func _open_light():
	await $new_bar._open_light()

func _close_light_bar():
	var tween = get_tree().create_tween()
	tween.tween_property($Viewport,"modulate:a",0,0)
	await $new_bar._close_light()

func _setup_shop_scene() -> void:
	FastForward.begin_scope(SHOP_FF_SCOPE, {
		"duration": shop_fast_forward_duration,
		"allow_when_dialogue_open": false,
		"priority": 40,
	})
	$CanvasLayer.show()
	$AnimationPlayer.play_backwards("check_money")
	FastForward.track_animation($AnimationPlayer, SHOP_FF_SCOPE)
	await _close_light_bar()
	if is_instance_valid($AfternightNpc):
		$AfternightNpc.queue_free()
	await FastForward.wait(2.0, self, SHOP_FF_SCOPE)
	if not is_inside_tree():
		FastForward.end_scope(SHOP_FF_SCOPE)
		return
	$ShopKeeper.show()
	await $new_bar._setup_shop_scene()
	$Player.in_shop = true
	await _open_light()
	FastForward.end_scope(SHOP_FF_SCOPE)
	if not is_inside_tree():
		return
	shop_phase = ShopPhase.INTRO
	if is_instance_valid(shopkeeper):
		shopkeeper.can_talk = true

func _reset_night():
	if GameState.use_restart():
		PlayerStats.reset_night_reputation_gains()
		get_tree().change_scene_to_file("res://Main3D.tscn")

func _finished_night():
	if _is_finishing_night:
		return
	_is_finishing_night = true
	shop_phase = ShopPhase.FINISHING
	FastForward.end_scope(SUMMARY_FF_SCOPE)
	FastForward.end_scope(SHOP_FF_SCOPE)
	if is_instance_valid(shopkeeper):
		shopkeeper.can_talk = false
	for node in get_tree().get_nodes_in_group("Choice"):
		if is_instance_valid(node) and node.has_method("_disable"):
			node._disable()
	await _close_light_bar()
	GameState.advance_night()
	PlayerStats.reset_night_reputation_gains()
	Transition._changing_scene("res://Main3D.tscn")

func _get_shop_options_title() -> String:
	if GameState.night > 3 or GameState.night < 1:
		return "options1"
	return "options" + str(GameState.night)

func _get_locked_unlocks(pick: String) -> Array:
	var temp_array = []
	if PlayerStats.unlocks.has(pick):
		for x in PlayerStats.unlocks[pick]:
			if(!PlayerStats.unlocks[pick][x]):
				temp_array.push_back(x)
	return temp_array

func _get_available_unlocks(pick: String) -> Array:
	var locked := _get_locked_unlocks(pick)
	if pick == "Ingredients":
		locked = locked.filter(func(item) -> bool:
			return PlayerStats.can_offer_ingredient_free_pick(str(item), GameState.night)
		)
	return locked

func _has_open_dialogue() -> bool:
	if GameState.is_dialogue_open:
		return true
	var tree := get_tree()
	if tree and tree.root:
		for balloon_name in ["Main_Ballon", "ExampleBalloon"]:
			var balloon := tree.root.find_child(balloon_name, true, false)
			if is_instance_valid(balloon) and not balloon.is_queued_for_deletion():
				return true
	return false

func _wait_for_dialogue_close() -> void:
	while is_inside_tree() and _has_open_dialogue():
		await get_tree().process_frame

func _enable_choices(choices_list: Array) -> void:
	for node in choices_list:
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.has_method("_enable"):
			node._enable()

func _go_next() -> void:
	if shop_phase == ShopPhase.TRANSITIONING or shop_phase == ShopPhase.FINISHING:
		return
	if ingredient_picked and drink_picked and upgrade_time:
		return
	if _is_advancing_shop:
		return
	_is_advancing_shop = true
	shop_phase = ShopPhase.TRANSITIONING
	if is_instance_valid(shopkeeper):
		shopkeeper.can_talk = false

	for node in get_tree().get_nodes_in_group("Choice"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.has_method("_disable"):
			node._disable()

	_advance_shop_step()

func _advance_shop_step() -> void:
	await _wait_for_dialogue_close()
	if not is_inside_tree():
		return

	FastForward.begin_scope(SHOP_FF_SCOPE, {
		"duration": shop_fast_forward_duration,
		"allow_when_dialogue_open": false,
		"priority": 40,
	})

	var old_nodes = get_tree().get_nodes_in_group("Choice")
	print("Removed Nodes: ", old_nodes)

	for node in old_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.has_method("_disable"):
			node._disable()

	var shopkeeper_position = shopkeeper.global_position
	shopkeeper_position.y -= 5

	var clear_tween: Tween = null
	for node in old_nodes:
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "global_position", shopkeeper_position, 0.5)
		FastForward.track_tween(tween, 0.5, SHOP_FF_SCOPE)
		clear_tween = tween

	if is_instance_valid(clear_tween) and clear_tween.is_running():
		await clear_tween.finished
	if not is_inside_tree():
		FastForward.end_scope(SHOP_FF_SCOPE)
		return

	for node in old_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()

	shopkeeper._play_animation_knocking()
	await FastForward.wait(1.0, self, SHOP_FF_SCOPE)
	if not is_inside_tree():
		FastForward.end_scope(SHOP_FF_SCOPE)
		return

	if not ingredient_picked and _get_available_unlocks("Drinks").is_empty():
		ingredient_picked = true
	if ingredient_picked and not drink_picked and _get_available_unlocks("Ingredients").is_empty():
		drink_picked = true

	_pending_choices.clear()

	if(ingredient_picked):
		if(drink_picked):
			upgrade_time = true
			if(GameState.night == 1):
				$ShopKeeper.force_dialogue("firstUpgrades")
			await _produce_upgrades()
			await _wait_for_dialogue_close()
			if not is_inside_tree():
				FastForward.end_scope(SHOP_FF_SCOPE)
				return
			if is_instance_valid(shopkeeper):
				shopkeeper.speaking_title = _get_shop_options_title()
			shop_phase = ShopPhase.UPGRADES
		else:
			drink_picked = true
			if(GameState.night == 1):
				$ShopKeeper.force_dialogue("firstIngredients")
			await _produce_unlocks_pick_3("Ingredients")
			await _wait_for_dialogue_close()
			if not is_inside_tree():
				FastForward.end_scope(SHOP_FF_SCOPE)
				return
			if is_instance_valid(shopkeeper):
				shopkeeper.speaking_title = "firstWait1" if GameState.night == 1 else "wait"
			shop_phase = ShopPhase.CHOOSING
	else:
		ingredient_picked = true
		if(GameState.night == 1):
			$ShopKeeper.force_dialogue("firstDrinks")
		await _produce_unlocks_pick_3("Drinks")
		await _wait_for_dialogue_close()
		if not is_inside_tree():
			FastForward.end_scope(SHOP_FF_SCOPE)
			return
		if is_instance_valid(shopkeeper):
			shopkeeper.speaking_title = "firstWait1" if GameState.night == 1 else "wait"
		shop_phase = ShopPhase.CHOOSING

	FastForward.end_scope(SHOP_FF_SCOPE)
	_enable_choices(_pending_choices)
	_is_advancing_shop = false
	if is_instance_valid(shopkeeper) and shop_phase != ShopPhase.FINISHING:
		shopkeeper.can_talk = true


func _produce_unlocks_pick_3(pick: String = "Ingredients") -> void:
	var temp_array = _get_available_unlocks(pick)
	print("Temp_array",temp_array)
	print("Temp_array:size",temp_array.size())
	var count: int = mini(3, temp_array.size())
	var slot_names: Array[String] = []
	match count:
		1:
			slot_names = ["Choice3"]
		2:
			slot_names = ["Choice2", "Choice4"]
		_:
			slot_names = ["Choice2", "Choice3", "Choice4"]
	var last_tween: Tween = null
	for x in count:
		if not is_inside_tree():
			return
		var random = randi_range(0,temp_array.size()-1)
		var obtain_node = get_node("ShopKeeper/" + slot_names[x])
		var random_object = temp_array.pop_at(random)
		var new_choice = choices.instantiate()
		new_choice.setup(self,random_object,pick)
		new_choice._disable()
		add_child(new_choice)
		_pending_choices.append(new_choice)
		new_choice.global_position = $ShopKeeper.global_position
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(new_choice,"global_position",obtain_node.global_position,0.5)
		FastForward.track_tween(tween, 0.5, SHOP_FF_SCOPE)
		last_tween = tween
		if x < count - 1:
			await FastForward.wait(0.75, self, SHOP_FF_SCOPE)
	if is_instance_valid(last_tween) and last_tween.is_running():
		await last_tween.finished

func _get_shop_slot_count() -> int:
	var extra_levels: int = UpgradeRegistry.get_level("Shelf Slots Increase", PlayerStats)
	var slots_per_level: int = maxi(1, int(round(UpgradeRegistry.get_effect_step("Shelf Slots Increase", float(SLOTS_PER_UPGRADE)))))
	return mini(BASE_SHOP_SLOTS + extra_levels * slots_per_level, MAX_SHOP_SLOTS)

func _get_ingredient_shop_cost(ingredient_id: String) -> int:
	return PlayerStats.get_ingredient_shop_cost(ingredient_id, GameState.night)

func _build_upgrade_shop_pool(exclude_active_choices: bool = false) -> Array[Dictionary]:
	var active_keys: Dictionary = {}
	if exclude_active_choices and is_inside_tree():
		for node in get_tree().get_nodes_in_group("Choice"):
			if is_instance_valid(node) and not node.is_queued_for_deletion() and "id" in node and "type" in node:
				active_keys[str(node.type) + ":" + str(node.id).to_lower()] = true

	var pool: Array[Dictionary] = []
	for chosen_upgrade in UpgradeRegistry.get_available_shop_upgrades(PlayerStats, GameState.night):
		var key := "Upgrades:" + chosen_upgrade.upgrade_id.to_lower()
		if active_keys.has(key):
			continue
		pool.append({
			"id": chosen_upgrade.upgrade_id,
			"type": "Upgrades",
			"cost": chosen_upgrade.get_shop_cost(GameState.night, PlayerStats),
		})

	for ing_id in _get_locked_unlocks("Ingredients"):
		var ing_str := str(ing_id)
		if not PlayerStats.can_buy_ingredient_in_shop(ing_str, GameState.night):
			continue
		var key := "Ingredients:" + ing_str.to_lower()
		if active_keys.has(key):
			continue
		pool.append({
			"id": ing_str,
			"type": "Ingredients",
			"cost": _get_ingredient_shop_cost(ing_str),
		})

	return pool

func _produce_upgrades() -> void:
	var pool := _build_upgrade_shop_pool()
	print("Temp_array", pool)

	var count: int = mini(_get_shop_slot_count(), pool.size())
	_used_shop_slots = 0
	var last_tween: Tween = null
	for x in count:
		if not is_inside_tree():
			return
		var obtain_node = $new_bar._get_marker(x + 1)
		if obtain_node == null:
			continue
		_used_shop_slots = x + 1
		var random = randi_range(0, pool.size() - 1)
		var entry: Dictionary = pool.pop_at(random)
		var new_choice = choices.instantiate()

		new_choice.setup(self, str(entry["id"]), str(entry["type"]), int(entry["cost"]))
		new_choice._disable()
		add_child(new_choice)
		_pending_choices.append(new_choice)
		new_choice.global_position = $ShopKeeper.global_position
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(new_choice, "global_position", obtain_node.global_position, 0.5)
		FastForward.track_tween(tween, 0.5, SHOP_FF_SCOPE)
		last_tween = tween
		if x < count - 1:
			await FastForward.wait(0.5, self, SHOP_FF_SCOPE)
	if is_instance_valid(last_tween) and last_tween.is_running():
		await last_tween.finished

func _expand_shop_slots() -> void:
	if _is_expanding_slots or not upgrade_time or _is_finishing_night or not is_inside_tree():
		return
	_is_expanding_slots = true
	while _used_shop_slots < _get_shop_slot_count():
		if not is_inside_tree() or _is_finishing_night:
			break
		var pool := _build_upgrade_shop_pool(true)
		if pool.is_empty():
			break
		var next_slot: int = _used_shop_slots + 1
		var obtain_node = $new_bar._get_marker(next_slot)
		if obtain_node == null:
			break
		_used_shop_slots = next_slot
		var random: int = randi_range(0, pool.size() - 1)
		var entry: Dictionary = pool.pop_at(random)
		var new_choice = choices.instantiate()
		new_choice.setup(self, str(entry["id"]), str(entry["type"]), int(entry["cost"]))
		new_choice._disable()
		add_child(new_choice)
		new_choice.global_position = $ShopKeeper.global_position
		var tween := get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(new_choice, "global_position", obtain_node.global_position, 0.5)
		tween.finished.connect(func() -> void:
			if is_instance_valid(new_choice) and not new_choice.is_queued_for_deletion() and not _is_finishing_night:
				new_choice._enable()
		)
		if _used_shop_slots < _get_shop_slot_count():
			await get_tree().create_timer(0.35).timeout
	_is_expanding_slots = false

#Temporary Functions
func _on_button_pressed() -> void:
	_finished_night()