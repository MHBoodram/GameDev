extends Control

const SUMMARY_FF_SCOPE := "afternight_summary"

@export var summary_fast_forward_duration: float = FastForward.DEFAULT_DURATION

@onready var item_scene = preload("res://UI/After_night/ItemButton.tscn")

@onready var info_label: Label = $TextureRect/VBoxContainer/InfoLabel
@onready var status_label: Label = $TextureRect/VBoxContainer/StatusLabel
@onready var top_species_label: Label = $TextureRect/VBoxContainer/TopSpeciesLabel
@onready var pay_quota_button: Button = $TextureRect/VBoxContainer/PayQuotaButton
@onready var buy_ingredient_button: Button = $TextureRect/VBoxContainer/BuyIngredientButton
@onready var buy_marketing_button: Button = $TextureRect/VBoxContainer/BuyMarketingButton
@onready var restart_button: Button = $TextureRect/VBoxContainer/RestartButton
@onready var next_night_button: Button = $TextureRect/VBoxContainer/NextNightButton

@onready var top_species_sprite: Sprite2D = $Recipt/Recipt/VBoxContainer/Top_species/Top_species_sprite
@onready var earning_number: Label = $Recipt/Recipt/VBoxContainer/Earning/Number
@onready var quota_number: Label = $Recipt/Recipt/VBoxContainer/Quota/Number
@onready var proft_number: Label = $Recipt/Recipt/VBoxContainer/Profit_number
@onready var marketing_container: GridContainer = $Marketing/Marketing/VBoxContainer/HBoxContainer/Marketing/GridContainer
@onready var ingredient_container: GridContainer = $Marketing/Marketing/VBoxContainer/HBoxContainer/Ingredient/GridContainer


var shopping_cart: Dictionary = {
	"Drinks":
		{

		},
	"Marketing":
		{

		},
	"Ingredients":
		{

		}
}
var quota_paid: bool = false
var ingredient_bought: bool = false
var marketing_bought: bool = false
var _owns_summary_scope: bool = false

const MANDATORY_INGREDIENT_COST: float = 50.0
const MANDATORY_MARKETING_COST: float = 50.0

func _ready() -> void:
	pay_quota_button.pressed.connect(_on_pay_quota_pressed)
	buy_ingredient_button.pressed.connect(_on_buy_ingredient_pressed)
	buy_marketing_button.pressed.connect(_on_buy_marketing_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	next_night_button.pressed.connect(_on_next_night_pressed)
	_refresh_display()

func _exit_tree() -> void:
	if _owns_summary_scope:
		_owns_summary_scope = false
		FastForward.end_scope(SUMMARY_FF_SCOPE)

func _display_recipt() -> void:
	var owns_scope := not FastForward.has_scope(SUMMARY_FF_SCOPE)
	if owns_scope:
		_owns_summary_scope = true
		FastForward.begin_scope(SUMMARY_FF_SCOPE, {
			"duration": summary_fast_forward_duration,
			"allow_when_dialogue_open": true,
			"priority": 50,
		})

	_top_speicies_check()
	await _display_container($Recipt/Recipt/VBoxContainer/Top_species)
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	await _display_container($Recipt/Recipt/VBoxContainer/Earning)
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	await _display_number(earning_number, PlayerStats.money)
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	await _display_container($Recipt/Recipt/VBoxContainer/Quota)
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	await _display_number(quota_number, GameState.get_night_quota(GameState.night))
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	await FastForward.wait(0.5, self, SUMMARY_FF_SCOPE)
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	await _display_container($Recipt/Recipt/VBoxContainer/Profits)
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	var net_profit: float = PlayerStats.money - GameState.get_night_quota(GameState.night)
	if net_profit < 0:
		proft_number.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0, 1.0))
	else:
		proft_number.add_theme_color_override("font_color", Color(0.424, 0.91, 0.0, 1.0))
	NumberInterpolator.set_number(proft_number, PlayerStats.money, " {coin}")
	await _display_container($Recipt/Recipt/VBoxContainer/Profit_number)
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	await _display_number(proft_number, net_profit, PlayerStats.money)
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	await FastForward.wait(1.0, self, SUMMARY_FF_SCOPE)
	if not is_inside_tree():
		_finish_owned_summary_scope(owns_scope)
		return
	if net_profit < 0:
		PlayerStats._change_money(net_profit)
		_finish_owned_summary_scope(owns_scope)
		#$Animation.play("failed_night")
		return
	else:
		PlayerStats._change_money(net_profit)
		#await get_tree().create_timer(1).timeout
		#_move_to_out($Recipt,false)
		#_move_to_in($Marketing,true)
		#_populate_grid_container_pick_3("Drinks",$Marketing/Marketing/VBoxContainer/HBoxContainer/Drinks/GridContainer)
	_finish_owned_summary_scope(owns_scope)

