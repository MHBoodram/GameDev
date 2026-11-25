class_name TextIcons
extends RefCounted

# Inline icon placeholders for any string, Label, Button, RichTextLabel, Label3D, Dialogue
# Example usage: "Cost: {coin} 30"

const _SENTINEL_TEXT := " "
const _USE_NODE_TEXT := "__TEXT_ICONS_USE_NODE_TEXT__"
const _OVERLAY_NAME := "__TextIconsRTL"
const _OVERLAY_3D_NAME := "__TextIconsSprite3D"

const _META_RAW_TEXT := "_text_icons_raw_text"
const _META_SENTINEL := "_text_icons_sentinel"
const _META_BASE_MIN_SIZE := "_text_icons_base_min_size"
const _META_STATE_SIG := "_text_icons_state_sig"
const _META_COLOR_SIG := "_text_icons_color_sig"
const _META_SHIFTED := "_text_icons_shifted"

static var ICONS: Dictionary = {
	"coin": "res://Assets/UI/Coin.png",
	"beer": "res://Assets/Items/Drinks/beer.png",
	"gin": "res://Assets/Items/Drinks/gin.png",
	"rum": "res://Assets/Items/Drinks/rum.png",
	"vodka": "res://Assets/Items/Drinks/vodka.png",
	"tequila": "res://Assets/Items/Drinks/tequila.png",
	"whiskey": "res://Assets/Items/Drinks/whiskey.png",
	"spirit": "res://Assets/Items/Drinks/spirit.png",
	"blood": "res://Assets/Items/Drinks/blood.png",
	"blood_drop": "res://Assets/Items/Ingreidents/Blood.png",
	"knife": "res://Assets/Items/Ingreidents/Knife.png",
	"fishing_rod": "res://Assets/Items/Ingreidents/Fishing_Rod.png",
	"mag": "res://Assets/Items/Ingreidents/Mag.png",
	"human": "res://Assets/NPC/UI/human.png",
	"vampire": "res://Assets/NPC/UI/vampire.png",
	"slime": "res://Assets/NPC/UI/slime.png",
	"tiny": "res://Assets/NPC/UI/tiny.png",
	"fish": "res://Assets/NPC/UI/fish.png",
	"hand": "res://Assets/UI/Hand.png",
	"arrow": "res://Assets/UI/Green_Arrow.png",
	"shaker": "res://Assets/Items/shaker.png",
}

static var _custom_textures: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _regex: RegEx = null


static func _get_regex() -> RegEx:
	if _regex == null:
		_regex = RegEx.new()
		_regex.compile("\\{([a-zA-Z0-9_]+)(?:[:=]([0-9]+(?:\\.[0-9]+)?)(em|px)?)?\\}")
	return _regex


static func install(host: Node) -> Node:
	if not is_instance_valid(host):
		return null
	var existing := host.get_node_or_null("TextIconsRuntime")
	if is_instance_valid(existing):
		return existing
	var runtime := TextIconsRuntime.new()
	runtime.name = "TextIconsRuntime"
	host.add_child(runtime)
	return runtime


static func register_icon(icon_id: String, path_or_texture: Variant) -> void:
	var key := icon_id.to_lower().strip_edges()
	if key == "":
		return
	if path_or_texture is String:
		ICONS[key] = str(path_or_texture)
		_custom_textures.erase(key)
		_texture_cache.erase(key)
	elif path_or_texture is Texture2D:
		var tex := path_or_texture as Texture2D
		_texture_cache[key] = tex
		if tex.resource_path != "":
			ICONS[key] = tex.resource_path
			_custom_textures.erase(key)
		else:
			_custom_textures[key] = tex
			ICONS.erase(key)


static func has_icon(icon_id: String) -> bool:
	var key := icon_id.to_lower().strip_edges()
	return ICONS.has(key) or _custom_textures.has(key)


static func get_icon_path(icon_id: String) -> String:
	return str(ICONS.get(icon_id.to_lower().strip_edges(), ""))


static func get_icon_texture(icon_id: String) -> Texture2D:
	var key := icon_id.to_lower().strip_edges()
	if _texture_cache.has(key):
		return _texture_cache[key] as Texture2D
	if _custom_textures.has(key):
		var custom_tex := _custom_textures[key] as Texture2D
		_texture_cache[key] = custom_tex
		return custom_tex
	var path := str(ICONS.get(key, ""))
	if path != "" and ResourceLoader.exists(path):
		var loaded := load(path) as Texture2D
		if loaded:
			_texture_cache[key] = loaded
		return loaded
	return null


static func coin(suffix: String = "") -> String:
	return "{coin}" + suffix


static func icon(icon_id: String, size_override: String = "") -> String:
	var clean_id := icon_id.to_lower().strip_edges()
	if size_override != "":
		return "{%s:%s}" % [clean_id, size_override]
	return "{%s}" % clean_id


static func has_icons(text: String) -> bool:
	if text == "" or not text.contains("{"):
		return false
	for m in _get_regex().search_all(text):
		var start := m.get_start()
		var end := m.get_end()
		if start > 0 and text[start - 1] == "{" and end < text.length() and text[end] == "}":
			continue
		if has_icon(m.get_string(1)):
			return true
	return false


