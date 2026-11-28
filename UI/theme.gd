class_name InkTheme
extends RefCounted

const FONT_PATH := "res://Assets/Font/Merchant Copy.ttf"

const INK_DARK := Color("#1E1A16")
const INK_MID := Color("#3B332C")
const INK_SOFT := Color("#6E655B")
const INK_SEPIA_TITLE := Color("#5D422C")

const PAPER_CREAM := Color("#FAF5E4")
const PAPER_LIGHT := Color("#FFFDF7")
const PAPER_HOVER := Color("#F6E9CB")
const PAPER_PRESSED := Color("#E4D7BA")
const PAPER_DISABLED := Color("#DDD7CB")

const WOOD_BROWN := Color("#93765D")
const WOOD_BROWN_HOVER := Color("#A38469")
const WOOD_BROWN_PRESSED := Color("#82664F")

const GOLD_ACTIVE := Color("#E0B354")
const GOLD_HOVER := Color("#ECC36B")
const GOLD_PRESSED := Color("#CCA044")

const CORAL_PRIMARY := Color("#DD6B4B")
const CORAL_HOVER := Color("#EA7B5B")
const CORAL_PRESSED := Color("#C35638")

const GRAY_MUTED := Color("#A6A29C")
const GRAY_MUTED_HOVER := Color("#B5B1AB")
const GRAY_MUTED_PRESSED := Color("#908C86")

const KRAFT_CARD := Color("#EFE6D0")
const DIVIDER_INK := Color("#2B231C")

const BOIL_FRAMES := 3
const BOIL_INTERVAL := 0.135

const EXCLUDED_ANCESTORS: Array[String] = [
	"Patience",
	"Recipt",
	"NameTag",
	"HudIndicators",
	"ToolCircle",
	"BloodMinigame",
	"LemonMinigame",
	"IceMinigame",
	"ShakeMinigame",
	"ChoiceButton",
	"Keys",
]

static var _initialized: bool = false
static var _font: Font = null
static var _textures: Dictionary = {}
static var _texture_frames: Dictionary = {}
static var _animated_styleboxes: Array[Dictionary] = []
static var _boil_frame: int = 0
static var _icons: Dictionary = {}
static var _theme_std: Theme = null
static var _theme_compact: Theme = null
static var _runtime: InkPaperRuntime = null


static func install(host: Node) -> Node:
	if not is_instance_valid(host):
		return null
	_ensure_loaded()
	var existing := host.get_node_or_null("InkPaperRuntime")
	if is_instance_valid(existing):
		_runtime = existing as InkPaperRuntime
		return existing
	var runtime := InkPaperRuntime.new()
	runtime.name = "InkPaperRuntime"
	host.add_child(runtime)
	_runtime = runtime
	return runtime


static func get_font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH) as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


static func _ensure_loaded() -> void:
	if _initialized:
		return
	_initialized = true
	get_font()
	_build_all_textures()
	_build_all_icons()
	_theme_std = _build_theme(false)
	_theme_compact = _build_theme(true)


static func get_theme() -> Theme:
	_ensure_loaded()
	return _theme_std


static func get_compact_theme() -> Theme:
	_ensure_loaded()
	return _theme_compact


static func _register_boil_variant(
	key: String,
	fill_color: Color,
	border_color: Color,
	tex_size: int,
	margin: int,
	radius: float,
	half_stroke: float,
	wobble_amp: float,
	base_seed: int,
	wood_grain: bool,
	subtle_shadow: bool,
	sketchy_scribble: bool
) -> void:
	var frames: Array[Texture2D] = []
	for f in BOIL_FRAMES:
		var tex := _generate_box_texture(
			fill_color,
			border_color,
			tex_size,
			margin,
			radius,
			half_stroke,
			wobble_amp,
			base_seed + f * 997,
			wood_grain,
			subtle_shadow,
			sketchy_scribble
		)
		frames.append(tex)
	_texture_frames[key] = frames
	_textures[key] = frames[0]


static func _build_all_textures() -> void:
	_textures["cream_std"] = _generate_box_texture(PAPER_CREAM, INK_DARK, 128, 14, 8.0, 1.45, 0.85, 101, false, true, false)
	_textures["cream_cmp"] = _generate_box_texture(PAPER_CREAM, INK_DARK, 64, 8, 5.0, 1.15, 0.55, 102, false, false, false)

	_textures["paper_std"] = _generate_box_texture(PAPER_LIGHT, INK_DARK, 128, 14, 8.0, 1.40, 0.85, 201, false, true, false)
	_textures["paper_cmp"] = _generate_box_texture(PAPER_LIGHT, INK_DARK, 64, 8, 5.0, 1.12, 0.55, 202, false, false, false)

	_register_boil_variant("hover_std", PAPER_HOVER, INK_DARK, 112, 14, 8.0, 1.45, 1.25, 301, false, true, true)
	_register_boil_variant("hover_cmp", PAPER_HOVER, INK_DARK, 56, 8, 5.0, 1.15, 0.80, 302, false, false, true)

	_register_boil_variant("pressed_std", PAPER_PRESSED, INK_DARK, 112, 14, 8.0, 1.50, 1.10, 401, false, false, true)
	_register_boil_variant("pressed_cmp", PAPER_PRESSED, INK_DARK, 56, 8, 5.0, 1.18, 0.72, 402, false, false, true)

	_textures["disabled_std"] = _generate_box_texture(PAPER_DISABLED, INK_SOFT, 128, 14, 8.0, 1.25, 0.70, 501, false, false, false)
	_textures["disabled_cmp"] = _generate_box_texture(PAPER_DISABLED, INK_SOFT, 64, 8, 5.0, 1.05, 0.45, 502, false, false, false)

	_textures["primary_std"] = _generate_box_texture(CORAL_PRIMARY, INK_DARK, 128, 14, 8.0, 1.45, 0.85, 601, false, true, false)
	_textures["primary_cmp"] = _generate_box_texture(CORAL_PRIMARY, INK_DARK, 64, 8, 5.0, 1.15, 0.55, 602, false, false, false)
	_register_boil_variant("primary_hover_std", CORAL_HOVER, INK_DARK, 112, 14, 8.0, 1.48, 1.25, 603, false, true, true)
	_register_boil_variant("primary_hover_cmp", CORAL_HOVER, INK_DARK, 56, 8, 5.0, 1.18, 0.80, 604, false, false, true)
	_register_boil_variant("primary_pressed_std", CORAL_PRESSED, INK_DARK, 112, 14, 8.0, 1.50, 1.10, 605, false, false, true)
	_register_boil_variant("primary_pressed_cmp", CORAL_PRESSED, INK_DARK, 56, 8, 5.0, 1.20, 0.72, 606, false, false, true)

	_textures["gold_std"] = _generate_box_texture(GOLD_ACTIVE, INK_DARK, 128, 14, 8.0, 1.45, 0.82, 701, false, true, false)
	_textures["gold_cmp"] = _generate_box_texture(GOLD_ACTIVE, INK_DARK, 64, 8, 5.0, 1.15, 0.52, 702, false, false, false)
	_register_boil_variant("gold_hover_std", GOLD_HOVER, INK_DARK, 112, 14, 8.0, 1.48, 1.25, 703, false, true, true)
	_register_boil_variant("gold_hover_cmp", GOLD_HOVER, INK_DARK, 56, 8, 5.0, 1.18, 0.80, 704, false, false, true)
	_register_boil_variant("gold_pressed_std", GOLD_PRESSED, INK_DARK, 112, 14, 8.0, 1.50, 1.10, 705, false, false, true)
	_register_boil_variant("gold_pressed_cmp", GOLD_PRESSED, INK_DARK, 56, 8, 5.0, 1.20, 0.72, 706, false, false, true)

	_textures["gold_static_std"] = _generate_box_texture(GOLD_ACTIVE, INK_DARK, 128, 14, 8.0, 1.45, 0.82, 751, false, true, false)

	_textures["muted_std"] = _generate_box_texture(GRAY_MUTED, INK_DARK, 128, 14, 8.0, 1.42, 0.80, 801, false, true, false)
	_textures["muted_cmp"] = _generate_box_texture(GRAY_MUTED, INK_DARK, 64, 8, 5.0, 1.12, 0.50, 802, false, false, false)
	_register_boil_variant("muted_hover_std", GRAY_MUTED_HOVER, INK_DARK, 112, 14, 8.0, 1.45, 1.20, 803, false, true, true)
	_register_boil_variant("muted_hover_cmp", GRAY_MUTED_HOVER, INK_DARK, 56, 8, 5.0, 1.15, 0.76, 804, false, false, true)
	_register_boil_variant("muted_pressed_std", GRAY_MUTED_PRESSED, INK_DARK, 112, 14, 8.0, 1.48, 1.05, 805, false, false, true)
	_register_boil_variant("muted_pressed_cmp", GRAY_MUTED_PRESSED, INK_DARK, 56, 8, 5.0, 1.18, 0.70, 806, false, false, true)

	_textures["wood_std"] = _generate_box_texture(WOOD_BROWN, INK_DARK, 128, 14, 7.0, 1.45, 0.80, 901, true, true, false)
	_textures["wood_cmp"] = _generate_box_texture(WOOD_BROWN, INK_DARK, 64, 8, 5.0, 1.15, 0.50, 902, true, false, false)
	_register_boil_variant("wood_hover_std", WOOD_BROWN_HOVER, INK_DARK, 112, 14, 7.0, 1.48, 1.20, 903, true, true, true)
	_register_boil_variant("wood_pressed_std", WOOD_BROWN_PRESSED, INK_DARK, 112, 14, 7.0, 1.50, 1.05, 905, true, false, true)

	_textures["kraft_std"] = _generate_box_texture(KRAFT_CARD, INK_DARK, 128, 14, 8.0, 1.45, 0.85, 1001, false, true, false)
	_register_boil_variant("focus_ring", Color(0, 0, 0, 0), Color(0.88, 0.67, 0.24, 0.88), 56, 8, 5.0, 1.15, 0.75, 1101, false, false, true)
	_register_boil_variant("soft_hover_pill", Color(0.95, 0.90, 0.78, 0.75), Color(0.12, 0.10, 0.08, 0.42), 56, 8, 5.0, 0.85, 0.65, 1201, false, false, true)

	_textures["divider_h"] = _generate_divider_texture(false, DIVIDER_INK, 128, 8, 1301)
	_textures["divider_v"] = _generate_divider_texture(true, DIVIDER_INK, 128, 8, 1302)
	_textures["scroll_track"] = _generate_box_texture(Color(0.90, 0.86, 0.76, 0.55), Color(0.12, 0.10, 0.08, 0.30), 48, 6, 4.0, 0.80, 0.30, 1401, false, false, false)
	_textures["scroll_grabber"] = _generate_box_texture(Color("#FFFFFF"), INK_DARK, 48, 6, 4.5, 1.15, 0.38, 1402, false, false, false)
	_register_boil_variant("scroll_grabber_hl", PAPER_CREAM, INK_DARK, 48, 6, 4.5, 1.25, 0.65, 1403, false, false, true)
	_register_boil_variant("scroll_grabber_pr", GOLD_ACTIVE, INK_DARK, 48, 6, 4.5, 1.25, 0.65, 1404, false, false, true)

	_textures["beer_slider_fill"] = _generate_dithered_beer_gradient_texture(180, 5)
	_textures["beer_slider_track"] = _generate_pixel_slider_track_texture(48, 6)


