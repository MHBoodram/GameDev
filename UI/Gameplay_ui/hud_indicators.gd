class_name HudIndicators
extends Control

const INDICATOR_FONT: Font = IndicatorSettings.INDICATOR_FONT
const LIQUIDS_LABEL_SCENE: PackedScene = preload("res://Player/Drink/Glasses/liquids_label.tscn")

const INCREASE_COLOR: Color = IndicatorSettings.COLORS["increase"]
const DECREASE_COLOR: Color = IndicatorSettings.COLORS["decrease"]
const CLEAN_COLOR: Color = IndicatorSettings.COLORS["clean"]
const OUTLINE_COLOR: Color = IndicatorSettings.COLORS["outline"]
const SHADOW_COLOR: Color = IndicatorSettings.COLORS["shadow"]

const DEFAULT_FONT_SIZE: int = IndicatorSettings.HUD_DEFAULTS["font_size"]
const DEFAULT_OUTLINE_SIZE: int = IndicatorSettings.HUD_DEFAULTS["outline_size"]
const DEFAULT_FLOAT_DISTANCE: float = IndicatorSettings.HUD_DEFAULTS["float_distance"]
const DEFAULT_DURATION: float = IndicatorSettings.HUD_DEFAULTS["duration"]
const DEFAULT_SCALE_PUNCH: float = IndicatorSettings.HUD_DEFAULTS["scale_punch"]

static var current: HudIndicators = null

var _channels: Dictionary = {}
var _active_floating_groups: Dictionary = {}
var _status_groups: Dictionary = {}
var _fallback_visual_helper: LiquidVisualHelper = LiquidVisualHelper.new()

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

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	_disconnect_player_stats()
	_disconnect_game_events()
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
	_connect_player_stats()
	_connect_game_events()

func _process(_delta: float) -> void:
	if _status_groups.has("pouring"):
		var pouring_group: Dictionary = _status_groups["pouring"]
		var owner_obj: Variant = pouring_group.get("owner", null)
		if owner_obj != null and not is_instance_valid(owner_obj):
			pouring_group["owner"] = null
			var fade_dur: float = float(IndicatorSettings.get_status_group("pouring").get("fade_duration", 1.0))
			hide_status_group("pouring", null, false, fade_dur)

func _register_default_channels() -> void:
	for channel_id in IndicatorSettings.HUD_CHANNELS.keys():
		register_channel(str(channel_id), IndicatorSettings.get_hud_channel(str(channel_id)))

func register_channel(channel_id: String, config: Dictionary) -> void:
	_channels[channel_id] = config.duplicate(true)

func _get_channel_config(channel_id: String, options: Dictionary = {}) -> Dictionary:
	var base: Dictionary = _channels.get(channel_id, _channels.get("default", IndicatorSettings.get_hud_channel("default"))).duplicate(true)
	for key in options.keys():
		base[key] = options[key]
	return base

func _connect_game_events() -> void:
	if not GameEvents.cup_spilled.is_connected(_on_cup_spilled):
		GameEvents.cup_spilled.connect(_on_cup_spilled)
	if not GameEvents.cup_emptied.is_connected(_on_cup_emptied):
		GameEvents.cup_emptied.connect(_on_cup_emptied)
	if not GameEvents.cup_pouring_updated.is_connected(_on_cup_pouring_updated):
		GameEvents.cup_pouring_updated.connect(_on_cup_pouring_updated)
	if not GameEvents.cup_pouring_stopped.is_connected(_on_cup_pouring_stopped):
		GameEvents.cup_pouring_stopped.connect(_on_cup_pouring_stopped)

func _disconnect_game_events() -> void:
	if not GameEvents._bus:
		return
	if GameEvents.cup_spilled.is_connected(_on_cup_spilled):
		GameEvents.cup_spilled.disconnect(_on_cup_spilled)
	if GameEvents.cup_emptied.is_connected(_on_cup_emptied):
		GameEvents.cup_emptied.disconnect(_on_cup_emptied)
	if GameEvents.cup_pouring_updated.is_connected(_on_cup_pouring_updated):
		GameEvents.cup_pouring_updated.disconnect(_on_cup_pouring_updated)
	if GameEvents.cup_pouring_stopped.is_connected(_on_cup_pouring_stopped):
		GameEvents.cup_pouring_stopped.disconnect(_on_cup_pouring_stopped)

func _on_cup_spilled(glass: Node3D, overflow_percent: float) -> void:
	show_cup_spill_indicator(glass, overflow_percent)

func _on_cup_emptied(glass: Node3D) -> void:
	show_cup_empty_indicator(glass)

