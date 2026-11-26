class_name NPCCharacterBase
extends RefCounted

# All NPCs, script characters etc. inherit from this class

enum NightPhase { BEFORE_NIGHT, DURING_NIGHT, AFTER_NIGHT }

var npc_id: String = ""
var display_name: String = ""
var species_id: String = "HUMAN"
var is_named: bool = true
var is_default_for_species: bool = false
var sort_order: int = 100

var can_spawn_randomly: bool = false
var spawn_weight: float = 1.0
var min_night: int = 1
var max_night: int = 999

var npc_resource_path: String = ""
var sprite_sheet_path: String = ""
var sprite_sheet: Texture2D = null
var hframes: int = -1
var vframes: int = 1
var npc_scale: Vector3 = Vector3.ZERO
var seat_y_offset: float = 0.0
var seat_offset: Vector3 = Vector3.ZERO
var patience_y_offset: float = 0.0
var patience_offset: Vector3 = Vector3.ZERO
var tint: Color = Color.WHITE
var flip_h: bool = false

var logo_frame: int = -1
var icon_texture_path: String = ""
var icon_texture: Texture2D = null

# Expression map: {"happy": 2} or {"happy": {"closed": 2, "open": 3}} or {"rage": {"texture": "res://...", "frame": 0}}
var expressions: Dictionary = {}
# Alternate spritesheets/textures: {"monster": {"texture": "res://...", "hframes": 4, "vframes": 1, "expressions": {...}}}
var sprite_variants: Dictionary = {}
# Optional visual/stat variations for unnamed default NPCs
var random_variants: Array[Dictionary] = []

var dialogue_path: String = ""
var dialogue_resource: DialogueResource = null
var default_dialogue_title: String = "start"
var next_order_title: String = "next_order"
var waiting_title: String = "mid"
var positive_title: String = "Positive"
var mid_title: String = "Mid"
var negative_title: String = "Negative"
var afternight_title: String = "afternight_1"

var patience_time: float = -1.0
var talk_only: bool = false
var leave_on_timeout: bool = true

var can_be_ghost: bool = true
var disallowed_modifiers: Array[String] = []
var custom_drink_pool: Array[String] = []
var default_order_count: int = -1

var appearances: Array[Dictionary] = []

var _cached_npc_resource: NPC = null
var _cached_dialogue_resource: DialogueResource = null

func create_instance() -> NPCCharacterBase:
	var script_res: Script = get_script()
	if script_res and script_res.can_instantiate():
		return script_res.new() as NPCCharacterBase
	return NPCCharacterBase.new()

func add_appearance(phase: int, night_num: int = -1, dialogue_title: String = "", trigger_time: float = 0.0, options: Dictionary = {}) -> void:
	var resolved_title := dialogue_title
	if resolved_title == "":
		resolved_title = afternight_title if phase == NightPhase.AFTER_NIGHT else default_dialogue_title
	appearances.append({
		"phase": phase,
		"night": night_num,
		"dialogue_title": resolved_title,
		"trigger_time": trigger_time,
		"options": options.duplicate(true)
	})

func is_unlocked(_stats: Node = null) -> bool:
	return true

func can_spawn_on_night(night: int, stats: Node = null) -> bool:
	if not can_spawn_randomly:
		return false
	if night < min_night or night > max_night:
		return false
	return is_unlocked(stats)

func can_appear(_night: int, _phase: int, _stats: Node = null) -> bool:
	return true

func can_accept_modifier(modifier_id: String) -> bool:
	var normalized := modifier_id.to_upper().strip_edges()
	for blocked in disallowed_modifiers:
		if blocked.to_upper().strip_edges() == normalized:
			return false
	if normalized == "GHOST" and not can_be_ghost:
		return false
	return true

func get_speaker_name(species_def: SpeciesBase = null) -> String:
	if display_name.strip_edges() != "":
		return display_name
	if species_def and species_def.display_name.strip_edges() != "":
		return species_def.display_name
	var sp := SpeciesRegistry.get_species_or_default(species_id)
	if sp and sp.display_name.strip_edges() != "":
		return sp.display_name
	return "Patron"

