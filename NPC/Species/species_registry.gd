class_name SpeciesRegistry
extends RefCounted

# Detects every SpeciesBase subclass in NPC/Species and every ModifierBase subclass in NPC/Modifiers
# Calls species and modifier functions

const SPECIES_DIR := "res://NPC/Species"
const MODIFIERS_DIR := "res://NPC/Modifiers"

static var _initialized: bool = false
static var _species_by_id: Dictionary = {}
static var _ordered_species: Array[SpeciesBase] = []
static var _modifiers_by_id: Dictionary = {}
static var _ordered_modifiers: Array[ModifierBase] = []

static func ensure_loaded() -> void:
	if _initialized:
		return
	_initialized = true
	_species_by_id.clear()
	_ordered_species.clear()
	_modifiers_by_id.clear()
	_ordered_modifiers.clear()

	_ordered_species.assign(_load_registry_entries(
		SPECIES_DIR,
		["species_base.gd", "species_registry.gd"],
		"species_id",
		_species_by_id,
		func(inst) -> bool: return inst is SpeciesBase
	))

	_ordered_modifiers.assign(_load_registry_entries(
		MODIFIERS_DIR,
		["modifier_base.gd", "modifier_registry.gd"],
		"modifier_id",
		_modifiers_by_id,
		func(inst) -> bool: return inst is ModifierBase,
		["NONE"]
	))

static func _load_registry_entries(dir_path: String, excluded_files: Array[String], id_prop: String, by_id: Dictionary, type_check: Callable, ignored_ids: Array[String] = []) -> Array:
	var loaded: Array = []
	for script_path in _discover_scripts(dir_path, excluded_files):
		var res = load(script_path)
		if res is GDScript and res.can_instantiate():
			var instance = res.new()
			if type_check.call(instance):
				var key := str(instance.get(id_prop)).to_upper().strip_edges()
				if key != "" and not ignored_ids.has(key) and not by_id.has(key):
					by_id[key] = instance
					loaded.append(instance)

	loaded.sort_custom(func(a, b) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return str(a.get(id_prop)) < str(b.get(id_prop))
	)
	return loaded

static func reload() -> void:
	_initialized = false
	ensure_loaded()

static func _discover_scripts(dir_path: String, excluded_files: Array[String]) -> Array[String]:
	var found: Array[String] = []
	var filenames: PackedStringArray = PackedStringArray()

	if ResourceLoader.has_method("list_directory"):
		filenames = ResourceLoader.list_directory(dir_path)

	if filenames.is_empty():
		var dir := DirAccess.open(dir_path)
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
		if excluded_files.has(clean_name):
			continue
		var full_path := dir_path + "/" + clean_name
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

static func get_all_modifiers() -> Array[ModifierBase]:
	ensure_loaded()
	var list: Array[ModifierBase] = []
	list.assign(_ordered_modifiers)
	return list

static func get_modifier(mod_name: String) -> ModifierBase:
	ensure_loaded()
	var key := mod_name.to_upper().strip_edges()
	if _modifiers_by_id.has(key):
		return _modifiers_by_id[key] as ModifierBase
	for mod in _ordered_modifiers:
		if mod.display_name.to_upper() == key:
			return mod
	return null

static func roll_modifier(species_id: String, is_unique: bool = false, stats: Node = null) -> ModifierBase:
	ensure_loaded()
	if is_unique:
		return ModifierBase.new()
	for proto in _ordered_modifiers:
		if proto.can_apply_to_species(species_id, is_unique, stats):
			var chance := clampf(proto.get_spawn_chance(species_id, stats), 0.0, 1.0)
			if chance > 0.0 and randf() < chance:
				return proto.create_instance()
	return ModifierBase.new()

static func create_modifier_for_species(mod_name: String, species_id: String, is_unique: bool = false, stats: Node = null) -> ModifierBase:
	ensure_loaded()
	var proto := get_modifier(mod_name)
	if proto and proto.can_apply_to_species(species_id, is_unique, stats):
		return proto.create_instance()
	return ModifierBase.new()

static func clear_npc_visuals(npc: Sprite3D) -> void:
	ensure_loaded()
	for proto in _ordered_modifiers:
		proto.on_npc_clear(npc)
	for sp in _ordered_species:
		sp.on_npc_clear(npc)

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
	for proto in _ordered_modifiers:
		proto.on_score_drink_global(served, wanted, score_data)

static func get_glass_resource_multiplier(glass: Area3D, liquid_id: String = "") -> float:
	ensure_loaded()
	var sp_mult := 1.0
	for sp in _ordered_species:
		sp_mult *= sp.get_glass_resource_multiplier(glass, liquid_id)
	var mod_mult := 1.0
	for proto in _ordered_modifiers:
		mod_mult *= proto.get_glass_resource_multiplier(glass, liquid_id)
	return maxf(0.05, maxf(0.05, sp_mult) * maxf(0.05, mod_mult))

static func handle_counter_edge_tool(tool_id: String, player: Node3D, main_node: Node3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	for sp in _ordered_species:
		if sp.on_tool_counter_action(normalized_tool, player, main_node):
			return true
	for proto in _ordered_modifiers:
		if proto.on_tool_counter_action(normalized_tool, player, main_node):
			return true
	return false

static func handle_world_tool_click(tool_id: String, player: Node3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	for sp in _ordered_species:
		if sp.on_tool_world_click(normalized_tool, player):
			return true
	return false

static func handle_glass_tool_click(tool_id: String, glass: Area3D, player: Node3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	for sp in _ordered_species:
		if sp.on_tool_interact_glass(normalized_tool, glass, player):
			return true
	for proto in _ordered_modifiers:
		if proto.on_tool_interact_glass(normalized_tool, glass, player):
			return true
	return false

static func should_consume_glass_click(tool_id: String, glass: Area3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	for proto in _ordered_modifiers:
		if proto.should_consume_glass_click(normalized_tool, glass):
			return true
	for sp in _ordered_species:
		if sp.should_consume_glass_click(normalized_tool, glass):
			return true
	return false

static func can_highlight_glass(tool_id: String, glass: Area3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	for proto in _ordered_modifiers:
		var mod_verdict := proto.can_highlight_glass(normalized_tool, glass)
		if mod_verdict != -1:
			return mod_verdict == 1
	for sp in _ordered_species:
		var sp_verdict := sp.can_highlight_glass(normalized_tool, glass)
		if sp_verdict != -1:
			return sp_verdict == 1
	return true

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
	var npc_mod: ModifierBase = npc.get("modifier") as ModifierBase if npc else null
	if npc_mod and npc_mod.on_npc_tool_click(npc, normalized_tool, player):
		return true
	for proto in _ordered_modifiers:
		if npc_mod and proto.get_script() == npc_mod.get_script():
			continue
		if proto.on_npc_tool_click(npc, normalized_tool, player):
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