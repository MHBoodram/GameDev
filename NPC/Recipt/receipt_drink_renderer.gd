class_name ReceiptDrinkRenderer
extends RefCounted

const BEER_CUP_SCENE: PackedScene = preload("res://Player/Drink/Glasses/beer_cup.tscn")
const SHOT_CUP_SCENE: PackedScene = preload("res://Player/Drink/Glasses/shot_cup.tscn")
const LIQUID_RESOURCE_DIR := "res://Player/Drink/Liquids/resource"

const GLASS_SCENES := {
	"": BEER_CUP_SCENE,
	"beer": BEER_CUP_SCENE,
	"shot": SHOT_CUP_SCENE,
}

const FALLBACK_GLASS_ASSETS := {
	"": {
		"inside": "res://Assets/Items/beer.png",
		"outside": "res://Assets/Items/beer_outside.png",
	},
	"beer": {
		"inside": "res://Assets/Items/beer.png",
		"outside": "res://Assets/Items/beer_outside.png",
	},
	"shot": {
		"inside": "res://Assets/Items/inside_shot_glass.png",
		"outside": "res://Assets/Items/outside_shot_glass.png",
	},
}

const GRID_SIZE: int = 64
const TARGET_CUP_HEIGHT: int = 128
const DEFAULT_RECEIPT_FILL_RATIO: float = 0.92
const CUP_PAD_LEFT: float = 0.14
const CUP_PAD_RIGHT: float = 0.14
const CUP_PAD_TOP: float = 0.20
const CUP_PAD_BOTTOM: float = 0.06
const TRIM_MARGIN_RATIO: float = 0.075

static var _glass_spec_cache: Dictionary = {}
static var _order_tex_cache: Dictionary = {}
static var _liquid_resources_scanned: bool = false
static var _liquid_resource_cache: Dictionary = {}
static var _custom_liquid_colors: Dictionary = {}

static func get_shaken_render_mode() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var ss := tree.root.get_node_or_null("SettingState")
		if is_instance_valid(ss) and ss.has_method("get_shaken_receipt_mode"):
			return str(ss.call("get_shaken_receipt_mode"))
	return "split"

static func get_order_display_name(order: DrinkOrder) -> String:
	if order == null:
		return ""
	if order.recipe_name.strip_edges() != "":
		return order.recipe_name
	if not order.require_ingredient_match:
		return "Anything"
	var names := PackedStringArray()
	for ing_name in order.ingredients.keys():
		names.append(str(ing_name).capitalize())
	if not names.is_empty():
		return " & ".join(names)
	return ""

static func clear_cache() -> void:
	_order_tex_cache.clear()