static func strip_icons(text: String, replacement: String = "") -> String:
	if not has_icons(text):
		return text
	var parts := PackedStringArray()
	var cursor := 0
	for m in _get_regex().search_all(text):
		var start := m.get_start()
		var end := m.get_end()
		if start > 0 and text[start - 1] == "{" and end < text.length() and text[end] == "}":
			continue
		if not has_icon(m.get_string(1)):
			continue
		if start > cursor:
			parts.append(text.substr(cursor, start - cursor))
		if replacement != "":
			parts.append(replacement)
		cursor = end
	if cursor < text.length():
		parts.append(text.substr(cursor))
	return "".join(parts)


static func get_default_icon_height(font: Font, font_size: int) -> int:
	var eff_size := font_size if font_size > 0 else 16
	var line_h := font.get_height(eff_size) if font else float(eff_size)
	if line_h <= 0.0:
		line_h = float(eff_size)
	return maxi(8, roundi(line_h * 0.80))


static func _resolve_token_dimensions(icon_id: String, size_val: String, size_unit: String, font: Font, font_size: int, default_icon_h: int) -> Vector2i:
	var target_h := default_icon_h if default_icon_h > 0 else get_default_icon_height(font, font_size)
	if size_val != "":
		var num := float(size_val)
		if size_unit == "em":
			var eff_size := font_size if font_size > 0 else 16
			var line_h := font.get_height(eff_size) if font else float(eff_size)
			if line_h <= 0.0:
				line_h = float(eff_size)
			target_h = maxi(8, roundi(num * line_h))
		else:
			target_h = maxi(8, roundi(num))
	var tex := get_icon_texture(icon_id)
	var target_w := target_h
	if tex:
		var sz := tex.get_size()
		if sz.y > 0.0:
			target_w = maxi(8, roundi(float(target_h) * (sz.x / sz.y)))
	return Vector2i(target_w, target_h)


static func _tokenize(text: String, font: Font, font_size: int, default_icon_h: int) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if text == "":
		return segments
	if not text.contains("{"):
		segments.append({"type": "text", "text": text})
		return segments

	var cursor := 0
	for m in _get_regex().search_all(text):
		var start := m.get_start()
		var end := m.get_end()
		if start > 0 and text[start - 1] == "{" and end < text.length() and text[end] == "}":
			continue
		var icon_id := m.get_string(1).to_lower().strip_edges()
		if not has_icon(icon_id):
			continue
		if start > cursor:
			segments.append({"type": "text", "text": text.substr(cursor, start - cursor)})
		var dims := _resolve_token_dimensions(icon_id, m.get_string(2), m.get_string(3), font, font_size, default_icon_h)
		segments.append({
			"type": "icon",
			"id": icon_id,
			"raw": m.get_string(0),
			"start": start,
			"end": end,
			"w": dims.x,
			"h": dims.y,
			"path": get_icon_path(icon_id),
			"texture": get_icon_texture(icon_id),
		})
		cursor = end
	if cursor < text.length():
		segments.append({"type": "text", "text": text.substr(cursor)})
	return segments


static func to_bbcode(text: String, default_icon_h: int = 24, escape_plain_text: bool = false, font: Font = null, font_size: int = 16) -> String:
	if not has_icons(text):
		return text.replace("[", "[lb]") if escape_plain_text else text
	var segments := _tokenize(text, font, font_size, default_icon_h)
	var out := PackedStringArray()
	for seg in segments:
		if seg["type"] == "text":
			var txt := str(seg["text"])
			out.append(txt.replace("[", "[lb]") if escape_plain_text else txt)
		else:
			var path := str(seg["path"])
			if path != "":
				out.append("[img=%dx%d]%s[/img]" % [int(seg["w"]), int(seg["h"]), path])
			else:
				out.append(str(seg["raw"]))
	return "".join(out)


static func set_text(target: Node, text: String) -> void:
	if not is_instance_valid(target):
		return
	if target is RichTextLabel:
		var rtl := target as RichTextLabel
		rtl.text = text
		_sync_dialogue_or_rich_text(rtl)
	elif target is Control:
		apply_to_control(target as Control, text)
	elif target is Label3D:
		_sync_label3d(target as Label3D, text)
	elif "text" in target:
		target.set("text", text)


static func apply_to_control(ctrl: Control, raw_text_override: String = _USE_NODE_TEXT) -> void:
	if not is_instance_valid(ctrl):
		return
	if ctrl is RichTextLabel:
		var rtl := ctrl as RichTextLabel
		if raw_text_override != _USE_NODE_TEXT:
			rtl.text = raw_text_override
		_sync_dialogue_or_rich_text(rtl)
		return
	if not (ctrl is Label or (ctrl is Button and not (ctrl is OptionButton))):
		return

	var raw_text := ""
	if raw_text_override != _USE_NODE_TEXT:
		raw_text = raw_text_override
	elif ctrl.has_meta(_META_SENTINEL) and str(ctrl.get("text")) == str(ctrl.get_meta(_META_SENTINEL)):
		raw_text = str(ctrl.get_meta(_META_RAW_TEXT, ""))
	else:
		raw_text = str(ctrl.get("text"))

	if not has_icons(raw_text):
		var had_overlay := ctrl.has_meta(_META_SENTINEL)
		if had_overlay:
			_clear_control_overlay(ctrl)
		if raw_text_override != _USE_NODE_TEXT or (had_overlay and str(ctrl.get("text")) == _SENTINEL_TEXT):
			ctrl.set("text", raw_text)
		return

	_apply_control_overlay(ctrl, raw_text)