func _finish_owned_summary_scope(owns_scope: bool) -> void:
	if owns_scope:
		_owns_summary_scope = false
		FastForward.end_scope(SUMMARY_FF_SCOPE)

func _move_to_in(node: ColorRect,big: bool = false):
	var tween = get_tree().create_tween()
	if(big):
		tween.tween_property(node,"global_position",Vector2(11.0,4),1)
	else:
		tween.tween_property(node,"global_position",Vector2(400.0,4),1)

func _move_to_out(node: ColorRect,big: bool = false):
	var tween = get_tree().create_tween()
	if(big):
		tween.tween_property(node,"global_position",Vector2(-1309.0,4),1)
	else:
		tween.tween_property(node,"global_position",Vector2(-906,4),1)

func _add_or_remove_from_shopping_cart(node: Button):
	var node_type = node._get_type()
	var node_name = node._get_name()
	if(shopping_cart[node_type].has(node_name)):
		shopping_cart[node_type].erase(node_name)
		return
	else:
		var temp_dic = {"name" : node_name,"cost" : 50}
		shopping_cart[node_type][node_name] = temp_dic

func _go_next(node: Button):
	var node_type = node._get_type()
	var node_name = node._get_name()
	if(shopping_cart[node_type].has(node_name)):
		shopping_cart[node_type].erase(node_name)
		return
	else:
		var temp_dic = {"name" : node_name,"cost" : 0}
		shopping_cart[node_type][node_name] = temp_dic
	if(node_type.to_lower() == "marketing"):
		$Marketing/Marketing/VBoxContainer/HBoxContainer/Marketing.hide()
		_populate_grid_container_pick_3("Ingredients",$Marketing/Marketing/VBoxContainer/HBoxContainer/Ingredient/GridContainer)
		$Marketing/Marketing/VBoxContainer/HBoxContainer/Ingredient.show()
	elif(node_type.to_lower() == "drinks"):
		$Marketing/Marketing/VBoxContainer/HBoxContainer/Drinks.hide()
		_populate_grid_container_pick_3("Ingredients",$Marketing/Marketing/VBoxContainer/HBoxContainer/Ingredient/GridContainer)
		$Marketing/Marketing/VBoxContainer/HBoxContainer/Ingredient.show()
	else:
		$Marketing/Marketing/VBoxContainer/HBoxContainer/Marketing.show()
		$Marketing/Marketing/VBoxContainer/HBoxContainer/Ingredient.show()
		$Marketing/Marketing/VBoxContainer/Last.show()
		_populate_grid_container("Marketing",$Marketing/Marketing/VBoxContainer/HBoxContainer/Marketing/GridContainer)
		_populate_grid_container("Ingredients",$Marketing/Marketing/VBoxContainer/HBoxContainer/Ingredient/GridContainer)

func _populate_grid_container_pick_3(type: String, container: GridContainer):
	while(container.get_children()):
		container.remove_child(container.get_child(0))
	var temp_array = []
	print(type)
	if(type == "Ingredients"):
		temp_array = _produce_unlocks_pick_3_ingrediants()
	elif(type == "Marketing"):
		temp_array = _produce_unlocks_marketing()
	elif(type == "Drinks"):
		temp_array = _produce_unlocks_drinks()
	print(temp_array)
	for item in temp_array:
		var target_container = container
		if item != "index":
			var item_slot = item_scene.instantiate()
			item_slot.setup(item, type,self,true)
			item_slot.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
			target_container.add_child(item_slot)