static func get_or_render_order_texture(
	order: DrinkOrder,
	species_def: SpeciesBase = null,
	modifier: ModifierBase = null,
	aspect_comp: float = 1.4715
) -> Texture2D:
	if order == null:
		push_warning("ReceiptDrinkRenderer: order is null.")
		return null

	var shaken_mode := get_shaken_render_mode()
	var eff_aspect: float = aspect_comp if aspect_comp > 0.1 else 1.0
	var cache_key := _build_cache_key(order, species_def, modifier, eff_aspect, shaken_mode)
	if _order_tex_cache.has(cache_key):
		var cached := _order_tex_cache[cache_key] as Texture2D
		if is_instance_valid(cached):
			return cached

	var spec := _get_glass_spec(order.required_glass)
	var inside_img: Image = spec["inside_img"] as Image
	var outside_img: Image = spec["outside_img"] as Image

	var base_w: int = inside_img.get_width() if (inside_img != null and not inside_img.is_empty()) else 48
	var base_h: int = inside_img.get_height() if (inside_img != null and not inside_img.is_empty()) else 48
	var int_scale: int = maxi(1, roundi(float(TARGET_CUP_HEIGHT) / float(maxi(base_w, base_h))))
	var cup_w: int = base_w * int_scale
	var cup_h: int = base_h * int_scale

	var pad_l: int = roundi(float(cup_w) * CUP_PAD_LEFT / (1.0 - CUP_PAD_LEFT - CUP_PAD_RIGHT))
	var pad_r: int = roundi(float(cup_w) * CUP_PAD_RIGHT / (1.0 - CUP_PAD_LEFT - CUP_PAD_RIGHT))
	var pad_t: int = roundi(float(cup_h) * CUP_PAD_TOP / (1.0 - CUP_PAD_TOP - CUP_PAD_BOTTOM))
	var pad_b: int = roundi(float(cup_h) * CUP_PAD_BOTTOM / (1.0 - CUP_PAD_TOP - CUP_PAD_BOTTOM))

	var canvas_w: int = cup_w + pad_l + pad_r
	var canvas_h: int = cup_h + pad_t + pad_b
	var canvas_img := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	canvas_img.fill(Color(0, 0, 0, 0))

	var is_anything := (not order.require_ingredient_match) or order.ingredients.is_empty()
	var is_shaken := order.required_processing.has("shaken")
	var is_spectral := order.required_processing.has("spectral")
	var fill_ratio := clampf(order.ideal_fill_ratio if order.ideal_fill_ratio >= 0.0 else DEFAULT_RECEIPT_FILL_RATIO, 0.1, 1.0)

	# 1. Draw glass base (Inside)
	if inside_img != null and not inside_img.is_empty():
		var scaled_inside := inside_img.duplicate() as Image
		if scaled_inside.get_width() != cup_w or scaled_inside.get_height() != cup_h:
			scaled_inside.resize(cup_w, cup_h, Image.INTERPOLATE_NEAREST)
		var inside_mod: Color = spec["inside_modulate"] as Color
		_apply_inside_tint(scaled_inside, inside_mod, is_spectral)
		canvas_img.blend_rect(scaled_inside, Rect2i(0, 0, cup_w, cup_h), Vector2i(pad_l, pad_t))
	else:
		push_warning("ReceiptDrinkRenderer: Missing inside_img for glass '%s'." % str(spec["glass_key"]))

	# 2. Draw liquid + glass sheen (Outside)
	if outside_img != null and not outside_img.is_empty():
		var fluid_grid := _build_fluid_grid(spec, order, fill_ratio, is_shaken, is_anything, shaken_mode)
		var rel_scale: Vector2 = spec["outside_rel_scale"] as Vector2
		var out_w: int = maxi(1, roundi(float(cup_w) * rel_scale.x))
		var out_h: int = maxi(1, roundi(float(cup_h) * rel_scale.y))
		var out_x: int = pad_l + (cup_w - out_w) / 2
		var out_y: int = pad_t + (cup_h - out_h) / 2
		var shaded_outside := _render_outside_liquid_image(
			outside_img,
			fluid_grid,
			out_w,
			out_h,
			spec["shader_params"] as Dictionary,
			is_spectral,
			is_anything
		)
		canvas_img.blend_rect(shaded_outside, Rect2i(0, 0, out_w, out_h), Vector2i(out_x, out_y))
	else:
		push_warning("ReceiptDrinkRenderer: Missing outside_img for glass '%s'." % str(spec["glass_key"]))

	# 3. Composite garnishes & ice
	var garnish_entries := _build_garnish_entries(spec["uv_bounds"] as Dictionary, order, fill_ratio)
	for entry in garnish_entries:
		var g_tex := entry["texture"] as Texture2D
		var g_img := _get_texture_image(g_tex)
		if g_img == null or g_img.is_empty():
			continue
		var g_size := maxi(4, roundi(float(entry["size_rel"]) * float(cup_w)))
		var scaled_g := g_img.duplicate() as Image
		scaled_g.resize(g_size, g_size, Image.INTERPOLATE_NEAREST)
		var cx := pad_l + roundi(float(entry["u"]) * float(cup_w))
		var cy := pad_t + roundi(float(entry["v"]) * float(cup_h))
		_blend_rotated_image(canvas_img, scaled_g, Vector2i(cx, cy), float(entry["rotation_deg"]))

	# 4. Trim excess empty border and leave a small uniform margin on all sides
	var used_rect: Rect2i = _get_visible_used_rect(canvas_img, 0.05)
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		var margin := maxi(2, roundi(float(maxi(used_rect.size.x, used_rect.size.y)) * TRIM_MARGIN_RATIO))
		var trimmed_w := used_rect.size.x + margin * 2
		var trimmed_h := used_rect.size.y + margin * 2
		var trimmed_img := Image.create(trimmed_w, trimmed_h, false, Image.FORMAT_RGBA8)
		trimmed_img.fill(Color(0, 0, 0, 0))
		trimmed_img.blit_rect(canvas_img, used_rect, Vector2i(margin, margin))
		canvas_img = trimmed_img

	# 5. Compensate for Base_viewport Sprite3D vertical stretch
	if not is_equal_approx(eff_aspect, 1.0):
		var target_w := maxi(1, roundi(float(canvas_img.get_width()) * eff_aspect))
		canvas_img.resize(target_w, canvas_img.get_height(), Image.INTERPOLATE_BILINEAR)

	var opaque_count := _count_visible_pixels(canvas_img)
	print("[ReceiptDrinkRenderer] key=%s size=%dx%d opaque_samples=%d" % [cache_key, canvas_img.get_width(), canvas_img.get_height(), opaque_count])

	var out_tex := ImageTexture.create_from_image(canvas_img)
	_order_tex_cache[cache_key] = out_tex
	return out_tex

static func _get_visible_used_rect(img: Image, alpha_threshold: float = 0.05) -> Rect2i:
	if img == null or img.is_empty():
		return Rect2i()
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var max_x := -1
	var min_y := h
	var max_y := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > alpha_threshold:
				if x < min_x:
					min_x = x
				if x > max_x:
					max_x = x
				if y < min_y:
					min_y = y
				if y > max_y:
					max_y = y
	if max_x < min_x or max_y < min_y:
		return img.get_used_rect()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

static func _count_visible_pixels(img: Image) -> int:
	if img == null or img.is_empty():
		return 0
	var count := 0
	var w := img.get_width()
	var h := img.get_height()
	var sx := maxi(1, w / 32)
	var sy := maxi(1, h / 32)
	for y in range(0, h, sy):
		for x in range(0, w, sx):
			if img.get_pixel(x, y).a > 0.05:
				count += 1
	return count

