class_name HudIndicators
extends Control

const INDICATOR_FONT: Font = preload("res://Assets/Font/Merchant Copy.ttf")
const LIQUIDS_LABEL_SCENE: PackedScene = preload("res://UI/Gameplay_ui/liquids_label.tscn")

const INCREASE_COLOR: Color = Color(0.28, 0.96, 0.36, 1.0)
const DECREASE_COLOR: Color = Color(1.0, 0.25, 0.25, 1.0)
const OK_COLOR: Color = Color(1.0, 0.82, 0.24, 1.0)
const PERFECT_COLOR: Color = Color(0.38, 0.94, 1.0, 1.0)
const CLEAN_COLOR: Color = Color(0.55, 0.92, 1.0, 1.0)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.75)

const DEFAULT_HIGHLIGHT_GLOW_COLOR: Color = Color(1.0, 0.96, 0.55, 1.0)
const GARNISH_HUD_COLORS: Dictionary = {
	"lemon_whole": Color(1.0, 0.92, 0.25, 1.0),
	"lemon_half": Color(1.0, 0.92, 0.25, 1.0),
	"lemon_sliced": Color(1.0, 0.92, 0.25, 1.0),
	"herb": Color(0.28, 0.9, 0.38, 1.0),
	"cherry": Color(0.96, 0.22, 0.3, 1.0),
	"olive": Color(0.6, 0.82, 0.24, 1.0),
	"ice": Color(0.68, 0.94, 1.0, 1.0),
	"ice_ball": Color(0.68, 0.94, 1.0, 1.0),
}

const COMBO_COMPONENT_COLOR: Color = Color(1.0, 0.82, 0.24, 1.0)
const COMBO_FINAL_COLOR: Color = Color(1.0, 0.62, 0.16, 1.0)
const COMBO_INITIAL_DELAY: float = 0.0
const COMBO_COMPONENT_DELAY: float = 0.35
const COMBO_FINAL_DELAY: float = 0.35
const COMBO_DURATION: float = 1.45
const COMBO_FLOAT_DISTANCE: float = 64.0
const COMBO_COMPONENT_FONT_SIZE: int = 44
const COMBO_FINAL_FONT_SIZE: int = 56
const COMBO_COMPONENT_SCALE_PUNCH: float = 1.28
const COMBO_FINAL_SCALE_PUNCH: float = 1.48

const SCORE_THRESHOLD_PERFECT: float = 0.95
const SCORE_THRESHOLD_GOOD: float = 0.85
const SCORE_THRESHOLD_OK: float = 0.65

const DEFAULT_FONT_SIZE: int = 50
const DEFAULT_OUTLINE_SIZE: int = 8
const DEFAULT_FLOAT_DISTANCE: float = 64.0
const DEFAULT_DURATION: float = 1.45
const DEFAULT_SCALE_PUNCH: float = 1.28

static var current: HudIndicators = null

var _channels: Dictionary = {}
var _active_floating_groups: Dictionary = {}
var _status_groups: Dictionary = {}
var _fallback_visual_helper: LiquidVisualHelper = LiquidVisualHelper.new()

var _serve_combo_box: VBoxContainer = null
var _serve_combo_label: Label = null
var _serve_combo_bar: ProgressBar = null
var _serve_combo_fill_style: StyleBoxFlat = null
var _serve_combo_fade_tween: Tween = null
var _serve_combo_punch_tween: Tween = null
var _last_serve_combo_streak: int = 0

static func get_current() -> HudIndicators:
	if is_instance_valid(current) and current.is_inside_tree():
		return current
	if is_instance_valid(GameState.gameplay_ui):
		var found = GameState.gameplay_ui.get("hud_indicators")
		if is_instance_valid(found) and found is HudIndicators:
			return found
	return null

static func format_number(value: float, currency_decimals: bool = false) -> String:
	var abs_val: float = absf(value)
	var rounded: float = roundf(abs_val)
	if absf(abs_val - rounded) < 0.005:
		return str(int(rounded))
	if currency_decimals:
		return "%.2f" % snappedf(abs_val, 0.01)
	var tenths: float = snappedf(abs_val, 0.1)
	if absf(abs_val - tenths) < 0.005:
		return "%.1f" % tenths
	return "%.2f" % snappedf(abs_val, 0.01)

static func get_garnish_display_name(garnish_id: String) -> String:
	var clean_id := GarnishDefinitions.normalize_id(garnish_id)
	var def := GarnishDefinitions.get_definition(clean_id)
	var raw_name := str(def.get("display_name", ""))
	if raw_name != "":
		return raw_name
	return clean_id.replace("_", " ").capitalize()

static func get_garnish_hud_color(garnish_id: String) -> Color:
	var clean_id := GarnishDefinitions.normalize_id(garnish_id)
	return GARNISH_HUD_COLORS.get(clean_id, Color(0.95, 0.95, 0.95, 1.0)) as Color

