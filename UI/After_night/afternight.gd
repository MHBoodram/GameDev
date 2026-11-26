extends Node3D

enum ShopPhase {
	NONE,
	INTRO,
	TRANSITIONING,
	CHOOSING,
	UPGRADES,
	FINISHING
}

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

func _check_money() -> void:
	#$Player/Secondary.current = true
	$AnimationPlayer.play("check_money")
	await $Viewport/SubViewport/AfterNightMenu._display_recipt()
	#$Player/Secondary.current = true
	#$Player/Camera3D.current = false
	
func _open_light():
	await $new_bar._open_light()

func _close_light_bar():
	var tween = get_tree().create_tween()
	tween.tween_property($Viewport,"modulate:a",0,0)
	await $new_bar._close_light()

func _setup_shop_scene() -> void:
	$CanvasLayer.show()
	$AnimationPlayer.play_backwards("check_money")
	await _close_light_bar()
	if is_instance_valid($AfternightNpc):
		$AfternightNpc.queue_free()
	await get_tree().create_timer(2).timeout
	if not is_inside_tree():
		return
	$ShopKeeper.show()
	await $new_bar._setup_shop_scene()
	$Player.in_shop = true
	await _open_light()
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
	if GameState.night == 1 and pick == "Ingredients":
		if not PlayerStats.has_knife_unlock(false):
			return ["Knife"]
		return []
	return _get_locked_unlocks(pick)

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
			continue  # skip it, don't abort the whole function
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "global_position", shopkeeper_position, 0.5)
		clear_tween = tween

	if is_instance_valid(clear_tween) and clear_tween.is_running():
		await clear_tween.finished
	if not is_inside_tree():
		return

	for node in old_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()

	shopkeeper._play_animation_knocking()
	await get_tree().create_timer(1).timeout
	if not is_inside_tree():
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
			return
		if is_instance_valid(shopkeeper):
			shopkeeper.speaking_title = "firstWait1" if GameState.night == 1 else "wait"
		shop_phase = ShopPhase.CHOOSING

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
		last_tween = tween
		if x < count - 1:
			await get_tree().create_timer(0.75).timeout
	if is_instance_valid(last_tween) and last_tween.is_running():
		await last_tween.finished

func _produce_upgrades() -> void:
	var available_upgrades := UpgradeRegistry.get_available_shop_upgrades(PlayerStats, GameState.night)
	print("Temp_array", available_upgrades)

	var count: int = mini(5, available_upgrades.size())
	var last_tween: Tween = null
	for x in count:
		if not is_inside_tree():
			return
		var random = randi_range(0, available_upgrades.size() - 1)
		var obtain_node = $new_bar._get_marker(x + 1)
		var chosen_upgrade: UpgradeDef = available_upgrades.pop_at(random)
		var new_choice = choices.instantiate()
		var cost: int = chosen_upgrade.get_shop_cost(GameState.night, PlayerStats)

		new_choice.setup(self, chosen_upgrade.upgrade_id, "Upgrades", cost)
		new_choice._disable()
		add_child(new_choice)
		_pending_choices.append(new_choice)
		new_choice.global_position = $ShopKeeper.global_position
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(new_choice, "global_position", obtain_node.global_position, 0.5)
		last_tween = tween
		if x < count - 1:
			await get_tree().create_timer(0.5).timeout
	if is_instance_valid(last_tween) and last_tween.is_running():
		await last_tween.finished

#Temporary Functions
func _on_button_pressed() -> void:
	_finished_night()