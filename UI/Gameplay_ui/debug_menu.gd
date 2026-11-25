extends CanvasLayer

const BEER_CUP_SCENE := preload("res://Player/Drink/Glasses/beer_cup.tscn")
const SHOT_CUP_SCENE := preload("res://Player/Drink/Glasses/shot_cup.tscn")
const SPEED_STEPS: Array[float] = [1.0, 2.0, 4.0, 8.0]

var camera: Camera3D
var _speed_index: int = 0
var _cursor_over_debug: bool = false

@onready var box_root: ColorRect = $TextureRect
@onready var fps_label: Label = $TextureRect/VBoxContainer/HBoxContainer/Fps
@onready var skip_tutorial_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/Skip_Tutorial
@onready var speed_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/FlowRow/Speed
@onready var skip_time_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/FlowRow/Skip_Time
@onready var end_shift_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/NightEndRow/End_Shift
@onready var end_night_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/NightEndRow/End_Night
@onready var jump_night_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/JumpNightRow/Jump_Night
@onready var night_option: OptionButton = $TextureRect/VBoxContainer/HBoxContainer/JumpNightRow/NightOption
@onready var serve_good_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/ServeRow/Serve_Good
@onready var serve_bad_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/ServeRow/Serve_Bad
@onready var spawn_cup_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/CupRow/Spawn_Order_Cup
@onready var ready_check: CheckBox = $TextureRect/VBoxContainer/HBoxContainer/CupRow/Ready_Check
@onready var take_orders_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/OrderRow/Take_Orders
@onready var low_patience_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/OrderRow/Low_Patience
@onready var spawn_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/HBoxContainer/Add_NPC_Specific
@onready var species_option: OptionButton = $TextureRect/VBoxContainer/HBoxContainer/HBoxContainer/OptionButton
@onready var modifier_option: OptionButton = $TextureRect/VBoxContainer/HBoxContainer/HBoxContainer/ModifierOptionButton
@onready var unlock_all_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/ItemsRow/Unlock_All
@onready var refill_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/ItemsRow/Refill_Bottles
@onready var blood_game_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/ItemsRow/Blood_Game
@onready var add_money_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/MoneyRow/Add_Money
@onready var add_quota_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/MoneyRow/Add_Quota
@onready var zero_money_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/MoneyRow/Zero_Money
@onready var add_rep_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/RepRow/Add_Rep
@onready var add_species_rep_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/RepRow/Add_Species_Rep
@onready var remove_npc_btn: Button = $TextureRect/VBoxContainer/HBoxContainer/MiscRow/Remove_NPC
@onready var shake_btn: Button = $"TextureRect/VBoxContainer/HBoxContainer/MiscRow/Camera Shake"

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	_disable_focus_recursive(box_root)
	_populate_night_dropdown()
	_populate_species_dropdown()
	_populate_modifier_dropdown()

	skip_tutorial_btn.pressed.connect(_on_skip_tutorial_pressed)
	speed_btn.pressed.connect(_on_speed_pressed)
	skip_time_btn.pressed.connect(_on_skip_time_pressed)
	end_shift_btn.pressed.connect(_on_end_shift_pressed)
	end_night_btn.pressed.connect(_on_end_night_pressed)
	jump_night_btn.pressed.connect(_on_jump_night_pressed)
	serve_good_btn.pressed.connect(_on_serve_good_pressed)
	serve_bad_btn.pressed.connect(_on_serve_bad_pressed)
	spawn_cup_btn.pressed.connect(_on_spawn_cup_pressed)
	take_orders_btn.pressed.connect(_on_take_orders_pressed)
	low_patience_btn.pressed.connect(_on_low_patience_pressed)
	spawn_btn.pressed.connect(_on_spawn_pressed)
	unlock_all_btn.pressed.connect(_on_unlock_all_pressed)
	refill_btn.pressed.connect(_on_refill_pressed)
	blood_game_btn.pressed.connect(_on_blood_game_pressed)
	add_money_btn.pressed.connect(_on_add_money_pressed)
	add_quota_btn.pressed.connect(_on_add_quota_pressed)
	zero_money_btn.pressed.connect(_on_zero_money_pressed)
	add_rep_btn.pressed.connect(_on_add_rep_pressed)
	add_species_rep_btn.pressed.connect(_on_add_species_rep_pressed)
	remove_npc_btn.pressed.connect(_on_remove_npc_pressed)
	shake_btn.pressed.connect(_on_camera_shake_pressed)

	visibility_changed.connect(_on_visibility_changed)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _cursor_over_debug and is_inside_tree() and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _disable_focus_recursive(root: Node) -> void:
	if root is Control:
		(root as Control).focus_mode = Control.FOCUS_NONE
	for child in root.get_children():
		_disable_focus_recursive(child)

