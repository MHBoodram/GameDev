class_name IndicatorSettings
extends RefCounted

# All 2D HUD and 3D floating indicators

const INDICATOR_FONT: Font = preload("res://Assets/Font/Merchant Copy.ttf")

const COLORS := {
	"increase": Color(0.28, 0.96, 0.36, 1.0),
	"decrease": Color(1.0, 0.25, 0.25, 1.0),
	"clean": Color(0.55, 0.92, 1.0, 1.0),
	"outline": Color(0.0, 0.0, 0.0, 1.0),
	"shadow": Color(0.0, 0.0, 0.0, 0.75),
	"npc_default": Color(1.0, 0.9, 0.35, 1.0),
	"pouring_secondary": Color(0.5, 0.9, 1.0, 1.0),
}

# Defaults for 2D HUD
const HUD_DEFAULTS := {
	"enabled": true,
	"font": INDICATOR_FONT,
	"font_size": 50,
	"outline_size": 8,
	"outline_color": COLORS["outline"],
	"shadow_color": COLORS["shadow"],
	"shadow_offset": Vector2i(2, 2),
	"shadow_outline_size": 2,
	"float_distance": 64.0,
	"duration": 1.45,
	"scale_punch": 1.28,
	"punch_duration": 0.14,
	"fade_start_ratio": 0.55,
	"delay": 0.0,
	"align": "right",
	"jitter_min_x": -8.0,
	"jitter_max_x": 8.0,
	"stack_spacing": 4.0,
	"screen_margin_x": 16.0,
	"screen_margin_y": 20.0,
	"positive_prefix": "+",
	"negative_prefix": "-",
	"positive_color": COLORS["increase"],
	"negative_color": COLORS["decrease"],
}

# Individual 2D HUD indicators
const HUD_CHANNELS := {
	"money": {
		"enabled": true,
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 4.0,
		"fallback_y": 98.0,
		"font_size": 50,
		"float_distance": 64.0,
		"duration": 1.45,
		"scale_punch": 1.28,
		"positive_color": COLORS["increase"],
		"negative_color": COLORS["decrease"],
		"currency_decimals": true,
		"text_format": "{sign}${amount}{suffix}",
	},
	"overall_rep": {
		"enabled": true,
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 46.0,
		"fallback_y": 140.0,
		"font_size": 50,
		"float_distance": 64.0,
		"duration": 1.45,
		"scale_punch": 1.28,
		"positive_color": COLORS["increase"],
		"negative_color": COLORS["decrease"],
		"currency_decimals": false,
		"text_format": "{sign}{amount} Overall Rep{suffix}",
	},
	"species_rep": {
		"enabled": true,
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 46.0,
		"fallback_y": 140.0,
		"font_size": 50,
		"float_distance": 64.0,
		"duration": 1.45,
		"scale_punch": 1.28,
		"positive_color": COLORS["increase"],
		"negative_color": COLORS["decrease"],
		"currency_decimals": false,
		"default_species_label": "Species",
		"text_format": "{sign}{amount} {species} Rep{suffix}",
	},
	"bonus": {
		"enabled": true,
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 88.0,
		"fallback_y": 182.0,
		"font_size": 50,
		"float_distance": 64.0,
		"duration": 1.45,
		"scale_punch": 1.28,
		"positive_color": COLORS["increase"],
		"negative_color": COLORS["decrease"],
	},
	"combo": {
		"enabled": true,
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 130.0,
		"fallback_y": 224.0,
		"font_size": 50,
		"float_distance": 64.0,
		"duration": 1.45,
		"scale_punch": 1.35,
		"positive_color": COLORS["increase"],
		"negative_color": COLORS["decrease"],
	},
	"cup_spill": {
		"enabled": true,
		"stack_group": "cup_feedback",
		"align": "center",
		"font_size": 48,
		"float_distance": 56.0,
		"duration": 1.15,
		"scale_punch": 1.36,
		"positive_color": COLORS["increase"],
		"negative_color": COLORS["decrease"],
		"jitter_x": 0.0,
		"world_offset": Vector3(0.0, 0.15, 0.0),
		"fallback_anchor_ratio": Vector2(0.5, 0.35),
		"min_percent_for_value": 0.05,
		"text_format": "{sign}{amount}% Spill!",
		"fallback_text": "Spilling!",
	},
	"cup_reset": {
		"enabled": true,
		"stack_group": "cup_feedback",
		"align": "center",
		"font_size": 48,
		"float_distance": 64.0,
		"duration": 1.45,
		"scale_punch": 1.32,
		"positive_color": COLORS["clean"],
		"negative_color": COLORS["decrease"],
		"color": COLORS["clean"],
		"jitter_x": 0.0,
		"world_offset": Vector3(0.0, 0.15, 0.0),
		"fallback_anchor_ratio": Vector2(0.5, 0.35),
		"text": "Cup Empty! (Reset)",
	},
	"default": {
		"enabled": true,
		"stack_group": "right_hud",
		"align": "right",
		"y_offset_below_money": 46.0,
		"fallback_y": 140.0,
		"font_size": 50,
		"float_distance": 64.0,
		"duration": 1.45,
		"scale_punch": 1.28,
		"positive_color": COLORS["increase"],
		"negative_color": COLORS["decrease"],
	},
}

