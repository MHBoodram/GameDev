# Tracks active tool held in hand ("hand", "knife", etc.)
# Loops through SpeciesRegistry to dispatch species and modifier tool actions
# Updates player hand animation states
class_name ToolController
extends RefCounted

var tool_in_hand: String = "hand"
static var _hand_hotspot_offset_cache: Dictionary = {}

func _get_player_stats() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("PlayerStats")
	return null

func set_tool(new_tool: String) -> void:
	var normalized := new_tool.to_lower().strip_edges()
	var stats := _get_player_stats()
	if is_instance_valid(stats) and stats.has_method("is_tool_unlocked") and not stats.is_tool_unlocked(normalized):
		return
	tool_in_hand = normalized

func get_tool() -> String:
	return tool_in_hand

# triggers species/modifier-registered tool actions when clicking bottom screen edge
func handle_counter_edge_click(player: Node3D, main_node: Node3D = null) -> bool:
	return SpeciesRegistry.handle_counter_edge_tool(tool_in_hand, player, main_node)

# triggers species-registered tool actions when clicking empty space / bar
func handle_world_click(player: Node3D = null) -> bool:
	return SpeciesRegistry.handle_world_tool_click(tool_in_hand, player)

# triggers species/modifier-registered tool actions when clicking a glass
func handle_glass_click(glass: Area3D, player: Node3D = null) -> bool:
	return SpeciesRegistry.handle_glass_tool_click(tool_in_hand, glass, player)

func can_highlight_glass(glass: Area3D) -> bool:
	return SpeciesRegistry.can_highlight_glass(tool_in_hand, glass)

func should_consume_glass_click(glass: Area3D) -> bool:
	return SpeciesRegistry.should_consume_glass_click(tool_in_hand, glass)

# triggers species/modifier-registered tool actions when clicking a customer NPC
func handle_npc_click(npc: Sprite3D, player: Node3D = null) -> bool:
	return SpeciesRegistry.handle_npc_tool_click(npc, tool_in_hand, player)

func handle_npc_hover(npc: Sprite3D, is_hovered: bool) -> void:
	if not is_instance_valid(npc):
		return
	var sp: SpeciesBase = npc.get("species_def") as SpeciesBase
	if sp:
		sp.on_npc_tool_hover(npc, tool_in_hand, is_hovered)
	var mod: ModifierBase = npc.get("modifier") as ModifierBase
	if mod:
		mod.on_npc_tool_hover(npc, tool_in_hand, is_hovered)

func can_npc_interact_with_tool(npc: Sprite3D, interaction_type: String) -> bool:
	if not is_instance_valid(npc):
		return true
	var sp: SpeciesBase = npc.get("species_def") as SpeciesBase
	if sp and not sp.can_interact_with_tool(npc, tool_in_hand, interaction_type):
		return false
	var mod: ModifierBase = npc.get("modifier") as ModifierBase
	if mod and not mod.can_interact_with_tool(npc, tool_in_hand, interaction_type):
		return false
	return true