static func _apply_inside_tint(img: Image, mod_col: Color, is_spectral: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var spec_col := Color(0.45, 0.92, 1.0, 1.0)
	var sec_col := Color(0.55, 0.65, 1.0, 1.0)
	for y in h:
		var v := (float(y) + 0.5) / float(h)
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= 0.01:
				continue
			c = Color(c.r * mod_col.r, c.g * mod_col.g, c.b * mod_col.b, c.a * mod_col.a)
			if is_spectral:
				var u := (float(x) + 0.5) / float(w)
				var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				var wisp := 0.5 + 0.5 * sin(v * 18.0 + u * 8.0)
				var aura := spec_col.lerp(sec_col, wisp * 0.45)
				var mult := lerpf(0.55, 1.35, luma)
				var tinted := Color(aura.r * mult, aura.g * mult, aura.b * mult, 1.0)
				var final_rgb := c.lerp(tinted, 0.65)
				var top_factor := clampf((1.0 - v) / 0.35, 0.0, 1.0)
				var bottom_fade := lerpf(0.88, 1.0, top_factor)
				c = Color(
					clampf(final_rgb.r * 1.2, 0.0, 1.0),
					clampf(final_rgb.g * 1.2, 0.0, 1.0),
					clampf(final_rgb.b * 1.2, 0.0, 1.0),
					clampf(c.a * 0.56 * bottom_fade, 0.0, 0.92)
				)
			img.set_pixel(x, y, c)

static func _render_outside_liquid_image(
	outside_img: Image,
	fluid_grid: Image,
	out_w: int,
	out_h: int,
	shader_params: Dictionary,
	is_spectral: bool,
	is_anything: bool
) -> Image:
	var result := Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))

	var bottom_dark := float(shader_params.get("bottom_darkening", 0.45))
	var liq_transp := float(shader_params.get("liquid_transparency", 0.9))
	var glass_refl := float(shader_params.get("glass_reflection_strength", 0.28))
	var margin_top := float(shader_params.get("inner_margin_top", 0.12))
	var margin_bot := float(shader_params.get("inner_margin_bottom", 0.88))

	var raw_surf = shader_params.get("surface_highlight_color", Color(1.4, 1.4, 1.5, 1.0))
	var surf_col: Color = raw_surf if raw_surf is Color else Color(1.4, 1.4, 1.5, 1.0)
	var raw_sec = shader_params.get("secondary_highlight_color", Color(0.9, 0.4, 0.95, 0.85))
	var sec_col: Color = raw_sec if raw_sec is Color else Color(0.9, 0.4, 0.95, 0.85)

	var tint_col := Color.WHITE
	var tint_strength := 0.0

	if is_spectral:
		tint_col = Color(0.45, 0.92, 1.0, 1.0)
		tint_strength = 0.35
		liq_transp = 0.5
		surf_col = Color(0.55, 1.45, 1.65, 1.0)
		sec_col = Color(0.45, 0.85, 1.5, 0.9)
		glass_refl = maxf(glass_refl, 0.5)
	elif is_anything:
		surf_col = Color(1.35, 1.35, 1.35, 1.0)
		sec_col = Color(0.78, 0.78, 0.78, 0.85)

	var mw := outside_img.get_width()
	var mh := outside_img.get_height()

	for py in GRID_SIZE:
		var uv_y := (float(py) + 0.5) / float(GRID_SIZE)
		for px in GRID_SIZE:
			var uv_x := (float(px) + 0.5) / float(GRID_SIZE)
			var mask_a := _sample_nearest(outside_img, mw, mh, uv_x, uv_y).a
			if mask_a < 0.05:
				continue

			var fluid := fluid_grid.get_pixel(px, py)
			var diag := uv_x * 0.85 + uv_y * 0.45
			var s1 := _smoothstep(0.08, 0.0, absf(diag - 0.52)) * 0.75
			var s2 := _smoothstep(0.04, 0.0, absf(diag - 0.68)) * 0.45
			var rim := _smoothstep(0.42, 0.49, absf(uv_x - 0.5)) * 0.35
			var glass_sheen := clampf(s1 + s2 + rim, 0.0, 1.0) * glass_refl

			if fluid.a < 0.08:
				result.set_pixel(px, py, Color(0.92, 0.96, 1.0, glass_sheen * mask_a))
			else:
				var m_up := _sample_nearest(outside_img, mw, mh, uv_x, (float(maxi(py - 1, 0)) + 0.5) / float(GRID_SIZE)).a
				var m_dn := _sample_nearest(outside_img, mw, mh, uv_x, (float(mini(py + 1, GRID_SIZE - 1)) + 0.5) / float(GRID_SIZE)).a
				var m_lf := _sample_nearest(outside_img, mw, mh, (float(maxi(px - 1, 0)) + 0.5) / float(GRID_SIZE), uv_y).a
				var m_rt := _sample_nearest(outside_img, mw, mh, (float(mini(px + 1, GRID_SIZE - 1)) + 0.5) / float(GRID_SIZE), uv_y).a

				var f_up := fluid_grid.get_pixel(px, maxi(py - 1, 0)).a
				var f_dn := fluid_grid.get_pixel(px, mini(py + 1, GRID_SIZE - 1)).a
				var f_lf := fluid_grid.get_pixel(maxi(px - 1, 0), py).a
				var f_rt := fluid_grid.get_pixel(mini(px + 1, GRID_SIZE - 1), py).a

				var air_up := (f_up < 0.25) and (m_up > 0.1 or py <= 1)
				var air_dn := (f_dn < 0.25) and (m_dn > 0.1)
				var air_lf := (f_lf < 0.25) and (m_lf > 0.1)
				var air_rt := (f_rt < 0.25) and (m_rt > 0.1)
				var is_surface := 1.0 if (air_up or air_dn or air_lf or air_rt) else 0.0

				var depth_factor := clampf((uv_y - margin_top) / maxf(margin_bot - margin_top, 0.1), 0.0, 1.0)
				var fr := lerpf(fluid.r, tint_col.r, tint_strength)
				var fg := lerpf(fluid.g, tint_col.g, tint_strength)
				var fb := lerpf(fluid.b, tint_col.b, tint_strength)

				var dark_mult := lerpf(1.0, 1.0 - bottom_dark, depth_factor)
				var br := fr * dark_mult
				var bg := fg * dark_mult
				var bb := fb * dark_mult

				if is_surface > 0.0:
					var st := sec_col.lerp(surf_col, 1.0 if air_up else 0.55)
					var w_s := is_surface * 0.72
					br = lerpf(br, maxf(br, st.r * 0.85), w_s)
					bg = lerpf(bg, maxf(bg, st.g * 0.85), w_s)
					bb = lerpf(bb, maxf(bb, st.b * 0.85), w_s)

				var sheen_w := glass_sheen * 0.55
				br = clampf(lerpf(br, 0.95, sheen_w), 0.0, 1.0)
				bg = clampf(lerpf(bg, 0.98, sheen_w), 0.0, 1.0)
				bb = clampf(lerpf(bb, 1.0, sheen_w), 0.0, 1.0)
				var out_a := clampf(fluid.a * liq_transp + glass_sheen * 0.35 + is_surface * 0.12, 0.0, 1.0) * mask_a
				result.set_pixel(px, py, Color(br, bg, bb, out_a))

	result.resize(out_w, out_h, Image.INTERPOLATE_NEAREST)
	return result