static func sync_control_visuals(ctrl: Control) -> void:
	if not is_instance_valid(ctrl) or not ctrl.has_meta(_META_SENTINEL):
		return
	var rtl := ctrl.get_node_or_null(_OVERLAY_NAME) as RichTextLabel
	if not is_instance_valid(rtl):
		return
	_apply_control_overlay(ctrl, str(ctrl.get_meta(_META_RAW_TEXT, "")))


static func _clear_control_overlay(ctrl: Control) -> void:
	var rtl := ctrl.get_node_or_null(_OVERLAY_NAME) as RichTextLabel
	if is_instance_valid(rtl):
		if rtl.get_parent() == ctrl:
			ctrl.remove_child(rtl)
		rtl.queue_free()
	if ctrl.has_meta(_META_BASE_MIN_SIZE):
		var base_min: Variant = ctrl.get_meta(_META_BASE_MIN_SIZE)
		if base_min is Vector2:
			ctrl.custom_minimum_size = base_min as Vector2
		ctrl.remove_meta(_META_BASE_MIN_SIZE)
	ctrl.remove_meta(_META_RAW_TEXT)
	ctrl.remove_meta(_META_SENTINEL)
	ctrl.remove_meta(_META_STATE_SIG)
	ctrl.remove_meta(_META_COLOR_SIG)


static func _get_or_create_overlay_rtl(ctrl: Control) -> RichTextLabel:
	var rtl := ctrl.get_node_or_null(_OVERLAY_NAME) as RichTextLabel
	if not is_instance_valid(rtl):
		rtl = RichTextLabel.new()
		rtl.name = _OVERLAY_NAME
		rtl.bbcode_enabled = true
		rtl.fit_content = false
		rtl.scroll_active = false
		rtl.selection_enabled = false
		rtl.context_menu_enabled = false
		rtl.focus_mode = Control.FOCUS_NONE
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		rtl.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		ctrl.add_child(rtl)
	return rtl


static func _read_control_style(ctrl: Control) -> Dictionary:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 16
	var font_color: Color = Color.WHITE
	var outline_color: Color = Color.BLACK
	var outline_size: int = 0
	var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.0)
	var shadow_offset_x: int = 0
	var shadow_offset_y: int = 0
	var shadow_outline_size: int = 0
	var line_sep: int = 3
	var h_align: int = HORIZONTAL_ALIGNMENT_LEFT
	var v_align: int = VERTICAL_ALIGNMENT_TOP
	var autowrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF
	var clip_text: bool = false
	var pad_l: float = 0.0
	var pad_r: float = 0.0
	var pad_t: float = 0.0
	var pad_b: float = 0.0

	if ctrl is Label:
		var lbl := ctrl as Label
		var ls: LabelSettings = lbl.label_settings
		font = ls.font if (ls and ls.font) else lbl.get_theme_font("font")
		font_size = ls.font_size if (ls and ls.font_size > 0) else lbl.get_theme_font_size("font_size")
		font_color = ls.font_color if ls else lbl.get_theme_color("font_color")
		outline_color = ls.outline_color if ls else lbl.get_theme_color("font_outline_color")
		outline_size = ls.outline_size if ls else lbl.get_theme_constant("outline_size")
		shadow_color = ls.shadow_color if ls else lbl.get_theme_color("font_shadow_color")
		shadow_offset_x = roundi(ls.shadow_offset.x) if ls else lbl.get_theme_constant("shadow_offset_x")
		shadow_offset_y = roundi(ls.shadow_offset.y) if ls else lbl.get_theme_constant("shadow_offset_y")
		shadow_outline_size = ls.shadow_size if ls else lbl.get_theme_constant("shadow_outline_size")
		line_sep = roundi(ls.line_spacing) if ls else lbl.get_theme_constant("line_separation")
		h_align = lbl.horizontal_alignment
		v_align = lbl.vertical_alignment
		autowrap = lbl.autowrap_mode
		clip_text = lbl.clip_text
		var sb := lbl.get_theme_stylebox("normal")
		if sb:
			pad_l = maxf(0.0, sb.get_margin(SIDE_LEFT))
			pad_r = maxf(0.0, sb.get_margin(SIDE_RIGHT))
			pad_t = maxf(0.0, sb.get_margin(SIDE_TOP))
			pad_b = maxf(0.0, sb.get_margin(SIDE_BOTTOM))
	elif ctrl is Button:
		var btn := ctrl as Button
		font = btn.get_theme_font("font")
		font_size = btn.get_theme_font_size("font_size")
		outline_color = btn.get_theme_color("font_outline_color")
		outline_size = btn.get_theme_constant("outline_size")
		line_sep = btn.get_theme_constant("line_separation") if btn.has_theme_constant("line_separation") else 2
		h_align = btn.alignment
		v_align = VERTICAL_ALIGNMENT_CENTER
		autowrap = btn.autowrap_mode
		clip_text = btn.clip_text

		var sb_name := "normal"
		if btn.disabled:
			sb_name = "disabled"
			font_color = btn.get_theme_color("font_disabled_color")
		elif btn.button_pressed:
			sb_name = "pressed"
			font_color = btn.get_theme_color("font_hover_pressed_color") if btn.is_hovered() else btn.get_theme_color("font_pressed_color")
		elif btn.is_hovered():
			sb_name = "hover"
			font_color = btn.get_theme_color("font_hover_color")
		elif btn.has_focus():
			font_color = btn.get_theme_color("font_focus_color")
		else:
			font_color = btn.get_theme_color("font_color")

		var sb := btn.get_theme_stylebox(sb_name)
		if sb == null:
			sb = btn.get_theme_stylebox("normal")
		if sb:
			pad_l = maxf(0.0, sb.get_margin(SIDE_LEFT))
			pad_r = maxf(0.0, sb.get_margin(SIDE_RIGHT))
			pad_t = maxf(0.0, sb.get_margin(SIDE_TOP))
			pad_b = maxf(0.0, sb.get_margin(SIDE_BOTTOM))

		if btn.icon != null:
			var icon_sz := btn.icon.get_size()
			var max_w := float(btn.get_theme_constant("icon_max_width"))
			if btn.expand_icon and max_w > 0.0 and icon_sz.x > max_w:
				icon_sz *= max_w / icon_sz.x
			var h_sep := float(btn.get_theme_constant("h_separation"))
			if btn.icon_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
				pad_r += icon_sz.x + h_sep
			else:
				pad_l += icon_sz.x + h_sep

	if font == null:
		font = ThemeDB.fallback_font
	if font_size <= 0:
		font_size = 16

	return {
		"font": font,
		"font_size": font_size,
		"font_color": font_color,
		"outline_color": outline_color,
		"outline_size": outline_size,
		"shadow_color": shadow_color,
		"shadow_offset_x": shadow_offset_x,
		"shadow_offset_y": shadow_offset_y,
		"shadow_outline_size": shadow_outline_size,
		"line_separation": line_sep,
		"h_align": h_align,
		"v_align": v_align,
		"autowrap": autowrap,
		"clip_text": clip_text,
		"pad_l": pad_l,
		"pad_r": pad_r,
		"pad_t": pad_t,
		"pad_b": pad_b,
	}


