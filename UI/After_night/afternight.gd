extends Node3D

@onready var choices = preload("res://UI/After_night/ChoiceButton.tscn")

@onready var player: Node3D = $Player
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $WorldEnvironment/Sun
@onready var night_timer: Timer = $Night_Time
@onready var counter: Node3D = $Coutner
@onready var shopkeeper = $ShopKeeper
var ingredient_picked : bool = false
var drink_picked : bool = false
var upgrade_time : bool = false
var upgrades


func _ready() -> void:
	GameState.register_subsystems(self, player, night_timer, world_environment, sun, counter)
	$Viewport.modulate.a = 0
	await get_tree().create_timer(0.5).timeout
	$new_bar._open_light()
	var tween = get_tree().create_tween()
	tween.tween_property($Viewport,"modulate:a",1,0)
	match GameState.night:
		1:
			shopkeeper.speaking_title = "firstIntro"
		2:
			pass

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
	$AfternightNpc.queue_free()
	$ShopKeeper.show()
	$new_bar._setup_shop_scene()
	$Player.in_shop = true
	_open_light()

func _reset_night():
	if GameState.use_restart():
		PlayerStats.reset_night_reputation_gains()
		get_tree().change_scene_to_file("res://Main3D.tscn")

func _finished_night():
	GameState.advance_night()
	PlayerStats.reset_night_reputation_gains()
	Transition._changing_scene("res://Main3D.tscn")

func _go_next():
	if(ingredient_picked and drink_picked and upgrade_time):
		return
	
	var old_nodes = get_tree().get_nodes_in_group("Choice")
	print("Removed Nodes: ",old_nodes)
	for nodes in old_nodes:
		nodes._disable()

	var shopkeeper_position = shopkeeper.global_position
	shopkeeper_position.y = shopkeeper_position.y - 5
	for nodes in old_nodes:
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(nodes,"global_position",shopkeeper_position,0.5)
		await tween.finished
		#if(nodes==null):
		nodes.queue_free()
	
	if(ingredient_picked):
		if(drink_picked):
			shopkeeper.speaking_title = "options"
			_produce_upgrades()
			upgrade_time = true
		else:
			_produce_unlocks_pick_3("Ingredients")
			drink_picked = true
	else:
		_produce_unlocks_pick_3("Drinks")
		ingredient_picked = true
		

func _produce_unlocks_pick_3(pick: String = "Ingredients") -> void:
	var temp_array = []
	for x in PlayerStats.unlocks[pick]:
		if(!PlayerStats.unlocks[pick][x]):
			temp_array.push_back(x)
	print("Temp_array",temp_array)
	
	for x in min(3,temp_array.size()-1):
		var random = randi_range(0,temp_array.size()-1)
		var obtain_node = get_node("ShopKeeper/Choice" + str(x+2))
		var random_object = temp_array.pop_at(random)
		var new_choice = choices.instantiate()
		new_choice.setup(self,random_object,pick)
		add_child(new_choice)
		new_choice.global_position = $ShopKeeper.global_position
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(new_choice,"global_position",obtain_node.global_position,0.5)
		await get_tree().create_timer(0.5).timeout

func _produce_upgrades() -> void:
	var temp_array = []
	for x in PlayerStats.unlocks["Upgrades"]:
		if(!PlayerStats.unlocks["Upgrades"][x]):
			temp_array.push_back(x)
	print("Temp_array",temp_array)
	
	for x in min(5,temp_array.size()-1):
		var random = randi_range(0,temp_array.size()-1)
		var obtain_node = $new_bar._get_marker(x+1)
		var random_object = temp_array.pop_at(random)
		var new_choice = choices.instantiate()
		#temporary cost variable
		var cost = randi_range(1, GameState.night * 30)
		
		new_choice.setup(self,random_object,"Upgrades",cost) #Tempory
		add_child(new_choice)
		new_choice.global_position = $ShopKeeper.global_position
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(new_choice,"global_position",obtain_node.global_position,0.5)
		await get_tree().create_timer(0.5).timeout

#Temporary Functions
func _on_button_pressed() -> void:
	_finished_night()