static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 0.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _sample_nearest(img: Image, w: int, h: int, u: float, v: float) -> Color:
	var x := clampi(int(floorf(u * float(w))), 0, w - 1)
	var y := clampi(int(floorf(v * float(h))), 0, h - 1)
	return img.get_pixel(x, y)

static func _blend_rotated_image(dst: Image, src: Image, center: Vector2i, rotation_deg: float) -> void:
	var sw := src.get_width()
	var sh := src.get_height()
	if absf(rotation_deg) < 0.5:
		var tl := Vector2i(center.x - sw / 2, center.y - sh / 2)
		var dst_rect := Rect2i(0, 0, dst.get_width(), dst.get_height())
		var src_rect := Rect2i(0, 0, sw, sh)
		var clipped := Rect2i(tl, Vector2i(sw, sh)).intersection(dst_rect)
		if clipped.size.x > 0 and clipped.size.y > 0:
			var local_src := Rect2i(clipped.position - tl, clipped.size).intersection(src_rect)
			if local_src.size.x > 0 and local_src.size.y > 0:
				dst.blend_rect(src, local_src, clipped.position)
		return

	var rad := deg_to_rad(rotation_deg)
	var cos_a := cos(-rad)
	var sin_a := sin(-rad)
	var half := ceili(sqrt(float(sw * sw + sh * sh)) * 0.5)
	var dw := dst.get_width()
	var dh := dst.get_height()
	var scx := float(sw) * 0.5
	var scy := float(sh) * 0.5

	for dy in range(-half, half + 1):
		var py := center.y + dy
		if py < 0 or py >= dh:
			continue
		for dx in range(-half, half + 1):
			var px := center.x + dx
			if px < 0 or px >= dw:
				continue
			var sx := int(roundf(float(dx) * cos_a - float(dy) * sin_a + scx))
			var sy := int(roundf(float(dx) * sin_a + float(dy) * cos_a + scy))
			if sx < 0 or sx >= sw or sy < 0 or sy >= sh:
				continue
			var sc := src.get_pixel(sx, sy)
			if sc.a <= 0.01:
				continue
			var dc := dst.get_pixel(px, py)
			var out_a := sc.a + dc.a * (1.0 - sc.a)
			if out_a <= 0.0001:
				continue
			var inv_a := 1.0 - sc.a
			var out_rgb := Color(
				(sc.r * sc.a + dc.r * dc.a * inv_a) / out_a,
				(sc.g * sc.a + dc.g * dc.a * inv_a) / out_a,
				(sc.b * sc.a + dc.b * dc.a * inv_a) / out_a,
				out_a
			)
			dst.set_pixel(px, py, out_rgb)

