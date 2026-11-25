class_name UpgradeDef
extends RefCounted

# Modular upgrade definition (supports data-only upgrades, banners, passives, and custom callbacks)

var upgrade_id: String = ""
var display_name: String = ""
var description: String = ""
var icon_path: String = ""
var sort_order: int = 100

var repeatable: bool = false
var max_level: int = 1
var base_cost: int = 0
var show_in_shop: bool = true
var passive_key: String = ""
var banner_species: String = ""

var on_unlocked_cb: Callable = Callable()
var on_reset_cb: Callable = Callable()
var can_appear_cb: Callable = Callable()
var cost_cb: Callable = Callable()

static func from_dict(data: Dictionary) -> UpgradeDef:
	var def := UpgradeDef.new()
	def.upgrade_id = str(data.get("id", ""))
	def.display_name = str(data.get("display_name", def.upgrade_id))
	def.description = str(data.get("description", ""))
	def.icon_path = str(data.get("icon_path", ""))
	def.sort_order = int(data.get("sort_order", 100))
	def.repeatable = bool(data.get("repeatable", false))
	def.max_level = int(data.get("max_level", -1 if def.repeatable else 1))
	def.base_cost = int(data.get("base_cost", 0))
	def.show_in_shop = bool(data.get("show_in_shop", true))
	def.passive_key = str(data.get("passive_key", ""))
	def.banner_species = str(data.get("banner_species", ""))
	if data.get("on_unlocked") is Callable:
		def.on_unlocked_cb = data["on_unlocked"] as Callable
	if data.get("on_reset") is Callable:
		def.on_reset_cb = data["on_reset"] as Callable
	if data.get("can_appear") is Callable:
		def.can_appear_cb = data["can_appear"] as Callable
	if data.get("get_cost") is Callable:
		def.cost_cb = data["get_cost"] as Callable
	return def

func get_display_name() -> String:
	return display_name if display_name != "" else upgrade_id

func get_icon_path() -> String:
	if icon_path != "":
		return icon_path
	return "res://Assets/Upgrades/" + upgrade_id + ".png"

func get_icon() -> Texture2D:
	var path := get_icon_path()
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_shop_cost(night: int = 1, stats: Node = null) -> int:
	if cost_cb.is_valid():
		return int(cost_cb.call(night, get_level(stats), stats))
	if base_cost > 0:
		return base_cost
	return randi_range(1, maxi(1, night) * 30)

func ensure_stats_entries(stats: Node) -> void:
	if stats == null:
		return
	if "unlocks" in stats:
		if not stats.unlocks.has("Upgrades"):
			stats.unlocks["Upgrades"] = {}
		if not stats.unlocks["Upgrades"].has(upgrade_id):
			stats.unlocks["Upgrades"][upgrade_id] = false
	if passive_key != "" and "unlock_passive" in stats:
		if not stats.unlock_passive.has(passive_key):
			stats.unlock_passive[passive_key] = 0

func is_unlocked(stats: Node = null) -> bool:
	if stats == null:
		return false
	if stats.has_method("has_unlock"):
		return stats.has_unlock("Upgrades", upgrade_id)
	if "unlocks" in stats and stats.unlocks.has("Upgrades"):
		return bool(stats.unlocks["Upgrades"].get(upgrade_id, false))
	return false

func get_level(stats: Node = null) -> int:
	if stats == null:
		return 0
	if passive_key != "" and "unlock_passive" in stats and stats.unlock_passive.has(passive_key):
		return int(stats.unlock_passive[passive_key])
	return 1 if is_unlocked(stats) else 0

func can_purchase(stats: Node = null) -> bool:
	if repeatable:
		return max_level < 0 or get_level(stats) < max_level
	return not is_unlocked(stats)

func can_appear_in_shop(stats: Node = null, night: int = 1) -> bool:
	if not show_in_shop or not can_purchase(stats):
		return false
	if can_appear_cb.is_valid():
		return bool(can_appear_cb.call(stats, night))
	return true

func set_unlocked(enabled: bool, stats: Node = null) -> void:
	if stats == null:
		return
	ensure_stats_entries(stats)
	stats.unlocks["Upgrades"][upgrade_id] = enabled
	if enabled:
		if passive_key != "" and "unlock_passive" in stats:
			var cur := int(stats.unlock_passive.get(passive_key, 0))
			if cur < 1:
				stats.unlock_passive[passive_key] = 1
		on_unlocked(stats, get_level(stats))
	else:
		if passive_key != "" and "unlock_passive" in stats:
			stats.unlock_passive[passive_key] = 0
		on_reset(stats)

func apply_unlock(stats: Node = null, levels: int = 1) -> void:
	if stats == null or levels <= 0:
		return
	ensure_stats_entries(stats)
	stats.unlocks["Upgrades"][upgrade_id] = true
	if passive_key != "" and "unlock_passive" in stats:
		var cur := int(stats.unlock_passive.get(passive_key, 0))
		var next_val := cur + levels
		if max_level > 0:
			next_val = mini(next_val, max_level)
		stats.unlock_passive[passive_key] = next_val
	on_unlocked(stats, get_level(stats))

func on_unlocked(stats: Node = null, level: int = 1) -> void:
	_set_banner_state(stats, true)
	if on_unlocked_cb.is_valid():
		on_unlocked_cb.call(stats, level)

func on_reset(stats: Node = null) -> void:
	_set_banner_state(stats, false)
	if on_reset_cb.is_valid():
		on_reset_cb.call(stats)

func _set_banner_state(stats: Node, active: bool) -> void:
	if stats == null or banner_species == "" or not ("species_banners" in stats):
		return
	if stats.has_method("_find_species_key"):
		var key: String = stats._find_species_key(banner_species)
		stats.species_banners[key] = active
	else:
		stats.species_banners[banner_species] = active