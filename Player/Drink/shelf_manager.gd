# Spawns  unlocked ingredients on shelves
# Lookups for spawned ingredients and manages refills
class_name BarShelfManager
extends Node

const LIQUID_SCENE_PATH := "res://Player/Drink/Liquids/liquid.tscn"
const RESOURCE_BASE_PATH := "res://Player/Drink/Liquids/resource/"

var spawned_bottles: Dictionary = {}

func refresh_shelf_bottles(host: Node3D, counter_ref: Node3D) -> void:
	if not is_instance_valid(host):
		return

	if PlayerStats.unlocks.has("Drinks"):
		for drink_id in PlayerStats.unlocks["Drinks"]:
			if PlayerStats.unlocks["Drinks"][drink_id]:
				spawn_bottle_if_missing(host, counter_ref, str(drink_id))

	if PlayerStats.unlocks.has("Ingredients") and PlayerStats.unlocks["Ingredients"].get("Blood", false):
		spawn_bottle_if_missing(host, counter_ref, "blood")

func spawn_bottle_if_missing(host: Node3D, counter_ref: Node3D, drink_id: String) -> Node:
	if spawned_bottles.has(drink_id) and is_instance_valid(spawned_bottles[drink_id]):
		return spawned_bottles[drink_id]

	var existing := host.get_node_or_null(drink_id)
	if existing:
		spawned_bottles[drink_id] = existing
		return existing

	var marker := host.get_node_or_null(drink_id + "_marker") as Marker3D
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
	return bottle_instance

func get_bottle(drink_id: String) -> Node:
	return spawned_bottles.get(drink_id, null)

func add_liquid_to_bottle(drink_id: String, amount: float) -> void:
	var bottle = get_bottle(drink_id)
	if bottle and bottle.has_method("_add_liquid"):
		bottle._add_liquid(amount)