func get_loaded_npc_resource() -> NPC:
	if _cached_npc_resource != null:
		return _cached_npc_resource
	if npc_resource_path != "" and ResourceLoader.exists(npc_resource_path):
		var loaded = load(npc_resource_path)
		if loaded is NPC:
			_cached_npc_resource = loaded as NPC
			return _cached_npc_resource
	return null

func get_sprite_sheet(species_def: SpeciesBase = null) -> Texture2D:
	if sprite_sheet != null:
		return sprite_sheet
	if sprite_sheet_path != "" and ResourceLoader.exists(sprite_sheet_path):
		return load(sprite_sheet_path) as Texture2D
	var res_npc := get_loaded_npc_resource()
	if res_npc and res_npc.sprite_sheet != null:
		return res_npc.sprite_sheet
	var sp := species_def if species_def != null else SpeciesRegistry.get_species_or_default(species_id)
	if sp:
		var sp_res := sp.get_npc_resource()
		if sp_res and sp_res.sprite_sheet != null:
			return sp_res.sprite_sheet
		if sp.fallback_texture_path != "" and ResourceLoader.exists(sp.fallback_texture_path):
			return load(sp.fallback_texture_path) as Texture2D
	return null

func get_effective_hframes(species_def: SpeciesBase = null) -> int:
	if hframes > 0:
		return hframes
	var res_npc := get_loaded_npc_resource()
	if res_npc and res_npc.hframe > 0:
		return res_npc.hframe
	var sp := species_def if species_def != null else SpeciesRegistry.get_species_or_default(species_id)
	if sp:
		var sp_res := sp.get_npc_resource()
		if sp_res and sp_res.hframe > 0:
			return sp_res.hframe
		return maxi(1, sp.fallback_hframes)
	return 1

func get_effective_vframes() -> int:
	var res_npc := get_loaded_npc_resource()
	if vframes > 0:
		if vframes == 1 and res_npc and "vframe" in res_npc and int(res_npc.get("vframe")) > 1:
			return int(res_npc.get("vframe"))
		return vframes
	return 1

func get_effective_patience(species_def: SpeciesBase = null) -> float:
	if patience_time > 0.0:
		return patience_time
	var res_npc := get_loaded_npc_resource()
	if res_npc and res_npc.patience_time > 0.0:
		return res_npc.patience_time
	var sp := species_def if species_def != null else SpeciesRegistry.get_species_or_default(species_id)
	if sp and sp.default_patience > 0.0:
		return sp.default_patience
	return 90.0

func get_effective_scale(species_def: SpeciesBase = null) -> Vector3:
	if npc_scale != Vector3.ZERO:
		return npc_scale
	var res_npc := get_loaded_npc_resource()
	if res_npc and "npc_scale" in res_npc:
		var res_scale: Variant = res_npc.get("npc_scale")
		if res_scale is Vector3 and (res_scale as Vector3) != Vector3.ZERO:
			return res_scale as Vector3
	var sp := species_def if species_def != null else SpeciesRegistry.get_species_or_default(species_id)
	if sp:
		return sp.npc_scale
	return Vector3(0.5, 0.5, 0.5)

func get_effective_seat_offset(species_def: SpeciesBase = null) -> Vector3:
	if seat_offset != Vector3.ZERO or not is_zero_approx(seat_y_offset):
		return Vector3(seat_offset.x, seat_offset.y + seat_y_offset, seat_offset.z)
	var sp := species_def if species_def != null else SpeciesRegistry.get_species_or_default(species_id)
	return sp.get_seat_offset() if sp else Vector3.ZERO

func get_effective_patience_offset(species_def: SpeciesBase = null) -> Vector3:
	if patience_offset != Vector3.ZERO or not is_zero_approx(patience_y_offset):
		return Vector3(patience_offset.x, patience_offset.y + patience_y_offset, patience_offset.z)
	var sp := species_def if species_def != null else SpeciesRegistry.get_species_or_default(species_id)
	return sp.get_patience_offset() if sp else Vector3.ZERO

