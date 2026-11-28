class_name CupGarnishVisuals
extends RefCounted

const GARNISH_ROOT_NAME: String = "GarnishRoot"

const RIM_SCALE_RATIO: float = 0.34
const RIM_SHIFT_RATIO: float = 0.055
const RIM_CENTER_SPREAD: float = 0.70
const RIM_Z_BASE: float = -0.015
const RIM_Z_STEP: float = -0.002

const HERB_SCALE_RATIO: float = 0.30
const HERB_Z_BASE: float = -0.013

const ICE_CUBE_SCALE_RATIO: float = 0.40
const ICE_BALL_SCALE_RATIO: float = 0.78
const ICE_Z_BASE: float = -0.013

static var _layout_cache: Dictionary = {}

var _cup: Node3D = null
var _cup_sprite: Sprite3D = null
var _outside_sprite: Sprite3D = null
var _root: Node3D = null

var _left_nodes: Array[Sprite3D] = []
var _right_nodes: Array[Sprite3D] = []
var _herb_entries: Array[Dictionary] = []
var _ice_entries: Array[Dictionary] = []
var _interactive_entries: Array[Dictionary] = []

var _hovered_sprite: Sprite3D = null
var _dragged_sprite: Sprite3D = null

var _time: float = 0.0
var _synced_garnish_sig: String = ""
var _synced_has_ice: bool = false

func setup(cup: Node3D, cup_sprite: Sprite3D, outside_sprite: Sprite3D = null) -> void:
	_cup = cup
	_cup_sprite = cup_sprite
	_outside_sprite = outside_sprite
	_ensure_root()

func _ensure_root() -> Node3D:
	if is_instance_valid(_root):
		return _root
	var host: Node3D = _cup_sprite if is_instance_valid(_cup_sprite) else _cup
	if not is_instance_valid(host):
		return null
	var existing := host.get_node_or_null(GARNISH_ROOT_NAME) as Node3D
	if is_instance_valid(existing):
		_root = existing
		return _root
	_root = Node3D.new()
	_root.name = GARNISH_ROOT_NAME
	host.add_child(_root)
	return _root

func clear() -> void:
	_synced_garnish_sig = ""
	_synced_has_ice = false
	_hovered_sprite = null
	_dragged_sprite = null
	_interactive_entries.clear()
	for sp in _left_nodes:
		if is_instance_valid(sp):
			sp.queue_free()
	for sp in _right_nodes:
		if is_instance_valid(sp):
			sp.queue_free()
	for entry in _herb_entries:
		var sp := entry.get("sprite") as Sprite3D
		if is_instance_valid(sp):
			sp.queue_free()
	for entry in _ice_entries:
		var sp := entry.get("sprite") as Sprite3D
		if is_instance_valid(sp):
			sp.queue_free()
	_left_nodes.clear()
	_right_nodes.clear()
	_herb_entries.clear()
	_ice_entries.clear()

func sync_from_mix(mix: DrinkMix) -> void:
	if mix == null:
		clear()
		return
	var sig := "|".join(PackedStringArray(mix.garnishes))
	if sig == _synced_garnish_sig and mix.has_ice == _synced_has_ice:
		return

	_synced_garnish_sig = sig
	_synced_has_ice = mix.has_ice
	_rebuild_visuals(mix)

func _register_interactive_entry(sp: Sprite3D, garnish_id: String, is_ice_cube: bool) -> Dictionary:
	var entry := {
		"sprite": sp,
		"garnish_id": garnish_id,
		"is_ice_cube": is_ice_cube,
		"home_local_pos": sp.position,
		"home_rot_z": sp.rotation_degrees.z,
		"base_scale": sp.scale,
	}
	_interactive_entries.append(entry)
	return entry