func _on_cup_pouring_updated(glass: Node, liquids: Array, capacity: float, visual_helper: RefCounted) -> void:
	update_pouring_indicator(glass, liquids, capacity, visual_helper as LiquidVisualHelper)

func _on_cup_pouring_stopped(glass: Node, immediate: bool) -> void:
	hide_pouring_indicator(glass, immediate)

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

func show_money_change(delta: float, suffix: String = "", options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var cfg: Dictionary = _get_channel_config("money", options)
	if not bool(cfg.get("enabled", true)):
		return null
	var amount_str: String = format_number(delta, bool(cfg.get("currency_decimals", true)))
	var text: String = IndicatorSettings.format_delta_text("money", delta, {
		"amount": amount_str,
		"suffix": suffix,
	}, cfg)
	var color: Color = cfg.get("positive_color", INCREASE_COLOR) if delta > 0.0 else cfg.get("negative_color", DECREASE_COLOR)
	var merged: Dictionary = options.duplicate()
	if not merged.has("channel"):
		merged["channel"] = "money"
	return show_floating_text(text, color, merged)

func show_overall_rep_change(delta: float, suffix: String = "", options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var cfg: Dictionary = _get_channel_config("overall_rep", options)
	if not bool(cfg.get("enabled", true)):
		return null
	var amount_str: String = format_number(delta, bool(cfg.get("currency_decimals", false)))
	var text: String = IndicatorSettings.format_delta_text("overall_rep", delta, {
		"amount": amount_str,
		"suffix": suffix,
	}, cfg)
	var color: Color = cfg.get("positive_color", INCREASE_COLOR) if delta > 0.0 else cfg.get("negative_color", DECREASE_COLOR)
	var merged: Dictionary = options.duplicate()
	if not merged.has("channel"):
		merged["channel"] = "overall_rep"
	return show_floating_text(text, color, merged)

func show_species_rep_change(species_name: String, delta: float, suffix: String = "", options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var cfg: Dictionary = _get_channel_config("species_rep", options)
	if not bool(cfg.get("enabled", true)):
		return null
	var display_species: String = species_name.strip_edges()
	var sp := SpeciesRegistry.get_species(display_species)
	if sp:
		display_species = sp.display_name
	elif display_species == "":
		display_species = str(cfg.get("default_species_label", "Species"))
	var amount_str: String = format_number(delta, bool(cfg.get("currency_decimals", false)))
	var text: String = IndicatorSettings.format_delta_text("species_rep", delta, {
		"amount": amount_str,
		"species": display_species,
		"suffix": suffix,
	}, cfg)
	var color: Color = cfg.get("positive_color", INCREASE_COLOR) if delta > 0.0 else cfg.get("negative_color", DECREASE_COLOR)
	var merged: Dictionary = options.duplicate()
	if not merged.has("channel"):
		merged["channel"] = "species_rep"
	return show_floating_text(text, color, merged)

func show_cup_spill_indicator(glass: Node3D, _spilled_percent: float = 0.0, options: Dictionary = {}) -> Label:
	var cfg: Dictionary = _get_channel_config("cup_spill", options)
	if not bool(cfg.get("enabled", true)):
		return null
	var vp_size: Vector2 = _get_viewport_size()
	var fallback_ratio: Vector2 = cfg.get("fallback_anchor_ratio", Vector2(0.5, 0.35))
	var fallback := Vector2(vp_size.x * fallback_ratio.x, vp_size.y * fallback_ratio.y)
	var world_offset: Vector3 = cfg.get("world_offset", Vector3(0.0, 0.15, 0.0))
	var merged: Dictionary = options.duplicate()
	if not merged.has("channel"):
		merged["channel"] = "cup_spill"
	if not merged.has("anchor") and not merged.has("anchor_resolver"):
		merged["anchor"] = _get_world_anchor(glass, world_offset, fallback)
	if not merged.has("stack_group") and is_instance_valid(glass):
		merged["stack_group"] = "cup_" + str(glass.get_instance_id())
	if not merged.has("jitter_x") and cfg.has("jitter_x"):
		merged["jitter_x"] = cfg["jitter_x"]
	var text: String = str(cfg.get("text", "Spilled!"))
	return show_floating_text(text, cfg.get("negative_color", DECREASE_COLOR), merged)

func show_cup_empty_indicator(glass: Node3D, options: Dictionary = {}) -> Label:
	var cfg: Dictionary = _get_channel_config("cup_reset", options)
	if not bool(cfg.get("enabled", true)):
		return null
	var vp_size: Vector2 = _get_viewport_size()
	var fallback_ratio: Vector2 = cfg.get("fallback_anchor_ratio", Vector2(0.5, 0.35))
	var fallback := Vector2(vp_size.x * fallback_ratio.x, vp_size.y * fallback_ratio.y)
	var world_offset: Vector3 = cfg.get("world_offset", Vector3(0.0, 0.15, 0.0))
	var merged: Dictionary = options.duplicate()
	if not merged.has("channel"):
		merged["channel"] = "cup_reset"
	if not merged.has("anchor") and not merged.has("anchor_resolver"):
		merged["anchor"] = _get_world_anchor(glass, world_offset, fallback)
	if not merged.has("stack_group") and is_instance_valid(glass):
		merged["stack_group"] = "cup_" + str(glass.get_instance_id())
	if not merged.has("jitter_x") and cfg.has("jitter_x"):
		merged["jitter_x"] = cfg["jitter_x"]
	var text: String = str(cfg.get("text", "Cup Empty! (Reset)"))
	var color: Color = cfg.get("color", cfg.get("positive_color", CLEAN_COLOR))
	return show_floating_text(text, color, merged)

func show_delta_indicator(channel_id: String, delta: float, formatted_body: String, options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var cfg: Dictionary = _get_channel_config(channel_id, options)
	if not bool(cfg.get("enabled", true)):
		return null

	var is_positive: bool = delta > 0.0
	var color: Color = cfg.get("positive_color", INCREASE_COLOR) if is_positive else cfg.get("negative_color", DECREASE_COLOR)
	var sign_prefix: String = str(cfg.get("positive_prefix", "+")) if is_positive else str(cfg.get("negative_prefix", "-"))
	var merged_options: Dictionary = options.duplicate()
	if not merged_options.has("channel"):
		merged_options["channel"] = channel_id
	return show_floating_text(sign_prefix + formatted_body, color, merged_options)

func show_floating_text(text: String, color: Color = Color.WHITE, options: Dictionary = {}) -> Label:
	if not is_inside_tree() or text == "":
		return null

	var channel_id: String = str(options.get("channel", "default"))
	var cfg: Dictionary = _get_channel_config(channel_id, options)
	if not bool(cfg.get("enabled", true)):
		return null

	var vp_size: Vector2 = _get_viewport_size()
	var font_res: Font = cfg.get("font", INDICATOR_FONT) as Font
	var font_size: int = int(cfg.get("font_size", DEFAULT_FONT_SIZE))
	var outline_size: int = int(cfg.get("outline_size", DEFAULT_OUTLINE_SIZE))
	var outline_col: Color = cfg.get("outline_color", OUTLINE_COLOR)
	var shadow_col: Color = cfg.get("shadow_color", SHADOW_COLOR)
	var shadow_offset: Vector2i = cfg.get("shadow_offset", Vector2i(2, 2))
	var shadow_outline_size: int = int(cfg.get("shadow_outline_size", 2))
	var float_dist: float = float(cfg.get("float_distance", DEFAULT_FLOAT_DISTANCE))
	var duration: float = maxf(0.2, float(cfg.get("duration", DEFAULT_DURATION)))
	var scale_punch: float = float(cfg.get("scale_punch", DEFAULT_SCALE_PUNCH))
	var punch_duration: float = maxf(0.02, float(cfg.get("punch_duration", 0.14)))
	var fade_start_ratio: float = clampf(float(cfg.get("fade_start_ratio", 0.55)), 0.0, 0.99)
	var delay: float = maxf(0.0, float(cfg.get("delay", 0.0)))
	var align: String = str(cfg.get("align", "right"))
	var stack_group: String = str(cfg.get("stack_group", channel_id))
	var stack_spacing: float = float(cfg.get("stack_spacing", 4.0))
	var margin_x: float = float(cfg.get("screen_margin_x", 16.0))
	var margin_y: float = float(cfg.get("screen_margin_y", 20.0))

	var label := _create_styled_label(text, color, font_size, outline_col, outline_size, font_res, shadow_col, shadow_offset, shadow_outline_size)
	if align == "center":
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var label_size: Vector2 = label.get_minimum_size()
	label.size = label_size
	label.pivot_offset = label_size * 0.5

	var anchor: Vector2 = _resolve_anchor(cfg, vp_size)
	var j_min: float = float(cfg.get("jitter_min_x", -8.0))
	var j_max: float = float(cfg.get("jitter_max_x", 8.0))
	var jitter_x: float = float(cfg.get("jitter_x", randf_range(j_min, j_max)))

	var spawn_x: float = anchor.x
	if align == "right":
		spawn_x = anchor.x - label_size.x + jitter_x
	elif align == "center":
		spawn_x = anchor.x - label_size.x * 0.5 + jitter_x
	else:
		spawn_x = anchor.x + jitter_x
	spawn_x = clampf(spawn_x, margin_x, maxf(margin_x, vp_size.x - label_size.x - margin_x))

	var spawn_y: float = _resolve_stacked_y(stack_group, anchor.y, label_size.y, vp_size, stack_spacing, margin_y)
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
	tween.tween_property(label, "scale", Vector2.ONE, punch_duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", target_y, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration * (1.0 - fade_start_ratio)).set_delay(delay + duration * fade_start_ratio).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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

func _create_styled_label(
	text: String,
	color: Color,
	font_size: int,
	outline_col: Color,
	outline_size: int,
	font_res: Font = INDICATOR_FONT,
	shadow_col: Color = SHADOW_COLOR,
	shadow_offset: Vector2i = Vector2i(2, 2),
	shadow_outline_size: int = 2
) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if font_res:
		label.add_theme_font_override("font", font_res)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_col)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", shadow_col)
	label.add_theme_constant_override("shadow_offset_x", shadow_offset.x)
	label.add_theme_constant_override("shadow_offset_y", shadow_offset.y)
	label.add_theme_constant_override("shadow_outline_size", shadow_outline_size)
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

func _resolve_stacked_y(stack_group: String, desired_y: float, label_height: float, vp_size: Vector2, stack_spacing: float = 4.0, margin_y: float = 20.0) -> float:
	var active: Array = _prune_floating_group(stack_group)
	active.sort_custom(func(a: Control, b: Control) -> bool:
		return a.position.y < b.position.y
	)
	var candidate_y: float = desired_y
	for entry in active:
		var ctrl := entry as Control
		var ey: float = ctrl.position.y
		var eh: float = maxf(ctrl.size.y, label_height) + stack_spacing
		if candidate_y + label_height + stack_spacing > ey and candidate_y < ey + eh:
			candidate_y = ey + eh
	return clampf(candidate_y, margin_y, maxf(margin_y, vp_size.y - label_height - margin_y))

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

# Persistent (used by pouring)
func _ensure_pouring_group() -> void:
	var cfg: Dictionary = IndicatorSettings.get_status_group("pouring")
	get_or_create_status_group("pouring", cfg.get("layout", {}))

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

	var defaults := IndicatorSettings.HUD_DEFAULTS
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
				new_lbl = _create_styled_label("", Color.WHITE, int(defaults.get("font_size", DEFAULT_FONT_SIZE)), OUTLINE_COLOR, int(defaults.get("outline_size", DEFAULT_OUTLINE_SIZE)))
			box.add_child(new_lbl)
			_set_mouse_ignore_recursive(new_lbl)
		group["use_wavy"] = use_wavy_labels

	var group_cfg: Dictionary = IndicatorSettings.get_status_group(group_id)
	var default_sec_col: Color = group_cfg.get("default_secondary_color", IndicatorSettings.COLORS["pouring_secondary"])

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
				shader_mat.set_shader_parameter("secondary_color", entry.get("secondary_color", default_sec_col))
		else:
			lbl.add_theme_color_override("font_color", entry_color)

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

func update_pouring_indicator(glass: Node, liquids: Array, glass_size: float, visual_helper: LiquidVisualHelper = null) -> void:
	var cfg: Dictionary = IndicatorSettings.get_status_group("pouring")
	if not bool(cfg.get("enabled", true)) or liquids.is_empty():
		hide_pouring_indicator(glass, true)
		return

	var helper: LiquidVisualHelper = visual_helper if visual_helper else _fallback_visual_helper
	var has_tint: bool = helper._visual_override.has("liquid_tint_color")
	var tint_col: Color = helper._visual_override.get("liquid_tint_color", Color.WHITE)
	var tint_mix: float = float(helper._visual_override.get("liquid_tint_strength", 0.35))
	var layer_template: String = str(cfg.get("layer_text_format", "{name}: {percent}%"))

	var entries: Array[Dictionary] = []
	for layer in liquids:
		if not (layer is Array) or layer.size() < 2:
			continue
		var col: Color = helper.get_layer_color(layer)
		if has_tint:
			col = col.lerp(tint_col, tint_mix)
		var layer_name: String = helper.format_layer_name(layer[0])
		var pct: float = (float(layer[1]) / maxf(glass_size, 0.001)) * 100.0
		entries.append({
			"text": IndicatorSettings.format_text(layer_template, {
				"name": layer_name,
				"percent": str(snappedf(pct, 0.1)),
			}),
			"color": col
		})

	update_status_group("pouring", entries, glass, bool(cfg.get("use_wavy_labels", true)), cfg.get("layout", {}))

func hide_pouring_indicator(glass: Node = null, immediate: bool = false) -> void:
	var fade_dur: float = float(IndicatorSettings.get_status_group("pouring").get("fade_duration", 1.0))
	hide_status_group("pouring", glass, immediate, fade_dur)

func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)