func _populate_night_dropdown() -> void:
	night_option.clear()
	for n in range(1, GameState.max_nights + 1):
		night_option.add_item("Night %d" % n)
		night_option.set_item_metadata(night_option.item_count - 1, n)
	var default_night := mini(GameState.night + 1, GameState.max_nights)
	night_option.select(maxi(0, default_night - 1))

func _populate_species_dropdown() -> void:
	species_option.clear()
	species_option.add_item("Random")
	species_option.set_item_metadata(0, "")
	for sp in SpeciesRegistry.get_all_species():
		species_option.add_item(sp.display_name)
		species_option.set_item_metadata(species_option.item_count - 1, sp.species_id)
	species_option.select(0)

func _populate_modifier_dropdown() -> void:
	modifier_option.clear()
	modifier_option.add_item("Natural")
	modifier_option.set_item_metadata(0, "__NATURAL__")
	modifier_option.add_item("None")
	modifier_option.set_item_metadata(1, "__NONE__")
	for mod in ModifierRegistry.get_all_modifiers():
		modifier_option.add_item(mod.display_name)
		modifier_option.set_item_metadata(modifier_option.item_count - 1, mod.modifier_id)
	modifier_option.select(0)

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	_update_cursor_visibility()
	if visible:
		fps_label.text = "FPS: " + str(Engine.get_frames_per_second())

func _update_cursor_visibility() -> void:
	if not visible:
		if _cursor_over_debug:
			_cursor_over_debug = false
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var popup_open := (
		night_option.get_popup().visible
		or species_option.get_popup().visible
		or modifier_option.get_popup().visible
	)
	var should_show := popup_open or box_root.get_global_rect().has_point(mouse_pos)
	if should_show != _cursor_over_debug:
		_cursor_over_debug = should_show
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if should_show else Input.MOUSE_MODE_HIDDEN

func _on_visibility_changed() -> void:
	_update_cursor_visibility()

func _cleanup_tutorial_and_dialogue(remove_story_npcs: bool = true) -> void:
	if GameState.gameplay_ui:
		if "tutorial_director" in GameState.gameplay_ui and GameState.gameplay_ui.tutorial_director:
			GameState.gameplay_ui.tutorial_director.cancel_tutorial(GameState.gameplay_ui)
		if GameState.gameplay_ui.has_method("_out_down_minigame"):
			GameState.gameplay_ui._out_down_minigame()

	if GameState.night_manager and is_instance_valid(GameState.main_node):
		GameState.night_manager._clean_tutorial_keys(GameState.main_node)

	var tree := get_tree()
	if tree and tree.root:
		for balloon_name in ["Main_Ballon", "ExampleBalloon"]:
			var balloon := tree.root.find_child(balloon_name, true, false)
			if is_instance_valid(balloon):
				balloon.queue_free()
	GameState.is_dialogue_open = false
	GameState.character_talking = null

	if remove_story_npcs and GameState.seat_manager:
		var sm := GameState.seat_manager
		for i in sm.seats.size():
			var npc := sm.seats[i]
			if is_instance_valid(npc) and npc.unique_talk:
				sm.clear_receipt_for_seat(npc.seat_num)
				if npc.patience_timer:
					npc.patience_timer.stop()
				if npc._bounce_tween and npc._bounce_tween.is_valid():
					npc._bounce_tween.kill()
				sm.seats[i] = null
				npc.queue_free()

func _on_skip_tutorial_pressed() -> void:
	if is_instance_valid(GameState.main_node):
		var anim := GameState.main_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim and anim.is_playing() and anim.current_animation == "opening":
			anim.seek(anim.current_animation_length, true)
			await get_tree().process_frame

	_cleanup_tutorial_and_dialogue(true)
	GameState.special_state = false
	GameState.can_end_night = true

	if GameState.seat_manager:
		GameState.seat_manager.set_all_patience_paused(false)

	var nm := GameState.night_manager
	if nm:
		if nm.night_timer:
			nm.night_timer.paused = false
		if not nm.is_shift_active and not nm.is_shift_ended:
			nm.start_night_shift()
		else:
			GameState.resume_night()
	else:
		GameState.resume_night()

func _on_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % SPEED_STEPS.size()
	var mult := SPEED_STEPS[_speed_index]
	Engine.time_scale = mult
	speed_btn.text = "Speed: %dx" % int(mult)

func _on_skip_time_pressed() -> void:
	var nm := GameState.night_manager
	if not nm or not nm.night_timer or nm.night_timer.is_stopped():
		return
	nm.night_timer.start(maxf(0.5, nm.night_timer.time_left - 60.0))