func _rebuild_visuals(mix: DrinkMix) -> void:
	var root := _ensure_root()
	if not is_instance_valid(root):
		return

	_hovered_sprite = null
	_dragged_sprite = null
	_interactive_entries.clear()

	for sp in _left_nodes:
		if is_instance_valid(sp):
			sp.queue_free()
	for sp in _right_nodes:
		if is_instance_valid(sp):
			sp.queue_free()
	for entry in _herb_entries:
		var sp := entry.get("sprite") as Sprite3D
		if is_instance_valid(sp):
			sp.queue_free()
	for entry in _ice_entries:
		var sp := entry.get("sprite") as Sprite3D
		if is_instance_valid(sp):
			sp.queue_free()

	_left_nodes.clear()
	_right_nodes.clear()
	_herb_entries.clear()
	_ice_entries.clear()

	var layout := _get_local_layout()
	var rim_width: float = float(layout["rim_width"])
	var inner_min_x: float = float(layout["inner_min_x"])
	var inner_max_x: float = float(layout["inner_max_x"])
	var inner_center_x: float = (inner_min_x + inner_max_x) * 0.5
	var inner_width: float = maxf(inner_max_x - inner_min_x, rim_width * 0.7)
	var inner_half_w: float = maxf(inner_width * 0.5, 0.02)
	var bottom_y: float = float(layout["inner_bottom_y"])
	var top_y: float = float(layout["inner_top_y"])
	var liquid_h: float = maxf(top_y - bottom_y, 0.02)

	var left_edge_x: float = float(layout["left_edge_x"])
	var right_edge_x: float = float(layout["right_edge_x"])
	var rim_center_x: float = (left_edge_x + right_edge_x) * 0.5
	var left_start_x: float = lerpf(rim_center_x, left_edge_x, RIM_CENTER_SPREAD)
	var right_start_x: float = lerpf(rim_center_x, right_edge_x, RIM_CENTER_SPREAD)
	var top_lip_y: float = float(layout["top_lip_y"])
	var left_dir: float = float(layout["left_dir"])
	var right_dir: float = -left_dir

	var left_idx: int = 0
	var right_idx: int = 0
	var herb_idx: int = 0
	var ice_ball_idx: int = 0

	for raw_g in mix.garnishes:
		var g_id := GarnishDefinitions.normalize_id(str(raw_g))
		var placement := GarnishDefinitions.get_placement(g_id)
		match placement:
			"rim_left":
				var sp := _create_garnish_sprite(g_id, false, rim_width * RIM_SCALE_RATIO, 3 + left_idx)
				var shift_x := left_dir * (rim_width * RIM_SHIFT_RATIO * float(left_idx))
				sp.position = Vector3(left_start_x + shift_x, top_lip_y, RIM_Z_BASE + RIM_Z_STEP * float(left_idx))
				root.add_child(sp)
				_left_nodes.append(sp)
				_register_interactive_entry(sp, g_id, false)
				left_idx += 1
			"rim_right":
				var sp := _create_garnish_sprite(g_id, false, rim_width * RIM_SCALE_RATIO, 3 + right_idx)
				var shift_x := right_dir * (rim_width * RIM_SHIFT_RATIO * float(right_idx))
				sp.position = Vector3(right_start_x + shift_x, top_lip_y, RIM_Z_BASE + RIM_Z_STEP * float(right_idx))
				root.add_child(sp)
				_right_nodes.append(sp)
				_register_interactive_entry(sp, g_id, false)
				right_idx += 1
			"surface_float":
				var sp := _create_garnish_sprite(g_id, false, inner_width * HERB_SCALE_RATIO, 3)
				var spread_u := 0.0
				if herb_idx > 0:
					var side := -1.0 if (herb_idx % 2 == 1) else 1.0
					var ring := float((herb_idx + 1) / 2)
					spread_u = clampf(side * ring * 0.22, -0.58, 0.58)
				sp.rotation_degrees.z = randf_range(-16.0, 16.0)
				sp.position = Vector3(inner_center_x + spread_u * inner_half_w * 0.68, bottom_y + liquid_h * 0.06, HERB_Z_BASE - float(herb_idx) * 0.0005)
				root.add_child(sp)
				var i_entry := _register_interactive_entry(sp, g_id, false)
				_herb_entries.append({
					"sprite": sp,
					"interactive_entry": i_entry,
					"norm_x": spread_u,
					"phase": float(herb_idx) * 1.37 + randf_range(0.0, TAU),
					"base_rot": sp.rotation_degrees.z,
				})
				herb_idx += 1
			"liquid_float":
				var sp := _create_garnish_sprite(g_id, false, inner_width * ICE_BALL_SCALE_RATIO, 3)
				sp.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
				sp.modulate = Color.WHITE
				sp.rotation_degrees.z = 0.0 if ice_ball_idx == 0 else randf_range(-14.0, 14.0)
				var norm_depth := 0.56 if ice_ball_idx == 0 else clampf(0.45 + float(ice_ball_idx % 3) * 0.18 + randf_range(-0.08, 0.08), 0.20, 0.85)
				var norm_x := 0.0 if ice_ball_idx == 0 else clampf(randf_range(-0.35, 0.35), -0.38, 0.38)
				var init_x := clampf(inner_center_x + norm_x * inner_half_w * 0.28, inner_center_x - inner_half_w * 0.28, inner_center_x + inner_half_w * 0.28)
				var init_y := bottom_y + liquid_h * 0.36
				sp.position = Vector3(init_x, init_y, ICE_Z_BASE - float(ice_ball_idx) * 0.0005)
				root.add_child(sp)
				var i_entry := _register_interactive_entry(sp, g_id, false)
				_ice_entries.append({
					"sprite": sp,
					"interactive_entry": i_entry,
					"is_ball": true,
					"norm_x": norm_x,
					"norm_depth": norm_depth,
					"phase": randf_range(0.0, TAU),
					"speed": randf_range(1.1, 1.7),
					"base_rot": sp.rotation_degrees.z,
				})
				ice_ball_idx += 1

	if mix.has_ice:
		var cube_count := GarnishDefinitions.ICE_CUBE_COUNT
		for i in range(cube_count):
			var size_mult := randf_range(0.92, 1.16)
			var sp := _create_garnish_sprite("ice", true, inner_width * ICE_CUBE_SCALE_RATIO * size_mult, 3)
			sp.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
			sp.modulate = Color.WHITE
			sp.rotation_degrees.z = randf_range(-28.0, 28.0)
			var norm_depth := clampf((float(i) + 0.5) / float(cube_count) + randf_range(-0.06, 0.06), 0.05, 0.95)
			var norm_x := clampf(randf_range(-0.55, 0.55), -0.55, 0.55)
			var init_x := clampf(inner_center_x + norm_x * inner_half_w * 0.55, inner_min_x + inner_half_w * 0.22, inner_max_x - inner_half_w * 0.22)
			var init_y := lerpf(bottom_y + liquid_h * 0.14, bottom_y + liquid_h * 0.48, norm_depth)
			sp.position = Vector3(init_x, init_y, ICE_Z_BASE - 0.004 - float(i) * 0.0004)
			root.add_child(sp)
			var i_entry := _register_interactive_entry(sp, "ice", true)
			_ice_entries.append({
				"sprite": sp,
				"interactive_entry": i_entry,
				"is_ball": false,
				"norm_x": norm_x,
				"norm_depth": norm_depth,
				"phase": randf_range(0.0, TAU),
				"speed": randf_range(1.6, 2.8),
				"base_rot": sp.rotation_degrees.z,
			})

