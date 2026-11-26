class_name UpgradeRegistry
extends RefCounted

# Central registry of all upgrades (standardized list, lookup, shop filtering, and unlock-all)

static var _initialized: bool = false
static var _upgrades_by_id: Dictionary = {}
static var _ordered_upgrades: Array[UpgradeDef] = []

static func ensure_loaded() -> void:
	if _initialized:
		return
	_initialized = true
	_upgrades_by_id.clear()
	_ordered_upgrades.clear()
	_register_defaults()
	_ordered_upgrades.sort_custom(func(a: UpgradeDef, b: UpgradeDef) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.upgrade_id < b.upgrade_id
	)

static func reload() -> void:
	_initialized = false
	ensure_loaded()

static func _register_defaults() -> void:
	register_upgrade(UpgradeDef.from_dict({
		"id": "Jukebox",
		"description": "Decrease patience for a huge bonus",
		"sort_order": 1,
	}))
	register_upgrade(UpgradeDef.from_dict({
		"id": "Instant Refill",
		"description": "Pay to instantly refill ingrdients",
		"sort_order": 2,
		"on_unlocked": _on_instant_refill_unlocked,
		"on_reset": _on_ingredient_upgrade_reset,
	}))
	register_upgrade(UpgradeDef.from_dict({
		"id": "Drinks Size Increase",
		"description": "Increases ingredient capacity",
		"sort_order": 3,
		"repeatable": true,
		"max_level": -1,
		"passive_key": "Drinks Size Increase",
		"on_unlocked": _on_ingredient_upgrade_unlocked,
		"on_reset": _on_ingredient_upgrade_reset,
	}))
	register_upgrade(UpgradeDef.from_dict({
		"id": "Drinks Auto Increase",
		"description": "Speed up ingredient refills",
		"sort_order": 4,
		"repeatable": true,
		"max_level": 6,
		"passive_key": "Drinks Auto Increase",
		"on_unlocked": _on_ingredient_upgrade_unlocked,
		"on_reset": _on_ingredient_upgrade_reset,
	}))
	register_upgrade(UpgradeDef.from_dict({
		"id": "Combo Extension Increase",
		"description": "Extend serve combo grace period",
		"sort_order": 5,
		"repeatable": true,
		"max_level": -1,
		"show_in_shop": false,
		"passive_key": "Combo Extension Increase",
	}))
	register_upgrade(UpgradeDef.from_dict({
		"id": "Human Banner",
		"description": "Doubles Human patron spawn weight",
		"sort_order": 10,
		"banner_species": "Human",
	}))
	register_upgrade(UpgradeDef.from_dict({
		"id": "Vampire Banner",
		"description": "Doubles Vampire patron spawn weight",
		"sort_order": 11,
		"banner_species": "Vampire",
	}))
	register_upgrade(UpgradeDef.from_dict({
		"id": "Slime Banner",
		"description": "Doubles Slime patron spawn weight",
		"sort_order": 12,
		"banner_species": "Slime",
	}))
	register_upgrade(UpgradeDef.from_dict({
		"id": "Tiny Banner",
		"description": "Doubles Tiny patron spawn weight",
		"sort_order": 13,
		"banner_species": "Tiny",
	}))

static func register_upgrade(upg: UpgradeDef) -> void:
	if upg == null:
		return
	var key := upg.upgrade_id.to_lower().strip_edges()
	if key == "" or _upgrades_by_id.has(key):
		return
	_upgrades_by_id[key] = upg
	_ordered_upgrades.append(upg)

static func _refresh_shelf_ingredients() -> void:
	if GameState and GameState.shelf_manager and is_instance_valid(GameState.main_node):
		var counter_ref: Node3D = null
		if GameState.player and "counter" in GameState.player and is_instance_valid(GameState.player.counter):
			counter_ref = GameState.player.counter
		else:
			counter_ref = GameState.main_node.get_node_or_null("Coutner") as Node3D
		if GameState.shelf_manager.has_method("refresh_shelf_upgrades"):
			GameState.shelf_manager.refresh_shelf_upgrades(GameState.main_node, counter_ref)
		else:
			GameState.shelf_manager.refresh_shelf_bottles(GameState.main_node, counter_ref)

static func _on_instant_refill_unlocked(_stats: Node, _level: int) -> void:
	_refresh_shelf_ingredients()

static func _on_ingredient_upgrade_unlocked(_stats: Node, _level: int) -> void:
	_refresh_shelf_ingredients()

static func _on_ingredient_upgrade_reset(_stats: Node) -> void:
	_refresh_shelf_ingredients()

static func _resolve_stats(stats: Node = null) -> Node:
	if is_instance_valid(stats):
		return stats
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("PlayerStats")
	return null

static func get_all_upgrades() -> Array[UpgradeDef]:
	ensure_loaded()
	var list: Array[UpgradeDef] = []
	list.assign(_ordered_upgrades)
	return list

static func get_all_upgrade_ids() -> Array[String]:
	ensure_loaded()
	var ids: Array[String] = []
	for upg in _ordered_upgrades:
		ids.append(upg.upgrade_id)
	return ids

static func get_upgrade(id_or_name: String) -> UpgradeDef:
	ensure_loaded()
	var key := id_or_name.to_lower().strip_edges()
	if key == "":
		return null
	if _upgrades_by_id.has(key):
		return _upgrades_by_id[key] as UpgradeDef
	for upg in _ordered_upgrades:
		if upg.get_display_name().to_lower().strip_edges() == key:
			return upg
	return null

static func get_available_shop_upgrades(stats: Node = null, night: int = 1) -> Array[UpgradeDef]:
	ensure_loaded()
	var target_stats := _resolve_stats(stats)
	var available: Array[UpgradeDef] = []
	for upg in _ordered_upgrades:
		if upg.can_appear_in_shop(target_stats, night):
			available.append(upg)
	return available

static func get_unlocked_upgrades(stats: Node = null) -> Array[UpgradeDef]:
	ensure_loaded()
	var target_stats := _resolve_stats(stats)
	var unlocked: Array[UpgradeDef] = []
	for upg in _ordered_upgrades:
		if upg.is_unlocked(target_stats):
			unlocked.append(upg)
	return unlocked

static func is_unlocked(upgrade_id: String, stats: Node = null) -> bool:
	var upg := get_upgrade(upgrade_id)
	if upg == null:
		return false
	return upg.is_unlocked(_resolve_stats(stats))

static func get_level(upgrade_id: String, stats: Node = null) -> int:
	var upg := get_upgrade(upgrade_id)
	if upg == null:
		return 0
	return upg.get_level(_resolve_stats(stats))

static func sync_with_player_stats(stats: Node = null) -> void:
	ensure_loaded()
	var target_stats := _resolve_stats(stats)
	if target_stats == null:
		return
	for upg in _ordered_upgrades:
		upg.ensure_stats_entries(target_stats)

static func unlock_upgrade(upgrade_id: String, stats: Node = null, levels: int = 1) -> bool:
	var upg := get_upgrade(upgrade_id)
	var target_stats := _resolve_stats(stats)
	if upg == null or target_stats == null:
		return false
	upg.apply_unlock(target_stats, levels)
	return true

static func unlock_all_upgrades(stats: Node = null) -> void:
	ensure_loaded()
	var target_stats := _resolve_stats(stats)
	for upg in _ordered_upgrades:
		upg.set_unlocked(true, target_stats)

static func reset_all_upgrades(stats: Node = null) -> void:
	ensure_loaded()
	var target_stats := _resolve_stats(stats)
	for upg in _ordered_upgrades:
		upg.set_unlocked(false, target_stats)