func _produce_unlocks_drinks() -> Array:
	var temp_array = []
	#for x in PlayerStats.unlocks["Drinks"]:
		#if(!PlayerStats.unlocks["Drinks"][x]):
			#temp_array.push_back(x)
	for x in PlayerStats.unlocks["Drinks"]:
		if(!PlayerStats.unlocks["Drinks"][x]):
			temp_array.push_back(x)
		if(temp_array.size() >= 3):
			break
	return temp_array

func _produce_unlocks_pick_3_ingrediants() -> Array:
	var temp_array = []
	#for x in PlayerStats.unlocks["Drinks"]:
		#if(!PlayerStats.unlocks["Drinks"][x]):
			#temp_array.push_back(x)
	for x in PlayerStats.unlocks["Ingredients"]:
		if(!PlayerStats.unlocks["Ingredients"][x]):
			if not PlayerStats.can_offer_ingredient_free_pick(str(x), GameState.night):
				continue
			temp_array.push_back(x)
		if(temp_array.size() >= 3):
			break
	return temp_array

func _produce_unlocks_marketing() -> Array:
	var ids: Array = []
	for sp_id in SpeciesRegistry.get_marketing_unlock_ids(PlayerStats):
		ids.push_back(sp_id)
	return ids

func _populate_grid_container(type: String, container: GridContainer):
	while(container.get_children()):
		container.remove_child(container.get_child(0))
	for item in PlayerStats.upgrades[type]:
		var target_container = container
		if item != "index":
			var item_slot = item_scene.instantiate()
			item_slot.setup(item, type,self,true)
			item_slot.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
			target_container.add_child(item_slot)

func _display_container(container: Control, fast_forward_duration: float = -1.0) -> void:
	container.show()
	await get_tree().process_frame
	if not is_instance_valid(container) or not is_inside_tree():
		return
	container.pivot_offset = container.size / 2
	container.scale = Vector2(2.0, 2.0)
	container.rotation_degrees = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(container, "scale", Vector2.ONE, 1.0)
	#tween.tween_property(container, "rotation_degrees", 360.0, 1.0)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ff_opts := {"duration": fast_forward_duration} if fast_forward_duration >= 0.0 else {}
	FastForward.track_tween(tween, 1.0, SUMMARY_FF_SCOPE, ff_opts)

func _display_number(label: Label, to: float, from: float = 0.0, duration: float = NumberInterpolator.DEFAULT_SUMMARY_DURATION, fast_forward_duration: float = -1.0) -> void:
	label.show()
	var ff_opts := {"duration": fast_forward_duration} if fast_forward_duration >= 0.0 else {}
	var tween := NumberInterpolator.interpolate(label, to, from, duration, " {coin}", "", 0, SUMMARY_FF_SCOPE, ff_opts)
	if tween and tween.is_valid():
		await tween.finished
	#while not Input.is_action_just_pressed("Left_click"):
		#await get_tree().process_frame

func _top_speicies_check() -> void:
	var sp := SpeciesRegistry.get_species_or_default(PlayerStats.get_highest_gaining_species())
	if sp and top_species_sprite:
		top_species_sprite.frame = sp.logo_frame