func update(delta: float, total_liquids: float, cup_size: float, visual_helper: LiquidVisualHelper = null) -> void:
	_time += delta
	if _herb_entries.is_empty() and _ice_entries.is_empty():
		return

	var layout := _get_local_layout()
	var inner_min_x: float = float(layout["inner_min_x"])
	var inner_max_x: float = float(layout["inner_max_x"])
	var inner_center_x: float = (inner_min_x + inner_max_x) * 0.5
	var inner_half_w: float = maxf((inner_max_x - inner_min_x) * 0.5, 0.02)
	var bottom_y: float = float(layout["inner_bottom_y"])
	var top_y: float = float(layout["inner_top_y"])

	var has_liquid: bool = total_liquids > 0.001
	var fill_ratio: float = clampf(total_liquids / maxf(cup_size, 0.001), 0.0, 1.0) if has_liquid else 0.0
	var slosh_angle: float = visual_helper.slosh_angle if visual_helper else 0.0
	var slosh_v_off: float = visual_helper.slosh_vertical_offset if visual_helper else 0.0
	var liquid_h: float = maxf(top_y - bottom_y, 0.02)
	var surface_y: float = lerpf(bottom_y, top_y, fill_ratio) + slosh_v_off * liquid_h * 0.15
	surface_y = clampf(surface_y, bottom_y, top_y)

	for entry in _herb_entries:
		var sp := entry.get("sprite") as Sprite3D
		if not is_instance_valid(sp):
			continue
		var norm_x: float = float(entry["norm_x"])
		var phase: float = float(entry["phase"])
		var base_rot: float = float(entry["base_rot"])
		var drift_x := sin(_time * 1.4 + phase) * inner_half_w * 0.08 if has_liquid else 0.0
		var local_x := clampf(inner_center_x + norm_x * inner_half_w * 0.68 + drift_x, inner_min_x + inner_half_w * 0.15, inner_max_x - inner_half_w * 0.15)
		var local_y := bottom_y + liquid_h * 0.06
		var target_rot := base_rot
		if has_liquid:
			var slosh_tilt_y := -local_x * tan(slosh_angle) * 0.45
			var bob := sin(_time * 2.6 + phase) * liquid_h * 0.025
			local_y = clampf(surface_y + slosh_tilt_y + bob, bottom_y + liquid_h * 0.05, top_y)
			target_rot = base_rot + rad_to_deg(slosh_angle) * 0.5 + sin(_time * 2.1 + phase) * 5.0
		var i_entry: Variant = entry.get("interactive_entry", null)
		if i_entry is Dictionary:
			(i_entry as Dictionary)["home_local_pos"] = Vector3(local_x, local_y, sp.position.z)
			(i_entry as Dictionary)["home_rot_z"] = target_rot
		if sp == _dragged_sprite:
			continue
		sp.position.x = local_x
		sp.position.y = local_y
		sp.rotation_degrees.z = target_rot

	for entry in _ice_entries:
		var sp := entry.get("sprite") as Sprite3D
		if not is_instance_valid(sp):
			continue
		var is_ball := bool(entry.get("is_ball", false))
		var norm_x: float = float(entry["norm_x"])
		var norm_depth: float = float(entry["norm_depth"])
		var phase: float = float(entry["phase"])
		var spd: float = float(entry["speed"])
		var base_rot: float = float(entry["base_rot"])

		var local_x: float
		var rest_y: float
		var local_y: float
		var target_rot := base_rot
		if is_ball:
			local_x = clampf(inner_center_x + norm_x * inner_half_w * 0.28, inner_center_x - inner_half_w * 0.28, inner_center_x + inner_half_w * 0.28)
			rest_y = bottom_y + liquid_h * 0.36
			local_y = rest_y
			if has_liquid:
				var col_top := clampf(surface_y - liquid_h * 0.14, bottom_y + liquid_h * 0.34, top_y)
				var float_y := lerpf(bottom_y + liquid_h * 0.32, col_top, norm_depth)
				var sway_x := sin(_time * spd + phase) * inner_half_w * 0.04 + slosh_angle * inner_half_w * 0.10
				var bob_y := cos(_time * (spd * 0.85) + phase) * liquid_h * 0.025
				local_x = clampf(local_x + sway_x, inner_center_x - inner_half_w * 0.28, inner_center_x + inner_half_w * 0.28)
				local_y = clampf(maxf(rest_y, float_y) + bob_y, bottom_y + liquid_h * 0.30, maxf(rest_y, col_top))
				target_rot = base_rot + sin(_time * spd * 0.6 + phase) * 5.0 + rad_to_deg(slosh_angle) * 0.3
		else:
			local_x = clampf(inner_center_x + norm_x * inner_half_w * 0.55, inner_min_x + inner_half_w * 0.22, inner_max_x - inner_half_w * 0.22)
			rest_y = lerpf(bottom_y + liquid_h * 0.14, bottom_y + liquid_h * 0.48, norm_depth)
			local_y = rest_y
			if has_liquid:
				var col_top := clampf(surface_y - liquid_h * 0.06, bottom_y + liquid_h * 0.14, top_y)
				var float_y := lerpf(bottom_y + liquid_h * 0.14, col_top, norm_depth)
				var sway_x := sin(_time * spd + phase) * inner_half_w * 0.08 + slosh_angle * inner_half_w * 0.16
				var bob_y := cos(_time * (spd * 0.85) + phase) * liquid_h * 0.03
				local_x = clampf(local_x + sway_x, inner_min_x + inner_half_w * 0.22, inner_max_x - inner_half_w * 0.22)
				local_y = clampf(maxf(rest_y, float_y) + bob_y, bottom_y + liquid_h * 0.12, maxf(rest_y, col_top))
				target_rot = base_rot + sin(_time * spd * 0.7 + phase) * 8.0 + rad_to_deg(slosh_angle) * 0.4

		var i_entry: Variant = entry.get("interactive_entry", null)
		if i_entry is Dictionary:
			(i_entry as Dictionary)["home_local_pos"] = Vector3(local_x, local_y, sp.position.z)
			(i_entry as Dictionary)["home_rot_z"] = target_rot
		if sp == _dragged_sprite:
			continue
		sp.position.x = local_x
		sp.position.y = local_y
		sp.rotation_degrees.z = target_rot