func _on_end_shift_pressed() -> void:
	var nm := GameState.night_manager
	if not nm:
		return
	if GameState.special_state or not nm.is_shift_active:
		_cleanup_tutorial_and_dialogue(true)
		GameState.special_state = false
		GameState.can_end_night = true
		GameState.resume_night()
	nm.end_shift()

func _on_end_night_pressed() -> void:
	Engine.time_scale = 1.0
	_speed_index = 0
	speed_btn.text = "Speed: 1x"

	_cleanup_tutorial_and_dialogue(true)

	var sm := GameState.seat_manager
	if sm:
		sm.stop_spawning()
		for i in sm.seats.size():
			var npc := sm.seats[i]
			if is_instance_valid(npc):
				sm.clear_receipt_for_seat(npc.seat_num)
				if npc.patience_timer:
					npc.patience_timer.stop()
				if npc._bounce_tween and npc._bounce_tween.is_valid():
					npc._bounce_tween.kill()
				sm.seats[i] = null
				npc.queue_free()

	GameState.special_state = false
	GameState.night_paused = false
	GameState.can_end_night = true

	var nm := GameState.night_manager
	if nm:
		if nm.is_shift_ended:
			nm.check_night_concluded(true)
		else:
			nm.end_shift()

func _on_jump_night_pressed() -> void:
	if night_option.selected < 0:
		return
	var target_night := int(night_option.get_item_metadata(night_option.selected))
	Engine.time_scale = 1.0
	_cleanup_tutorial_and_dialogue(false)

	GameState.is_dialogue_open = false
	GameState.character_talking = null
	GameState.special_state = false
	GameState.night_paused = false
	GameState.can_end_night = true

	GameState.night = clampi(target_night, 1, GameState.max_nights)
	GameState.reset_night_restarts()
	GameState.get_night_quota(GameState.night)
	PlayerStats.reset_night_reputation_gains()

	get_tree().change_scene_to_file("res://Main3D.tscn")

func _on_serve_good_pressed() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.debug_serve_all("good")

func _on_serve_bad_pressed() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.debug_serve_all("bad")

func _on_spawn_cup_pressed() -> void:
	var sm := GameState.seat_manager
	var main := GameState.main_node
	if not sm or not is_instance_valid(main):
		return

	var target_npc: Base_NPC = null
	for npc in sm.seats:
		if is_instance_valid(npc) and not npc.is_leaving and not npc.drink_list.is_empty():
			target_npc = npc
			break
	if target_npc == null:
		return

	var existing_glasses := get_tree().get_nodes_in_group("glass")
	if existing_glasses.size() >= 6:
		return

	if not target_npc.unique_talk and not target_npc.has_receipt_spawned:
		target_npc.speaking_title = "mid"
		target_npc._add_recipt()

	var raw_want = target_npc.drink_list[0]
	var order: DrinkOrder = raw_want if raw_want is DrinkOrder else DrinkOrder.from_legacy_want(raw_want)
	var glass_scene: PackedScene = SHOT_CUP_SCENE if order.required_glass.to_lower() == "shot" else BEER_CUP_SCENE
	var glass := glass_scene.instantiate() as Glasses
	if not glass:
		return

	var counter_ref: Node3D = GameState.player.counter if (GameState.player and "counter" in GameState.player) else main.get_node_or_null("Coutner")
	var cup_scale: Vector3 = GameState.player.spawn_scale if (GameState.player and "spawn_scale" in GameState.player) else Vector3(0.2, 0.2, 0.2)
	glass.scale = cup_scale
	glass._skip_initial_snap = true
	glass._instiate(counter_ref)
	main.add_child(glass)

	var x_offsets := [-0.24, 0.0, 0.24, -0.12, 0.12, 0.34]
	var stagger_x: float = x_offsets[existing_glasses.size() % x_offsets.size()]
	var usable = WorkingAreaService.get_working_area_usable_bounds(glass)
	var target_pos := glass.global_position
	if usable is AABB:
		var box := usable as AABB
		var c := box.get_center()
		target_pos = Vector3(clampf(c.x + stagger_x, box.position.x + 0.08, box.end.x - 0.08), glass.get_working_area_surface_y(), c.z)
	elif counter_ref:
		target_pos = Vector3(counter_ref.global_position.x + stagger_x, glass.get_working_area_surface_y(), counter_ref.global_position.z)
	glass.global_position = target_pos
	glass.base_y_position = target_pos.y
	glass._last_counter_position = target_pos
	if glass.visual_helper:
		glass.visual_helper.last_global_pos = target_pos

	var norm_ing := order.get_normalized_ingredients()
	for ing_id in norm_ing:
		glass._pouring(str(ing_id), float(norm_ing[ing_id]) * glass.size)

	if order.is_tiny:
		glass.drink_mix.is_tiny = true

	if ready_check.button_pressed:
		if order.required_processing.has("shaken") and glass.can_be_shaken():
			glass.mark_mixed()
		if order.required_processing.has("spectral") and not glass.drink_mix.has_processing("spectral"):
			glass.drink_mix.add_processing("spectral")
			SpectralEffect.apply_to_glass(glass)

	glass._remove_displaying_list(true)