func get_effective_seat_y_offset(species_def: SpeciesBase = null) -> float:
	return get_effective_seat_offset(species_def).y

func get_effective_logo_frame(species_def: SpeciesBase = null) -> int:
	if logo_frame >= 0:
		return logo_frame
	var res_npc := get_loaded_npc_resource()
	if res_npc and "logo_frame" in res_npc and int(res_npc.get("logo_frame")) >= 0:
		return int(res_npc.get("logo_frame"))
	var sp := species_def if species_def != null else SpeciesRegistry.get_species_or_default(species_id)
	return sp.logo_frame if sp else -1

func get_icon_texture() -> Texture2D:
	if icon_texture != null:
		return icon_texture
	if icon_texture_path != "" and ResourceLoader.exists(icon_texture_path):
		return load(icon_texture_path) as Texture2D
	var res_npc := get_loaded_npc_resource()
	if res_npc and "icon_texture" in res_npc and res_npc.get("icon_texture") is Texture2D:
		return res_npc.get("icon_texture") as Texture2D
	return null

func get_dialogue_resource(species_def: SpeciesBase = null) -> DialogueResource:
	if dialogue_resource != null:
		return dialogue_resource
	if _cached_dialogue_resource != null:
		return _cached_dialogue_resource
	var res_npc := get_loaded_npc_resource()
	if res_npc and res_npc.dialogue_resource != null:
		_cached_dialogue_resource = res_npc.dialogue_resource
		return _cached_dialogue_resource
	if dialogue_path != "" and ResourceLoader.exists(dialogue_path):
		var loaded = load(dialogue_path)
		if loaded is DialogueResource:
			_cached_dialogue_resource = loaded as DialogueResource
			return _cached_dialogue_resource
	var sp := species_def if species_def != null else SpeciesRegistry.get_species_or_default(species_id)
	if sp and not is_named and sp.has_method("get_fallback_dialogue_resource_for_name"):
		_cached_dialogue_resource = sp.get_fallback_dialogue_resource_for_name(get_speaker_name(sp))
		return _cached_dialogue_resource
	var fallback_text := get_fallback_dialogue_text(species_def)
	if fallback_text != "":
		_cached_dialogue_resource = DialogueManager.create_resource_from_text(fallback_text)
	return _cached_dialogue_resource

func get_fallback_dialogue_text(species_def: SpeciesBase = null) -> String:
	var speaker := get_speaker_name(species_def)
	return """~ start
%s: [[Hi|Hello|Evening]], I'd like {{_current_order_text()}}
do _add_recipt()
set speaking_title = "%s"
=> END
~ next_order
%s: [[Another one|One more]], I want {{_current_order_text()}}
do _add_recipt()
set speaking_title = "%s"
=> END
~ mid
%s: Still waiting on my drink!
=> END
~ Positive
set emo = "happy"
%s: Great drink, thanks!
do _give_payment()
=> END
~ Mid
%s: Not bad.
do _give_payment()
=> END
~ Negative
set emo = "mad"
%s: This tastes awful.
do _give_payment()
=> END
~ TimeWarning1
%s: How much longer on that drink?
=> END
~ afternight_1
%s: Good evening.
=> END
""" % [speaker, waiting_title, speaker, waiting_title, speaker, speaker, speaker, speaker, speaker, speaker]

func build_runtime_npc_resource(species_def: SpeciesBase = null) -> NPC:
	var existing := get_loaded_npc_resource()
	var runtime := (existing.duplicate() as NPC) if existing != null else NPC.new()
	runtime.race = species_id if species_id != "" else (existing.race if existing else "HUMAN")
	runtime.sprite_sheet = get_sprite_sheet(species_def)
	runtime.hframe = get_effective_hframes(species_def)
	runtime.patience_time = get_effective_patience(species_def)
	runtime.dialogue_resource = get_dialogue_resource(species_def)
	if "npc_id" in runtime:
		runtime.set("npc_id", npc_id)
	if "display_name" in runtime:
		runtime.set("display_name", display_name)
	return runtime