func _refresh_display() -> void:
	var top_species: String = PlayerStats.get_highest_gaining_species()
	var sp_icon := ""
	if TextIcons.has_icon(top_species.to_lower()):
		sp_icon = " {" + top_species.to_lower() + "}"
	top_species_label.text = "Representative Visitor Tonight: " + top_species + sp_icon
	var target_quota: float = GameState.get_night_quota(GameState.night)
	info_label.text = "Night: " + str(GameState.night) + " / " + str(GameState.max_nights) + "\nMoney: " + str(int(PlayerStats.money)) + " {coin}\nQuota Due: " + str(int(target_quota)) + " {coin}"
	pay_quota_button.text = "Paid Quota" if quota_paid else "Pay Quota (" + str(int(target_quota)) + " {coin})"
	pay_quota_button.disabled = quota_paid
	buy_ingredient_button.text = "Ingredient Purchased" if ingredient_bought else "Buy Ingredient (" + str(int(MANDATORY_INGREDIENT_COST)) + " {coin})"
	buy_marketing_button.text = "Marketing Active" if marketing_bought else "Buy Marketing (" + str(int(MANDATORY_MARKETING_COST)) + " {coin})"
	restart_button.text = "Restart Night (" + str(GameState.restarts_left) + " left)"
	restart_button.disabled = GameState.restarts_left <= 0
	TextIcons.apply_to_control(top_species_label)
	TextIcons.apply_to_control(info_label)
	TextIcons.apply_to_control(pay_quota_button)
	TextIcons.apply_to_control(buy_ingredient_button)
	TextIcons.apply_to_control(buy_marketing_button)

# Deducts quota from balance
func _on_pay_quota_pressed() -> void:
	var target_quota: float = GameState.get_night_quota(GameState.night)
	if PlayerStats.money >= target_quota:
		PlayerStats._change_money(PlayerStats.money - target_quota)
		quota_paid = true
		status_label.text = "Quota paid successfully"
	else:
		status_label.text = "Cannot afford quota"
	_refresh_display()

# Purchases mandatory ingredient
func _on_buy_ingredient_pressed() -> void:
	if ingredient_bought:
		status_label.text = "Ingredient already purchased"
		return
	if PlayerStats.money >= MANDATORY_INGREDIENT_COST:
		PlayerStats._change_money(PlayerStats.money - MANDATORY_INGREDIENT_COST)
		ingredient_bought = true
		status_label.text = "Ingredient unlocked"
		buy_ingredient_button.disabled = true
	else:
		status_label.text = "Cannot afford ingredient"
	_refresh_display()

# Purchases mandatory marketing
func _on_buy_marketing_pressed() -> void:
	if marketing_bought:
		status_label.text = "Marketing already purchased"
		return
	if PlayerStats.money >= MANDATORY_MARKETING_COST:
		PlayerStats._change_money(PlayerStats.money - MANDATORY_MARKETING_COST)
		marketing_bought = true
		status_label.text = "Marketing active"
		buy_marketing_button.disabled = true
	else:
		status_label.text = "Cannot afford marketing"
	_refresh_display()

# Restarts current night shift
func _on_restart_pressed() -> void:
	if GameState.use_restart():
		PlayerStats.reset_night_reputation_gains()
		get_tree().change_scene_to_file("res://Main3D.tscn")
	else:
		status_label.text = "No restarts remaining"



# Cehck quota and mandatory purchases before proceeding to next night
func _on_next_night_pressed() -> void:
	print(shopping_cart)
	for main_key in shopping_cart:
		for sub_key in shopping_cart[main_key]:
			match main_key:
				"Marketing":
					var sp := SpeciesRegistry.get_species(str(sub_key))
					if sp:
						var current_weight: float = float(PlayerStats.species_marketing.get(sp.display_name, sp.default_marketing_weight))
						PlayerStats.set_species_marketing(sp.display_name, current_weight + 1.0)
				"Ingredients":
					PlayerStats.unlocks[main_key][sub_key] = true
					SpeciesRegistry.on_ingredient_unlocked(str(sub_key), PlayerStats)
				_:
					PlayerStats.unlocks[main_key][sub_key] = true
					print("Main_key ",main_key)
					print("Sub_key ",sub_key)
	if GameState.night >= GameState.max_nights:
		status_label.text = "VICTORY! You survived all 7 nights"
		next_night_button.disabled = true
		return

	GameState.advance_night()
	PlayerStats.reset_night_reputation_gains()
	Transition._changing_scene("res://Main3D.tscn")