static func align_hand_hotspot(hand_node: Node2D) -> void:
	if not is_instance_valid(hand_node):
		return
	if hand_node is Sprite2D:
		var sp := hand_node as Sprite2D
		if sp.texture == null:
			return
		var h_cnt := maxi(1, sp.hframes)
		var v_cnt := maxi(1, sp.vframes)
		var fw := float(sp.texture.get_width()) / float(h_cnt)
		var fh := float(sp.texture.get_height()) / float(v_cnt)
		var ref_frame := 6 if (h_cnt * v_cnt) > 6 else 0
		var cache_key := "s_%d_%d_%d_%d" % [sp.texture.get_rid().get_id(), h_cnt, v_cnt, ref_frame]
		var hotspot_offset := Vector2.ZERO
		if _hand_hotspot_offset_cache.has(cache_key):
			hotspot_offset = _hand_hotspot_offset_cache[cache_key] as Vector2
		else:
			var fx := (ref_frame % h_cnt) * int(fw)
			var fy := int(ref_frame / h_cnt) * int(fh)
			var region := Rect2i(fx, fy, int(fw), int(fh))
			hotspot_offset = _compute_hotspot_offset_from_image(sp.texture.get_image(), region, Vector2(fw, fh))
			_hand_hotspot_offset_cache[cache_key] = hotspot_offset
		sp.offset = hotspot_offset if sp.centered else (hotspot_offset - Vector2(fw, fh) * 0.5)
	elif hand_node is AnimatedSprite2D:
		var asp := hand_node as AnimatedSprite2D
		if asp.sprite_frames == null:
			return
		var anim_name: StringName = &"Interact" if asp.sprite_frames.has_animation(&"Interact") else asp.animation
		if asp.sprite_frames.get_frame_count(anim_name) <= 0:
			return
		var tex := asp.sprite_frames.get_frame_texture(anim_name, 0)
		if tex == null:
			return
		var frame_size := tex.get_size()
		var cache_key := "a_%d" % tex.get_rid().get_id()
		var hotspot_offset := Vector2.ZERO
		if _hand_hotspot_offset_cache.has(cache_key):
			hotspot_offset = _hand_hotspot_offset_cache[cache_key] as Vector2
		else:
			var img: Image = null
			var region := Rect2i(Vector2i.ZERO, Vector2i(int(frame_size.x), int(frame_size.y)))
			if tex is AtlasTexture:
				var at := tex as AtlasTexture
				if at.atlas:
					img = at.atlas.get_image()
					region = Rect2i(at.region)
			else:
				img = tex.get_image()
			hotspot_offset = _compute_hotspot_offset_from_image(img, region, frame_size)
			_hand_hotspot_offset_cache[cache_key] = hotspot_offset
		asp.offset = hotspot_offset if asp.centered else (hotspot_offset - frame_size * 0.5)

static func _compute_hotspot_offset_from_image(img: Image, region: Rect2i, frame_size: Vector2) -> Vector2:
	if img == null or img.is_empty():
		return Vector2.ZERO
	if img.is_compressed():
		img = img.duplicate() as Image
		img.decompress()
	var x0 := clampi(region.position.x, 0, img.get_width() - 1)
	var y0 := clampi(region.position.y, 0, img.get_height() - 1)
	var x1 := clampi(region.end.x, x0 + 1, img.get_width())
	var y1 := clampi(region.end.y, y0 + 1, img.get_height())

	var min_y := y1
	for y in range(y0, y1):
		for x in range(x0, x1):
			if img.get_pixel(x, y).a > 0.2:
				min_y = y
				break
		if min_y < y1:
			break

	if min_y >= y1:
		return Vector2.ZERO

	var sample_y_end := mini(y1, min_y + 4)
	var sum_x := 0.0
	var count := 0
	for y in range(min_y, sample_y_end):
		for x in range(x0, x1):
			if img.get_pixel(x, y).a > 0.2:
				sum_x += float(x - x0) + 0.5
				count += 1

	var tip_x := (sum_x / float(count)) if count > 0 else (frame_size.x * 0.5)
	var tip_y := float(min_y - y0) + 2.0
	return Vector2(frame_size.x * 0.5 - tip_x, frame_size.y * 0.5 - tip_y)

static func apply_hand_animation(anim_player: AnimationPlayer, action_state: String, tool_id: String = "hand") -> void:
	if not anim_player:
		return

	if tool_id == "knife":
		if anim_player.has_animation("knife_idle") and anim_player.current_animation != "knife_idle":
			anim_player.play("knife_idle")
	else:
		match action_state:
			"interact":
				if anim_player.current_animation != "interact":
					anim_player.play("interact")
			"holding":
				if anim_player.current_animation != "hold":
					anim_player.play("hold")
			_:
				if anim_player.current_animation != "idle":
					anim_player.play("idle")

# updates the hand sprite animation based on selected tool and hovering state
func update_hand_visual(anim_player: AnimationPlayer, action_state: String) -> void:
	apply_hand_animation(anim_player, action_state, tool_in_hand)