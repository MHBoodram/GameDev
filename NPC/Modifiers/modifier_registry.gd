class_name ModifierRegistry
extends RefCounted

# Auto-discovers every ModifierBase subclass in NPC/Modifiers

const MODIFIERS_DIR := "res://NPC/Modifiers"

static var _initialized: bool = false
static var _modifiers_by_id: Dictionary = {}
static var _ordered_modifiers: Array[ModifierBase] = []

static func ensure_loaded() -> void:
	if _initialized:
		return
	_initialized = true
	_modifiers_by_id.clear()
	_ordered_modifiers.clear()

	for script_path in _discover_modifier_scripts():
		var res = load(script_path)
		if res is GDScript and res.can_instantiate():
			var instance = res.new()
			if instance is ModifierBase:
				var mod := instance as ModifierBase
				var key := mod.modifier_id.to_upper().strip_edges()
				if key != "" and key != "NONE" and not _modifiers_by_id.has(key):
					_modifiers_by_id[key] = mod
					_ordered_modifiers.append(mod)

	_ordered_modifiers.sort_custom(func(a: ModifierBase, b: ModifierBase) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.modifier_id < b.modifier_id
	)

static func reload() -> void:
	_initialized = false
	ensure_loaded()

static func _discover_modifier_scripts() -> Array[String]:
	var found: Array[String] = []
	var filenames: PackedStringArray = PackedStringArray()

	if ResourceLoader.has_method("list_directory"):
		filenames = ResourceLoader.list_directory(MODIFIERS_DIR)

	if filenames.is_empty():
		var dir := DirAccess.open(MODIFIERS_DIR)
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
		if clean_name == "modifier_base.gd" or clean_name == "modifier_registry.gd":
			continue
		var full_path := MODIFIERS_DIR + "/" + clean_name
		if not found.has(full_path):
			found.append(full_path)

	return found

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

static func apply_drink_scoring_hooks(served: DrinkMix, wanted: DrinkOrder, score_data: Dictionary) -> void:
	ensure_loaded()
	for proto in _ordered_modifiers:
		proto.on_score_drink_global(served, wanted, score_data)

static func get_glass_resource_multiplier(glass: Area3D, liquid_id: String = "") -> float:
	ensure_loaded()
	var mult := 1.0
	for proto in _ordered_modifiers:
		mult *= proto.get_glass_resource_multiplier(glass, liquid_id)
	return maxf(0.05, mult)

static func handle_counter_edge_tool(tool_id: String, player: Node3D, main_node: Node3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	for proto in _ordered_modifiers:
		if proto.on_tool_counter_action(normalized_tool, player, main_node):
			return true
	return false

static func handle_glass_tool_click(tool_id: String, glass: Area3D, player: Node3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
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
	return false

static func can_highlight_glass(tool_id: String, glass: Area3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	for proto in _ordered_modifiers:
		var verdict := proto.can_highlight_glass(normalized_tool, glass)
		if verdict != -1:
			return verdict == 1
	return true

static func handle_npc_tool_click(npc: Sprite3D, tool_id: String, player: Node3D) -> bool:
	ensure_loaded()
	var normalized_tool := tool_id.to_lower().strip_edges()
	var npc_mod: ModifierBase = npc.get("modifier") as ModifierBase if npc else null
	if npc_mod and npc_mod.on_npc_tool_click(npc, normalized_tool, player):
		return true
	for proto in _ordered_modifiers:
		if npc_mod and proto.get_script() == npc_mod.get_script():
			continue
		if proto.on_npc_tool_click(npc, normalized_tool, player):
			return true
	return false