static func build_mix_ingredient_entries(
	mix: DrinkMix,
	liquids: Array = [],
	glass_size: float = 1.0,
	visual_helper: LiquidVisualHelper = null,
	highlighted_layer_idx: int = -1
) -> Array[Dictionary]:
	var helper: LiquidVisualHelper = visual_helper if visual_helper else LiquidVisualHelper.new()
	var has_tint: bool = helper._visual_override.has("liquid_tint_color")
	var tint_col: Color = helper._visual_override.get("liquid_tint_color", Color.WHITE)
	var tint_mix: float = float(helper._visual_override.get("liquid_tint_strength", 0.35))

	var entries: Array[Dictionary] = []
	var eff_size := maxf(glass_size, 0.001)

	if not liquids.is_empty():
		var sorted_indices: Array[int] = []
		for i in liquids.size():
			var l = liquids[i]
			if l is Array and l.size() >= 2 and float(l[1]) > 0.0001:
				sorted_indices.append(i)
		sorted_indices.sort_custom(func(a: int, b: int) -> bool:
			var ba := LiquidVisualHelper.get_layer_buoyancy(liquids[a])
			var bb := LiquidVisualHelper.get_layer_buoyancy(liquids[b])
			if is_equal_approx(ba, bb):
				return a < b
			return ba < bb
		)
		for idx_pos in range(sorted_indices.size() - 1, -1, -1):
			var orig_idx := sorted_indices[idx_pos]
			var layer = liquids[orig_idx]
			var amt := float(layer[1])
			var col: Color = helper.get_layer_color(layer)
			if has_tint:
				col = col.lerp(tint_col, tint_mix)
			var layer_name: String = helper.format_layer_name(layer[0])
			var pct: float = (amt / eff_size) * 100.0
			entries.append({
				"text": layer_name + ": " + str(snappedf(pct, 0.1)) + "%",
				"color": col,
				"highlighted": orig_idx == highlighted_layer_idx,
				"highlight_color": DEFAULT_HIGHLIGHT_GLOW_COLOR,
			})
	elif mix != null and not mix.is_empty():
		var ref_cap := mix.cup_capacity if mix.cup_capacity > 0.001 else eff_size
		var ing_entries: Array[Dictionary] = []
		var idx := 0
		for ing_id in mix.ingredients.keys():
			var amt := float(mix.ingredients[ing_id])
			if amt <= 0.001:
				continue
			ing_entries.append({
				"id": str(ing_id),
				"amt": amt,
				"buoy": AtomicFluidShaders.get_liquid_buoyancy(str(ing_id)),
				"orig_idx": idx,
			})
			idx += 1
		ing_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ba := float(a["buoy"])
			var bb := float(b["buoy"])
			if is_equal_approx(ba, bb):
				return int(a["orig_idx"]) > int(b["orig_idx"])
			return ba > bb
		)
		for item in ing_entries:
			var ing_name := str(item["id"])
			var amt := float(item["amt"])
			var col := LiquidVisualHelper.get_liquid_color(ing_name)
			if has_tint:
				col = col.lerp(tint_col, tint_mix)
			var pct: float = (amt / maxf(ref_cap, 0.001)) * 100.0
			entries.append({
				"text": ing_name + ": " + str(snappedf(pct, 0.1)) + "%",
				"color": col,
				"highlighted": int(item["orig_idx"]) == highlighted_layer_idx,
				"highlight_color": DEFAULT_HIGHLIGHT_GLOW_COLOR,
			})

	if mix != null:
		var garnish_order: Array[String] = []
		var garnish_counts: Dictionary = {}
		for raw_g in mix.garnishes:
			var clean_g := GarnishDefinitions.normalize_id(str(raw_g))
			if clean_g == "":
				continue
			if not garnish_counts.has(clean_g):
				garnish_counts[clean_g] = 0
				garnish_order.append(clean_g)
			garnish_counts[clean_g] = int(garnish_counts[clean_g]) + 1

		for g_id in garnish_order:
			var count := int(garnish_counts[g_id])
			var g_col := get_garnish_hud_color(g_id)
			entries.append({
				"text": get_garnish_display_name(g_id) + " x" + str(count),
				"color": g_col,
				"secondary_color": g_col.lightened(0.35),
				"highlighted": false,
			})

		if mix.has_ice:
			var ice_col := get_garnish_hud_color("ice")
			entries.append({
				"text": get_garnish_display_name("ice"),
				"color": ice_col,
				"secondary_color": Color.WHITE,
				"highlighted": false,
			})

		if mix.overfill_percent > 0.05:
			entries.append({
				"text": "Spilled!",
				"color": DECREASE_COLOR,
				"secondary_color": DECREASE_COLOR,
				"highlighted": false,
			})

	return entries

static func build_cup_ingredient_entries(glass: Node, visual_helper: LiquidVisualHelper = null, highlighted_layer_idx: int = -1) -> Array[Dictionary]:
	if not is_instance_valid(glass):
		return []
	var mix: DrinkMix = glass.get("drink_mix") as DrinkMix if "drink_mix" in glass else null
	var raw_liquids: Variant = glass.get("liquids") if "liquids" in glass else []
	var liqs: Array = raw_liquids if raw_liquids is Array else []
	var cup_size: float = float(glass.get("size")) if "size" in glass else 1.0
	var helper: LiquidVisualHelper = visual_helper
	if helper == null and "visual_helper" in glass:
		helper = glass.get("visual_helper") as LiquidVisualHelper
	return build_mix_ingredient_entries(mix, liqs, cup_size, helper, highlighted_layer_idx)

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	_disconnect_player_stats()
	if current == self:
		current = null

