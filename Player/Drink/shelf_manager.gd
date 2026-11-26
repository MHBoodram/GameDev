# Spawns  unlocked ingredients on shelves
# Lookups for spawned ingredients and manages refills
class_name BarShelfManager
extends Node

const LIQUID_SCENE_PATH := "res://Player/Drink/Liquids/liquid.tscn"
const GARNISH_DISPENSER_SCENE_PATH := "res://Player/Drink/garnish_dispenser.tscn"
const RESOURCE_BASE_PATH := "res://Player/Drink/Liquids/resource/"
const NAME_TAG_SCENE := preload("res://UI/Gameplay_ui/NameTag.tscn")

var spawned_bottles: Dictionary = {}
var spawned_garnishes: Dictionary = {}
var refill_tags: Dictionary = {}

func refresh_shelf_bottles(host: Node3D, counter_ref: Node3D) -> void:
	if not is_instance_valid(host):
		return

	if PlayerStats.unlocks.has("Drinks"):
		for drink_id in PlayerStats.unlocks["Drinks"]:
			if PlayerStats.unlocks["Drinks"][drink_id]:
				spawn_bottle_if_missing(host, counter_ref, str(drink_id))

	if PlayerStats.unlocks.has("Ingredients") and PlayerStats.unlocks["Ingredients"].get("Blood", false):
		spawn_bottle_if_missing(host, counter_ref, "blood")

	refresh_shelf_garnishes(host, counter_ref)

func refresh_shelf_upgrades(host: Node3D, counter_ref: Node3D) -> void:
	refresh_shelf_bottles(host, counter_ref)

func refresh_shelf_garnishes(host: Node3D, counter_ref: Node3D) -> void:
	if not is_instance_valid(host):
		return
	var garnishes_unlocked := PlayerStats.has_unlock("Ingredients", "Garnishes")
	var ice_unlocked := PlayerStats.has_unlock("Ingredients", "Ice")
	for marker_name in GarnishDefinitions.MARKER_MAP.keys():
		var garnish_id := str(GarnishDefinitions.MARKER_MAP[marker_name])
		var is_unlocked := ice_unlocked if GarnishDefinitions.is_ice(garnish_id) else garnishes_unlocked
		if is_unlocked:
			spawn_garnish_dispenser_if_missing(host, counter_ref, str(marker_name), garnish_id)

func spawn_garnish_dispenser_if_missing(host: Node3D, counter_ref: Node3D, marker_name: String, garnish_id: String) -> Node:
	var marker := host.get_node_or_null(marker_name) as Marker3D

	if spawned_garnishes.has(marker_name) and is_instance_valid(spawned_garnishes[marker_name]):
		var existing_dispenser: Node = spawned_garnishes[marker_name]
		if existing_dispenser.has_method("refresh_upgrades"):
			existing_dispenser.refresh_upgrades()
		_ensure_garnish_refill_tag(host, garnish_id, existing_dispenser, marker)
		return existing_dispenser

	var node_name := garnish_id + "_dispenser"
	var existing := host.get_node_or_null(node_name)
	if existing:
		spawned_garnishes[marker_name] = existing
		if existing.has_method("refresh_upgrades"):
			existing.refresh_upgrades()
		_ensure_garnish_refill_tag(host, garnish_id, existing, marker)
		return existing

	if not marker:
		return null

	if not ResourceLoader.exists(GARNISH_DISPENSER_SCENE_PATH):
		return null
	var dispenser_scene := load(GARNISH_DISPENSER_SCENE_PATH) as PackedScene
	if not dispenser_scene:
		return null

	var dispenser := dispenser_scene.instantiate()
	dispenser.name = node_name
	host.add_child(dispenser)
	if dispenser.has_method("setup"):
		dispenser.setup(marker, counter_ref, garnish_id)

	spawned_garnishes[marker_name] = dispenser
	_ensure_garnish_refill_tag(host, garnish_id, dispenser, marker)
	return dispenser

func spawn_bottle_if_missing(host: Node3D, counter_ref: Node3D, drink_id: String) -> Node:
	if spawned_bottles.has(drink_id) and is_instance_valid(spawned_bottles[drink_id]):
		_ensure_refill_tag(host, drink_id, spawned_bottles[drink_id], host.get_node_or_null(drink_id + "_marker") as Marker3D)
		return spawned_bottles[drink_id]

	var marker := host.get_node_or_null(drink_id + "_marker") as Marker3D

	var existing := host.get_node_or_null(drink_id)
	if existing:
		spawned_bottles[drink_id] = existing
		_ensure_refill_tag(host, drink_id, existing, marker)
		return existing

	if not marker:
		return null

	var res_path := RESOURCE_BASE_PATH + drink_id + ".tres"
	if not ResourceLoader.exists(res_path):
		return null

	var liquid_res = load(res_path)
	var liquid_scene = load(LIQUID_SCENE_PATH)
	if not liquid_scene or not liquid_res:
		return null

	var bottle_instance = liquid_scene.instantiate()
	bottle_instance.name = drink_id
	host.add_child(bottle_instance)

	if bottle_instance.has_method("setup"):
		bottle_instance.setup(marker, counter_ref, liquid_res)

	spawned_bottles[drink_id] = bottle_instance
	_ensure_refill_tag(host, drink_id, bottle_instance, marker)
	return bottle_instance