static func _get_glass_spec(glass_id: String) -> Dictionary:
	var key := glass_id.to_lower().strip_edges()
	if not GLASS_SCENES.has(key):
		key = ""
	if _glass_spec_cache.has(key):
		return _glass_spec_cache[key] as Dictionary

	var scene := GLASS_SCENES[key] as PackedScene
	var cup: Node = scene.instantiate() if scene else null
	var inside_sprite := cup.get_node_or_null("Inside") as Sprite3D if cup else null
	var outside_sprite := cup.get_node_or_null("Inside/Outside") as Sprite3D if cup else null

	var inside_tex: Texture2D = inside_sprite.texture if is_instance_valid(inside_sprite) else null
	var inside_modulate: Color = inside_sprite.modulate if is_instance_valid(inside_sprite) else Color.WHITE
	var outside_tex: Texture2D = outside_sprite.texture if is_instance_valid(outside_sprite) else null
	var outside_rel_scale := Vector2.ONE
	if is_instance_valid(outside_sprite):
		outside_rel_scale = Vector2(outside_sprite.scale.x, outside_sprite.scale.y)

	var shader_params: Dictionary = {}
	if is_instance_valid(outside_sprite) and outside_sprite.material_override is ShaderMaterial:
		var mat := outside_sprite.material_override as ShaderMaterial
		for p_name in [
			"pixel_resolution",
			"surface_highlight_color",
			"secondary_highlight_color",
			"surface_highlight_thickness",
			"bottom_darkening",
			"liquid_transparency",
			"inner_margin_top",
			"inner_margin_bottom",
			"caustic_beam_strength",
			"sparkle_density",
			"glass_reflection_strength",
			"meniscus_curve",
		]:
			var val = mat.get_shader_parameter(p_name)
			if val != null:
				shader_params[p_name] = val
		if outside_tex == null:
			var param_tex = mat.get_shader_parameter("texture_albedo")
			if param_tex is Texture2D:
				outside_tex = param_tex as Texture2D

	if is_instance_valid(cup):
		cup.free()

	var fallback_paths: Dictionary = FALLBACK_GLASS_ASSETS.get(key, FALLBACK_GLASS_ASSETS[""])
	if inside_tex == null:
		var in_path := str(fallback_paths.get("inside", ""))
		if in_path != "" and ResourceLoader.exists(in_path):
			inside_tex = load(in_path) as Texture2D
	if outside_tex == null:
		var out_path := str(fallback_paths.get("outside", ""))
		if out_path != "" and ResourceLoader.exists(out_path):
			outside_tex = load(out_path) as Texture2D

	var inside_img := _get_texture_image(inside_tex)
	var outside_img := _get_texture_image(outside_tex)
	var mask := _sample_mask(outside_img, GRID_SIZE)
	var mask_rows := _build_mask_rows(mask)
	var uv_bounds := CupGarnishVisuals._compute_uv_bounds(inside_tex, outside_tex)

	var spec := {
		"glass_key": key,
		"inside_img": inside_img,
		"inside_modulate": inside_modulate,
		"outside_img": outside_img,
		"outside_rel_scale": outside_rel_scale,
		"shader_params": shader_params,
		"mask": mask,
		"mask_rows": mask_rows,
		"uv_bounds": uv_bounds,
	}
	_glass_spec_cache[key] = spec
	return spec

static func _get_texture_image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	img = img.duplicate() as Image
	if img.is_compressed():
		var err := img.decompress()
		if err != OK:
			push_warning("ReceiptDrinkRenderer: Image.decompress() returned error %d" % err)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