func resolve_variant() -> Dictionary:
	if random_variants.is_empty():
		return {}
	var total_w := 0.0
	for v in random_variants:
		total_w += maxf(0.01, float(v.get("weight", 1.0)))
	var roll := randf_range(0.0, total_w)
	var acc := 0.0
	for v in random_variants:
		acc += maxf(0.01, float(v.get("weight", 1.0)))
		if roll <= acc:
			return v.duplicate(true)
	return (random_variants[0] as Dictionary).duplicate(true)

func resolve_expression(expr_name: String, open_mouth: bool, total_hframes: int, total_vframes: int, active_expressions: Dictionary = {}) -> Dictionary:
	var total_frames := maxi(1, total_hframes * total_vframes)
	var key := expr_name.to_lower().strip_edges()
	var lookup_keys: Array[String] = [key]
	if key == "neutral" or key == "netural" or key == "default" or key == "idle":
		lookup_keys = [key, "neutral", "netural", "default", "idle"]
	elif key == "mad" or key == "angry":
		lookup_keys = [key, "mad", "angry"]

	var active_map: Dictionary = active_expressions if not active_expressions.is_empty() else expressions
	var matched_val: Variant = null
	for candidate in lookup_keys:
		for map_key in active_map.keys():
			if str(map_key).to_lower().strip_edges() == candidate:
				matched_val = active_map[map_key]
				break
		if matched_val != null:
			break

	var out_tex: Texture2D = null
	var out_hframes: int = -1
	var out_vframes: int = -1
	var target_frame: int = 0

	if matched_val is int:
		var base_f := int(matched_val)
		var mouth_off := 1 if (open_mouth and total_hframes > 1 and base_f + 1 < total_frames) else 0
		target_frame = base_f + mouth_off
	elif matched_val is Dictionary:
		var d: Dictionary = matched_val
		if d.has("texture") and d["texture"] is Texture2D:
			out_tex = d["texture"] as Texture2D
		elif d.has("texture_path") and ResourceLoader.exists(str(d["texture_path"])):
			out_tex = load(str(d["texture_path"])) as Texture2D
		if d.has("hframes"):
			out_hframes = int(d["hframes"])
		if d.has("vframes"):
			out_vframes = int(d["vframes"])
		var eff_h := out_hframes if out_hframes > 0 else total_hframes
		var eff_v := out_vframes if out_vframes > 0 else total_vframes
		var eff_total := maxi(1, eff_h * eff_v)
		var closed_f := int(d.get("closed", d.get("frame", 0)))
		var default_off := 1 if eff_h > 1 else 0
		var mouth_off := int(d.get("mouth_offset", default_off))
		var open_f := int(d.get("open", closed_f + mouth_off))
		if open_f >= eff_total:
			open_f = closed_f
		target_frame = open_f if open_mouth else closed_f
		target_frame = clampi(target_frame, 0, eff_total - 1)
		return {"frame": target_frame, "texture": out_tex, "hframes": out_hframes, "vframes": out_vframes}
	else:
		var base_idx := 0
		match key:
			"netural", "neutral", "default", "idle":
				base_idx = 0
			"happy":
				base_idx = 2
			"mad", "angry":
				base_idx = 4
			"surprised", "alt1":
				base_idx = 6
			"alt2":
				base_idx = 8
			_:
				if key.is_valid_int():
					base_idx = key.to_int()
		var mouth_off := 1 if (open_mouth and total_hframes > 1 and base_idx + 1 < total_frames) else 0
		target_frame = base_idx + mouth_off

	target_frame = clampi(target_frame, 0, total_frames - 1)
	return {"frame": target_frame, "texture": out_tex, "hframes": out_hframes, "vframes": out_vframes}