static func _build_all_icons() -> void:
	_icons["toggle_on"] = _create_toggle_icon(true, false)
	_icons["toggle_off"] = _create_toggle_icon(false, false)
	_icons["toggle_on_dis"] = _create_toggle_icon(true, true)
	_icons["toggle_off_dis"] = _create_toggle_icon(false, true)

	_icons["check_on"] = _create_checkbox_icon(true, false, false)
	_icons["check_off"] = _create_checkbox_icon(false, false, false)
	_icons["check_on_dis"] = _create_checkbox_icon(true, false, true)
	_icons["check_off_dis"] = _create_checkbox_icon(false, false, true)

	_icons["radio_on"] = _create_checkbox_icon(true, true, false)
	_icons["radio_off"] = _create_checkbox_icon(false, true, false)
	_icons["radio_on_dis"] = _create_checkbox_icon(true, true, true)
	_icons["radio_off_dis"] = _create_checkbox_icon(false, true, true)

	_icons["arrow_down"] = _create_arrow_icon(false)
	_icons["arrow_right"] = _create_arrow_icon(true)
	_icons["empty_1x1"] = _create_empty_icon()


static func _track_animated_stylebox(sb: StyleBoxTexture, key: String) -> void:
	if not _texture_frames.has(key):
		return
	var frames: Array = _texture_frames[key] as Array
	if frames.size() <= 1:
		return
	var phase: int = absi(hash(key)) % frames.size()
	sb.texture = frames[(_boil_frame + phase) % frames.size()] as Texture2D
	_animated_styleboxes.append({
		"ref": weakref(sb),
		"frames": frames,
		"phase": phase,
	})


static func _tick_scribble_animation() -> void:
	_boil_frame = (_boil_frame + 1) % BOIL_FRAMES
	var i := _animated_styleboxes.size() - 1
	while i >= 0:
		var entry: Dictionary = _animated_styleboxes[i]
		var wr: WeakRef = entry["ref"] as WeakRef
		var obj: Variant = wr.get_ref() if wr else null
		if not is_instance_valid(obj) or not (obj is StyleBoxTexture):
			var last := _animated_styleboxes.size() - 1
			if i != last:
				_animated_styleboxes[i] = _animated_styleboxes[last]
			_animated_styleboxes.pop_back()
		else:
			var sb := obj as StyleBoxTexture
			var frames: Array = entry["frames"] as Array
			var phase := int(entry["phase"])
			sb.texture = frames[(_boil_frame + phase) % frames.size()] as Texture2D
		i -= 1


static func make_box_style(variant: String = "paper", compact: bool = false, content_pad: Vector4 = Vector4(-1.0, -1.0, -1.0, -1.0)) -> StyleBoxTexture:
	_ensure_loaded()
	var suffix := "_cmp" if compact else "_std"
	var clean := variant.to_lower().strip_edges()
	var key := clean + suffix
	if not _textures.has(key):
		if _textures.has(clean + "_std"):
			key = clean + "_std"
		elif _textures.has(clean):
			key = clean
		else:
			key = "paper" + suffix

	var tex := _textures[key] as Texture2D
	var margin := 8.0 if compact else 14.0
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.draw_center = true

	if content_pad.x >= 0.0:
		sb.content_margin_left = content_pad.x
		sb.content_margin_top = content_pad.y
		sb.content_margin_right = content_pad.z
		sb.content_margin_bottom = content_pad.w
	elif compact:
		sb.content_margin_left = 8.0
		sb.content_margin_top = 3.0
		sb.content_margin_right = 8.0
		sb.content_margin_bottom = 3.0
	else:
		sb.content_margin_left = 14.0
		sb.content_margin_top = 7.0
		sb.content_margin_right = 14.0
		sb.content_margin_bottom = 7.0

	_track_animated_stylebox(sb, key)
	return sb


static func make_focus_style() -> StyleBoxTexture:
	_ensure_loaded()
	var sb := StyleBoxTexture.new()
	sb.texture = _textures["focus_ring"] as Texture2D
	sb.texture_margin_left = 8.0
	sb.texture_margin_top = 8.0
	sb.texture_margin_right = 8.0
	sb.texture_margin_bottom = 8.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.draw_center = false
	sb.expand_margin_left = 2.0
	sb.expand_margin_top = 2.0
	sb.expand_margin_right = 2.0
	sb.expand_margin_bottom = 2.0
	_track_animated_stylebox(sb, "focus_ring")
	return sb


static func make_soft_hover_style() -> StyleBoxTexture:
	_ensure_loaded()
	var sb := StyleBoxTexture.new()
	sb.texture = _textures["soft_hover_pill"] as Texture2D
	sb.texture_margin_left = 8.0
	sb.texture_margin_top = 8.0
	sb.texture_margin_right = 8.0
	sb.texture_margin_bottom = 8.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.draw_center = true
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	sb.expand_margin_left = 8.0
	sb.expand_margin_top = 3.0
	sb.expand_margin_right = 8.0
	sb.expand_margin_bottom = 3.0
	_track_animated_stylebox(sb, "soft_hover_pill")
	return sb


static func make_divider_style(vertical: bool = false) -> StyleBoxTexture:
	_ensure_loaded()
	var sb := StyleBoxTexture.new()
	sb.texture = _textures["divider_v" if vertical else "divider_h"] as Texture2D
	if vertical:
		sb.texture_margin_left = 0.0
		sb.texture_margin_right = 0.0
		sb.texture_margin_top = 4.0
		sb.texture_margin_bottom = 4.0
		sb.content_margin_left = 2.0
		sb.content_margin_right = 2.0
	else:
		sb.texture_margin_left = 4.0
		sb.texture_margin_right = 4.0
		sb.texture_margin_top = 0.0
		sb.texture_margin_bottom = 0.0
		sb.content_margin_top = 2.0
		sb.content_margin_bottom = 2.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.draw_center = true
	return sb


static func make_scrollbar_style(role: String, vertical: bool) -> StyleBoxTexture:
	_ensure_loaded()
	var key := "scroll_track"
	match role:
		"grabber":
			key = "scroll_grabber"
		"highlight":
			key = "scroll_grabber_hl"
		"pressed":
			key = "scroll_grabber_pr"

	var sb := StyleBoxTexture.new()
	sb.texture = _textures[key] as Texture2D
	sb.texture_margin_left = 6.0
	sb.texture_margin_top = 6.0
	sb.texture_margin_right = 6.0
	sb.texture_margin_bottom = 6.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.draw_center = true
	if vertical:
		sb.content_margin_left = 6.0
		sb.content_margin_right = 6.0
		sb.content_margin_top = 3.0
		sb.content_margin_bottom = 3.0
	else:
		sb.content_margin_left = 3.0
		sb.content_margin_right = 3.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 6.0
	_track_animated_stylebox(sb, key)
	return sb