static func _sample_mask(img: Image, grid_n: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(grid_n * grid_n)
	if img != null and not img.is_empty():
		var w := img.get_width()
		var h := img.get_height()
		for y in grid_n:
			var y0 := clampi(int(floor(float(y) / float(grid_n) * float(h))), 0, h - 1)
			var y1 := clampi(int(ceil(float(y + 1) / float(grid_n) * float(h))) - 1, y0, h - 1)
			for x in grid_n:
				var x0 := clampi(int(floor(float(x) / float(grid_n) * float(w))), 0, w - 1)
				var x1 := clampi(int(ceil(float(x + 1) / float(grid_n) * float(w))) - 1, x0, w - 1)
				var max_a := 0.0
				for sy in range(y0, y1 + 1):
					for sx in range(x0, x1 + 1):
						max_a = maxf(max_a, img.get_pixel(sx, sy).a)
						if max_a > 0.1:
							break
					if max_a > 0.1:
						break
				mask[x + y * grid_n] = 1 if max_a > 0.1 else 0
	else:
		for y in range(4, grid_n - 4):
			for x in range(10, grid_n - 10):
				mask[x + y * grid_n] = 1
	return mask

static func _build_mask_rows(mask: PackedByteArray) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var total_cells := 0
	for y in range(GRID_SIZE - 1, -1, -1):
		var xs := PackedInt32Array()
		for x in GRID_SIZE:
			if mask[x + y * GRID_SIZE] == 1:
				xs.append(x)
		if not xs.is_empty():
			total_cells += xs.size()
			rows.append({"y": y, "xs": xs, "cum_end": total_cells})
	return rows

static func _build_fluid_grid(
	spec: Dictionary,
	order: DrinkOrder,
	fill_ratio: float,
	is_shaken: bool,
	is_anything: bool,
	shaken_mode: String = "split"
) -> Image:
	var rows: Array[Dictionary] = spec["mask_rows"] as Array[Dictionary]
	var img := Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if rows.is_empty():
		return img

	var total_cells: int = int(rows[rows.size() - 1]["cum_end"])
	var target_cells: int = clampi(roundi(float(total_cells) * fill_ratio), 1, total_cells)

	var top_row_idx := 0
	for i in rows.size():
		top_row_idx = i
		if int(rows[i]["cum_end"]) >= target_cells:
			break

	var bottom_y: int = int(rows[0]["y"])
	var surface_y: int = int(rows[top_row_idx]["y"])
	var y_span: float = maxf(float(bottom_y - surface_y), 1.0)
	var slices := _build_color_slices(order, is_shaken, is_anything, shaken_mode)
	var use_vertical_split := (not is_anything) and is_shaken and shaken_mode != "averaged" and slices.size() >= 2

	for r_idx in range(top_row_idx + 1):
		var row: Dictionary = rows[r_idx]
		var y: int = int(row["y"])
		var h_t: float = clampf(float(bottom_y - y) / y_span, 0.0, 1.0)
		var xs: PackedInt32Array = row["xs"]
		if xs.is_empty():
			continue
		if use_vertical_split:
			var row_min_x: int = xs[0]
			var row_max_x: int = xs[xs.size() - 1]
			var x_span: float = maxf(float(row_max_x - row_min_x + 1), 1.0)
			for x in xs:
				var w_t: float = clampf((float(x - row_min_x) + 0.5) / x_span, 0.0, 1.0)
				var col := _sample_slices_color(slices, w_t, 0.0)
				img.set_pixel(x, y, col)
		else:
			var col: Color
			if is_anything:
				var gray := lerpf(0.04, 0.98, h_t)
				col = Color(gray, gray, gray, 1.0)
			else:
				col = _sample_slices_color(slices, h_t)
			for x in xs:
				img.set_pixel(x, y, col)

	return img

static func _build_color_slices(order: DrinkOrder, is_shaken: bool, is_anything: bool, shaken_mode: String = "split") -> Array[Dictionary]:
	var slices: Array[Dictionary] = []
	if is_anything:
		return slices

	var norm_ings: Dictionary = order.get_normalized_ingredients()
	if norm_ings.is_empty():
		slices.append({"start": 0.0, "end": 1.0, "color": Color.WHITE})
		return slices

	if is_shaken and norm_ings.size() >= 2 and shaken_mode == "averaged":
		var color_weights: Array = []
		for ing_key in norm_ings.keys():
			var ing_id := str(ing_key).to_lower().strip_edges()
			var amt := float(norm_ings[ing_key])
			if amt > 0.0001:
				color_weights.append([_get_liquid_color(ing_id), amt])
		var mixed_col := _average_hsv_color(color_weights)
		slices.append({"start": 0.0, "end": 1.0, "color": mixed_col})
		return slices

	var layers: Array[Dictionary] = []
	var total_w := 0.0
	for ing_key in norm_ings.keys():
		var ing_id := str(ing_key).to_lower().strip_edges()
		var amt := float(norm_ings[ing_key])
		if amt <= 0.0001:
			continue
		var col := _get_liquid_color(ing_id)
		var buoy := AtomicFluidShaders.get_liquid_buoyancy(ing_id)
		total_w += amt
		layers.append({"id": ing_id, "amt": amt, "color": col, "buoy": buoy})

	layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ba := float(a["buoy"])
		var bb := float(b["buoy"])
		if is_equal_approx(ba, bb):
			return str(a["id"]) < str(b["id"])
		return ba < bb
	)

	var cursor := 0.0
	for i in layers.size():
		var share := float(layers[i]["amt"]) / maxf(total_w, 0.0001)
		var next_c := 1.0 if i == layers.size() - 1 else clampf(cursor + share, 0.0, 1.0)
		slices.append({"start": cursor, "end": next_c, "color": layers[i]["color"] as Color})
		cursor = next_c

	return slices

static func _sample_slices_color(slices: Array[Dictionary], t: float, blend_band: float = 0.025) -> Color:
	if slices.is_empty():
		return Color.WHITE
	if slices.size() == 1:
		return slices[0]["color"] as Color

	for i in slices.size():
		var s: Dictionary = slices[i]
		var st := float(s["start"])
		var en := float(s["end"])
		if t <= en or i == slices.size() - 1:
			var col := s["color"] as Color
			if blend_band > 0.0:
				if i + 1 < slices.size() and en - t < blend_band:
					var next_col := slices[i + 1]["color"] as Color
					var mix_t := clampf((blend_band - (en - t)) / (blend_band * 2.0), 0.0, 0.5)
					return col.lerp(next_col, mix_t)
				if i > 0 and t - st < blend_band:
					var prev_col := slices[i - 1]["color"] as Color
					var mix_t := clampf((blend_band - (t - st)) / (blend_band * 2.0), 0.0, 0.5)
					return col.lerp(prev_col, mix_t)
			return col
	return slices[slices.size() - 1]["color"] as Color