func _ensure_refill_tag(host: Node3D, drink_id: String, bottle_node: Node, marker: Marker3D) -> void:
	if not is_instance_valid(host) or not (bottle_node is Drinks):
		return

	var unlocked := PlayerStats.has_unlock("Upgrades", "Instant Refill")
	var bottle := bottle_node as Drinks

	if refill_tags.has(drink_id) and is_instance_valid(refill_tags[drink_id]):
		var existing_tag := refill_tags[drink_id] as NameTag
		if existing_tag:
			existing_tag.visible = unlocked
			existing_tag.set_interactive(unlocked)
			if unlocked:
				_update_refill_tag(bottle, existing_tag)
		return

	if not unlocked:
		return

	var tag := NAME_TAG_SCENE.instantiate() as NameTag
	tag.name = drink_id + "_refill_tag"
	host.add_child(tag)

	var base_pos := marker.global_position if is_instance_valid(marker) else bottle.global_position
	var tag_y := base_pos.y + 0.34
	var inside_sprite := bottle.get_node_or_null("Inside") as Sprite3D
	if inside_sprite:
		var sprite_bounds = WorkingAreaService.get_sprite_world_bounds(inside_sprite)
		if sprite_bounds is AABB:
			tag_y = maxf(tag_y, (sprite_bounds as AABB).end.y + 0.09)
	tag.global_position = Vector3(base_pos.x, tag_y, base_pos.z - 0.06)

	tag.setup(str(bottle.get_refill_cost()) + " {coin}", null, true)
	tag.set_disabled(bottle.get_refill_cost() <= 0)

	tag.pressed.connect(func() -> void:
		_on_refill_tag_pressed(bottle, tag)
	)
	bottle.liquid_changed.connect(func(_cur: float, _max: float) -> void:
		_update_refill_tag(bottle, tag)
	)
	refill_tags[drink_id] = tag

func _ensure_garnish_refill_tag(host: Node3D, garnish_id: String, dispenser_node: Node, marker: Marker3D) -> void:
	if not is_instance_valid(host) or not (dispenser_node is GarnishDispenser):
		return

	var unlocked := PlayerStats.has_unlock("Upgrades", "Instant Refill")
	var dispenser := dispenser_node as GarnishDispenser
	var tag_key := "garnish_" + garnish_id

	if refill_tags.has(tag_key) and is_instance_valid(refill_tags[tag_key]):
		var existing_tag := refill_tags[tag_key] as NameTag
		if existing_tag:
			existing_tag.visible = unlocked
			existing_tag.set_interactive(unlocked)
			if unlocked:
				_update_garnish_refill_tag(dispenser, existing_tag)
		return

	if not unlocked:
		return

	var tag := NAME_TAG_SCENE.instantiate() as NameTag
	tag.name = garnish_id + "_refill_tag"
	host.add_child(tag)

	var base_pos := marker.global_position if is_instance_valid(marker) else dispenser.global_position
	var tag_y := base_pos.y + 0.14
	var sprite_node := dispenser.get_node_or_null("Sprite3D") as Sprite3D
	if sprite_node:
		var sprite_bounds = WorkingAreaService.get_sprite_world_bounds(sprite_node)
		if sprite_bounds is AABB:
			tag_y = maxf(tag_y, (sprite_bounds as AABB).end.y + 0.08)
	tag.global_position = Vector3(base_pos.x, tag_y, base_pos.z - 0.06)

	var cost: int = dispenser.get_refill_cost()
	tag.setup(str(cost) + " {coin}", null, true)
	tag.set_disabled(cost <= 0)

	tag.pressed.connect(func() -> void:
		_on_garnish_refill_tag_pressed(dispenser, tag)
	)
	dispenser.stock_changed.connect(func(_cur: int, _max: int) -> void:
		_update_garnish_refill_tag(dispenser, tag)
	)
	refill_tags[tag_key] = tag

func _update_refill_tag(bottle: Drinks, tag: NameTag) -> void:
	if not is_instance_valid(bottle) or not is_instance_valid(tag):
		return
	var cost: int = bottle.get_refill_cost()
	tag.set_text(str(cost) + " {coin}")
	tag.set_disabled(cost <= 0)

func _update_garnish_refill_tag(dispenser: GarnishDispenser, tag: NameTag) -> void:
	if not is_instance_valid(dispenser) or not is_instance_valid(tag):
		return
	var cost: int = dispenser.get_refill_cost()
	tag.set_text(str(cost) + " {coin}")
	tag.set_disabled(cost <= 0)

func _on_refill_tag_pressed(bottle: Drinks, tag: NameTag) -> void:
	if not is_instance_valid(bottle) or not is_instance_valid(tag):
		return
	if not PlayerStats.has_unlock("Upgrades", "Instant Refill"):
		return
	if bottle.in_game or bottle.is_pouring or bottle.is_balls_dragging:
		return
	var cost: int = bottle.get_refill_cost()
	if cost <= 0:
		return
	if PlayerStats.money < float(cost):
		tag.deny()
		return
	PlayerStats._change_money(PlayerStats.money - float(cost))
	bottle.refill()
	UIAudio.play_click()

func _on_garnish_refill_tag_pressed(dispenser: GarnishDispenser, tag: NameTag) -> void:
	if not is_instance_valid(dispenser) or not is_instance_valid(tag):
		return
	if not PlayerStats.has_unlock("Upgrades", "Instant Refill"):
		return
	if GameState.player and "in_game" in GameState.player and GameState.player.in_game:
		return
	var cost: int = dispenser.get_refill_cost()
	if cost <= 0:
		return
	if PlayerStats.money < float(cost):
		tag.deny()
		return
	PlayerStats._change_money(PlayerStats.money - float(cost))
	dispenser.refill()
	UIAudio.play_click()

func get_bottle(drink_id: String) -> Node:
	return spawned_bottles.get(drink_id, null)

func add_liquid_to_bottle(drink_id: String, amount: float) -> void:
	var bottle = get_bottle(drink_id)
	if bottle and bottle.has_method("_add_liquid"):
		bottle._add_liquid(amount)