class_name HudIndicators
extends Control

const INDICATOR_FONT: Font = preload("res://Assets/Font/Merchant Copy.ttf")
const LIQUIDS_LABEL_SCENE: PackedScene = preload("res://Player/Drink/Glasses/liquids_label.tscn")

const INCREASE_COLOR: Color = Color(0.28, 0.96, 0.36, 1.0)
const DECREASE_COLOR: Color = Color(1.0, 0.25, 0.25, 1.0)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.75)

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

func _process(_delta: float) -> void:
	if _status_groups.has("pouring"):
		var pouring_group: Dictionary = _status_groups["pouring"]
		var owner_obj: Variant = pouring_group.get("owner", null)
		if owner_obj != null and not is_instance_valid(owner_obj):
			pouring_group["owner"] = null
			hide_status_group("pouring", null, false, 1.0)

func _register_default_channels() -> void:
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

func show_money_change(delta: float, suffix: String = "", options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var amount_str: String = format_number(delta, true)
	return show_delta_indicator("money", delta, "$" + amount_str + suffix, options)

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
	return show_delta_indicator("species_rep", delta, amount_str + " " + display_species + " Rep" + suffix, options)

func show_delta_indicator(channel_id: String, delta: float, formatted_body: String, options: Dictionary = {}) -> Label:
	if absf(delta) < 0.005:
		return null
	var cfg: Dictionary = _channels.get(channel_id, _channels.get("default", {})).duplicate(true)
	for key in options.keys():
		cfg[key] = options[key]

	var is_positive: bool = delta > 0.0
	var color: Color = cfg.get("positive_color", INCREASE_COLOR) if is_positive else cfg.get("negative_color", DECREASE_COLOR)
	var sign_prefix: String = "+" if is_positive else "-"
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
	var label_size: Vector2 = label.get_minimum_size()
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
			(_active_floating_groups[stack_group] as Array).erase(label)
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

# Persistent (used by pouring)
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
				(lbl.material as ShaderMaterial).set_shader_parameter("base_color", entry_color)
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
	if liquids.is_empty():
		hide_pouring_indicator(glass, true)
		return

	var helper: LiquidVisualHelper = visual_helper if visual_helper else _fallback_visual_helper
	var has_tint: bool = helper._visual_override.has("liquid_tint_color")
	var tint_col: Color = helper._visual_override.get("liquid_tint_color", Color.WHITE)
	var tint_mix: float = float(helper._visual_override.get("liquid_tint_strength", 0.35))

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
			"text": layer_name + ": " + str(snappedf(pct, 0.1)) + "%",
			"color": col
		})

	update_status_group("pouring", entries, glass, true)

func hide_pouring_indicator(glass: Node = null, immediate: bool = false) -> void:
	hide_status_group("pouring", glass, immediate, 1.0)

func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)