static func _build_garnish_entries(uv_bounds: Dictionary, order: DrinkOrder, fill_ratio: float) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	var rim_min_u := float(uv_bounds.get("rim_min_u", 0.15))
	var rim_max_u := float(uv_bounds.get("rim_max_u", 0.85))
	var rim_width := maxf(rim_max_u - rim_min_u, 0.25)
	var rim_center_u := (rim_min_u + rim_max_u) * 0.5
	var top_lip_v := float(uv_bounds.get("outer_top_v", 0.12))

	var inner_min_u := float(uv_bounds.get("inner_min_u", 0.18))
	var inner_max_u := float(uv_bounds.get("inner_max_u", 0.82))
	var inner_width := maxf(inner_max_u - inner_min_u, rim_width * 0.7)
	var inner_center_u := (inner_min_u + inner_max_u) * 0.5
	var inner_half_w := inner_width * 0.5

	var inner_top_v := float(uv_bounds.get("inner_top_v", 0.15))
	var inner_bottom_v := float(uv_bounds.get("inner_bottom_v", 0.88))
	var surface_v := lerpf(inner_bottom_v, inner_top_v, clampf(fill_ratio, 0.05, 0.96))
	var liquid_span_v := maxf(inner_bottom_v - surface_v, 0.04)

	var left_start_u := lerpf(rim_center_u, rim_min_u, CupGarnishVisuals.RIM_CENTER_SPREAD)
	var right_start_u := lerpf(rim_center_u, rim_max_u, CupGarnishVisuals.RIM_CENTER_SPREAD)

	var left_idx := 0
	var right_idx := 0
	var herb_idx := 0
	var ice_ball_idx := 0

	for raw_g in order.garnishes:
		var g_id := GarnishDefinitions.normalize_id(str(raw_g))
		var placement := GarnishDefinitions.get_placement(g_id)
		match placement:
			"rim_left":
				var shift_u := -rim_width * CupGarnishVisuals.RIM_SHIFT_RATIO * float(left_idx)
				entries.append({
					"texture": GarnishDefinitions.get_texture(g_id, false),
					"u": left_start_u + shift_u,
					"v": top_lip_v,
					"size_rel": rim_width * CupGarnishVisuals.RIM_SCALE_RATIO,
					"rotation_deg": 0.0,
				})
				left_idx += 1
			"rim_right":
				var shift_u := rim_width * CupGarnishVisuals.RIM_SHIFT_RATIO * float(right_idx)
				entries.append({
					"texture": GarnishDefinitions.get_texture(g_id, false),
					"u": right_start_u + shift_u,
					"v": top_lip_v,
					"size_rel": rim_width * CupGarnishVisuals.RIM_SCALE_RATIO,
					"rotation_deg": 0.0,
				})
				right_idx += 1
			"surface_float":
				var spread_u := 0.0
				if herb_idx > 0:
					var side := -1.0 if (herb_idx % 2 == 1) else 1.0
					var ring := float((herb_idx + 1) / 2)
					spread_u = clampf(side * ring * 0.22, -0.58, 0.58)
				var rot := fmod(float(herb_idx) * 19.0 - 8.0, 32.0) - 16.0
				entries.append({
					"texture": GarnishDefinitions.get_texture(g_id, false),
					"u": clampf(inner_center_u + spread_u * inner_half_w * 0.68, inner_min_u + inner_half_w * 0.15, inner_max_u - inner_half_w * 0.15),
					"v": surface_v,
					"size_rel": inner_width * CupGarnishVisuals.HERB_SCALE_RATIO,
					"rotation_deg": rot,
				})
				herb_idx += 1
			"liquid_float":
				var norm_depth := clampf(0.42 + float(ice_ball_idx % 3) * 0.20, 0.15, 0.88)
				var norm_x := 0.0 if ice_ball_idx == 0 else clampf((float((ice_ball_idx % 3) - 1)) * 0.32, -0.45, 0.45)
				entries.append({
					"texture": GarnishDefinitions.get_texture(g_id, false),
					"u": clampf(inner_center_u + norm_x * inner_half_w * 0.5, inner_min_u + inner_half_w * 0.25, inner_max_u - inner_half_w * 0.25),
					"v": lerpf(inner_bottom_v - liquid_span_v * 0.16, surface_v + liquid_span_v * 0.14, norm_depth),
					"size_rel": inner_width * CupGarnishVisuals.ICE_BALL_SCALE_RATIO,
					"rotation_deg": float((ice_ball_idx % 4) * 11 - 15),
				})
				ice_ball_idx += 1

	if order.ice_preference == DrinkRecipe.IcePreference.REQUIRED:
		var cube_count := GarnishDefinitions.ICE_CUBE_COUNT
		var cube_offsets := [-0.42, 0.36, -0.15, 0.48, -0.48, 0.14, -0.26, 0.28]
		var cube_rots := [-22.0, 18.0, -11.0, 25.0, 14.0, -26.0, 8.0, -16.0]
		for i in range(cube_count):
			var norm_depth := clampf((float(i) + 0.5) / float(cube_count), 0.10, 0.90)
			var norm_x := float(cube_offsets[i % cube_offsets.size()])
			entries.append({
				"texture": GarnishDefinitions.get_texture("ice", true),
				"u": clampf(inner_center_u + norm_x * inner_half_w * 0.55, inner_min_u + inner_half_w * 0.22, inner_max_u - inner_half_w * 0.22),
				"v": lerpf(inner_bottom_v - liquid_span_v * 0.14, surface_v + liquid_span_v * 0.12, norm_depth),
				"size_rel": inner_width * CupGarnishVisuals.ICE_CUBE_SCALE_RATIO,
				"rotation_deg": float(cube_rots[i % cube_rots.size()]),
			})

	return entries