# Persistent HUD status groups
const STATUS_GROUPS := {
	"pouring": {
		"enabled": true,
		"use_wavy_labels": true,
		"fade_duration": 1.0,
		"min_spilled_percent": 0.05,
		"layer_text_format": "{name}: {percent}%",
		"spilled_text_format": "Spilled: -{percent}%",
		"spilled_color": COLORS["decrease"],
		"spilled_secondary_color": COLORS["decrease"],
		"default_secondary_color": COLORS["pouring_secondary"],
		"layout": {
			"anchor_preset": Control.PRESET_TOP_RIGHT,
			"offset_left": -261.0,
			"offset_top": 285.0,
			"offset_right": -15.0,
			"offset_bottom": 325.0,
			"grow_horizontal": Control.GROW_DIRECTION_BEGIN,
		},
	},
}

# Defaults for 3D indicators
const NPC_FEEDBACK_DEFAULTS := {
	"enabled": true,
	"font_size": 48,
	"outline_size": 12,
	"color": COLORS["npc_default"],
	"billboard": true,
	"no_depth_test": true,
	"local_offset": Vector3(0.0, 1.35, 0.1),
	"float_distance": 0.55,
	"duration": 1.0,
	"max_inv_scale": 1.8,
}

# Individual 3D indicators
const NPC_FEEDBACK := {
	"ghost_passed_through": {
		"text": "Passed right through!",
		"color": COLORS["decrease"],
	},
	"ghost_spectral_delight": {
		"text": "Spectral delight!",
		"color": COLORS["clean"],
	},
	"slime_too_small": {
		"text": "Too small to slice!",
		"color": COLORS["npc_default"],
	},
	"slime_already_sliced": {
		"text": "Already sliced!",
		"color": COLORS["npc_default"],
	},
	"slime_no_seats": {
		"text": "No empty seats!",
		"color": COLORS["decrease"],
	},
}

static func get_hud_channel(channel_id: String, overrides: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = HUD_DEFAULTS.duplicate(true)
	var default_ch: Dictionary = HUD_CHANNELS.get("default", {})
	for k in default_ch.keys():
		cfg[k] = default_ch[k]
	if HUD_CHANNELS.has(channel_id):
		var ch: Dictionary = HUD_CHANNELS[channel_id]
		for k in ch.keys():
			cfg[k] = ch[k]
	for k in overrides.keys():
		cfg[k] = overrides[k]
	return cfg

static func get_status_group(group_id: String, overrides: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = STATUS_GROUPS.get(group_id, {}).duplicate(true)
	for k in overrides.keys():
		cfg[k] = overrides[k]
	return cfg

static func has_npc_feedback(feedback_id: String) -> bool:
	return NPC_FEEDBACK.has(feedback_id)

static func get_npc_feedback_config(message_or_id: String, overrides: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = NPC_FEEDBACK_DEFAULTS.duplicate(true)
	if NPC_FEEDBACK.has(message_or_id):
		var entry: Dictionary = NPC_FEEDBACK[message_or_id]
		for k in entry.keys():
			cfg[k] = entry[k]
	else:
		cfg["text"] = message_or_id
	for k in overrides.keys():
		cfg[k] = overrides[k]
	return cfg

static func format_text(template: String, values: Dictionary = {}) -> String:
	var result: String = template
	for key in values.keys():
		result = result.replace("{" + str(key) + "}", str(values[key]))
	return result

static func format_delta_text(channel_id: String, delta: float, values: Dictionary = {}, overrides: Dictionary = {}) -> String:
	var cfg: Dictionary = get_hud_channel(channel_id, overrides)
	var sign_prefix: String = str(cfg.get("positive_prefix", "+")) if delta > 0.0 else str(cfg.get("negative_prefix", "-"))
	var merged_values: Dictionary = values.duplicate()
	if not merged_values.has("sign"):
		merged_values["sign"] = sign_prefix
	var template: String = str(cfg.get("text_format", "{sign}{amount}"))
	return format_text(template, merged_values)