static func _measure_text_size(text: String, font: Font, font_size: int, line_sep: float, max_wrap_width: float, default_icon_h: int) -> Vector2:
	var eff_font := font if font else ThemeDB.fallback_font
	var eff_size := font_size if font_size > 0 else 16
	var base_line_h := eff_font.get_height(eff_size) if eff_font else float(eff_size)
	if base_line_h <= 0.0:
		base_line_h = float(eff_size)

	var lines := text.split("\n")
	var max_w := 0.0
	var total_h := 0.0
	var total_visual_lines := 0

	for line_str in lines:
		var segs := _tokenize(line_str, eff_font, eff_size, default_icon_h)
		if max_wrap_width <= 0.0:
			var cur_w := 0.0
			var cur_h := base_line_h
			for seg in segs:
				if seg["type"] == "text":
					var t := str(seg["text"])
					if t != "":
						cur_w += eff_font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, eff_size).x if eff_font else float(t.length() * eff_size) * 0.55
				else:
					cur_w += float(seg["w"])
					cur_h = maxf(cur_h, float(seg["h"]))
			max_w = maxf(max_w, cur_w)
			if total_visual_lines > 0:
				total_h += line_sep
			total_h += cur_h
			total_visual_lines += 1
		else:
			var cur_w := 0.0
			var cur_h := base_line_h
			var line_has_items := false
			for seg in segs:
				if seg["type"] == "icon":
					var iw := float(seg["w"])
					var ih := float(seg["h"])
					if line_has_items and cur_w + iw > max_wrap_width:
						max_w = maxf(max_w, cur_w)
						if total_visual_lines > 0:
							total_h += line_sep
						total_h += cur_h
						total_visual_lines += 1
						cur_w = iw
						cur_h = maxf(base_line_h, ih)
					else:
						cur_w += iw
						cur_h = maxf(cur_h, ih)
						line_has_items = true
				else:
					var raw_part := str(seg["text"])
					var words := _split_words_preserve_spaces(raw_part)
					for word in words:
						var ww := eff_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, eff_size).x if eff_font else float(word.length() * eff_size) * 0.55
						if line_has_items and word.strip_edges() != "" and cur_w + ww > max_wrap_width:
							max_w = maxf(max_w, cur_w)
							if total_visual_lines > 0:
								total_h += line_sep
							total_h += cur_h
							total_visual_lines += 1
							cur_w = ww
							cur_h = base_line_h
						else:
							cur_w += ww
							line_has_items = true
			max_w = maxf(max_w, cur_w)
			if total_visual_lines > 0:
				total_h += line_sep
			total_h += cur_h
			total_visual_lines += 1

	return Vector2(max_w + 4.0, total_h + 2.0)