static func _average_hsv_color(color_weights: Array) -> Color:
	if color_weights.is_empty():
		return Color.WHITE

	var total_weight: float = 0.0
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_s: float = 0.0
	var sum_v: float = 0.0
	var sum_a: float = 0.0

	for item in color_weights:
		var c: Color = item[0]
		var w: float = float(item[1])
		if w <= 0.0:
			continue
		total_weight += w
		var angle := c.h * TAU
		var sat_w := maxf(c.s, 0.01) * w
		sum_x += cos(angle) * sat_w
		sum_y += sin(angle) * sat_w
		sum_s += c.s * w
		sum_v += c.v * w
		sum_a += c.a * w

	if total_weight <= 0.0:
		return Color.WHITE

	var avg_h: float = 0.0
	if absf(sum_x) > 0.0001 or absf(sum_y) > 0.0001:
		var avg_angle := atan2(sum_y, sum_x)
		if avg_angle < 0.0:
			avg_angle += TAU
		avg_h = avg_angle / TAU
	else:
		avg_h = color_weights[0][0].h

	var avg_s := clampf(sum_s / total_weight, 0.35, 1.0)
	var avg_v := clampf(sum_v / total_weight, 0.5, 1.0)
	var avg_a := clampf(sum_a / total_weight, 0.0, 1.0)
	return Color.from_hsv(avg_h, avg_s, avg_v, avg_a)

static func _get_liquid_color(ing_id: String) -> Color:
	if _custom_liquid_colors.has(ing_id):
		return _custom_liquid_colors[ing_id] as Color
	if AtomicFluidShaders.LIQUID_COLOR.has(ing_id):
		return AtomicFluidShaders.LIQUID_COLOR[ing_id] as Color
	var res := _find_liquid_resource(ing_id)
	if res:
		_custom_liquid_colors[ing_id] = res.liquid_color
		if res.buoyancy > 0.0:
			AtomicFluidShaders.register_liquid_buoyancy(ing_id, res.buoyancy)
		if res.viscosity >= 0.0:
			AtomicFluidShaders.register_liquid_viscosity(ing_id, res.viscosity)
		return res.liquid_color
	return Color.WHITE

static func _find_liquid_resource(ing_id: String) -> Liquid:
	var direct_path := "%s/%s.tres" % [LIQUID_RESOURCE_DIR, ing_id]
	if ResourceLoader.exists(direct_path):
		var loaded = load(direct_path)
		if loaded is Liquid:
			return loaded as Liquid

	if not _liquid_resources_scanned:
		_liquid_resources_scanned = true
		var filenames: PackedStringArray = PackedStringArray()
		if ResourceLoader.has_method("list_directory"):
			filenames = ResourceLoader.list_directory(LIQUID_RESOURCE_DIR)
		if filenames.is_empty():
			var dir := DirAccess.open(LIQUID_RESOURCE_DIR)
			if dir:
				dir.list_dir_begin()
				var entry := dir.get_next()
				while entry != "":
					if not dir.current_is_dir():
						filenames.append(entry)
					entry = dir.get_next()
				dir.list_dir_end()
		for raw_name in filenames:
			var clean_name := raw_name.trim_suffix(".remap")
			if not clean_name.ends_with(".tres"):
				continue
			var res_obj = load(LIQUID_RESOURCE_DIR + "/" + clean_name)
			if res_obj is Liquid:
				var liq := res_obj as Liquid
				_liquid_resource_cache[liq.id.to_lower().strip_edges()] = liq

	return _liquid_resource_cache.get(ing_id, null) as Liquid

static func _build_cache_key(
	order: DrinkOrder,
	species_def: SpeciesBase,
	modifier: ModifierBase,
	aspect_comp: float,
	shaken_mode: String = "split"
) -> String:
	var glass_id := order.required_glass.to_lower().strip_edges()
	var is_anything := (not order.require_ingredient_match) or order.ingredients.is_empty()
	var fill_ratio := clampf(order.ideal_fill_ratio if order.ideal_fill_ratio >= 0.0 else DEFAULT_RECEIPT_FILL_RATIO, 0.1, 1.0)

	var ing_parts := PackedStringArray()
	if not is_anything:
		var norm := order.get_normalized_ingredients()
		var keys := norm.keys()
		keys.sort()
		for k in keys:
			ing_parts.append("%s:%.3f" % [str(k).to_lower().strip_edges(), float(norm[k])])

	var proc_parts := PackedStringArray()
	for tag in order.required_processing:
		var clean_tag := str(tag).to_lower().strip_edges()
		if clean_tag != "" and not proc_parts.has(clean_tag):
			proc_parts.append(clean_tag)
	proc_parts.sort()

	var g_counts := order.get_garnish_counts()
	var g_keys := g_counts.keys()
	g_keys.sort()
	var garnish_parts := PackedStringArray()
	for gk in g_keys:
		garnish_parts.append("%s:%d" % [str(gk), int(g_counts[gk])])

	var has_ice := order.ice_preference == DrinkRecipe.IcePreference.REQUIRED
	var sp_id := species_def.species_id if species_def else order.species_id
	var mod_id := modifier.modifier_id if modifier else ""

	return "%s|any=%s|fill=%.3f|ing=[%s]|proc=[%s]|gar=[%s]|ice=%s|tiny=%s|sp=%s|mod=%s|ar=%.3f|sm=%s" % [
		glass_id,
		str(is_anything),
		fill_ratio,
		",".join(ing_parts),
		",".join(proc_parts),
		",".join(garnish_parts),
		str(has_ice),
		str(order.is_tiny),
		sp_id.to_upper(),
		mod_id.to_upper(),
		aspect_comp,
		shaken_mode,
	]