func hit_test(mouse_pos: Vector2, cam: Camera3D) -> Dictionary:
	if not is_instance_valid(cam) or _interactive_entries.is_empty():
		return {}
	var vp := cam.get_viewport()
	var ray_pos := Ingredients._unwarp_fisheye_screen_pos(vp, mouse_pos) if is_instance_valid(vp) else mouse_pos
	var from := cam.project_ray_origin(ray_pos)
	var dir := cam.project_ray_normal(ray_pos)
	var best_entry: Dictionary = {}
	var best_dist: float = INF
	var best_prio: int = -999

	for entry in _interactive_entries:
		var sp := entry.get("sprite") as Sprite3D
		if not is_instance_valid(sp) or not sp.visible or not sp.is_inside_tree():
			continue
		var normal := sp.global_transform.basis.z.normalized()
		if normal.length_squared() < 0.0001:
			continue
		var hit = Plane(normal, sp.global_position).intersects_ray(from, dir)
		if hit == null:
			continue
		var hit_vec: Vector3 = hit as Vector3
		var local_p := sp.global_transform.affine_inverse() * hit_vec

		var opaque_rect = Ingredients.compute_sprite_opaque_rect(sp)
		if opaque_rect is Rect2:
			var r := opaque_rect as Rect2
			if local_p.x < r.position.x or local_p.x > r.end.x or local_p.y < r.position.y or local_p.y > r.end.y:
				continue
		else:
			var dims: Rect2 = sp.get_item_rect()
			var ps := sp.pixel_size
			if dims.size.x <= 0.0 or dims.size.y <= 0.0 or ps <= 0.000001:
				continue
			var px_x := local_p.x / ps
			var px_y := local_p.y / ps
			if px_x < dims.position.x or px_x > dims.end.x or px_y < dims.position.y or px_y > dims.end.y:
				continue

		var dist := from.distance_to(hit_vec)
		var prio := sp.render_priority
		if prio > best_prio or (prio == best_prio and dist < best_dist):
			best_prio = prio
			best_dist = dist
			best_entry = entry

	return best_entry