func _ready() -> void:
	name = "HudIndicators"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_default_channels()
	_ensure_pouring_group()
	_ensure_serve_combo_ui()
	_connect_player_stats()

func _process(_delta: float) -> void:
	if _status_groups.has("pouring"):
		var pouring_group: Dictionary = _status_groups["pouring"]
		var owner_obj: Variant = pouring_group.get("owner", null)
		if owner_obj != null and not is_instance_valid(owner_obj):
			pouring_group["owner"] = null
			hide_status_group("pouring", null, false, 1.0)

func _register_default_channels() -> void:
	register_channel("drink_score", {
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 4.0,
		"fallback_y": 98.0,
		"font_size": DEFAULT_FONT_SIZE,
		"float_distance": DEFAULT_FLOAT_DISTANCE,
		"duration": DEFAULT_DURATION,
		"scale_punch": 1.32,
		"positive_color": INCREASE_COLOR,
		"negative_color": DECREASE_COLOR
	})
	register_channel("money", {
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 4.0,
		"fallback_y": 98.0,
		"font_size": DEFAULT_FONT_SIZE,
		"float_distance": DEFAULT_FLOAT_DISTANCE,
		"duration": DEFAULT_DURATION,
		"scale_punch": DEFAULT_SCALE_PUNCH,
		"positive_color": INCREASE_COLOR,
		"negative_color": DECREASE_COLOR
	})
	register_channel("overall_rep", {
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 46.0,
		"fallback_y": 140.0,
		"font_size": DEFAULT_FONT_SIZE,
		"float_distance": DEFAULT_FLOAT_DISTANCE,
		"duration": DEFAULT_DURATION,
		"scale_punch": DEFAULT_SCALE_PUNCH,
		"positive_color": INCREASE_COLOR,
		"negative_color": DECREASE_COLOR
	})
	register_channel("species_rep", {
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 46.0,
		"fallback_y": 140.0,
		"font_size": DEFAULT_FONT_SIZE,
		"float_distance": DEFAULT_FLOAT_DISTANCE,
		"duration": DEFAULT_DURATION,
		"scale_punch": DEFAULT_SCALE_PUNCH,
		"positive_color": INCREASE_COLOR,
		"negative_color": DECREASE_COLOR
	})
	register_channel("bonus", {
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 88.0,
		"fallback_y": 182.0,
		"font_size": DEFAULT_FONT_SIZE,
		"float_distance": DEFAULT_FLOAT_DISTANCE,
		"duration": DEFAULT_DURATION,
		"scale_punch": DEFAULT_SCALE_PUNCH,
		"positive_color": INCREASE_COLOR,
		"negative_color": DECREASE_COLOR
	})
	register_channel("combo", {
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 130.0,
		"fallback_y": 224.0,
		"font_size": DEFAULT_FONT_SIZE,
		"float_distance": DEFAULT_FLOAT_DISTANCE,
		"duration": DEFAULT_DURATION,
		"scale_punch": 1.35,
		"positive_color": INCREASE_COLOR,
		"negative_color": DECREASE_COLOR
	})
	register_channel("cup_spill", {
		"stack_group": "cup_feedback",
		"align": "center",
		"font_size": 48,
		"float_distance": 56.0,
		"duration": 1.15,
		"scale_punch": 1.36,
		"positive_color": INCREASE_COLOR,
		"negative_color": DECREASE_COLOR
	})
	register_channel("cup_reset", {
		"stack_group": "cup_feedback",
		"align": "center",
		"font_size": 48,
		"float_distance": DEFAULT_FLOAT_DISTANCE,
		"duration": DEFAULT_DURATION,
		"scale_punch": 1.32,
		"positive_color": CLEAN_COLOR,
		"negative_color": DECREASE_COLOR
	})
	register_channel("default", {
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 46.0,
		"fallback_y": 140.0,
		"font_size": DEFAULT_FONT_SIZE,
		"float_distance": DEFAULT_FLOAT_DISTANCE,
		"duration": DEFAULT_DURATION,
		"scale_punch": DEFAULT_SCALE_PUNCH,
		"positive_color": INCREASE_COLOR,
		"negative_color": DECREASE_COLOR
	})

func register_channel(channel_id: String, config: Dictionary) -> void:
	_channels[channel_id] = config.duplicate(true)

func _connect_player_stats() -> void:
	if not PlayerStats:
		return
	if not PlayerStats.money_changed.is_connected(_on_money_changed):
		PlayerStats.money_changed.connect(_on_money_changed)
	if not PlayerStats.overall_reputation_changed.is_connected(_on_overall_reputation_changed):
		PlayerStats.overall_reputation_changed.connect(_on_overall_reputation_changed)
	if not PlayerStats.species_reputation_changed.is_connected(_on_species_reputation_changed):
		PlayerStats.species_reputation_changed.connect(_on_species_reputation_changed)

