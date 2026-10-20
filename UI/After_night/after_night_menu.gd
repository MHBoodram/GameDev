extends Control

@onready var info_label: Label = $TextureRect/VBoxContainer/InfoLabel
@onready var status_label: Label = $TextureRect/VBoxContainer/StatusLabel
@onready var top_species_label: Label = $TextureRect/VBoxContainer/TopSpeciesLabel
@onready var pay_quota_button: Button = $TextureRect/VBoxContainer/PayQuotaButton
@onready var buy_ingredient_button: Button = $TextureRect/VBoxContainer/BuyIngredientButton
@onready var buy_marketing_button: Button = $TextureRect/VBoxContainer/BuyMarketingButton
@onready var restart_button: Button = $TextureRect/VBoxContainer/RestartButton
@onready var next_night_button: Button = $TextureRect/VBoxContainer/NextNightButton

var quota_paid: bool = false
var ingredient_bought: bool = false
var marketing_bought: bool = false

const MANDATORY_INGREDIENT_COST: float = 50.0
const MANDATORY_MARKETING_COST: float = 50.0

func _ready() -> void:
	pay_quota_button.pressed.connect(_on_pay_quota_pressed)
	buy_ingredient_button.pressed.connect(_on_buy_ingredient_pressed)
	buy_marketing_button.pressed.connect(_on_buy_marketing_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	next_night_button.pressed.connect(_on_next_night_pressed)
	_refresh_display()

func _refresh_display() -> void:
	var top_species: String = PlayerStats.get_highest_gaining_species()
	top_species_label.text = "Representative Visitor Tonight: " + top_species
	var target_quota: float = GameState.get_night_quota(GameState.night)
	info_label.text = "Night: " + str(GameState.night) + " / " + str(GameState.max_nights) + "\nMoney: $" + str(int(PlayerStats.money)) + "\nQuota Due: $" + str(int(target_quota))
	pay_quota_button.text = "Paid Quota" if quota_paid else "Pay Quota ($" + str(int(target_quota)) + ")"
	pay_quota_button.disabled = quota_paid
	restart_button.text = "Restart Night (" + str(GameState.restarts_left) + " left)"
	restart_button.disabled = GameState.restarts_left <= 0

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
	var target_quota: float = GameState.get_night_quota(GameState.night)
	if not quota_paid:
		if PlayerStats.money < target_quota:
			status_label.text = "BANKRUPT! Bar goes out of business"
			next_night_button.disabled = true
			return
		else:
			status_label.text = "Pay the quota first"
			return

	if not ingredient_bought or not marketing_bought:
		status_label.text = "Mandatory purchases required: 1 ingredient and 1 marketing"
		return

	if GameState.night >= GameState.max_nights:
		status_label.text = "VICTORY! You survived all 7 nights"
		next_night_button.disabled = true
		return

	GameState.advance_night()
	PlayerStats.reset_night_reputation_gains()
	get_tree().change_scene_to_file("res://Main3D.tscn")