func set_hovered_sprite(sp: Sprite3D) -> void:
	if _hovered_sprite == sp:
		return
	if is_instance_valid(_hovered_sprite) and _hovered_sprite != _dragged_sprite:
		_hovered_sprite.modulate = Color.WHITE
	_hovered_sprite = sp
	if is_instance_valid(_hovered_sprite) and _hovered_sprite != _dragged_sprite:
		_hovered_sprite.modulate = Color(1.5, 1.5, 0.4, 1.0)

func set_dragged_sprite(sp: Sprite3D, outside_cup: bool = false) -> void:
	if is_instance_valid(_dragged_sprite) and _dragged_sprite != sp:
		_dragged_sprite.modulate = Color.WHITE
	_dragged_sprite = sp
	if is_instance_valid(_dragged_sprite):
		_dragged_sprite.modulate = Color(1.0, 0.4, 0.4, 0.85) if outside_cup else Color(1.25, 1.25, 0.95, 1.0)

func clear_interaction_states() -> void:
	if is_instance_valid(_hovered_sprite):
		_hovered_sprite.modulate = Color.WHITE
	if is_instance_valid(_dragged_sprite):
		_dragged_sprite.modulate = Color.WHITE
	_hovered_sprite = null
	_dragged_sprite = null

func _create_garnish_sprite(garnish_id: String, for_cup_cube: bool, target_local_size: float, render_prio: int) -> Sprite3D:
	var tex := GarnishDefinitions.get_texture(garnish_id, for_cup_cube)
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.render_priority = render_prio
	sp.shaded = true

	var tex_size := tex.get_size() if tex else Vector2(32.0, 32.0)
	var max_dim := maxf(maxf(tex_size.x, tex_size.y) * sp.pixel_size, 0.001)
	var s := target_local_size / max_dim
	sp.scale = Vector3(s, s, 1.0)
	return sp