static func _split_words_preserve_spaces(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	if s == "":
		return out
	var start := 0
	var i := 0
	while i < s.length():
		if s[i] == " ":
			if i > start:
				out.append(s.substr(start, i - start))
			out.append(" ")
			start = i + 1
		i += 1
	if start < s.length():
		out.append(s.substr(start))
	return out


static func _populate_rich_text_label(rtl: RichTextLabel, raw_text: String, default_icon_h: int, escape_plain_text: bool, font: Font, font_size: int, align_tag: String = "") -> void:
	var segs := _tokenize(raw_text, font, font_size, default_icon_h)
	var all_have_paths := true
	for seg in segs:
		if seg["type"] == "icon" and str(seg["path"]) == "":
			all_have_paths = false
			break

	rtl.bbcode_enabled = true
	if all_have_paths:
		var bbcode := to_bbcode(raw_text, default_icon_h, escape_plain_text, font, font_size)
		if align_tag != "":
			bbcode = "[%s]%s[/%s]" % [align_tag, bbcode, align_tag]
		rtl.text = bbcode
		return

	rtl.clear()
	if align_tag == "center":
		rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	elif align_tag == "right":
		rtl.push_paragraph(HORIZONTAL_ALIGNMENT_RIGHT)
	for seg in segs:
		if seg["type"] == "text":
			var t := str(seg["text"])
			rtl.append_text(t.replace("[", "[lb]") if escape_plain_text else t)
		else:
			var tex := seg["texture"] as Texture2D
			if tex:
				rtl.add_image(tex, int(seg["w"]), int(seg["h"]), Color.WHITE, INLINE_ALIGNMENT_CENTER)
			else:
				rtl.append_text(str(seg["raw"]))
	if align_tag == "center" or align_tag == "right":
		rtl.pop()


static func _apply_control_overlay(ctrl: Control, raw_text: String) -> void:
	if not ctrl.has_meta(_META_BASE_MIN_SIZE):
		ctrl.set_meta(_META_BASE_MIN_SIZE, ctrl.custom_minimum_size)
	ctrl.set_meta(_META_RAW_TEXT, raw_text)
	ctrl.set_meta(_META_SENTINEL, _SENTINEL_TEXT)

	var st := _read_control_style(ctrl)
	var font: Font = st["font"] as Font
	var font_size: int = int(st["font_size"])
	var default_icon_h := get_default_icon_height(font, font_size)
	var autowrap: TextServer.AutowrapMode = st["autowrap"] as TextServer.AutowrapMode
	var pad_l: float = float(st["pad_l"])
	var pad_r: float = float(st["pad_r"])
	var pad_t: float = float(st["pad_t"])
	var pad_b: float = float(st["pad_b"])
	var h_align: int = int(st["h_align"])
	var v_align: int = int(st["v_align"])
	var line_sep: int = int(st["line_separation"])

	var wrap_w := 0.0
	if autowrap != TextServer.AUTOWRAP_OFF:
		wrap_w = maxf(ctrl.size.x - pad_l - pad_r, 32.0)

	var rtl := _get_or_create_overlay_rtl(ctrl)

	var color_sig := "%s|%s|%d|%s|%d|%d|%d|%d|%s|%s|%s|%s|%s" % [
		str(st["font_color"]),
		str(st["outline_color"]),
		int(st["outline_size"]),
		str(st["shadow_color"]),
		int(st["shadow_offset_x"]),
		int(st["shadow_offset_y"]),
		int(st["shadow_outline_size"]),
		int(st["clip_text"]),
		str(pad_l),
		str(pad_r),
		str(pad_t),
		str(pad_b),
		str(ctrl.texture_filter),
	]

	var font_id: int = font.get_rid().get_id() if font else 0
	var state_sig := "%s|%d|%d|%d|%d|%d|%d|%d" % [
		raw_text,
		font_id,
		font_size,
		line_sep,
		h_align,
		v_align,
		int(autowrap),
		roundi(wrap_w),
	]

	var need_rebuild := str(ctrl.get_meta(_META_STATE_SIG, "")) != state_sig
	var need_visuals := need_rebuild or str(ctrl.get_meta(_META_COLOR_SIG, "")) != color_sig

	if need_visuals:
		ctrl.set_meta(_META_COLOR_SIG, color_sig)
		rtl.add_theme_color_override("default_color", st["font_color"] as Color)
		rtl.add_theme_color_override("font_outline_color", st["outline_color"] as Color)
		rtl.add_theme_constant_override("outline_size", int(st["outline_size"]))
		rtl.add_theme_color_override("font_shadow_color", st["shadow_color"] as Color)
		rtl.add_theme_constant_override("shadow_offset_x", int(st["shadow_offset_x"]))
		rtl.add_theme_constant_override("shadow_offset_y", int(st["shadow_offset_y"]))
		rtl.add_theme_constant_override("shadow_outline_size", int(st["shadow_outline_size"]))
		rtl.clip_contents = bool(st["clip_text"])
		rtl.texture_filter = ctrl.texture_filter

	var has_align_props := ("horizontal_alignment" in rtl) and ("vertical_alignment" in rtl)
	if need_rebuild:
		ctrl.set_meta(_META_STATE_SIG, state_sig)
		rtl.add_theme_font_override("normal_font", font)
		rtl.add_theme_font_size_override("normal_font_size", font_size)
		rtl.add_theme_constant_override("line_separation", line_sep)
		rtl.autowrap_mode = autowrap

		var fallback_align_tag := ""
		if has_align_props:
			rtl.set("horizontal_alignment", h_align)
			rtl.set("vertical_alignment", v_align)
		else:
			if h_align == HORIZONTAL_ALIGNMENT_CENTER:
				fallback_align_tag = "center"
			elif h_align == HORIZONTAL_ALIGNMENT_RIGHT:
				fallback_align_tag = "right"

		_populate_rich_text_label(rtl, raw_text, default_icon_h, true, font, font_size, fallback_align_tag)

	var content_sz := _measure_text_size(raw_text, font, font_size, float(line_sep), wrap_w, default_icon_h)
	var extra_outline := float(maxi(0, int(st["outline_size"]))) * 0.5
	var base_min: Vector2 = ctrl.get_meta(_META_BASE_MIN_SIZE, Vector2.ZERO) as Vector2
	var needed_min_w := base_min.x if autowrap != TextServer.AUTOWRAP_OFF else maxf(base_min.x, ceilf(content_sz.x + pad_l + pad_r + extra_outline))
	var needed_min_h := maxf(base_min.y, ceilf(content_sz.y + pad_t + pad_b + extra_outline))
	if autowrap != TextServer.AUTOWRAP_OFF and rtl.is_inside_tree():
		var actual_ch := float(rtl.get_content_height())
		if actual_ch > 0.0:
			needed_min_h = maxf(needed_min_h, ceilf(actual_ch + pad_t + pad_b + extra_outline))

	var target_min := Vector2(needed_min_w, needed_min_h)
	if absf(ctrl.custom_minimum_size.x - target_min.x) > 1.0 or absf(ctrl.custom_minimum_size.y - target_min.y) > 1.0:
		ctrl.custom_minimum_size = target_min

	rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rtl.offset_left = pad_l
	rtl.offset_right = -pad_r
	if has_align_props:
		rtl.offset_top = pad_t
		rtl.offset_bottom = -pad_b
	else:
		var inner_h := maxf(0.0, ctrl.size.y - pad_t - pad_b)
		var v_off := 0.0
		if v_align == VERTICAL_ALIGNMENT_CENTER and inner_h > content_sz.y:
			v_off = (inner_h - content_sz.y) * 0.5
		elif v_align == VERTICAL_ALIGNMENT_BOTTOM and inner_h > content_sz.y:
			v_off = inner_h - content_sz.y
		rtl.offset_top = pad_t + v_off
		rtl.offset_bottom = -pad_b

	if str(ctrl.get("text")) != _SENTINEL_TEXT:
		ctrl.set("text", _SENTINEL_TEXT)


static func _compute_dialogue_shifts(bbcode_source: String, font: Font, font_size: int, default_icon_h: int) -> Array[Dictionary]:
	var shifts: Array[Dictionary] = []
	if not has_icons(bbcode_source):
		return shifts

	var matches := _get_regex().search_all(bbcode_source)
	var token_by_start: Dictionary = {}
	for m in matches:
		var start := m.get_start()
		var end := m.get_end()
		if start > 0 and bbcode_source[start - 1] == "{" and end < bbcode_source.length() and bbcode_source[end] == "}":
			continue
		if has_icon(m.get_string(1)):
			token_by_start[start] = m

	var visible_idx := 0
	var i := 0
	var n := bbcode_source.length()
	while i < n:
		if token_by_start.has(i):
			var tok := token_by_start[i] as RegExMatch
			var tok_len := tok.get_end() - tok.get_start()
			var _dims := _resolve_token_dimensions(tok.get_string(1).to_lower().strip_edges(), tok.get_string(2), tok.get_string(3), font, font_size, default_icon_h)
			shifts.append({
				"visible_pos": visible_idx,
				"visible_len": tok_len,
			})
			visible_idx += tok_len
			i = tok.get_end()
			continue

		if bbcode_source[i] == "[":
			var close := bbcode_source.find("]", i + 1)
			if close != -1:
				var tag_inner := bbcode_source.substr(i + 1, close - i - 1).strip_edges().to_lower()
				if tag_inner == "lb":
					visible_idx += 1
					i = close + 1
					continue
				if tag_inner.begins_with("img"):
					var end_img := bbcode_source.find("[/img]", close + 1)
					if end_img != -1:
						visible_idx += 1
						i = end_img + 6
						continue
				i = close + 1
				continue

		visible_idx += 1
		i += 1

	return shifts


static func _shift_marker_index(old_idx: int, shifts: Array[Dictionary]) -> int:
	var new_idx := old_idx
	for s in shifts:
		var vpos: int = int(s["visible_pos"])
		var vlen: int = int(s["visible_len"])
		var delta := 1 - vlen
		if old_idx >= vpos + vlen:
			new_idx += delta
		elif old_idx > vpos:
			new_idx = vpos + 1
	return maxi(0, new_idx)


static func _sync_dialogue_or_rich_text(rtl: RichTextLabel) -> void:
	if not is_instance_valid(rtl):
		return
	var raw_text := rtl.text
	if not has_icons(raw_text):
		return

	var font := rtl.get_theme_font("normal_font")
	var font_size := rtl.get_theme_font_size("normal_font_size")
	var default_icon_h := get_default_icon_height(font, font_size)

	var line: Variant = rtl.get("dialogue_line") if "dialogue_line" in rtl else null
	if line != null and line is Object and not (line as Object).get_meta(_META_SHIFTED, false):
		var line_obj := line as Object
		var shifts := _compute_dialogue_shifts(raw_text, font, font_size, default_icon_h)
		if not shifts.is_empty():
			var raw_pauses: Variant = line_obj.get("pauses") if "pauses" in line_obj else null
			if raw_pauses is Dictionary:
				var old_pauses: Dictionary = raw_pauses as Dictionary
				var new_pauses: Dictionary = {}
				for k in old_pauses.keys():
					new_pauses[_shift_marker_index(int(k), shifts)] = old_pauses[k]
				line_obj.set("pauses", new_pauses)
			var raw_speeds: Variant = line_obj.get("speeds") if "speeds" in line_obj else null
			if raw_speeds is Dictionary:
				var old_speeds: Dictionary = raw_speeds as Dictionary
				var new_speeds: Dictionary = {}
				for k in old_speeds.keys():
					new_speeds[_shift_marker_index(int(k), shifts)] = old_speeds[k]
				line_obj.set("speeds", new_speeds)
			var raw_muts: Variant = line_obj.get("inline_mutations") if "inline_mutations" in line_obj else null
			if raw_muts is Array:
				var muts: Array = raw_muts as Array
				for mut in muts:
					if mut is Array and (mut as Array).size() > 0:
						(mut as Array)[0] = _shift_marker_index(int((mut as Array)[0]), shifts)
		line_obj.set_meta(_META_SHIFTED, true)

	var prev_vis := rtl.visible_characters
	_populate_rich_text_label(rtl, raw_text, default_icon_h, false, font, font_size)
	if line != null and line is Object and "text" in (line as Object) and rtl.text != raw_text:
		(line as Object).set("text", rtl.text)
	if prev_vis >= 0:
		rtl.visible_characters = prev_vis


static func _sync_label3d(lbl: Label3D, raw_text_override: String = _USE_NODE_TEXT) -> void:
	if not is_instance_valid(lbl):
		return
	var raw_text := ""
	if raw_text_override != _USE_NODE_TEXT:
		raw_text = raw_text_override
	elif lbl.has_meta(_META_SENTINEL) and lbl.text == str(lbl.get_meta(_META_SENTINEL)):
		raw_text = str(lbl.get_meta(_META_RAW_TEXT, ""))
	else:
		raw_text = lbl.text

	if not has_icons(raw_text):
		var had_overlay := lbl.has_meta(_META_SENTINEL)
		if had_overlay:
			var old_sp := lbl.get_node_or_null(_OVERLAY_3D_NAME)
			if is_instance_valid(old_sp):
				lbl.remove_child(old_sp)
				old_sp.queue_free()
			lbl.remove_meta(_META_RAW_TEXT)
			lbl.remove_meta(_META_SENTINEL)
			lbl.remove_meta(_META_STATE_SIG)
		if raw_text_override != _USE_NODE_TEXT or (had_overlay and lbl.text == _SENTINEL_TEXT):
			lbl.text = raw_text
		return

	lbl.set_meta(_META_RAW_TEXT, raw_text)
	lbl.set_meta(_META_SENTINEL, _SENTINEL_TEXT)

	var sprite := lbl.get_node_or_null(_OVERLAY_3D_NAME) as Sprite3D
	var sv: SubViewport = null
	var rtl: RichTextLabel = null
	if not is_instance_valid(sprite):
		sprite = Sprite3D.new()
		sprite.name = _OVERLAY_3D_NAME
		sprite.transparent = true
		lbl.add_child(sprite)
		sv = SubViewport.new()
		sv.name = "SubViewport"
		sv.transparent_bg = true
		sv.gui_disable_input = true
		sv.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
		sprite.add_child(sv)
		rtl = RichTextLabel.new()
		rtl.name = _OVERLAY_NAME
		rtl.bbcode_enabled = true
		rtl.fit_content = false
		rtl.scroll_active = false
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		sv.add_child(rtl)
	else:
		sv = sprite.get_node_or_null("SubViewport") as SubViewport
		rtl = sv.get_node_or_null(_OVERLAY_NAME) as RichTextLabel if sv else null

	if not is_instance_valid(sv) or not is_instance_valid(rtl):
		return

	var font: Font = lbl.font if lbl.font else ThemeDB.fallback_font
	var font_size := maxi(1, lbl.font_size)
	var default_icon_h := get_default_icon_height(font, font_size)
	var wrap_w := maxf(lbl.width, 32.0) if lbl.autowrap_mode != TextServer.AUTOWRAP_OFF else 0.0
	var font_id: int = font.get_rid().get_id() if font else 0
	var sig := "%s|%d|%d|%s|%s|%d|%f|%d|%d|%d|%f" % [
		raw_text,
		font_id,
		font_size,
		str(lbl.modulate),
		str(lbl.outline_modulate),
		lbl.outline_size,
		lbl.pixel_size,
		int(lbl.horizontal_alignment),
		int(lbl.vertical_alignment),
		int(lbl.autowrap_mode),
		wrap_w,
	]

	if str(lbl.get_meta(_META_STATE_SIG, "")) != sig:
		lbl.set_meta(_META_STATE_SIG, sig)
		rtl.add_theme_font_override("normal_font", font)
		rtl.add_theme_font_size_override("normal_font_size", font_size)
		rtl.add_theme_color_override("default_color", Color.WHITE)
		rtl.add_theme_color_override("font_outline_color", lbl.outline_modulate)
		rtl.add_theme_constant_override("outline_size", lbl.outline_size)
		rtl.add_theme_constant_override("line_separation", roundi(lbl.line_spacing))
		rtl.autowrap_mode = lbl.autowrap_mode

		var has_align_props := ("horizontal_alignment" in rtl) and ("vertical_alignment" in rtl)
		var fallback_tag := ""
		if has_align_props:
			rtl.set("horizontal_alignment", lbl.horizontal_alignment)
			rtl.set("vertical_alignment", lbl.vertical_alignment)
		elif lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			fallback_tag = "center"
		elif lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			fallback_tag = "right"

		_populate_rich_text_label(rtl, raw_text, default_icon_h, true, font, font_size, fallback_tag)
		var content_sz := _measure_text_size(raw_text, font, font_size, lbl.line_spacing, wrap_w, default_icon_h)
		var pad := float(maxi(2, lbl.outline_size))
		var sv_w := maxi(2, ceili((wrap_w if wrap_w > 0.0 else content_sz.x) + pad * 2.0))
		var sv_h := maxi(2, ceili(content_sz.y + pad * 2.0))
		sv.size = Vector2i(sv_w, sv_h)
		rtl.position = Vector2(pad, pad)
		rtl.size = Vector2(float(sv_w) - pad * 2.0, float(sv_h) - pad * 2.0)

		var off := lbl.offset
		if lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
			off.x += float(sv_w) * 0.5
		elif lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			off.x -= float(sv_w) * 0.5
		if lbl.vertical_alignment == VERTICAL_ALIGNMENT_TOP:
			off.y -= float(sv_h) * 0.5
		elif lbl.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
			off.y += float(sv_h) * 0.5
		sprite.offset = off

	sprite.texture = sv.get_texture()
	sprite.pixel_size = lbl.pixel_size
	sprite.billboard = lbl.billboard
	sprite.no_depth_test = lbl.no_depth_test
	sprite.shaded = lbl.shaded
	match lbl.alpha_cut:
		Label3D.ALPHA_CUT_DISCARD:
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		Label3D.ALPHA_CUT_OPAQUE_PREPASS:
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		Label3D.ALPHA_CUT_HASH:
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_HASH
		_:
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = lbl.texture_filter
	sprite.render_priority = lbl.render_priority
	sprite.modulate = lbl.modulate

	if lbl.text != _SENTINEL_TEXT:
		lbl.text = _SENTINEL_TEXT


static func _sync_node(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node.name == _OVERLAY_NAME or node.name == _OVERLAY_3D_NAME:
		return
	if node is RichTextLabel:
		var rtl := node as RichTextLabel
		if rtl.text.contains("{"):
			_sync_dialogue_or_rich_text(rtl)
	elif node is Label:
		var lbl := node as Label
		if lbl.has_meta(_META_SENTINEL) or lbl.text.contains("{"):
			apply_to_control(lbl)
	elif node is Button and not (node is OptionButton):
		var btn := node as Button
		if btn.has_meta(_META_SENTINEL) or btn.text.contains("{"):
			apply_to_control(btn)
	elif node is Label3D:
		var lbl3 := node as Label3D
		if lbl3.has_meta(_META_SENTINEL) or lbl3.text.contains("{"):
			_sync_label3d(lbl3)


class TextIconsRuntime extends Node:
	var _watched_nodes: Array[Node] = []
	var _watched_ids: Dictionary = {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -100
		var tree := get_tree()
		if not tree:
			return
		if not tree.node_added.is_connected(_on_node_added):
			tree.node_added.connect(_on_node_added)
		if tree.root:
			_scan_recursive(tree.root)
			var dm := tree.root.get_node_or_null("DialogueManager")
			if dm and dm.has_signal("got_dialogue"):
				if not dm.got_dialogue.is_connected(_on_got_dialogue):
					dm.got_dialogue.connect(_on_got_dialogue)

	func _scan_recursive(root: Node) -> void:
		_register_node(root)
		for child in root.get_children():
			_scan_recursive(child)

	func _on_node_added(node: Node) -> void:
		_register_node(node)

	func _register_node(node: Node) -> void:
		if not is_instance_valid(node):
			return
		if node.name == _OVERLAY_NAME or node.name == _OVERLAY_3D_NAME:
			return
		var is_supported := (
			node is RichTextLabel
			or node is Label
			or node is Label3D
			or (node is Button and not (node is OptionButton))
		)
		if not is_supported:
			return

		var id := node.get_instance_id()
		if not _watched_ids.has(id):
			_watched_ids[id] = true
			_watched_nodes.append(node)

		if node is RichTextLabel and node.has_signal("started_typing"):
			var cb := _on_started_typing.bind(node)
			if not node.started_typing.is_connected(cb):
				node.started_typing.connect(cb)

		if node.is_inside_tree():
			TextIcons._sync_node(node)
		if not node.is_node_ready():
			call_deferred("_deferred_sync", node)

	func _deferred_sync(node: Node) -> void:
		if is_instance_valid(node) and node.is_inside_tree():
			TextIcons._sync_node(node)

	func _on_started_typing(node: Node) -> void:
		if is_instance_valid(node) and node.is_inside_tree():
			TextIcons._sync_node(node)

	func _on_got_dialogue(_line: Variant) -> void:
		_sync_all_watched()

	func _process(_delta: float) -> void:
		_sync_all_watched()

	func _sync_all_watched() -> void:
		var i := _watched_nodes.size() - 1
		while i >= 0:
			var node := _watched_nodes[i]
			if not is_instance_valid(node) or not node.is_inside_tree():
				if is_instance_valid(node):
					_watched_ids.erase(node.get_instance_id())
				else:
					for key_id in _watched_ids.keys():
						if not is_instance_id_valid(int(key_id)):
							_watched_ids.erase(key_id)
				var last_idx := _watched_nodes.size() - 1
				if i != last_idx:
					_watched_nodes[i] = _watched_nodes[last_idx]
				_watched_nodes.pop_back()
			else:
				TextIcons._sync_node(node)
			i -= 1