func _disconnect_player_stats() -> void:
	if not PlayerStats:
		return
	if PlayerStats.money_changed.is_connected(_on_money_changed):
		PlayerStats.money_changed.disconnect(_on_money_changed)
	if PlayerStats.overall_reputation_changed.is_connected(_on_overall_reputation_changed):
		PlayerStats.overall_reputation_changed.disconnect(_on_overall_reputation_changed)
	if PlayerStats.species_reputation_changed.is_connected(_on_species_reputation_changed):
		PlayerStats.species_reputation_changed.disconnect(_on_species_reputation_changed)

func _on_money_changed(_new_value: float, delta: float) -> void:
	show_money_change(delta)

func _on_overall_reputation_changed(_new_value: float, delta: float) -> void:
	show_overall_rep_change(delta)

func _on_species_reputation_changed(species_name: String, _new_value: float, delta: float) -> void:
	show_species_rep_change(species_name, delta)

func show_drink_score_indicator(drink_score: float, options: Dictionary = {}) -> Label:
	var rating_text: String
	var rating_color: Color
	if drink_score >= SCORE_THRESHOLD_PERFECT:
		rating_text = "Perfect!"
		rating_color = PERFECT_COLOR
	elif drink_score >= SCORE_THRESHOLD_GOOD:
		rating_text = "Good!"
		rating_color = INCREASE_COLOR
	elif drink_score >= SCORE_THRESHOLD_OK:
		rating_text = "Ok"
		rating_color = OK_COLOR
	else:
		rating_text = "Bad!"
		rating_color = DECREASE_COLOR

	var merged: Dictionary = options.duplicate()
	if not merged.has("channel"):
		merged["channel"] = "drink_score"
	return show_floating_text(rating_text, rating_color, merged)

func show_combo_indicators(combo_data: Dictionary, options: Dictionary = {}) -> void:
	if not is_inside_tree():
		return
	var total_combo: float = float(combo_data.get("total_combo", 0.0))
	if total_combo <= 0.0:
		return

	var raw_components: Variant = combo_data.get("components", [])
	var components: Array = raw_components.duplicate(true) if raw_components is Array else []
	if components.is_empty():
		return

	var initial_delay: float = maxf(0.0, float(options.get("initial_delay", COMBO_INITIAL_DELAY)))
	var component_delay: float = maxf(0.0, float(options.get("component_delay", COMBO_COMPONENT_DELAY)))
	var final_delay: float = maxf(0.0, float(options.get("final_delay", COMBO_FINAL_DELAY)))

	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay, false).timeout
		if not is_inside_tree():
			return

	for i in components.size():
		if i > 0 and component_delay > 0.0:
			await get_tree().create_timer(component_delay, false).timeout
			if not is_inside_tree():
				return
		if not (components[i] is Dictionary):
			continue
		var comp: Dictionary = components[i]
		var comp_text: String = str(comp.get("label", ""))
		if comp_text == "":
			continue
		var comp_opts: Dictionary = options.duplicate()
		comp_opts["channel"] = "combo"
		if not comp_opts.has("font_size"):
			comp_opts["font_size"] = COMBO_COMPONENT_FONT_SIZE
		if not comp_opts.has("scale_punch"):
			comp_opts["scale_punch"] = COMBO_COMPONENT_SCALE_PUNCH
		if not comp_opts.has("duration"):
			comp_opts["duration"] = COMBO_DURATION
		if not comp_opts.has("float_distance"):
			comp_opts["float_distance"] = COMBO_FLOAT_DISTANCE
		if not comp_opts.has("jitter_x"):
			comp_opts["jitter_x"] = 0.0
		show_floating_text(comp_text, COMBO_COMPONENT_COLOR, comp_opts)

	if final_delay > 0.0:
		await get_tree().create_timer(final_delay, false).timeout
		if not is_inside_tree():
			return

	var final_text := "x %d%% combo" % roundi(total_combo * 100.0)
	var final_opts: Dictionary = options.duplicate()
	final_opts["channel"] = "combo"
	if not final_opts.has("font_size"):
		final_opts["font_size"] = COMBO_FINAL_FONT_SIZE
	if not final_opts.has("scale_punch"):
		final_opts["scale_punch"] = COMBO_FINAL_SCALE_PUNCH
	if not final_opts.has("duration"):
		final_opts["duration"] = COMBO_DURATION
	if not final_opts.has("float_distance"):
		final_opts["float_distance"] = COMBO_FLOAT_DISTANCE
	if not final_opts.has("jitter_x"):
		final_opts["jitter_x"] = 0.0
	show_floating_text(final_text, COMBO_FINAL_COLOR, final_opts)