func _get_screen_left_sign() -> float:
	if is_instance_valid(_cup_sprite) and _cup_sprite.is_inside_tree():
		var vp := _cup_sprite.get_viewport()
		var cam := vp.get_camera_3d() if vp else null
		if is_instance_valid(cam):
			return 1.0 if _cup_sprite.global_transform.basis.x.dot(cam.global_transform.basis.x) < 0.0 else -1.0
	return 1.0

func _get_local_layout() -> Dictionary:
	var target_sprite := _cup_sprite if is_instance_valid(_cup_sprite) else _outside_sprite
	var left_dir := _get_screen_left_sign()

	if not is_instance_valid(target_sprite) or target_sprite.texture == null:
		return {
			"rim_width": 0.40,
			"left_edge_x": 0.20 * left_dir,
			"right_edge_x": -0.20 * left_dir,
			"top_lip_y": 0.20,
			"inner_min_x": -0.18,
			"inner_max_x": 0.18,
			"inner_bottom_y": -0.20,
			"inner_top_y": 0.20,
			"left_dir": left_dir,
		}

	var mask_sprite := _outside_sprite if (is_instance_valid(_outside_sprite) and _outside_sprite.texture != null) else target_sprite
	var tex_key := "%d_%d" % [target_sprite.texture.get_rid().get_id(), mask_sprite.texture.get_rid().get_id()]
	var cached: Dictionary = {}
	if _layout_cache.has(tex_key):
		cached = _layout_cache[tex_key]
	else:
		cached = _compute_uv_bounds(target_sprite.texture, mask_sprite.texture)
		_layout_cache[tex_key] = cached

	var dims: Rect2 = target_sprite.get_item_rect()
	var ps: float = target_sprite.pixel_size

	var raw_rim_min_u := float(cached["rim_min_u"])
	var raw_rim_max_u := float(cached["rim_max_u"])
	var eff_rim_min_u := (1.0 - raw_rim_max_u) if target_sprite.flip_h else raw_rim_min_u
	var eff_rim_max_u := (1.0 - raw_rim_min_u) if target_sprite.flip_h else raw_rim_max_u
	var eff_rim_top_v := (1.0 - float(cached["outer_top_v"])) if target_sprite.flip_v else float(cached["outer_top_v"])

	var rim_x_a := lerpf(dims.position.x, dims.end.x, eff_rim_min_u) * ps
	var rim_x_b := lerpf(dims.position.x, dims.end.x, eff_rim_max_u) * ps
	var top_lip_y := lerpf(dims.end.y, dims.position.y, eff_rim_top_v) * ps

	var raw_in_min_u := float(cached["inner_min_u"])
	var raw_in_max_u := float(cached["inner_max_u"])
	var eff_in_min_u := (1.0 - raw_in_max_u) if target_sprite.flip_h else raw_in_min_u
	var eff_in_max_u := (1.0 - raw_in_min_u) if target_sprite.flip_h else raw_in_max_u
	var eff_in_top_v := (1.0 - float(cached["inner_top_v"])) if target_sprite.flip_v else float(cached["inner_top_v"])
	var eff_in_bottom_v := (1.0 - float(cached["inner_bottom_v"])) if target_sprite.flip_v else float(cached["inner_bottom_v"])

	var inner_min_x := lerpf(dims.position.x, dims.end.x, eff_in_min_u) * ps
	var inner_max_x := lerpf(dims.position.x, dims.end.x, eff_in_max_u) * ps
	var inner_bottom_y := lerpf(dims.end.y, dims.position.y, eff_in_bottom_v) * ps
	var inner_top_y := lerpf(dims.end.y, dims.position.y, eff_in_top_v) * ps

	var left_edge_x := maxf(rim_x_a, rim_x_b) if left_dir > 0.0 else minf(rim_x_a, rim_x_b)
	var right_edge_x := minf(rim_x_a, rim_x_b) if left_dir > 0.0 else maxf(rim_x_a, rim_x_b)

	return {
		"rim_width": maxf(absf(rim_x_b - rim_x_a), 0.15),
		"left_edge_x": left_edge_x,
		"right_edge_x": right_edge_x,
		"top_lip_y": top_lip_y,
		"inner_min_x": minf(inner_min_x, inner_max_x),
		"inner_max_x": maxf(inner_min_x, inner_max_x),
		"inner_bottom_y": minf(inner_bottom_y, inner_top_y),
		"inner_top_y": maxf(inner_bottom_y, inner_top_y),
		"left_dir": left_dir,
	}

