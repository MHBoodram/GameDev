class_name SpeciesRegistry
extends RefCounted

# Auto-discovers every SpeciesBase subclass in /species
# Hooks in many files by looping through the loaded species lis

const SPECIES_DIR := "res://NPC/Species"

static var _initialized: bool = false
static var _species_by_id: Dictionary = {}
static var _ordered_species: Array[SpeciesBase] = []

static func ensure_loaded() -> void:
	if _initialized:
		return
	_initialized = true
	_species_by_id.clear()
	_ordered_species.clear()

	for script_path in _discover_species_scripts():
		var res = load(script_path)
		if res is GDScript and res.can_instantiate():
			var instance = res.new()
			if instance is SpeciesBase:
				var sp := instance as SpeciesBase
				var key := sp.species_id.to_upper().strip_edges()
				if key != "" and not _species_by_id.has(key):
					_species_by_id[key] = sp
					_ordered_species.append(sp)

	_ordered_species.sort_custom(func(a: SpeciesBase, b: SpeciesBase) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.species_id < b.species_id
	)

static func reload() -> void:
	_initialized = false
	ensure_loaded()

static func _discover_species_scripts() -> Array[String]:
	var found: Array[String] = []
	var filenames: PackedStringArray = PackedStringArray()

	if ResourceLoader.has_method("list_directory"):
		filenames = ResourceLoader.list_directory(SPECIES_DIR)

	if filenames.is_empty():
		var dir := DirAccess.open(SPECIES_DIR)
		if dir:
			dir.list_dir_begin()
			var entry := dir.get_next()
			while entry != "":
				if not dir.current_is_dir():
					filenames.append(entry)
				entry = dir.get_next()
			dir.list_dir_end()

	for raw_name in filenames:
		var clean_name := raw_name
		if clean_name.ends_with(".remap"):
			clean_name = clean_name.trim_suffix(".remap")
		if clean_name.ends_with(".gdc"):
			clean_name = clean_name.trim_suffix(".gdc") + ".gd"
		if not clean_name.ends_with(".gd"):
			continue
		if clean_name == "species_base.gd" or clean_name == "species_registry.gd":
			continue
		var full_path := SPECIES_DIR + "/" + clean_name
		if not found.has(full_path):
			found.append(full_path)

	return found

static func get_all_species() -> Array[SpeciesBase]:
	ensure_loaded()
	var list: Array[SpeciesBase] = []
	list.assign(_ordered_species)
	return list

static func get_species(species_name: String) -> SpeciesBase:
	ensure_loaded()
	var key := species_name.to_upper().strip_edges()
	if _species_by_id.has(key):
		return _species_by_id[key] as SpeciesBase
	for sp in _ordered_species:
		if sp.display_name.to_upper() == key:
			return sp
	return null

static func get_species_or_default(species_name: String) -> SpeciesBase:
	var sp := get_species(species_name)
	if sp != null:
		return sp
	sp = get_species("HUMAN")
	if sp != null:
		return sp
	return _ordered_species[0] if not _ordered_species.is_empty() else null

static func get_spawnable_species_weights(stats: Node = null) -> Array[Dictionary]:
	ensure_loaded()
	var entries: Array[Dictionary] = []
	for sp in _ordered_species:
		if sp.can_spawn_randomly(stats):
			var w: float = maxf(0.0, sp.get_spawn_weight(stats))
			if w > 0.0:
				entries.append({"species": sp, "weight": w})
	return entries

static func get_combined_other_species_drinks(exclude_id: String, stats: Node = null) -> Array[String]:
	ensure_loaded()
	var excluded := exclude_id.to_upper().strip_edges()
	var pool: Array[String] = []
	for sp in _ordered_species:
		if sp.species_id == excluded:
			continue
		if not sp.is_unlocked(stats):
			continue
		for drink_id in sp.get_drink_pool(stats):
			if not pool.has(drink_id):
				pool.append(drink_id)
	if pool.is_empty():
		return ["beer", "gin"]
	return pool

static func apply_drink_scoring_hooks(served: DrinkMix, wanted: DrinkOrder, score_data: Dictionary) -> void:
	ensure_loaded()
	for sp in _ordered_species:
		sp.on_score_drink_global(served, wanted, score_data)
	if wanted and wanted.species_id != "":
		var target_sp := get_species(wanted.species_id)
		if target_sp:
			target_sp.on_score_drink(served, wanted, score_data)

static func get_glass_resource_multiplier(glass: Area3D, liquid_id: String = "") -> float:
	ensure_loaded()
	var mult := 1.0
	for sp in _ordered_species:
		mult *= sp.get_glass_resource_multiplier(glass, liquid_id)
	return maxf(0.05, mult)

static func handle_counter_edge_tool(tool_id: String, player: Node3D, main_node: Node3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	for sp in _ordered_species:
		if sp.on_tool_counter_action(normalized_tool, player, main_node):
			return true
	return false

static func handle_glass_tool_click(tool_id: String, glass: Area3D, player: Node3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	for sp in _ordered_species:
		if sp.on_tool_interact_glass(normalized_tool, glass, player):
			return true
	return false

static func handle_npc_tool_click(npc: Sprite3D, tool_id: String, player: Node3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	var primary_sp: SpeciesBase = npc.get("species_def") as SpeciesBase if npc else null
	if primary_sp and primary_sp.on_npc_tool_click(npc, normalized_tool, player):
		return true
	for sp in _ordered_species:
		if sp == primary_sp:
			continue
		if sp.on_npc_tool_click(npc, normalized_tool, player):
			return true
	return false

static func on_ingredient_unlocked(ingredient_key: String, stats: Node = null) -> void:
	ensure_loaded()
	for sp in _ordered_species:
		sp.on_ingredient_unlocked(ingredient_key, stats)

static func get_marketing_unlock_ids(stats: Node = null) -> Array[String]:
	ensure_loaded()
	var ids: Array[String] = []
	for sp in _ordered_species:
		if sp.is_unlocked_for_marketing(stats):
			ids.append(sp.species_id.to_lower())
	return ids