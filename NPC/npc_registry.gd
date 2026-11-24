class_name NPCRegistry
extends RefCounted

const CHARACTERS_DIR := "res://NPC/Characters"

static var _initialized: bool = false
static var _characters_by_id: Dictionary = {}
static var _ordered_characters: Array[NPCCharacterBase] = []
static var _characters_by_resource_path: Dictionary = {}
static var _wrapped_resource_cache: Dictionary = {}

static func ensure_loaded() -> void:
	if _initialized:
		return
	_initialized = true
	_characters_by_id.clear()
	_ordered_characters.clear()
	_characters_by_resource_path.clear()

	var loaded: Array[NPCCharacterBase] = []
	for script_path in SpeciesRegistry._discover_scripts(CHARACTERS_DIR, []):
		var res = load(script_path)
		if res is GDScript and res.can_instantiate():
			var inst = res.new()
			if inst is NPCCharacterBase:
				var char_def := inst as NPCCharacterBase
				var key := char_def.npc_id.to_lower().strip_edges()
				if key == "":
					key = script_path.get_file().get_basename().to_lower()
					char_def.npc_id = key
				if not _characters_by_id.has(key):
					_characters_by_id[key] = char_def
					loaded.append(char_def)
					if char_def.npc_resource_path != "":
						_characters_by_resource_path[char_def.npc_resource_path] = char_def

	loaded.sort_custom(func(a: NPCCharacterBase, b: NPCCharacterBase) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.npc_id < b.npc_id
	)
	_ordered_characters = loaded

static func reload() -> void:
	_initialized = false
	_wrapped_resource_cache.clear()
	ensure_loaded()

static func get_all_characters() -> Array[NPCCharacterBase]:
	ensure_loaded()
	var list: Array[NPCCharacterBase] = []
	list.assign(_ordered_characters)
	return list

static func get_character(id_or_name: String) -> NPCCharacterBase:
	ensure_loaded()
	var key := id_or_name.to_lower().strip_edges()
	if key == "":
		return null
	if _characters_by_id.has(key):
		return (_characters_by_id[key] as NPCCharacterBase).create_instance()
	for ch in _ordered_characters:
		if ch.display_name.to_lower().strip_edges() == key:
			return ch.create_instance()
	return null

static func get_characters_for_species(species_id: String, stats: Node = null, random_only: bool = true) -> Array[NPCCharacterBase]:
	ensure_loaded()
	var target_sp := species_id.to_upper().strip_edges()
	var current_night := GameState.night if GameState else 1
	var matches: Array[NPCCharacterBase] = []
	for ch in _ordered_characters:
		if ch.species_id.to_upper().strip_edges() != target_sp:
			continue
		if random_only:
			if not ch.can_spawn_on_night(current_night, stats):
				continue
		elif not ch.is_unlocked(stats):
			continue
		matches.append(ch)
	return matches

static func pick_character_for_species(species_id: String, stats: Node = null) -> NPCCharacterBase:
	var candidates := get_characters_for_species(species_id, stats, true)
	if candidates.is_empty():
		return get_default_character_for_species(species_id, stats)

	var total_weight := 0.0
	for ch in candidates:
		total_weight += maxf(0.0, ch.spawn_weight)
	if total_weight <= 0.0:
		return candidates[0].create_instance()

	var roll := randf_range(0.0, total_weight)
	var acc := 0.0
	for ch in candidates:
		acc += maxf(0.0, ch.spawn_weight)
		if roll <= acc:
			return ch.create_instance()
	return candidates[0].create_instance()

static func get_default_character_for_species(species_id: String, stats: Node = null) -> NPCCharacterBase:
	ensure_loaded()
	var target_sp := species_id.to_upper().strip_edges()
	var named_default: NPCCharacterBase = null
	for ch in _ordered_characters:
		if ch.species_id.to_upper().strip_edges() != target_sp:
			continue
		if not ch.is_unlocked(stats):
			continue
		if ch.is_default_for_species:
			if not ch.is_named:
				return ch.create_instance()
			if named_default == null:
				named_default = ch
	if named_default != null:
		return named_default.create_instance()
	return create_unnamed_default(species_id)