static func _compute_uv_bounds(outer_tex: Texture2D, inner_tex: Texture2D) -> Dictionary:
	var outer_bounds := _scan_opaque_uv_bounds(outer_tex)
	var inner_bounds := _scan_opaque_uv_bounds(inner_tex)
	return {
		"rim_min_u": float(outer_bounds["rim_min_u"]),
		"rim_max_u": float(outer_bounds["rim_max_u"]),
		"outer_top_v": float(outer_bounds["top_v"]),
		"outer_bottom_v": float(outer_bounds["bottom_v"]),
		"inner_min_u": float(inner_bounds["min_u"]),
		"inner_max_u": float(inner_bounds["max_u"]),
		"inner_top_v": float(inner_bounds["top_v"]),
		"inner_bottom_v": float(inner_bounds["bottom_v"]),
	}

static func _scan_opaque_uv_bounds(tex: Texture2D) -> Dictionary:
	var fallback := {
		"min_u": 0.15,
		"max_u": 0.85,
		"rim_min_u": 0.15,
		"rim_max_u": 0.85,
		"top_v": 0.12,
		"bottom_v": 0.88,
	}
	if tex == null:
		return fallback
	var img := tex.get_image()
	if img == null or img.is_empty():
		return fallback
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return fallback

	var min_x := w
	var max_x := -1
	var min_y := h
	var max_y := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.1:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return fallback

	var rim_band_end := mini(min_y + maxi(3, int(round(float(max_y - min_y) * 0.10))), max_y)
	var rim_min_x := w
	var rim_max_x := -1
	for y in range(min_y, rim_band_end + 1):
		for x in w:
			if img.get_pixel(x, y).a > 0.1:
				rim_min_x = mini(rim_min_x, x)
				rim_max_x = maxi(rim_max_x, x)

	if rim_max_x < rim_min_x:
		rim_min_x = min_x
		rim_max_x = max_x

	return {
		"min_u": (float(min_x) + 0.5) / float(w),
		"max_u": (float(max_x) + 0.5) / float(w),
		"rim_min_u": (float(rim_min_x) + 0.5) / float(w),
		"rim_max_u": (float(rim_max_x) + 0.5) / float(w),
		"top_v": (float(min_y) + 0.5) / float(h),
		"bottom_v": (float(max_y) + 0.5) / float(h),
	}