func _on_take_orders_pressed() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.take_all_pending_orders()

func _on_low_patience_pressed() -> void:
	var sm := GameState.seat_manager
	if not sm:
		return
	for npc in sm.seats:
		if not is_instance_valid(npc) or npc.is_leaving:
			continue
		if npc._dialouge_paused_patience >= 0.0:
			npc._dialouge_paused_patience = minf(npc._dialouge_paused_patience, 5.0)
		elif npc.patience_timer and not npc.patience_timer.is_stopped():
			npc.patience_timer.start(minf(npc.patience_timer.time_left, 5.0))

func _on_spawn_pressed() -> void:
	if not GameState.seat_manager or GameState.seat_manager.get_empty_seat_count() <= 0:
		return
	var sp_id := str(species_option.get_selected_metadata()) if species_option.selected >= 0 else ""
	var mod_id := str(modifier_option.get_selected_metadata()) if modifier_option.selected >= 0 else "__NATURAL__"
	GameState.seat_manager.spawn_custom_customer(sp_id, mod_id)

func _on_unlock_all_pressed() -> void:
	if PlayerStats.unlocks.has("Drinks"):
		for d in PlayerStats.unlocks["Drinks"]:
			PlayerStats.unlocks["Drinks"][d] = true
	if PlayerStats.unlocks.has("Ingredients"):
		for ing in PlayerStats.unlocks["Ingredients"]:
			PlayerStats.unlocks["Ingredients"][ing] = true
			SpeciesRegistry.on_ingredient_unlocked(str(ing), PlayerStats)
	if GameState.shelf_manager and is_instance_valid(GameState.main_node):
		var counter_ref: Node3D = GameState.player.counter if (GameState.player and "counter" in GameState.player) else GameState.main_node.get_node_or_null("Coutner")
		GameState.shelf_manager.refresh_shelf_bottles(GameState.main_node, counter_ref)

func _on_refill_pressed() -> void:
	if not GameState.shelf_manager:
		return
	for bottle in GameState.shelf_manager.spawned_bottles.values():
		if is_instance_valid(bottle) and bottle.has_method("refill"):
			bottle.refill()

func _on_blood_game_pressed() -> void:
	if not GameState.minigame_host:
		return
	if GameState.minigame_host.is_minigame_active or ShakerMinigame.active or GameState.is_dialogue_open:
		return
	if PlayerStats.unlocks.has("Ingredients"):
		PlayerStats.unlocks["Ingredients"]["Blood"] = true
	if GameState.shelf_manager and is_instance_valid(GameState.main_node):
		var counter_ref: Node3D = GameState.player.counter if (GameState.player and "counter" in GameState.player) else GameState.main_node.get_node_or_null("Coutner")
		GameState.shelf_manager.refresh_shelf_bottles(GameState.main_node, counter_ref)
	visible = false
	GameState.minigame_host.start_blood_minigame(GameState.main_node, GameState.player)

func _on_add_money_pressed() -> void:
	PlayerStats._change_money(PlayerStats.money + 1000.0)

func _on_add_quota_pressed() -> void:
	PlayerStats._change_money(PlayerStats.money + GameState.get_night_quota(GameState.night))

func _on_zero_money_pressed() -> void:
	PlayerStats._change_money(0.0)

func _on_add_rep_pressed() -> void:
	PlayerStats.add_overall_reputation(10.0)

func _on_add_species_rep_pressed() -> void:
	var sp_id := str(species_option.get_selected_metadata()) if species_option.selected >= 0 else ""
	if sp_id == "":
		sp_id = "HUMAN"
	var sp := SpeciesRegistry.get_species_or_default(sp_id)
	var sp_name := sp.display_name if sp else "Human"
	PlayerStats.change_species_reputation(sp_name, 5.0)

func _on_remove_npc_pressed() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.remove_first_occupied_seat()

func _on_camera_shake_pressed() -> void:
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if camera and camera.has_method("add_shake"):
		camera.add_shake(1.0)