func show_money_change(delta: float, suffix: String = "", options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var amount_str: String = format_number(delta, true)
	return show_delta_indicator("money", delta, amount_str + " {coin}" + suffix, options)

func show_overall_rep_change(delta: float, suffix: String = "", options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var amount_str: String = format_number(delta, false)
	return show_delta_indicator("overall_rep", delta, amount_str + " Overall Rep" + suffix, options)

func show_species_rep_change(species_name: String, delta: float, suffix: String = "", options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var display_species: String = species_name.strip_edges()
	var sp := SpeciesRegistry.get_species(display_species)
	if sp:
		display_species = sp.display_name
	elif display_species == "":
		display_species = "Species"
	var amount_str: String = format_number(delta, false)
	var lower_sp := display_species.to_lower()
	var body_text := ""
	if TextIcons.has_icon(lower_sp):
		body_text = amount_str + " {" + lower_sp + "} Rep" + suffix
	else:
		body_text = amount_str + " " + display_species + " Rep" + suffix
	return show_delta_indicator("species_rep", delta, body_text, options)

func show_cup_spill_indicator(glass: Node3D, _spilled_percent: float = 0.0, options: Dictionary = {}) -> Label:
	var vp_size: Vector2 = _get_viewport_size()
	var fallback := Vector2(vp_size.x * 0.5, vp_size.y * 0.35)
	var merged: Dictionary = options.duplicate()
	if not merged.has("channel"):
		merged["channel"] = "cup_spill"
	if not merged.has("anchor") and not merged.has("anchor_resolver"):
		merged["anchor"] = _get_world_anchor(glass, Vector3(0.0, 0.15, 0.0), fallback)
	if not merged.has("stack_group") and is_instance_valid(glass):
		merged["stack_group"] = "cup_" + str(glass.get_instance_id())
	if not merged.has("jitter_x"):
		merged["jitter_x"] = 0.0
	return show_floating_text("Spilling!", DECREASE_COLOR, merged)

func show_cup_empty_indicator(glass: Node3D, options: Dictionary = {}) -> Label:
	var vp_size: Vector2 = _get_viewport_size()
	var fallback := Vector2(vp_size.x * 0.5, vp_size.y * 0.35)
	var merged: Dictionary = options.duplicate()
	if not merged.has("channel"):
		merged["channel"] = "cup_reset"
	if not merged.has("anchor") and not merged.has("anchor_resolver"):
		merged["anchor"] = _get_world_anchor(glass, Vector3(0.0, 0.15, 0.0), fallback)
	if not merged.has("stack_group") and is_instance_valid(glass):
		merged["stack_group"] = "cup_" + str(glass.get_instance_id())
	if not merged.has("jitter_x"):
		merged["jitter_x"] = 0.0
	return show_floating_text("Cup Empty! (Reset)", CLEAN_COLOR, merged)

func show_delta_indicator(channel_id: String, delta: float, formatted_body: String, options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var cfg: Dictionary = _channels.get(channel_id, _channels.get("default", {})).duplicate(true)
	for key in options.keys():
		cfg[key] = options[key]

	var is_positive: bool = delta > 0.0
	var color: Color = cfg.get("positive_color", INCREASE_COLOR) if is_positive else cfg.get("negative_color", DECREASE_COLOR)
	var sign_prefix: String = "+ " if is_positive else "- "
	var merged_options: Dictionary = options.duplicate()
	if not merged_options.has("channel"):
		merged_options["channel"] = channel_id
	return show_floating_text(sign_prefix + formatted_body, color, merged_options)

func show_floating_text(text: String, color: Color = Color.WHITE, options: Dictionary = {}) -> Label:
	if not is_inside_tree() or text == "":
		return null

	var channel_id: String = str(options.get("channel", "default"))
	var cfg: Dictionary = _channels.get(channel_id, _channels.get("default", {})).duplicate(true)
	for key in options.keys():
		cfg[key] = options[key]

	var vp_size: Vector2 = _get_viewport_size()
	var font_size: int = int(cfg.get("font_size", DEFAULT_FONT_SIZE))
	var outline_size: int = int(cfg.get("outline_size", DEFAULT_OUTLINE_SIZE))
	var outline_col: Color = cfg.get("outline_color", OUTLINE_COLOR)
	var float_dist: float = float(cfg.get("float_distance", DEFAULT_FLOAT_DISTANCE))
	var duration: float = maxf(0.2, float(cfg.get("duration", DEFAULT_DURATION)))
	var scale_punch: float = float(cfg.get("scale_punch", DEFAULT_SCALE_PUNCH))
	var delay: float = maxf(0.0, float(cfg.get("delay", 0.0)))
	var align: String = str(cfg.get("align", "right"))
	var stack_group: String = str(cfg.get("stack_group", channel_id))

	var label := _create_styled_label(text, color, font_size, outline_col, outline_size)
	if align == "center":
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TextIcons.apply_to_control(label)
	var label_size: Vector2 = label.get_combined_minimum_size()
	label.size = label_size
	label.pivot_offset = label_size * 0.5

	var anchor: Vector2 = _resolve_anchor(cfg, vp_size)
	var jitter_x: float = float(cfg.get("jitter_x", randf_range(-8.0, 8.0)))

	var spawn_x: float = anchor.x
	if align == "right":
		spawn_x = anchor.x - label_size.x + jitter_x
	elif align == "center":
		spawn_x = anchor.x - label_size.x * 0.5 + jitter_x
	else:
		spawn_x = anchor.x + jitter_x
	spawn_x = clampf(spawn_x, 16.0, maxf(16.0, vp_size.x - label_size.x - 16.0))

	var spawn_y: float = _resolve_stacked_y(stack_group, anchor.y, label_size.y, vp_size)
	label.position = Vector2(spawn_x, spawn_y)
	label.scale = Vector2.ONE * scale_punch
	label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	add_child(label)
	_track_floating_label(stack_group, label)

	var target_y: float = maxf(8.0, spawn_y - float_dist)
	var tween := create_tween().set_parallel(true)
	if delay > 0.0:
		label.visible = false
		tween.tween_callback(func():
			if is_instance_valid(label):
				label.visible = true
		).set_delay(delay)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", target_y, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.45).set_delay(delay + duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		if _active_floating_groups.has(stack_group):
			var arr := _active_floating_groups[stack_group] as Array
			arr.erase(label)
			if arr.is_empty():
				_active_floating_groups.erase(stack_group)
		if is_instance_valid(label):
			label.queue_free()
	)
	return label

func _create_styled_label(text: String, color: Color, font_size: int, outline_col: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("font", INDICATOR_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_col)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 2)
	return label

func _get_viewport_size() -> Vector2:
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return Vector2(1280.0, 720.0)
	return vp_size

func _get_world_anchor(target_node: Node3D, world_offset: Vector3, fallback_anchor: Vector2) -> Vector2:
	if not is_instance_valid(target_node) or not is_inside_tree():
		return fallback_anchor
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(cam):
		return fallback_anchor
	var world_pos: Vector3 = target_node.global_position + world_offset
	if cam.is_position_behind(world_pos):
		return fallback_anchor
	return cam.unproject_position(world_pos)

func _resolve_anchor(cfg: Dictionary, vp_size: Vector2) -> Vector2:
	if cfg.has("anchor") and cfg["anchor"] is Vector2:
		return cfg["anchor"] as Vector2
	var custom_resolver: Variant = cfg.get("anchor_resolver", null)
	if custom_resolver is Callable and (custom_resolver as Callable).is_valid():
		return (custom_resolver as Callable).call(vp_size)

	var parent_node := get_parent()
	var money_node: Control = parent_node.get_node_or_null("Right Container/Money") as Control if parent_node else null
	var right_x: float = vp_size.x - 245.0
	var base_y: float = float(cfg.get("fallback_y", 120.0))
	if is_instance_valid(money_node) and money_node.is_visible_in_tree():
		var money_rect: Rect2 = money_node.get_global_rect()
		right_x = minf(right_x, money_rect.position.x - 18.0)
		base_y = money_rect.end.y + float(cfg.get("y_offset_below_money", 10.0))
	return Vector2(right_x, base_y)

func _resolve_stacked_y(stack_group: String, desired_y: float, label_height: float, vp_size: Vector2) -> float:
	var active: Array = _prune_floating_group(stack_group)
	active.sort_custom(func(a: Control, b: Control) -> bool:
		return a.position.y < b.position.y
	)
	var candidate_y: float = desired_y
	for entry in active:
		var ctrl := entry as Control
		var ey: float = ctrl.position.y
		var eh: float = maxf(ctrl.size.y, label_height) + 4.0
		if candidate_y + label_height + 4.0 > ey and candidate_y < ey + eh:
			candidate_y = ey + eh
	return clampf(candidate_y, 20.0, maxf(20.0, vp_size.y - label_height - 20.0))

func _prune_floating_group(stack_group: String) -> Array:
	var raw: Array = _active_floating_groups.get(stack_group, [])
	var alive: Array = []
	for item in raw:
		if is_instance_valid(item) and item is Control and not (item as Control).is_queued_for_deletion():
			alive.append(item)
	_active_floating_groups[stack_group] = alive
	return alive

func _track_floating_label(stack_group: String, label: Label) -> void:
	var alive: Array = _prune_floating_group(stack_group)
	alive.append(label)
	_active_floating_groups[stack_group] = alive

func _ensure_pouring_group() -> void:
	get_or_create_status_group("pouring", {
		"anchor_preset": Control.PRESET_TOP_RIGHT,
		"offset_left": -261.0,
		"offset_top": 285.0,
		"offset_right": -15.0,
		"offset_bottom": 325.0,
		"grow_horizontal": Control.GROW_DIRECTION_BEGIN
	})

func get_or_create_status_group(group_id: String, layout: Dictionary = {}) -> VBoxContainer:
	if _status_groups.has(group_id):
		var existing: Dictionary = _status_groups[group_id]
		var existing_box := existing.get("container", null) as VBoxContainer
		if is_instance_valid(existing_box):
			return existing_box

	var box := VBoxContainer.new()
	box.name = "StatusGroup_" + group_id.capitalize()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(int(layout.get("anchor_preset", Control.PRESET_TOP_RIGHT)))
	box.offset_left = float(layout.get("offset_left", -261.0))
	box.offset_top = float(layout.get("offset_top", 285.0))
	box.offset_right = float(layout.get("offset_right", -15.0))
	box.offset_bottom = float(layout.get("offset_bottom", 325.0))
	box.grow_horizontal = int(layout.get("grow_horizontal", Control.GROW_DIRECTION_BEGIN))
	box.modulate.a = 0.0
	box.visible = false
	add_child(box)

	_status_groups[group_id] = {
		"container": box,
		"fade_tween": null,
		"owner": null,
		"is_hiding": false,
		"use_wavy": false
	}
	return box

func update_status_group(group_id: String, entries: Array[Dictionary], owner_obj: Object = null, use_wavy_labels: bool = false, layout: Dictionary = {}) -> void:
	if not is_inside_tree():
		return
	if entries.is_empty():
		hide_status_group(group_id, owner_obj, true, 0.0)
		return

	var box := get_or_create_status_group(group_id, layout)
	var group: Dictionary = _status_groups[group_id]
	var fade_tween: Tween = group.get("fade_tween", null) as Tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	group["fade_tween"] = null
	group["owner"] = owner_obj
	group["is_hiding"] = false

	var was_wavy: bool = bool(group.get("use_wavy", false))
	var children := box.get_children()
	if children.size() != entries.size() or was_wavy != use_wavy_labels:
		for c in children:
			box.remove_child(c)
			c.queue_free()
		for _i in entries.size():
			var new_lbl: Label
			if use_wavy_labels:
				new_lbl = LIQUIDS_LABEL_SCENE.instantiate() as Label
			else:
				new_lbl = _create_styled_label("", Color.WHITE, DEFAULT_FONT_SIZE, OUTLINE_COLOR, DEFAULT_OUTLINE_SIZE)
			box.add_child(new_lbl)
			_set_mouse_ignore_recursive(new_lbl)
		group["use_wavy"] = use_wavy_labels

	children = box.get_children()
	for i in range(mini(children.size(), entries.size())):
		var lbl := children[i] as Label
		var entry: Dictionary = entries[i]
		var entry_text: String = str(entry.get("text", ""))
		var entry_color: Color = entry.get("color", Color.WHITE)
		if lbl.has_method("change_text"):
			lbl.change_text(entry_text)
		else:
			lbl.text = entry_text
		if use_wavy_labels:
			if lbl.material is ShaderMaterial:
				var shader_mat := lbl.material as ShaderMaterial
				shader_mat.set_shader_parameter("base_color", entry_color)
				shader_mat.set_shader_parameter("secondary_color", entry.get("secondary_color", Color(0.5, 0.9, 1.0, 1.0)))
			var is_hl: bool = bool(entry.get("highlighted", false))
			var hl_col: Color = entry.get("highlight_color", DEFAULT_HIGHLIGHT_GLOW_COLOR)
			if lbl.has_method("set_highlighted"):
				lbl.set_highlighted(is_hl, hl_col)
			elif lbl.material is ShaderMaterial:
				var shader_mat := lbl.material as ShaderMaterial
				shader_mat.set_shader_parameter("highlight_amount", 1.0 if is_hl else 0.0)
				shader_mat.set_shader_parameter("highlight_glow_color", hl_col)
		else:
			lbl.add_theme_color_override("font_color", entry_color)
			TextIcons.apply_to_control(lbl)

	box.visible = true
	box.modulate.a = 1.0

func hide_status_group(group_id: String, owner_obj: Object = null, immediate: bool = false, fade_duration: float = 1.0) -> void:
	if not _status_groups.has(group_id):
		return
	var group: Dictionary = _status_groups[group_id]
	var current_owner: Variant = group.get("owner", null)
	if owner_obj != null and is_instance_valid(current_owner) and current_owner != owner_obj:
		return

	var box := group.get("container", null) as VBoxContainer
	if not is_instance_valid(box):
		return

	if immediate or not is_inside_tree():
		var old_tween: Tween = group.get("fade_tween", null) as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		group["fade_tween"] = null
		group["is_hiding"] = false
		group["owner"] = null
		box.modulate.a = 0.0
		box.visible = false
		return

	if bool(group.get("is_hiding", false)):
		return
	if not box.visible or box.modulate.a <= 0.0:
		group["owner"] = null
		box.visible = false
		return

	var fade_tween: Tween = group.get("fade_tween", null) as Tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()

	group["is_hiding"] = true
	var tween := create_tween()
	group["fade_tween"] = tween
	tween.tween_property(box, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func():
		if _status_groups.has(group_id):
			var g: Dictionary = _status_groups[group_id]
			g["is_hiding"] = false
			g["owner"] = null
			g["fade_tween"] = null
		if is_instance_valid(box):
			box.visible = false
	)

func get_status_group_owner(group_id: String) -> Variant:
	if not _status_groups.has(group_id):
		return null
	return _status_groups[group_id].get("owner", null)

func show_cup_ingredients(glass: Node, highlighted_layer_idx: int = -1, visual_helper: LiquidVisualHelper = null) -> void:
	if not is_instance_valid(glass):
		return
	var entries := build_cup_ingredient_entries(glass, visual_helper, highlighted_layer_idx)
	if entries.is_empty():
		hide_cup_ingredients(glass, true)
		return
	update_status_group("pouring", entries, glass, true)

func hide_cup_ingredients(glass: Node = null, immediate: bool = false, fade_duration: float = 0.35) -> void:
	hide_status_group("pouring", glass, immediate, fade_duration)

func update_pouring_indicator(glass: Node, liquids: Array, glass_size: float, visual_helper: LiquidVisualHelper = null, highlighted_layer_idx: int = -1) -> void:
	var mix: DrinkMix = glass.get("drink_mix") as DrinkMix if (is_instance_valid(glass) and "drink_mix" in glass) else null
	var helper: LiquidVisualHelper = visual_helper if visual_helper else _fallback_visual_helper
	var entries := build_mix_ingredient_entries(mix, liquids, glass_size, helper, highlighted_layer_idx)
	if entries.is_empty():
		hide_pouring_indicator(glass, true)
		return
	update_status_group("pouring", entries, glass, true)

func hide_pouring_indicator(glass: Node = null, immediate: bool = false) -> void:
	hide_status_group("pouring", glass, immediate, 1.0)

func _ensure_serve_combo_ui() -> void:
	if is_instance_valid(_serve_combo_box):
		return
	_serve_combo_box = VBoxContainer.new()
	_serve_combo_box.name = "ServeComboIndicator"
	_serve_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_serve_combo_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_serve_combo_box.offset_left = 27.0
	_serve_combo_box.offset_top = 210.0
	_serve_combo_box.offset_right = 240.0
	_serve_combo_box.offset_bottom = 265.0
	_serve_combo_box.grow_horizontal = Control.GROW_DIRECTION_END
	_serve_combo_box.modulate.a = 0.0
	_serve_combo_box.visible = false
	add_child(_serve_combo_box)

	_serve_combo_label = _create_styled_label("{arrow} Serve Combo", COMBO_FINAL_COLOR, 32, OUTLINE_COLOR, 4)
	_serve_combo_label.name = "ServeComboLabel"
	TextIcons.apply_to_control(_serve_combo_label)
	_serve_combo_box.add_child(_serve_combo_label)

	_serve_combo_bar = ProgressBar.new()
	_serve_combo_bar.name = "ServeComboBar"
	_serve_combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_serve_combo_bar.show_percentage = false
	_serve_combo_bar.custom_minimum_size = Vector2(0.0, 10.0)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.14, 0.85)
	bg_style.set_corner_radius_all(2)
	_serve_combo_bar.add_theme_stylebox_override("background", bg_style)

	_serve_combo_fill_style = StyleBoxFlat.new()
	_serve_combo_fill_style.bg_color = COMBO_FINAL_COLOR
	_serve_combo_fill_style.set_corner_radius_all(2)
	_serve_combo_bar.add_theme_stylebox_override("fill", _serve_combo_fill_style)

	_serve_combo_box.add_child(_serve_combo_bar)
	_set_mouse_ignore_recursive(_serve_combo_box)

func update_serve_combo_indicator(streak: int, grace_left: float, grace_max: float, current_bonus: float, next_step_bonus: float) -> void:
	if not is_inside_tree() or streak <= 0 or grace_left <= 0.0:
		hide_serve_combo_indicator(true)
		return

	_ensure_serve_combo_ui()

	if _serve_combo_fade_tween and _serve_combo_fade_tween.is_valid():
		_serve_combo_fade_tween.kill()
		_serve_combo_fade_tween = null

	_serve_combo_box.visible = true
	_serve_combo_box.modulate.a = 1.0

	var pct := clampf(grace_left / maxf(grace_max, 0.001), 0.0, 1.0)
	_serve_combo_bar.max_value = grace_max
	_serve_combo_bar.value = grace_left

	if _serve_combo_fill_style:
		var bar_col := COMBO_FINAL_COLOR if pct > 0.3 else DECREASE_COLOR.lerp(COMBO_FINAL_COLOR, pct / 0.3)
		_serve_combo_fill_style.bg_color = bar_col

	var title_text := ""
	if current_bonus > 0.0:
		title_text = "{arrow} Serve Combo x%d" % streak
	else:
		title_text = "{arrow} Serve Combo"

	_serve_combo_label.text = title_text
	TextIcons.apply_to_control(_serve_combo_label)

	if streak > _last_serve_combo_streak:
		_last_serve_combo_streak = streak
		if _serve_combo_punch_tween and _serve_combo_punch_tween.is_valid():
			_serve_combo_punch_tween.kill()
		_serve_combo_box.scale = Vector2(1.15, 1.15)
		_serve_combo_punch_tween = create_tween()
		_serve_combo_punch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_serve_combo_punch_tween.tween_property(_serve_combo_box, "scale", Vector2.ONE, 0.18)

func hide_serve_combo_indicator(immediate: bool = false) -> void:
	_last_serve_combo_streak = 0
	if not is_instance_valid(_serve_combo_box):
		return
	if _serve_combo_fade_tween and _serve_combo_fade_tween.is_valid():
		_serve_combo_fade_tween.kill()
		_serve_combo_fade_tween = null
	if immediate or not is_inside_tree():
		_serve_combo_box.modulate.a = 0.0
		_serve_combo_box.visible = false
		return
	if not _serve_combo_box.visible or _serve_combo_box.modulate.a <= 0.0:
		_serve_combo_box.visible = false
		return
	_serve_combo_fade_tween = create_tween()
	_serve_combo_fade_tween.tween_property(_serve_combo_box, "modulate:a", 0.0, 0.35)
	_serve_combo_fade_tween.tween_callback(func():
		if is_instance_valid(_serve_combo_box):
			_serve_combo_box.visible = false
			_serve_combo_box.scale = Vector2.ONE
	)

func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)