static func create_unnamed_default(species_id: String) -> NPCCharacterBase:
	var sp := SpeciesRegistry.get_species_or_default(species_id)
	return NPCCharacterBase.create_default_for_species(sp)

static func from_npc_resource(npc_res: NPC) -> NPCCharacterBase:
	ensure_loaded()
	if npc_res == null:
		return create_unnamed_default("HUMAN")

	var res_path := npc_res.resource_path
	if res_path != "" and _characters_by_resource_path.has(res_path):
		return (_characters_by_resource_path[res_path] as NPCCharacterBase).create_instance()

	if "npc_id" in npc_res and str(npc_res.get("npc_id")).strip_edges() != "":
		var existing := get_character(str(npc_res.get("npc_id")))
		if existing != null:
			return existing

	var cache_key := res_path if res_path != "" else str(npc_res.get_instance_id())
	if _wrapped_resource_cache.has(cache_key):
		return (_wrapped_resource_cache[cache_key] as NPCCharacterBase).create_instance()

	var ch := NPCCharacterBase.new()
	ch.species_id = npc_res.race if npc_res.race != "" else "HUMAN"
	ch.npc_id = str(npc_res.get("npc_id")) if "npc_id" in npc_res and str(npc_res.get("npc_id")) != "" else (res_path.get_file().get_basename().to_lower() if res_path != "" else "resource_npc")
	ch.display_name = str(npc_res.get("display_name")) if "display_name" in npc_res else ""
	ch.is_named = bool(npc_res.get("is_named")) if "is_named" in npc_res else (ch.display_name != "")
	ch.sprite_sheet = npc_res.sprite_sheet
	ch.hframes = npc_res.hframe
	ch.vframes = int(npc_res.get("vframe")) if "vframe" in npc_res and int(npc_res.get("vframe")) > 0 else 1
	ch.dialogue_resource = npc_res.dialogue_resource
	ch.patience_time = npc_res.patience_time
	if "expressions" in npc_res and npc_res.get("expressions") is Dictionary:
		ch.expressions = (npc_res.get("expressions") as Dictionary).duplicate(true)
	if "icon_texture" in npc_res and npc_res.get("icon_texture") is Texture2D:
		ch.icon_texture = npc_res.get("icon_texture") as Texture2D
	if "logo_frame" in npc_res:
		ch.logo_frame = int(npc_res.get("logo_frame"))
	if "npc_scale" in npc_res and npc_res.get("npc_scale") is Vector3:
		ch.npc_scale = npc_res.get("npc_scale") as Vector3
	if "seat_y_offset" in npc_res:
		ch.seat_y_offset = float(npc_res.get("seat_y_offset"))
	if res_path != "":
		ch.npc_resource_path = res_path
		_wrapped_resource_cache[cache_key] = ch
	return ch

static func get_scheduled_appearances(night: int, phase: int, stats: Node = null) -> Array[Dictionary]:
	ensure_loaded()
	var result: Array[Dictionary] = []
	for ch in _ordered_characters:
		var entries := ch.get_appearances_for(night, phase, stats)
		for entry in entries:
			entry["character"] = ch.create_instance()
			result.append(entry)

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var opts_a: Dictionary = a.get("options", {})
		var opts_b: Dictionary = b.get("options", {})
		var prio_a := int(opts_a.get("priority", 0))
		var prio_b := int(opts_b.get("priority", 0))
		if prio_a != prio_b:
			return prio_a > prio_b
		var time_a := float(a.get("trigger_time", 0.0))
		var time_b := float(b.get("trigger_time", 0.0))
		if not is_equal_approx(time_a, time_b):
			return time_a < time_b
		var sort_a := int(opts_a.get("sort_order", (a["character"] as NPCCharacterBase).sort_order))
		var sort_b := int(opts_b.get("sort_order", (b["character"] as NPCCharacterBase).sort_order))
		return sort_a < sort_b
	)
	return result