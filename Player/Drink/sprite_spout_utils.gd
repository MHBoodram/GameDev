class_name SpriteSpoutUtils
extends RefCounted

static var _sprite_anchor_cache: Dictionary = {}

static func _get_texture_anchors(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {
			"top_v": 0.1,
			"bottom_v": 0.9,
			"top_center_u": 0.5,
			"top_min_u": 0.2,
			"top_max_u": 0.8,
			"top_min_v": 0.1,
			"top_max_v": 0.1,
		}
	var key := tex.get_rid().get_id()
	if _sprite_anchor_cache.has(key):
		return _sprite_anchor_cache[key]
	var result := {
		"top_v": 0.1,
		"bottom_v": 0.9,
		"top_center_u": 0.5,
		"top_min_u": 0.2,
		"top_max_u": 0.8,
		"top_min_v": 0.1,
		"top_max_v": 0.1,
	}
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		if w > 0 and h > 0:
			var top_y := h
			var bottom_y := -1
			for y in h:
				for x in w:
					if img.get_pixel(x, y).a > 0.1:
						top_y = mini(top_y, y)
						bottom_y = maxi(bottom_y, y)
						break
			if bottom_y >= top_y:
				var band_end := mini(top_y + maxi(2, int(float(h) * 0.08)), bottom_y)
				var min_x := w
				var max_x := -1
				var min_x_y := top_y
				var max_x_y := top_y
				var sum_x := 0.0
				var count_x := 0
				for y in range(top_y, band_end + 1):
					for x in w:
						if img.get_pixel(x, y).a > 0.1:
							if x < min_x:
								min_x = x
								min_x_y = y
							if x > max_x:
								max_x = x
								max_x_y = y
							sum_x += float(x)
							count_x += 1
				result["top_v"] = (float(top_y) + 0.5) / float(h)
				result["bottom_v"] = (float(bottom_y) + 0.5) / float(h)
				if count_x > 0 and max_x >= min_x:
					result["top_center_u"] = (sum_x / float(count_x) + 0.5) / float(w)
					result["top_min_u"] = (float(min_x) + 0.5) / float(w)
					result["top_max_u"] = (float(max_x) + 0.5) / float(w)
					result["top_min_v"] = (float(min_x_y) + 0.5) / float(h)
					result["top_max_v"] = (float(max_x_y) + 0.5) / float(h)
	_sprite_anchor_cache[key] = result
	return result

static func _uv_to_sprite_world(sprite: Sprite3D, u: float, v: float) -> Vector3:
	if not is_instance_valid(sprite):
		return Vector3.ZERO
	var dims: Rect2 = sprite.get_item_rect()
	if dims.size.x <= 0.0 or dims.size.y <= 0.0:
		return sprite.global_position
	var ps := sprite.pixel_size
	var eff_u := (1.0 - u) if sprite.flip_h else u
	var eff_v := (1.0 - v) if sprite.flip_v else v
	var lx := lerpf(dims.position.x, dims.end.x, eff_u) * ps
	var ly := lerpf(dims.end.y, dims.position.y, eff_v) * ps
	return sprite.global_transform * Vector3(lx, ly, 0.0)

static func get_sprite_top_spout_world_position(sprite: Sprite3D) -> Vector3:
	if not is_instance_valid(sprite):
		return Vector3.ZERO
	var anchors := _get_texture_anchors(sprite.texture)
	return _uv_to_sprite_world(sprite, float(anchors["top_center_u"]), float(anchors["top_v"]))

static func get_sprite_rim_spout_world_position(sprite: Sprite3D, tilt_degrees: float = 0.0) -> Vector3:
	if not is_instance_valid(sprite):
		return Vector3.ZERO
	var anchors := _get_texture_anchors(sprite.texture)
	var want_local_neg_x := tilt_degrees >= 0.0
	var u: float
	if want_local_neg_x:
		u = float(anchors["top_max_u"]) if sprite.flip_h else float(anchors["top_min_u"])
	else:
		u = float(anchors["top_min_u"]) if sprite.flip_h else float(anchors["top_max_u"])
	return _uv_to_sprite_world(sprite, u, float(anchors["top_v"]))

static func get_sprite_rim_edges_world_positions(sprite: Sprite3D) -> Dictionary:
	if not is_instance_valid(sprite):
		return {"center": Vector3.ZERO, "left": Vector3.ZERO, "right": Vector3.ZERO}
	var anchors := _get_texture_anchors(sprite.texture)
	var center := _uv_to_sprite_world(sprite, float(anchors["top_center_u"]), float(anchors["top_v"]))
	var min_v := float(anchors.get("top_min_v", anchors["top_v"]))
	var max_v := float(anchors.get("top_max_v", anchors["top_v"]))
	var edge_min := _uv_to_sprite_world(sprite, float(anchors["top_min_u"]), min_v)
	var edge_max := _uv_to_sprite_world(sprite, float(anchors["top_max_u"]), max_v)
	return {
		"center": center,
		"left": edge_max if sprite.flip_h else edge_min,
		"right": edge_min if sprite.flip_h else edge_max,
	}

static func get_sprite_surface_world_position(sprite: Sprite3D, fill_ratio: float, u_override: float = -1.0) -> Vector3:
	if not is_instance_valid(sprite):
		return Vector3.ZERO
	var anchors := _get_texture_anchors(sprite.texture)
	var clamped_fill := clampf(fill_ratio, 0.05, 0.98)
	var v := lerpf(float(anchors["bottom_v"]), float(anchors["top_v"]), clamped_fill)
	var u := clampf(u_override, 0.05, 0.95) if u_override >= 0.0 else float(anchors["top_center_u"])
	return _uv_to_sprite_world(sprite, u, v)

static func world_pos_to_sprite_u(sprite: Sprite3D, world_pos: Vector3) -> float:
	if not is_instance_valid(sprite):
		return 0.5
	var dims: Rect2 = sprite.get_item_rect()
	var ps := sprite.pixel_size
	if dims.size.x <= 0.0 or ps <= 0.000001:
		return 0.5
	var local_p := sprite.global_transform.affine_inverse() * world_pos
	var px_x := local_p.x / ps
	var eff_u := inverse_lerp(dims.position.x, dims.end.x, px_x)
	var u := (1.0 - eff_u) if sprite.flip_h else eff_u
	return clampf(u, 0.0, 1.0)

static func world_vel_to_grid_vel(sprite: Sprite3D, world_vel: Vector3) -> Vector2:
	if not is_instance_valid(sprite) or not sprite.is_inside_tree():
		return Vector2(0.0, 36.0)
	var b := sprite.global_transform.basis
	var axis_x := -b.x.normalized() if sprite.flip_h else b.x.normalized()
	var axis_y := -b.y.normalized() if sprite.flip_v else b.y.normalized()
	var scale_vel := 18.0
	return Vector2(world_vel.dot(axis_x) * scale_vel, -world_vel.dot(axis_y) * scale_vel)