func get_appearances_for(night: int, phase: int, stats: Node = null) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	if not is_unlocked(stats) or not can_appear(night, phase, stats):
		return matched

	for app in appearances:
		if int(app.get("phase", -1)) != phase:
			continue
		var app_night: int = int(app.get("night", -1))
		var opts: Dictionary = app.get("options", {})
		if app_night != -1 and app_night != night:
			continue
		if opts.has("nights") and opts["nights"] is Array:
			if not (opts["nights"] as Array).has(night):
				continue
		if opts.has("min_night") and night < int(opts["min_night"]):
			continue
		if opts.has("max_night") and night > int(opts["max_night"]):
			continue
		if opts.has("chance") and randf() > clampf(float(opts["chance"]), 0.0, 1.0):
			continue
		if opts.has("condition") and opts["condition"] is Callable:
			var cond := opts["condition"] as Callable
			if cond.is_valid() and not bool(cond.call(night, phase)):
				continue
		var copy := app.duplicate(true)
		copy["character"] = self
		matched.append(copy)
	return matched

func generate_orders(npc: Sprite3D, modifier: RefCounted = null, stats: Node = null) -> Array[DrinkOrder]:
	if custom_drink_pool.is_empty() and default_order_count <= 0:
		return []

	var sp := SpeciesRegistry.get_species_or_default(species_id)
	var pool: Array[String] = custom_drink_pool.duplicate()
	if pool.is_empty() and sp:
		pool = sp.get_drink_pool(stats)
	if pool.is_empty():
		pool = ["gin"]

	var count := default_order_count if default_order_count > 0 else (sp.get_order_count(npc, modifier) if sp else 1)
	if modifier and modifier.has_method("modify_order_count"):
		count = maxi(1, int(modifier.modify_order_count(npc, count)))

	var orders: Array[DrinkOrder] = []
	for _i in range(maxi(1, count)):
		var drink_name := str(pool.pick_random())
		var order := DrinkOrder.new()
		order.species_id = species_id
		order.ingredients[drink_name] = 1.0
		orders.append(order)
	return orders

func on_npc_setup(_npc: Sprite3D) -> void:
	pass

func on_npc_clear(_npc: Sprite3D) -> void:
	pass

func on_npc_process(_npc: Sprite3D, _delta: float) -> void:
	pass

func on_dialogue_started(_npc: Node, _title: String) -> void:
	pass

func on_dialogue_ended(_npc: Node, _title: String) -> void:
	pass

func on_drink_served(_npc: Sprite3D, _mix: DrinkMix, _wanted: DrinkOrder, _score_data: Dictionary) -> void:
	pass

func modify_payout(_npc: Sprite3D, _base_price: float, _is_satisfactory: bool, _drink_score: float, current_payment: float) -> float:
	return current_payment

func modify_tip(_npc: Sprite3D, current_tip: float, _is_satisfactory: bool, _drink_score: float) -> float:
	return current_tip

static func create_default_for_species(sp: SpeciesBase) -> NPCCharacterBase:
	var c := NPCCharacterBase.new()
	var sp_id := sp.species_id if sp else "HUMAN"
	c.npc_id = "default_" + sp_id.to_lower()
	c.display_name = sp.display_name if sp else "Patron"
	c.species_id = sp_id
	c.is_named = false
	c.is_default_for_species = true
	c.can_spawn_randomly = true
	if sp:
		c.npc_resource_path = sp.npc_resource_path
		c.sprite_sheet_path = sp.fallback_texture_path
		c.hframes = sp.fallback_hframes
		c.patience_time = sp.default_patience
		c.npc_scale = sp.npc_scale
		c.seat_y_offset = sp.seat_y_offset
		c.seat_offset = sp.seat_offset
		c.patience_y_offset = sp.patience_y_offset
		c.patience_offset = sp.patience_offset
		c.logo_frame = sp.logo_frame
		c.can_be_ghost = sp.can_be_ghost
		c.disallowed_modifiers = sp.disallowed_modifiers.duplicate()
	return c