static func apply_dithered_beer_slider(slider: HSlider) -> void:
	if not is_instance_valid(slider):
		return
	_ensure_loaded()
	slider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slider.set_meta("_ink_paper_styled", true)

	var empty_track := StyleBoxEmpty.new()
	empty_track.content_margin_top = 8.0
	empty_track.content_margin_bottom = 8.0
	var empty_fill := StyleBoxEmpty.new()

	slider.add_theme_stylebox_override("slider", empty_track)
	slider.add_theme_stylebox_override("grabber_area", empty_fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", empty_fill)

	var track := slider.get_node_or_null("__BeerSliderTrack") as _BeerSliderTrack
	if not is_instance_valid(track):
		track = _BeerSliderTrack.new()
		track.name = "__BeerSliderTrack"
		slider.add_child(track)
	track.bind_slider(slider)


static func _build_theme(compact: bool) -> Theme:
	var t := Theme.new()
	var fnt := get_font()
	t.default_font = fnt
	t.default_font_size = 15 if compact else 24

	var normal_sb := make_box_style("paper", compact)
	var hover_sb := make_box_style("hover", compact)
	var pressed_sb := make_box_style("pressed", compact)
	pressed_sb.content_margin_top += 1.0
	pressed_sb.content_margin_bottom = maxf(1.0, pressed_sb.content_margin_bottom - 1.0)
	var disabled_sb := make_box_style("disabled", compact)
	var focus_sb := StyleBoxEmpty.new()

	for cls_name in ["Button", "MenuButton", "ColorPickerButton"]:
		t.set_stylebox("normal", cls_name, normal_sb)
		t.set_stylebox("hover", cls_name, hover_sb)
		t.set_stylebox("pressed", cls_name, pressed_sb)
		t.set_stylebox("disabled", cls_name, disabled_sb)
		t.set_stylebox("focus", cls_name, focus_sb)
		t.set_color("font_color", cls_name, INK_DARK)
		t.set_color("font_hover_color", cls_name, INK_DARK)
		t.set_color("font_pressed_color", cls_name, INK_DARK)
		t.set_color("font_focus_color", cls_name, INK_DARK)
		t.set_color("font_disabled_color", cls_name, INK_SOFT)
		t.set_color("font_outline_color", cls_name, Color(0, 0, 0, 0))
		t.set_constant("outline_size", cls_name, 0)
		t.set_font("font", cls_name, fnt)

	t.set_stylebox("normal", "OptionButton", normal_sb)
	t.set_stylebox("hover", "OptionButton", hover_sb)
	t.set_stylebox("pressed", "OptionButton", pressed_sb)
	t.set_stylebox("disabled", "OptionButton", disabled_sb)
	t.set_stylebox("focus", "OptionButton", focus_sb)
	t.set_color("font_color", "OptionButton", INK_DARK)
	t.set_color("font_hover_color", "OptionButton", INK_DARK)
	t.set_color("font_pressed_color", "OptionButton", INK_DARK)
	t.set_color("font_focus_color", "OptionButton", INK_DARK)
	t.set_color("font_disabled_color", "OptionButton", INK_SOFT)
	t.set_color("font_outline_color", "OptionButton", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "OptionButton", 0)
	t.set_constant("arrow_margin", "OptionButton", 6 if compact else 8)
	t.set_icon("arrow", "OptionButton", _icons["arrow_down"] as Texture2D)
	t.set_font("font", "OptionButton", fnt)

	var empty_check_sb := StyleBoxEmpty.new()
	var soft_hover := make_soft_hover_style()
	t.set_stylebox("normal", "CheckButton", empty_check_sb)
	t.set_stylebox("hover", "CheckButton", soft_hover)
	t.set_stylebox("hover_pressed", "CheckButton", soft_hover)
	t.set_stylebox("pressed", "CheckButton", empty_check_sb)
	t.set_stylebox("disabled", "CheckButton", empty_check_sb)
	t.set_stylebox("focus", "CheckButton", focus_sb)
	t.set_color("font_color", "CheckButton", INK_DARK)
	t.set_color("font_hover_color", "CheckButton", INK_DARK)
	t.set_color("font_hover_pressed_color", "CheckButton", INK_DARK)
	t.set_color("font_pressed_color", "CheckButton", INK_DARK)
	t.set_color("font_focus_color", "CheckButton", INK_DARK)
	t.set_color("font_disabled_color", "CheckButton", INK_SOFT)
	t.set_constant("outline_size", "CheckButton", 0)
	t.set_constant("h_separation", "CheckButton", 8)
	t.set_icon("checked", "CheckButton", _icons["toggle_on"] as Texture2D)
	t.set_icon("unchecked", "CheckButton", _icons["toggle_off"] as Texture2D)
	t.set_icon("checked_disabled", "CheckButton", _icons["toggle_on_dis"] as Texture2D)
	t.set_icon("unchecked_disabled", "CheckButton", _icons["toggle_off_dis"] as Texture2D)
	t.set_icon("checked_mirrored", "CheckButton", _icons["toggle_on"] as Texture2D)
	t.set_icon("unchecked_mirrored", "CheckButton", _icons["toggle_off"] as Texture2D)
	t.set_icon("checked_disabled_mirrored", "CheckButton", _icons["toggle_on_dis"] as Texture2D)
	t.set_icon("unchecked_disabled_mirrored", "CheckButton", _icons["toggle_off_dis"] as Texture2D)
	t.set_font("font", "CheckButton", fnt)

	t.set_stylebox("normal", "CheckBox", empty_check_sb)
	t.set_stylebox("hover", "CheckBox", soft_hover)
	t.set_stylebox("hover_pressed", "CheckBox", soft_hover)
	t.set_stylebox("pressed", "CheckBox", empty_check_sb)
	t.set_stylebox("disabled", "CheckBox", empty_check_sb)
	t.set_stylebox("focus", "CheckBox", focus_sb)
	t.set_color("font_color", "CheckBox", INK_DARK)
	t.set_color("font_hover_color", "CheckBox", INK_DARK)
	t.set_color("font_hover_pressed_color", "CheckBox", INK_DARK)
	t.set_color("font_pressed_color", "CheckBox", INK_DARK)
	t.set_color("font_focus_color", "CheckBox", INK_DARK)
	t.set_color("font_disabled_color", "CheckBox", INK_SOFT)
	t.set_constant("outline_size", "CheckBox", 0)
	t.set_constant("h_separation", "CheckBox", 6)
	t.set_icon("checked", "CheckBox", _icons["check_on"] as Texture2D)
	t.set_icon("unchecked", "CheckBox", _icons["check_off"] as Texture2D)
	t.set_icon("checked_disabled", "CheckBox", _icons["check_on_dis"] as Texture2D)
	t.set_icon("unchecked_disabled", "CheckBox", _icons["check_off_dis"] as Texture2D)
	t.set_icon("radio_checked", "CheckBox", _icons["radio_on"] as Texture2D)
	t.set_icon("radio_unchecked", "CheckBox", _icons["radio_off"] as Texture2D)
	t.set_icon("radio_checked_disabled", "CheckBox", _icons["radio_on_dis"] as Texture2D)
	t.set_icon("radio_unchecked_disabled", "CheckBox", _icons["radio_off_dis"] as Texture2D)
	t.set_font("font", "CheckBox", fnt)

	var panel_pad := Vector4(8.0, 6.0, 8.0, 6.0) if compact else Vector4(10.0, 8.0, 10.0, 8.0)
	var cream_panel := make_box_style("cream", compact, panel_pad)
	t.set_stylebox("panel", "Panel", cream_panel)
	t.set_stylebox("panel", "PanelContainer", cream_panel)
	t.set_stylebox("panel", "TooltipPanel", make_box_style("paper", true, Vector4(10.0, 6.0, 10.0, 6.0)))
	t.set_color("font_color", "TooltipLabel", INK_DARK)
	t.set_font("font", "TooltipLabel", fnt)
	t.set_font_size("font_size", "TooltipLabel", 20)

	var popup_panel := make_box_style("cream", true, Vector4(8.0, 10.0, 8.0, 10.0))
	var popup_hover := make_box_style("gold_hover", true, Vector4(10.0, 5.0, 10.0, 5.0))
	popup_hover.texture_margin_top = 5.0
	popup_hover.texture_margin_bottom = 5.0
	t.set_stylebox("panel", "PopupMenu", popup_panel)
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_stylebox("separator", "PopupMenu", make_divider_style(false))
	t.set_stylebox("labeled_separator_left", "PopupMenu", make_divider_style(false))
	t.set_stylebox("labeled_separator_right", "PopupMenu", make_divider_style(false))
	t.set_color("font_color", "PopupMenu", INK_DARK)
	t.set_color("font_hover_color", "PopupMenu", INK_DARK)
	t.set_color("font_accelerator_color", "PopupMenu", INK_SOFT)
	t.set_color("font_disabled_color", "PopupMenu", INK_SOFT)
	t.set_color("font_separator_color", "PopupMenu", INK_SEPIA_TITLE)
	t.set_color("font_outline_color", "PopupMenu", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "PopupMenu", 0)
	t.set_constant("item_start_padding", "PopupMenu", 8)
	t.set_constant("item_end_padding", "PopupMenu", 8)
	t.set_constant("v_separation", "PopupMenu", 12)
	t.set_icon("checked", "PopupMenu", _icons["check_on"] as Texture2D)
	t.set_icon("unchecked", "PopupMenu", _icons["check_off"] as Texture2D)
	t.set_icon("radio_checked", "PopupMenu", _icons["radio_on"] as Texture2D)
	t.set_icon("radio_unchecked", "PopupMenu", _icons["radio_off"] as Texture2D)
	t.set_icon("submenu", "PopupMenu", _icons["arrow_right"] as Texture2D)
	t.set_font("font", "PopupMenu", fnt)
	t.set_font_size("font_size", "PopupMenu", 18 if compact else 22)

	var input_normal := make_box_style("paper", true, Vector4(10.0, 5.0, 10.0, 5.0))
	var input_focus := make_box_style("hover", true, Vector4(10.0, 5.0, 10.0, 5.0))
	var input_ro := make_box_style("disabled", true, Vector4(10.0, 5.0, 10.0, 5.0))
	for input_cls in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", input_cls, input_normal)
		t.set_stylebox("focus", input_cls, input_focus)
		t.set_stylebox("read_only", input_cls, input_ro)
		t.set_color("font_color", input_cls, INK_DARK)
		t.set_color("font_placeholder_color", input_cls, INK_SOFT)
		t.set_color("font_selected_color", input_cls, INK_DARK)
		t.set_color("font_uneditable_color", input_cls, INK_SOFT)
		t.set_color("font_readonly_color", input_cls, INK_SOFT)
		t.set_color("caret_color", input_cls, INK_DARK)
		t.set_color("selection_color", input_cls, Color(0.88, 0.70, 0.33, 0.55))
		t.set_font("font", input_cls, fnt)

	var tab_sel := make_box_style("gold", compact, Vector4(14.0, 6.0, 14.0, 6.0))
	var tab_unsel := make_box_style("paper", compact, Vector4(14.0, 6.0, 14.0, 6.0))
	var tab_hov := make_box_style("gold_hover", compact, Vector4(14.0, 6.0, 14.0, 6.0))
	for tab_cls in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", tab_cls, tab_sel)
		t.set_stylebox("tab_unselected", tab_cls, tab_unsel)
		t.set_stylebox("tab_hovered", tab_cls, tab_hov)
		t.set_stylebox("tab_disabled", tab_cls, disabled_sb)
		t.set_stylebox("tab_focus", tab_cls, focus_sb)
		t.set_color("font_selected_color", tab_cls, INK_DARK)
		t.set_color("font_unselected_color", tab_cls, INK_MID)
		t.set_color("font_hovered_color", tab_cls, INK_DARK)
		t.set_color("font_disabled_color", tab_cls, INK_SOFT)
		t.set_font("font", tab_cls, fnt)
	t.set_stylebox("panel", "TabContainer", cream_panel)

	var empty_icon := _icons["empty_1x1"] as Texture2D
	for vertical in [true, false]:
		var sb_cls := "VScrollBar" if vertical else "HScrollBar"
		t.set_stylebox("scroll", sb_cls, make_scrollbar_style("scroll", vertical))
		t.set_stylebox("scroll_focus", sb_cls, make_scrollbar_style("scroll", vertical))
		t.set_stylebox("grabber", sb_cls, make_scrollbar_style("grabber", vertical))
		t.set_stylebox("grabber_highlight", sb_cls, make_scrollbar_style("highlight", vertical))
		t.set_stylebox("grabber_pressed", sb_cls, make_scrollbar_style("pressed", vertical))
		t.set_icon("increment", sb_cls, empty_icon)
		t.set_icon("decrement", sb_cls, empty_icon)
		t.set_icon("increment_highlight", sb_cls, empty_icon)
		t.set_icon("decrement_highlight", sb_cls, empty_icon)
		t.set_icon("increment_pressed", sb_cls, empty_icon)
		t.set_icon("decrement_pressed", sb_cls, empty_icon)

	t.set_stylebox("separator", "HSeparator", make_divider_style(false))
	t.set_stylebox("separator", "VSeparator", make_divider_style(true))

	t.set_stylebox("panel", "ItemList", cream_panel)
	t.set_stylebox("hovered", "ItemList", hover_sb)
	t.set_stylebox("selected", "ItemList", make_box_style("gold", true))
	t.set_stylebox("selected_focus", "ItemList", make_box_style("gold", true))
	t.set_stylebox("focus", "ItemList", focus_sb)
	t.set_color("font_color", "ItemList", INK_DARK)
	t.set_color("font_selected_color", "ItemList", INK_DARK)
	t.set_font("font", "ItemList", fnt)

	t.set_stylebox("panel", "Tree", cream_panel)
	t.set_color("font_color", "Tree", INK_DARK)
	t.set_color("font_selected_color", "Tree", INK_DARK)
	t.set_font("font", "Tree", fnt)

	t.set_color("font_color", "Label", INK_DARK)
	t.set_font("font", "Label", fnt)
	t.set_color("default_color", "RichTextLabel", INK_DARK)
	t.set_font("normal_font", "RichTextLabel", fnt)

	return t


static func apply_button_variant(btn: BaseButton, variant: String = "paper", compact: bool = false, font_size_override: int = -1) -> void:
	if not is_instance_valid(btn):
		return
	_ensure_loaded()
	btn.set_meta("_ink_paper_styled", true)
	btn.set_meta("_ink_paper_variant", variant)

	var clean := variant.to_lower().strip_edges()
	var n_var := "paper"
	var h_var := "hover"
	var p_var := "pressed"
	var text_col := INK_DARK
	var hover_text_col := INK_DARK

	match clean:
		"primary", "coral":
			n_var = "primary"
			h_var = "primary_hover"
			p_var = "primary_pressed"
			text_col = PAPER_LIGHT
			hover_text_col = Color.WHITE
		"muted", "gray":
			n_var = "muted"
			h_var = "muted_hover"
			p_var = "muted_pressed"
			text_col = PAPER_LIGHT
			hover_text_col = Color.WHITE
		"gold":
			n_var = "gold"
			h_var = "gold_hover"
			p_var = "gold_pressed"
			text_col = INK_DARK
			hover_text_col = INK_DARK
		"wood":
			n_var = "wood"
			h_var = "wood_hover"
			p_var = "wood_pressed"
			text_col = PAPER_LIGHT
			hover_text_col = Color.WHITE
		"cream":
			n_var = "cream"
			h_var = "hover"
			p_var = "pressed"
			text_col = INK_DARK
			hover_text_col = INK_DARK
		_:
			n_var = "paper"
			h_var = "hover"
			p_var = "pressed"
			text_col = INK_DARK
			hover_text_col = INK_DARK

	var normal_sb := make_box_style(n_var, compact)
	var hover_sb := make_box_style(h_var, compact)
	var pressed_sb := make_box_style(p_var, compact)
	pressed_sb.content_margin_top += 1.0
	pressed_sb.content_margin_bottom = maxf(1.0, pressed_sb.content_margin_bottom - 1.0)
	var disabled_sb := make_box_style("disabled", compact)

	btn.set_meta("_ink_normal_sb", normal_sb)
	btn.set_meta("_ink_hover_sb", hover_sb)
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("disabled", disabled_sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", hover_text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_focus_color", text_col)
	btn.add_theme_color_override("font_disabled_color", INK_SOFT)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	btn.add_theme_constant_override("outline_size", 0)
	btn.add_theme_font_override("font", get_font())

	if font_size_override > 0:
		btn.add_theme_font_size_override("font_size", font_size_override)

	if btn is OptionButton:
		var opt := btn as OptionButton
		opt.add_theme_icon_override("arrow", _icons["arrow_down"] as Texture2D)
		opt.add_theme_constant_override("arrow_margin", 6 if compact else 8)
		style_popup_menu(opt.get_popup(), compact)

	TextIcons.sync_control_visuals(btn)


static func set_button_forced_hover(btn: BaseButton, hovered: bool) -> void:
	if not is_instance_valid(btn):
		return
	var sb_key := "_ink_hover_sb" if hovered else "_ink_normal_sb"
	if btn.has_meta(sb_key):
		var sb := btn.get_meta(sb_key) as StyleBox
		if is_instance_valid(sb):
			btn.add_theme_stylebox_override("normal", sb)


static func apply_check_button(cb: CheckButton, font_size_override: int = -1) -> void:
	if not is_instance_valid(cb):
		return
	_ensure_loaded()
	cb.set_meta("_ink_paper_styled", true)
	var empty_sb := StyleBoxEmpty.new()
	var soft_hover := make_soft_hover_style()
	cb.add_theme_stylebox_override("normal", empty_sb)
	cb.add_theme_stylebox_override("hover", soft_hover)
	cb.add_theme_stylebox_override("hover_pressed", soft_hover)
	cb.add_theme_stylebox_override("pressed", empty_sb)
	cb.add_theme_stylebox_override("disabled", empty_sb)
	cb.add_theme_stylebox_override("focus", empty_sb)

	cb.add_theme_icon_override("checked", _icons["toggle_on"] as Texture2D)
	cb.add_theme_icon_override("unchecked", _icons["toggle_off"] as Texture2D)
	cb.add_theme_icon_override("checked_disabled", _icons["toggle_on_dis"] as Texture2D)
	cb.add_theme_icon_override("unchecked_disabled", _icons["toggle_off_dis"] as Texture2D)
	cb.add_theme_icon_override("checked_mirrored", _icons["toggle_on"] as Texture2D)
	cb.add_theme_icon_override("unchecked_mirrored", _icons["toggle_off"] as Texture2D)
	cb.add_theme_icon_override("checked_disabled_mirrored", _icons["toggle_on_dis"] as Texture2D)
	cb.add_theme_icon_override("unchecked_disabled_mirrored", _icons["toggle_off_dis"] as Texture2D)

	cb.add_theme_color_override("font_color", INK_DARK)
	cb.add_theme_color_override("font_hover_color", INK_DARK)
	cb.add_theme_color_override("font_hover_pressed_color", INK_DARK)
	cb.add_theme_color_override("font_pressed_color", INK_DARK)
	cb.add_theme_color_override("font_focus_color", INK_DARK)
	cb.add_theme_color_override("font_disabled_color", INK_SOFT)
	cb.add_theme_constant_override("outline_size", 0)
	cb.add_theme_constant_override("h_separation", 8)
	cb.add_theme_font_override("font", get_font())
	if font_size_override > 0:
		cb.add_theme_font_size_override("font_size", font_size_override)


static func apply_check_box(cb: CheckBox, font_size_override: int = -1) -> void:
	if not is_instance_valid(cb):
		return
	_ensure_loaded()
	cb.set_meta("_ink_paper_styled", true)
	var empty_sb := StyleBoxEmpty.new()
	var soft_hover := make_soft_hover_style()
	cb.add_theme_stylebox_override("normal", empty_sb)
	cb.add_theme_stylebox_override("hover", soft_hover)
	cb.add_theme_stylebox_override("hover_pressed", soft_hover)
	cb.add_theme_stylebox_override("pressed", empty_sb)
	cb.add_theme_stylebox_override("disabled", empty_sb)
	cb.add_theme_stylebox_override("focus", empty_sb)

	cb.add_theme_icon_override("checked", _icons["check_on"] as Texture2D)
	cb.add_theme_icon_override("unchecked", _icons["check_off"] as Texture2D)
	cb.add_theme_icon_override("checked_disabled", _icons["check_on_dis"] as Texture2D)
	cb.add_theme_icon_override("unchecked_disabled", _icons["check_off_dis"] as Texture2D)
	cb.add_theme_icon_override("radio_checked", _icons["radio_on"] as Texture2D)
	cb.add_theme_icon_override("radio_unchecked", _icons["radio_off"] as Texture2D)
	cb.add_theme_icon_override("radio_checked_disabled", _icons["radio_on_dis"] as Texture2D)
	cb.add_theme_icon_override("radio_unchecked_disabled", _icons["radio_off_dis"] as Texture2D)

	cb.add_theme_color_override("font_color", INK_DARK)
	cb.add_theme_color_override("font_hover_color", INK_DARK)
	cb.add_theme_color_override("font_hover_pressed_color", INK_DARK)
	cb.add_theme_color_override("font_pressed_color", INK_DARK)
	cb.add_theme_color_override("font_focus_color", INK_DARK)
	cb.add_theme_color_override("font_disabled_color", INK_SOFT)
	cb.add_theme_constant_override("outline_size", 0)
	cb.add_theme_constant_override("h_separation", 6)
	cb.add_theme_font_override("font", get_font())
	if font_size_override > 0:
		cb.add_theme_font_size_override("font_size", font_size_override)


static func apply_panel_variant(panel: Control, variant: String = "cream", compact: bool = false, content_pad: Vector4 = Vector4(-1.0, -1.0, -1.0, -1.0)) -> void:
	if not is_instance_valid(panel):
		return
	_ensure_loaded()
	panel.set_meta("_ink_paper_styled", true)
	var pad := content_pad
	if pad.x < 0.0:
		pad = Vector4(6.0, 5.0, 6.0, 5.0) if compact else Vector4(8.0, 8.0, 8.0, 8.0)
	panel.add_theme_stylebox_override("panel", make_box_style(variant, compact, pad))


static func ensure_color_rect_paper(rect: ColorRect, variant: String = "cream", compact: bool = false, expand_edges: Vector4 = Vector4.ZERO) -> Panel:
	if not is_instance_valid(rect):
		return null
	_ensure_loaded()
	rect.set_meta("_ink_paper_styled", true)
	rect.color.a = 0.0
	var bg := rect.get_node_or_null("__InkPaperBackdrop") as Panel
	if not is_instance_valid(bg):
		bg = Panel.new()
		bg.name = "__InkPaperBackdrop"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.add_child(bg)
		rect.move_child(bg, 0)
	bg.offset_left = -expand_edges.x
	bg.offset_top = -expand_edges.y
	bg.offset_right = expand_edges.z
	bg.offset_bottom = expand_edges.w
	apply_panel_variant(bg, variant, compact, Vector4(0.0, 0.0, 0.0, 0.0))
	return bg


static func style_divider(ctrl: Control, vertical: bool = false) -> void:
	if not is_instance_valid(ctrl):
		return
	_ensure_loaded()
	ctrl.set_meta("_ink_paper_styled", true)
	if ctrl is ColorRect:
		(ctrl as ColorRect).color = Color(0.0, 0.0, 0.0, 0.0)
		var div_panel := ctrl.get_node_or_null("__InkDividerLine") as Panel
		if not is_instance_valid(div_panel):
			div_panel = Panel.new()
			div_panel.name = "__InkDividerLine"
			div_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			div_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ctrl.add_child(div_panel)
		div_panel.set_meta("_ink_paper_styled", true)
		div_panel.add_theme_stylebox_override("panel", make_divider_style(vertical))
	elif ctrl is HSeparator:
		ctrl.add_theme_stylebox_override("separator", make_divider_style(false))
	elif ctrl is VSeparator:
		ctrl.add_theme_stylebox_override("separator", make_divider_style(true))


static func apply_scrollbar_theme(scroll_container: ScrollContainer) -> void:
	if not is_instance_valid(scroll_container):
		return
	_ensure_loaded()
	for bar in [scroll_container.get_v_scroll_bar(), scroll_container.get_h_scroll_bar()]:
		if not is_instance_valid(bar):
			continue
		var vertical := bar is VScrollBar
		apply_single_scrollbar(bar, vertical)


static func apply_single_scrollbar(bar: ScrollBar, vertical: bool) -> void:
	if not is_instance_valid(bar):
		return
	_ensure_loaded()
	bar.set_meta("_ink_paper_styled", true)
	var empty_icon := _icons["empty_1x1"] as Texture2D
	bar.add_theme_stylebox_override("scroll", make_scrollbar_style("scroll", vertical))
	bar.add_theme_stylebox_override("scroll_focus", make_scrollbar_style("scroll", vertical))
	bar.add_theme_stylebox_override("grabber", make_scrollbar_style("grabber", vertical))
	bar.add_theme_stylebox_override("grabber_highlight", make_scrollbar_style("highlight", vertical))
	bar.add_theme_stylebox_override("grabber_pressed", make_scrollbar_style("pressed", vertical))
	bar.add_theme_icon_override("increment", empty_icon)
	bar.add_theme_icon_override("decrement", empty_icon)
	bar.add_theme_icon_override("increment_highlight", empty_icon)
	bar.add_theme_icon_override("decrement_highlight", empty_icon)
	bar.add_theme_icon_override("increment_pressed", empty_icon)
	bar.add_theme_icon_override("decrement_pressed", empty_icon)


static func apply_line_edit(le: LineEdit, compact: bool = true) -> void:
	if not is_instance_valid(le):
		return
	_ensure_loaded()
	le.set_meta("_ink_paper_styled", true)
	le.add_theme_stylebox_override("normal", make_box_style("paper", compact, Vector4(10.0, 5.0, 10.0, 5.0)))
	le.add_theme_stylebox_override("focus", make_box_style("hover", compact, Vector4(10.0, 5.0, 10.0, 5.0)))
	le.add_theme_stylebox_override("read_only", make_box_style("disabled", compact, Vector4(10.0, 5.0, 10.0, 5.0)))
	le.add_theme_color_override("font_color", INK_DARK)
	le.add_theme_color_override("font_placeholder_color", INK_SOFT)
	le.add_theme_color_override("font_selected_color", INK_DARK)
	le.add_theme_color_override("font_uneditable_color", INK_SOFT)
	le.add_theme_color_override("caret_color", INK_DARK)
	le.add_theme_color_override("selection_color", Color(0.88, 0.70, 0.33, 0.55))
	le.add_theme_font_override("font", get_font())


static func apply_text_edit(te: TextEdit, compact: bool = true) -> void:
	if not is_instance_valid(te):
		return
	_ensure_loaded()
	te.set_meta("_ink_paper_styled", true)
	te.add_theme_stylebox_override("normal", make_box_style("paper", compact, Vector4(10.0, 6.0, 10.0, 6.0)))
	te.add_theme_stylebox_override("focus", make_box_style("hover", compact, Vector4(10.0, 6.0, 10.0, 6.0)))
	te.add_theme_stylebox_override("read_only", make_box_style("disabled", compact, Vector4(10.0, 6.0, 10.0, 6.0)))
	te.add_theme_color_override("font_color", INK_DARK)
	te.add_theme_color_override("font_placeholder_color", INK_SOFT)
	te.add_theme_color_override("font_selected_color", INK_DARK)
	te.add_theme_color_override("font_readonly_color", INK_SOFT)
	te.add_theme_color_override("caret_color", INK_DARK)
	te.add_theme_color_override("selection_color", Color(0.88, 0.70, 0.33, 0.55))
	te.add_theme_font_override("font", get_font())


static func style_popup_menu(pm: PopupMenu, compact: bool = false) -> void:
	if not is_instance_valid(pm):
		return
	_ensure_loaded()
	pm.set_meta("_ink_paper_styled", true)
	var popup_hover := make_box_style("gold_hover", true, Vector4(10.0, 5.0, 10.0, 5.0))
	popup_hover.texture_margin_top = 5.0
	popup_hover.texture_margin_bottom = 5.0
	pm.add_theme_stylebox_override("panel", make_box_style("cream", true, Vector4(8.0, 10.0, 8.0, 10.0)))
	pm.add_theme_stylebox_override("hover", popup_hover)
	pm.add_theme_stylebox_override("separator", make_divider_style(false))
	pm.add_theme_stylebox_override("labeled_separator_left", make_divider_style(false))
	pm.add_theme_stylebox_override("labeled_separator_right", make_divider_style(false))
	pm.add_theme_color_override("font_color", INK_DARK)
	pm.add_theme_color_override("font_hover_color", INK_DARK)
	pm.add_theme_color_override("font_accelerator_color", INK_SOFT)
	pm.add_theme_color_override("font_disabled_color", INK_SOFT)
	pm.add_theme_color_override("font_separator_color", INK_SEPIA_TITLE)
	pm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	pm.add_theme_constant_override("outline_size", 0)
	pm.add_theme_constant_override("item_start_padding", 8)
	pm.add_theme_constant_override("item_end_padding", 8)
	pm.add_theme_constant_override("v_separation", 12)
	pm.add_theme_icon_override("checked", _icons["check_on"] as Texture2D)
	pm.add_theme_icon_override("unchecked", _icons["check_off"] as Texture2D)
	pm.add_theme_icon_override("radio_checked", _icons["radio_on"] as Texture2D)
	pm.add_theme_icon_override("radio_unchecked", _icons["radio_off"] as Texture2D)
	pm.add_theme_icon_override("submenu", _icons["arrow_right"] as Texture2D)
	pm.add_theme_font_override("font", get_font())
	pm.add_theme_font_size_override("font_size", 18 if compact else 22)


static func style_dialogue_balloon(root: Node) -> void:
	if not is_instance_valid(root):
		return
	_ensure_loaded()
	for child in root.find_children("*", "Control", true, false):
		var ctrl := child as Control
		if not is_instance_valid(ctrl):
			continue
		if ctrl.name == "__TextIconsRTL" or ctrl.name == "__InkPaperBackdrop":
			continue
		if ctrl is Panel or ctrl is PanelContainer:
			if ctrl.name.to_lower().contains("dim") or ctrl.name.to_lower().contains("blur"):
				continue
			if ctrl.modulate.a > 0.01 and ctrl.self_modulate.a > 0.01:
				apply_panel_variant(ctrl, "cream", false, Vector4(16.0, 12.0, 16.0, 12.0))
		elif ctrl is Button:
			if ctrl.modulate.a > 0.01 and ctrl.self_modulate.a > 0.01:
				apply_button_variant(ctrl as Button, "paper", false)
		elif ctrl is RichTextLabel:
			var rtl := ctrl as RichTextLabel
			var is_char := rtl.name.to_lower().contains("character")
			rtl.add_theme_color_override("default_color", INK_SEPIA_TITLE if is_char else INK_DARK)
			rtl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
			rtl.add_theme_constant_override("outline_size", 0)
			rtl.add_theme_font_override("normal_font", get_font())
			if is_char:
				rtl.add_theme_font_override("bold_font", get_font())
		elif ctrl is Label:
			var lbl := ctrl as Label
			var is_char := lbl.name.to_lower().contains("character")
			lbl.add_theme_color_override("font_color", INK_SEPIA_TITLE if is_char else INK_DARK)
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
			lbl.add_theme_constant_override("outline_size", 0)
			lbl.add_theme_font_override("font", get_font())
		elif ctrl is ScrollContainer:
			apply_scrollbar_theme(ctrl as ScrollContainer)

	var balloon_ctrl := root as Control
	if not is_instance_valid(balloon_ctrl):
		balloon_ctrl = root.get_node_or_null("Balloon") as Control
	if is_instance_valid(balloon_ctrl):
		balloon_ctrl.theme = get_theme()


static func _hash_float(a: int, b: int, seed_val: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (seed_val * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 65535) / 65535.0


static func _smoothstep(e0: float, e1: float, x: float) -> float:
	if is_equal_approx(e0, e1):
		return 0.0
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _build_edge_wobble(span: int, edge_seed: int, amp: float, thick_amp: float, include_second: bool = false) -> Dictionary:
	var offs := PackedFloat32Array()
	var thks := PackedFloat32Array()
	var offs2 := PackedFloat32Array()
	offs.resize(maxi(1, span))
	thks.resize(maxi(1, span))
	if include_second:
		offs2.resize(maxi(1, span))

	var p0 := _hash_float(1, 0, edge_seed) * TAU
	var p1 := _hash_float(2, 0, edge_seed) * TAU
	var p2 := _hash_float(3, 0, edge_seed) * TAU
	var p3 := _hash_float(4, 0, edge_seed) * TAU
	var p4 := _hash_float(5, 0, edge_seed) * TAU
	var p5 := _hash_float(6, 0, edge_seed) * TAU
	var p6 := _hash_float(7, 0, edge_seed) * TAU
	var p7 := _hash_float(8, 0, edge_seed) * TAU

	for i in offs.size():
		var t := float(i) / float(maxi(offs.size() - 1, 1))
		var env := pow(sin(PI * t), 0.65)
		var raw_off := (
			0.48 * sin(TAU * 1.0 * t + p0)
			+ 0.30 * sin(TAU * 2.5 * t + p1)
			+ 0.22 * sin(TAU * 5.0 * t + p2)
			+ 0.14 * sin(TAU * 9.5 * t + p3)
		)
		var raw_thk := (
			0.55 * sin(TAU * 2.0 * t + p4)
			+ 0.45 * sin(TAU * 5.5 * t + p5)
		)
		offs[i] = raw_off * env * amp
		thks[i] = raw_thk * env * thick_amp
		if include_second:
			var raw_off2 := (
				0.52 * sin(TAU * 1.5 * t + p6)
				+ 0.34 * sin(TAU * 4.0 * t + p7)
				+ 0.22 * sin(TAU * 8.0 * t + p1)
			)
			offs2[i] = raw_off2 * env * (amp * 1.15)

	return {"off": offs, "thk": thks, "off2": offs2}


static func _generate_box_texture(
	fill_color: Color,
	border_color: Color,
	tex_size: int,
	margin: int,
	radius: float,
	half_stroke: float,
	wobble_amp: float,
	seed_val: int,
	wood_grain: bool,
	subtle_shadow: bool,
	sketchy_scribble: bool = false
) -> ImageTexture:
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var extra_pad := 1.0 if sketchy_scribble else 0.0
	var pad := half_stroke + wobble_amp + 1.15 + extra_pad
	var cx := float(tex_size) * 0.5
	var cy := float(tex_size) * 0.5
	var bx := cx - pad
	var by := cy - pad
	var eff_r := minf(radius, minf(bx, by) * 0.85)
	var span := maxi(1, tex_size - margin * 2)
	var thick_amp := 0.40 if sketchy_scribble else 0.28

	var top_w := _build_edge_wobble(span, seed_val + 11, wobble_amp, thick_amp, sketchy_scribble)
	var bot_w := _build_edge_wobble(span, seed_val + 23, wobble_amp, thick_amp, sketchy_scribble)
	var left_w := _build_edge_wobble(span, seed_val + 37, wobble_amp, thick_amp, sketchy_scribble)
	var right_w := _build_edge_wobble(span, seed_val + 53, wobble_amp, thick_amp, sketchy_scribble)

	var top_off: PackedFloat32Array = top_w["off"]
	var top_thk: PackedFloat32Array = top_w["thk"]
	var top_off2: PackedFloat32Array = top_w["off2"]
	var bot_off: PackedFloat32Array = bot_w["off"]
	var bot_thk: PackedFloat32Array = bot_w["thk"]
	var bot_off2: PackedFloat32Array = bot_w["off2"]
	var left_off: PackedFloat32Array = left_w["off"]
	var left_thk: PackedFloat32Array = left_w["thk"]
	var left_off2: PackedFloat32Array = left_w["off2"]
	var right_off: PackedFloat32Array = right_w["off"]
	var right_thk: PackedFloat32Array = right_w["thk"]
	var right_off2: PackedFloat32Array = right_w["off2"]

	var corner_phases: Array[float] = [
		_hash_float(10, 1, seed_val) * TAU,
		_hash_float(10, 2, seed_val) * TAU,
		_hash_float(10, 3, seed_val) * TAU,
		_hash_float(10, 4, seed_val) * TAU,
	]

	var band := margin + 4
	var far := tex_size - band

	for y in tex_size:
		var py := float(y) + 0.5
		var in_y_mid := (y >= margin and y < tex_size - margin)
		for x in tex_size:
			var grain := _hash_float(x, y, seed_val) - 0.5
			var paper_tone := 1.0 + grain * 0.022
			if wood_grain:
				var streak := sin(py * 0.72 + sin(float(x) * 0.10) * 2.2) * 0.032
				paper_tone += streak

			var p_r := clampf(fill_color.r * paper_tone, 0.0, 1.0)
			var p_g := clampf(fill_color.g * paper_tone, 0.0, 1.0)
			var p_b := clampf(fill_color.b * paper_tone, 0.0, 1.0)

			if x >= band and x < far and y >= band and y < far:
				img.set_pixel(x, y, Color(p_r, p_g, p_b, fill_color.a))
				continue

			var px := float(x) + 0.5
			var dx := absf(px - cx) - (bx - eff_r)
			var dy := absf(py - cy) - (by - eff_r)
			var sdf := Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length() + minf(maxf(dx, dy), 0.0) - eff_r

			var in_x_mid := (x >= margin and x < tex_size - margin)
			var edge_off := 0.0
			var edge_thk := 0.0
			var edge_off2 := 0.0

			if in_x_mid and not in_y_mid:
				var xi := x - margin
				if py < cy:
					edge_off = top_off[xi]
					edge_thk = top_thk[xi]
					if sketchy_scribble:
						edge_off2 = top_off2[xi]
				else:
					edge_off = bot_off[xi]
					edge_thk = bot_thk[xi]
					if sketchy_scribble:
						edge_off2 = bot_off2[xi]
			elif in_y_mid and not in_x_mid:
				var yi := y - margin
				if px < cx:
					edge_off = left_off[yi]
					edge_thk = left_thk[yi]
					if sketchy_scribble:
						edge_off2 = left_off2[yi]
				else:
					edge_off = right_off[yi]
					edge_thk = right_thk[yi]
					if sketchy_scribble:
						edge_off2 = right_off2[yi]
			elif not in_x_mid and not in_y_mid:
				var ang := atan2(maxf(dy, 0.001), maxf(dx, 0.001))
				var c_env := sin(ang * 2.0)
				var cid := (0 if px < cx else 1) + (0 if py < cy else 2)
				edge_off = c_env * wobble_amp * 0.60 * sin(ang * 4.0 + float(corner_phases[cid]))
				edge_thk = c_env * 0.22 * sin(ang * 3.0 + float(corner_phases[cid]) * 1.7)
				if sketchy_scribble:
					edge_off2 = c_env * wobble_amp * 0.72 * cos(ang * 3.0 + float(corner_phases[cid]) * 1.3)

			var eff_sdf := sdf + edge_off + grain * 0.28
			var eff_half_stroke := half_stroke + edge_thk + grain * 0.14

			var fill_a := (1.0 - _smoothstep(-0.65, 0.65, eff_sdf)) * fill_color.a
			var stroke_a := (1.0 - _smoothstep(eff_half_stroke - 0.72, eff_half_stroke + 0.72, absf(eff_sdf))) * border_color.a
			if sketchy_scribble:
				var eff_sdf2 := sdf + edge_off2 + grain * 0.32
				var stroke2_a := (1.0 - _smoothstep(half_stroke * 0.55 - 0.6, half_stroke * 0.55 + 0.6, absf(eff_sdf2))) * (border_color.a * 0.42)
				stroke_a = clampf(maxf(stroke_a, stroke2_a), 0.0, 1.0)

			if subtle_shadow and py > cy and eff_sdf < 0.0 and eff_sdf > -3.5:
				var sh := (1.0 - (-eff_sdf / 3.5)) * 0.055
				p_r = maxf(0.0, p_r - sh)
				p_g = maxf(0.0, p_g - sh)
				p_b = maxf(0.0, p_b - sh)

			var out_a := stroke_a + fill_a * (1.0 - stroke_a)
			if out_a <= 0.002:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			else:
				var inv_s := 1.0 - stroke_a
				var out_r := (border_color.r * stroke_a + p_r * fill_a * inv_s) / out_a
				var out_g := (border_color.g * stroke_a + p_g * fill_a * inv_s) / out_a
				var out_b := (border_color.b * stroke_a + p_b * fill_a * inv_s) / out_a
				img.set_pixel(x, y, Color(out_r, out_g, out_b, out_a))

	return ImageTexture.create_from_image(img)


static func _generate_dithered_beer_gradient_texture(width: int = 180, height: int = 5) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var bayer4: PackedInt32Array = PackedInt32Array([
		0, 8, 2, 10,
		12, 4, 14, 6,
		3, 11, 1, 9,
		15, 7, 13, 5,
	])
	var palette: Array[Color] = [
		Color("#8E4202"),
		Color("#B55606"),
		Color("#D97416"),
		Color("#E09A2E"),
		Color("#F2CB78"),
		Color("#FAF5E4"),
	]
	var steps: int = palette.size() - 1
	for y in height:
		for x in width:
			var u := float(x) / float(maxi(width - 1, 1))
			var v := float(y) / float(maxi(height - 1, 1))
			var grad_t := clampf(pow(u, 1.10) + (0.5 - v) * 0.06, 0.0, 1.0)
			var scaled := grad_t * float(steps)
			var idx0 := mini(int(floorf(scaled)), steps)
			var idx1 := mini(idx0 + 1, steps)
			var frac := scaled - float(idx0)
			var threshold := (float(bayer4[(x & 3) + ((y & 3) << 2)]) + 0.5) / 16.0
			var chosen: Color = palette[idx1] if frac > threshold else palette[idx0]
			img.set_pixel(x, y, chosen)
	return ImageTexture.create_from_image(img)


static func _generate_pixel_slider_track_texture(width: int = 48, height: int = 6) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var is_border := (x == 0 or x == width - 1 or y == 0 or y == height - 1)
			img.set_pixel(x, y, INK_DARK if is_border else Color("#362B22"))
	return ImageTexture.create_from_image(img)


static func _generate_divider_texture(vertical: bool, line_color: Color, length: int, thickness_px: int, seed_val: int) -> ImageTexture:
	var w := thickness_px if vertical else length
	var h := length if vertical else thickness_px
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var p0 := _hash_float(1, 0, seed_val) * TAU
	var p1 := _hash_float(2, 0, seed_val) * TAU
	var p2 := _hash_float(3, 0, seed_val) * TAU
	var center := float(thickness_px) * 0.5

	for i in length:
		var t := float(i) / float(length)
		var env := pow(sin(PI * t), 0.5)
		var offset := (0.55 * sin(TAU * 1.0 * t + p0) + 0.30 * sin(TAU * 3.0 * t + p1)) * env * 0.75
		var half_w := 0.90 + 0.25 * sin(TAU * 2.0 * t + p2) * env
		for j in thickness_px:
			var dist := absf((float(j) + 0.5) - (center + offset))
			var grain := (_hash_float(i, j, seed_val) - 0.5) * 0.25
			var alpha := (1.0 - _smoothstep(half_w - 0.65, half_w + 0.65, dist + grain)) * line_color.a
			if alpha > 0.01:
				var col := Color(line_color.r, line_color.g, line_color.b, alpha)
				if vertical:
					img.set_pixel(j, i, col)
				else:
					img.set_pixel(i, j, col)

	return ImageTexture.create_from_image(img)


static func _create_toggle_icon(is_checked: bool, is_disabled: bool) -> ImageTexture:
	var w := 44
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var border_col := INK_SOFT if is_disabled else INK_DARK
	var track_col := CORAL_PRIMARY if is_checked else Color("#CFC8BA")
	if is_disabled:
		track_col = Color("#CBB9AE") if is_checked else PAPER_DISABLED

	var cy := float(h) * 0.5
	var cx := float(w) * 0.5
	var half_w := cx - 2.0
	var r := cy - 2.0

	var knob_cx := (float(w) - cy) if is_checked else cy
	var knob_cy := cy
	var knob_r := r - 2.4
	var knob_col := PAPER_LIGHT if not is_disabled else Color("#ECE8DF")

	for y in h:
		var py := float(y) + 0.5
		for x in w:
			var px := float(x) + 0.5
			var grain := (_hash_float(x, y, 2100 + (1 if is_checked else 0)) - 0.5) * 0.22
			var wobble := sin(px * 0.32 + py * 0.21) * 0.35

			var dx := absf(px - cx) - (half_w - r)
			var dy := py - cy
			var track_sdf := Vector2(maxf(dx, 0.0), absf(dy)).length() + minf(maxf(dx, absf(dy)), 0.0) - r + wobble * 0.55 + grain * 0.4

			var track_fill_a := (1.0 - _smoothstep(-0.6, 0.6, track_sdf)) * track_col.a
			var track_stroke_a := (1.0 - _smoothstep(0.65, 1.85, absf(track_sdf))) * border_col.a

			var out_a := track_stroke_a + track_fill_a * (1.0 - track_stroke_a)
			var out_rgb := Vector3.ZERO
			if out_a > 0.001:
				var inv := 1.0 - track_stroke_a
				out_rgb = Vector3(
					(border_col.r * track_stroke_a + track_col.r * track_fill_a * inv) / out_a,
					(border_col.g * track_stroke_a + track_col.g * track_fill_a * inv) / out_a,
					(border_col.b * track_stroke_a + track_col.b * track_fill_a * inv) / out_a
				)

			var k_sdf := Vector2(px - knob_cx, py - knob_cy).length() - knob_r + wobble * 0.35 + grain * 0.35
			var k_fill_a := 1.0 - _smoothstep(-0.6, 0.6, k_sdf)
			var k_stroke_a := (1.0 - _smoothstep(0.55, 1.65, absf(k_sdf))) * border_col.a
			var k_tot_a := k_stroke_a + k_fill_a * (1.0 - k_stroke_a)
			if k_tot_a > 0.001:
				var k_inv := 1.0 - k_stroke_a
				var k_rgb := Vector3(
					(border_col.r * k_stroke_a + knob_col.r * k_fill_a * k_inv) / k_tot_a,
					(border_col.g * k_stroke_a + knob_col.g * k_fill_a * k_inv) / k_tot_a,
					(border_col.b * k_stroke_a + knob_col.b * k_fill_a * k_inv) / k_tot_a
				)
				var final_a := k_tot_a + out_a * (1.0 - k_tot_a)
				var final_rgb := (k_rgb * k_tot_a + out_rgb * out_a * (1.0 - k_tot_a)) / maxf(final_a, 0.0001)
				img.set_pixel(x, y, Color(final_rgb.x, final_rgb.y, final_rgb.z, final_a))
			elif out_a > 0.001:
				img.set_pixel(x, y, Color(out_rgb.x, out_rgb.y, out_rgb.z, out_a))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(img)


static func _create_checkbox_icon(is_checked: bool, is_radio: bool, is_disabled: bool) -> ImageTexture:
	var sz := 22
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var border_col := INK_SOFT if is_disabled else INK_DARK
	var fill_col := PAPER_DISABLED if is_disabled else (CORAL_PRIMARY if is_checked else PAPER_LIGHT)

	var c := float(sz) * 0.5
	var b := c - 2.4
	var r := b if is_radio else 4.0

	var p0 := Vector2(5.5, 11.2)
	var p1 := Vector2(9.6, 15.2)
	var p2 := Vector2(16.5, 6.8)

	for y in sz:
		var py := float(y) + 0.5
		for x in sz:
			var px := float(x) + 0.5
			var grain := (_hash_float(x, y, 2200) - 0.5) * 0.22
			var wobble := sin(px * 0.45 + py * 0.38) * 0.30
			var sdf: float
			if is_radio:
				sdf = Vector2(px - c, py - c).length() - b + wobble * 0.5 + grain * 0.4
			else:
				var dx := absf(px - c) - (b - r)
				var dy := absf(py - c) - (b - r)
				sdf = Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length() + minf(maxf(dx, dy), 0.0) - r + wobble * 0.5 + grain * 0.4

			var fill_a := 1.0 - _smoothstep(-0.6, 0.6, sdf)
			var stroke_a := (1.0 - _smoothstep(0.55, 1.70, absf(sdf))) * border_col.a
			var out_a := stroke_a + fill_a * (1.0 - stroke_a)
			if out_a <= 0.002:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var inv := 1.0 - stroke_a
			var col := Color(
				(border_col.r * stroke_a + fill_col.r * fill_a * inv) / out_a,
				(border_col.g * stroke_a + fill_col.g * fill_a * inv) / out_a,
				(border_col.b * stroke_a + fill_col.b * fill_a * inv) / out_a,
				out_a
			)

			if is_checked:
				if is_radio:
					var dot_d := Vector2(px - c, py - c).length() - 3.6 + wobble * 0.25
					var dot_a := 1.0 - _smoothstep(-0.6, 0.6, dot_d)
					col = col.lerp(PAPER_LIGHT, dot_a)
				else:
					var pt := Vector2(px, py)
					var d1 := Geometry2D.get_closest_point_to_segment(pt, p0, p1).distance_to(pt)
					var d2 := Geometry2D.get_closest_point_to_segment(pt, p1, p2).distance_to(pt)
					var mark_a := 1.0 - _smoothstep(0.75, 1.85, minf(d1, d2))
					col = col.lerp(PAPER_LIGHT, mark_a)

			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


static func _create_arrow_icon(point_right: bool) -> ImageTexture:
	var sz := 16
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p0 := Vector2(5.5, 3.5) if point_right else Vector2(3.5, 5.5)
	var p1 := Vector2(10.5, 8.0) if point_right else Vector2(8.0, 10.5)
	var p2 := Vector2(5.5, 12.5) if point_right else Vector2(12.5, 5.5)

	for y in sz:
		for x in sz:
			var pt := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d1 := Geometry2D.get_closest_point_to_segment(pt, p0, p1).distance_to(pt)
			var d2 := Geometry2D.get_closest_point_to_segment(pt, p1, p2).distance_to(pt)
			var alpha := 1.0 - _smoothstep(0.70, 1.75, minf(d1, d2))
			if alpha > 0.01:
				img.set_pixel(x, y, Color(INK_DARK.r, INK_DARK.g, INK_DARK.b, alpha))
	return ImageTexture.create_from_image(img)


static func _create_empty_icon() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


class _BeerSliderTrack extends Control:
	const PIXEL_CELL := 2
	const BAR_HEIGHT := 14.0
	const BORDER_PX := 2.0

	var _slider: HSlider = null
	var _fill_tex: ImageTexture = null
	var _tex_w: int = 0
	var _tex_h: int = 0
	var _cached_inner_w: int = -1
	var _cached_inner_h: int = -1

	func _ready() -> void:
		show_behind_parent = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func bind_slider(slider: HSlider) -> void:
		if _slider == slider:
			queue_redraw()
			return
		_slider = slider
		if not is_instance_valid(_slider):
			return
		if not _slider.value_changed.is_connected(_on_slider_updated_val):
			_slider.value_changed.connect(_on_slider_updated_val)
		if not _slider.changed.is_connected(_on_slider_updated):
			_slider.changed.connect(_on_slider_updated)
		if not _slider.resized.is_connected(_on_slider_updated):
			_slider.resized.connect(_on_slider_updated)
		queue_redraw()

	func _on_slider_updated_val(_v: float) -> void:
		queue_redraw()

	func _on_slider_updated() -> void:
		queue_redraw()

	func _ensure_fill_texture(inner_w: int, inner_h: int) -> void:
		if _fill_tex != null and _cached_inner_w == inner_w and _cached_inner_h == inner_h:
			return
		_cached_inner_w = inner_w
		_cached_inner_h = inner_h
		_tex_w = maxi(1, ceili(float(inner_w) / float(PIXEL_CELL)))
		_tex_h = maxi(1, ceili(float(inner_h) / float(PIXEL_CELL)))
		_fill_tex = InkTheme._generate_dithered_beer_gradient_texture(_tex_w, _tex_h)

	func _draw() -> void:
		if not is_instance_valid(_slider) or size.x <= 4.0 or size.y <= 4.0:
			return

		var bar_h := minf(BAR_HEIGHT, maxf(8.0, size.y - 2.0))
		var bar_y := roundf((size.y - bar_h) * 0.5)
		var inner_x := BORDER_PX
		var inner_y := bar_y + BORDER_PX
		var inner_w := maxf(1.0, size.x - BORDER_PX * 2.0)
		var inner_h := maxf(2.0, bar_h - BORDER_PX * 2.0)

		_ensure_fill_texture(int(roundf(inner_w)), int(roundf(inner_h)))

		draw_rect(Rect2(inner_x, inner_y, inner_w, inner_h), Color("#362B22"), true)

		var center_grabber := _slider.get_theme_constant("center_grabber") != 0
		var grabber := _slider.get_theme_icon("grabber")
		var grabber_w := float(grabber.get_width()) if grabber else 0.0
		var areasize := maxf(0.0, size.x - (0.0 if center_grabber else grabber_w))
		var grabber_shift := (-grabber_w * 0.5) if center_grabber else 0.0
		var r := clampf(_slider.ratio, 0.0, 1.0)
		var eff_r := (1.0 - r) if _slider.is_layout_rtl() else r
		var knob_x := areasize * eff_r + grabber_w * 0.5 + grabber_shift
		var fill_w := clampf(knob_x - inner_x, 0.0, inner_w)

		if fill_w > 0.5 and _fill_tex != null:
			var src_w := (fill_w / inner_w) * float(_tex_w)
			draw_texture_rect_region(
				_fill_tex,
				Rect2(inner_x, inner_y, fill_w, inner_h),
				Rect2(0.0, 0.0, src_w, float(_tex_h))
			)

		draw_rect(Rect2(0.0, bar_y, size.x, BORDER_PX), InkTheme.INK_DARK, true)
		draw_rect(Rect2(0.0, bar_y + bar_h - BORDER_PX, size.x, BORDER_PX), InkTheme.INK_DARK, true)
		draw_rect(Rect2(0.0, bar_y, BORDER_PX, bar_h), InkTheme.INK_DARK, true)
		draw_rect(Rect2(size.x - BORDER_PX, bar_y, BORDER_PX, bar_h), InkTheme.INK_DARK, true)


class InkPaperRuntime extends Node:
	var _boil_accum: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -70
		var tree := get_tree()
		if not tree:
			return
		if not tree.node_added.is_connected(_on_node_added):
			tree.node_added.connect(_on_node_added)
		if tree.root:
			_scan_recursive(tree.root)

	func _process(delta: float) -> void:
		if InkTheme._animated_styleboxes.is_empty():
			return
		var unscaled := delta / maxf(Engine.time_scale, 0.0001)
		_boil_accum += unscaled
		if _boil_accum >= InkTheme.BOIL_INTERVAL:
			_boil_accum = fmod(_boil_accum, InkTheme.BOIL_INTERVAL)
			InkTheme._tick_scribble_animation()

	func _scan_recursive(root: Node) -> void:
		_on_node_added(root)
		for child in root.get_children():
			_scan_recursive(child)

	func _on_node_added(node: Node) -> void:
		if not is_instance_valid(node):
			return
		call_deferred("_apply_to_node_deferred", node)

	func _apply_to_node_deferred(node: Node) -> void:
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
		if node is Control and (node as Control).has_meta("ink_paper_ignore"):
			return
		if _is_excluded(node):
			return

		if _is_dialogue_balloon_root(node):
			InkTheme.style_dialogue_balloon(node)
			return

		if _is_in_dialogue_balloon(node):
			if node is Button:
				InkTheme.apply_button_variant(node as Button, "paper", false)
			elif node is Panel or node is PanelContainer:
				var pctrl := node as Control
				if not pctrl.name.to_lower().contains("dim") and pctrl.modulate.a > 0.01 and pctrl.self_modulate.a > 0.01:
					InkTheme.apply_panel_variant(pctrl, "cream", false, Vector4(16.0, 12.0, 16.0, 12.0))
			return

		if node is PopupMenu:
			if not node.has_meta("_ink_paper_styled"):
				InkTheme.style_popup_menu(node as PopupMenu, _is_compact_context(node))
			return

		if not (node is Control):
			return

		var ctrl := node as Control
		if ctrl.name == "__TextIconsRTL" or ctrl.name == "__InkPaperBackdrop" or ctrl.name == "__InkDividerLine" or ctrl.name == "__CooldownOverlay" or ctrl.name == "__BeerSliderTrack":
			return
		if ctrl is Slider or ctrl is ColorRect or ctrl is TextureRect or ctrl is TextureProgressBar:
			return
		if ctrl.has_meta("_ink_paper_styled"):
			return
		if ctrl.modulate.a <= 0.01 or ctrl.self_modulate.a <= 0.01:
			return

		var compact := _is_compact_context(ctrl)
		if ctrl is CheckButton:
			InkTheme.apply_check_button(ctrl as CheckButton)
		elif ctrl is CheckBox:
			InkTheme.apply_check_box(ctrl as CheckBox)
		elif ctrl is OptionButton:
			InkTheme.apply_button_variant(ctrl as OptionButton, "paper", compact)
		elif ctrl is Button:
			var btn := ctrl as Button
			if not btn.has_theme_stylebox_override("normal"):
				InkTheme.apply_button_variant(btn, "paper", compact)
		elif ctrl is LineEdit:
			InkTheme.apply_line_edit(ctrl as LineEdit, true)
		elif ctrl is TextEdit:
			InkTheme.apply_text_edit(ctrl as TextEdit, true)
		elif ctrl is ScrollContainer:
			InkTheme.apply_scrollbar_theme(ctrl as ScrollContainer)
		elif ctrl is VScrollBar:
			InkTheme.apply_single_scrollbar(ctrl as VScrollBar, true)
		elif ctrl is HScrollBar:
			InkTheme.apply_single_scrollbar(ctrl as HScrollBar, false)
		elif ctrl is HSeparator:
			InkTheme.style_divider(ctrl, false)
		elif ctrl is VSeparator:
			InkTheme.style_divider(ctrl, true)
		elif ctrl is Panel or ctrl is PanelContainer:
			if ctrl.material == null and not ctrl.has_theme_stylebox_override("panel"):
				InkTheme.apply_panel_variant(ctrl, "cream", compact)

	func _is_excluded(node: Node) -> bool:
		var cur := node
		while is_instance_valid(cur):
			var n := cur.name
			if InkTheme.EXCLUDED_ANCESTORS.has(n):
				return true
			if cur is Control and (cur as Control).has_meta("ink_paper_ignore"):
				return true
			if cur is SubViewport:
				var p := cur.get_parent()
				if is_instance_valid(p) and (p.name == "Base_viewport" or p.name == "Sprite3D"):
					var gp := p.get_parent()
					if is_instance_valid(gp) and (gp.name.begins_with("Recipt") or gp.name.begins_with("BaseNpc") or gp.name.begins_with("seat")):
						return true
			cur = cur.get_parent()
		return false

	func _is_compact_context(node: Node) -> bool:
		var cur := node
		while is_instance_valid(cur):
			if cur.name == "DebugMenu":
				return true
			cur = cur.get_parent()
		if node is Control and (node as Control).custom_minimum_size.y > 0.0 and (node as Control).custom_minimum_size.y <= 34.0:
			return true
		return false

	func _is_dialogue_balloon_root(node: Node) -> bool:
		return node.name == "Main_Ballon" or node.name == "ExampleBalloon" or (node is CanvasLayer and node.get_node_or_null("Balloon") != null and node.find_child("DialogueLabel", true, false) != null)

	func _is_in_dialogue_balloon(node: Node) -> bool:
		var cur := node.get_parent()
		while is_instance_valid(cur):
			if _is_dialogue_balloon_root(cur):
				return true
			cur = cur.get_parent()
		return false