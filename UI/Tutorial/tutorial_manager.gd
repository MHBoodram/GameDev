class_name TutorialManager
extends Node

# manages the night 1 guided tutorial sequence including wasd popup and drink instruction hints

var hint_hand: TextureRect = null
var _tutorial_running: bool = false
var _intro_tutorial_running: bool = false
var _cancel_requested: bool = false

func is_dialogue_active() -> bool:
	if GameState.is_dialogue_open:
		return true
	if GameState.main_node and "is_dialogue_open" in GameState.main_node and GameState.main_node.is_dialogue_open:
		return true
	var tree := get_tree()
	if tree and tree.root:
		var b1 = tree.root.find_child("Main_Ballon", true, false)
		if b1 and b1.visible:
			return true
		var b2 = tree.root.find_child("ExampleBalloon", true, false)
		if b2 and b2.visible:
			return true
	return false

func cancel_tutorial(ui_node: CanvasLayer = null) -> void:
	_cancel_requested = true
	_tutorial_running = false
	_intro_tutorial_running = false

	if is_instance_valid(hint_hand):
		hint_hand.queue_free()
	hint_hand = null

	var target_ui: CanvasLayer = ui_node if is_instance_valid(ui_node) else GameState.gameplay_ui
	if is_instance_valid(target_ui):
		var label := target_ui.get_node_or_null("Tutorial Label") as Label
		if is_instance_valid(label):
			label.hide()
		var ui_keys := target_ui.get_node_or_null("Keys") as Control
		if is_instance_valid(ui_keys) and not ui_keys.is_queued_for_deletion():
			if ui_keys.has_signal("tutorial_completed"):
				ui_keys.tutorial_completed.emit()
			ui_keys.hide()
			ui_keys.queue_free()

	if is_instance_valid(GameState.main_node):
		var main_keys := GameState.main_node.get_node_or_null("Keys") as Control
		if is_instance_valid(main_keys) and not main_keys.is_queued_for_deletion():
			if main_keys.has_signal("tutorial_completed"):
				main_keys.tutorial_completed.emit()
			main_keys.hide()
			main_keys.queue_free()

# starts night 1 tutorial steps
func start_tutorial(ui_node: CanvasLayer, keys_node: Control = null) -> void:
	if _intro_tutorial_running:
		return
	_cancel_requested = false
	_intro_tutorial_running = true
	_run_tutorial_intro(ui_node, keys_node)

func _run_tutorial_intro(ui_node: CanvasLayer, keys_node: Control = null) -> void:
	var keys: Control = keys_node
	if not is_instance_valid(keys) and GameState.main_node:
		keys = GameState.main_node.get_node_or_null("Keys") as Control
	if not is_instance_valid(keys):
		var keys_scene = load("res://UI/Tutorial/Keys.tscn")
		if keys_scene:
			keys = keys_scene.instantiate() as Control
			ui_node.add_child(keys)

	if is_instance_valid(keys) and not _cancel_requested:
		if keys.has_method("popup"):
			keys.popup()
		else:
			keys.show()

		# wait for wasd panel inputs to be pressed
		while is_inside_tree() and not _cancel_requested and is_instance_valid(keys) and not keys.is_queued_for_deletion():
			if is_dialogue_active():
				if keys.has_method("_bye_bye"):
					keys._bye_bye()
				break
			if keys.has_method("_tutorial_finished") and keys._tutorial_finished():
				break
			await get_tree().process_frame

		if _cancel_requested:
			_intro_tutorial_running = false
			return

		if is_instance_valid(keys) and not keys.is_queued_for_deletion():
			if keys.has_signal("tutorial_completed"):
				await keys.tutorial_completed
			elif keys.has_method("_bye_bye"):
				keys._bye_bye()

	if _cancel_requested:
		_intro_tutorial_running = false
		return

	var shark := find_shark()
	if shark:
		shark.can_talk = true
		if shark.speaking_title == "tutorial_walk":
			shark.speaking_title = "tutorial_walk_finished"

	var label := ui_node.get_node_or_null("Tutorial Label") as Label
	if is_instance_valid(label):
		label.show()
	_create_hint_hand(ui_node)

	var camera: Camera3D = ui_node.get_viewport().get_camera_3d()
	while is_inside_tree() and not _cancel_requested:
		shark = find_shark()
		if is_dialogue_active() or shark == null or shark.is_leaving:
			break

		var is_down: bool = ui_node.get("down") if "down" in ui_node else false
		if is_down:
			if is_instance_valid(label):
				label.text = "Press W to look up"
			if is_instance_valid(hint_hand):
				hint_hand.hide()
		else:
			if is_instance_valid(label):
				label.text = "Click the Loan Shark to talk to him"
			if is_instance_valid(hint_hand) and camera and is_instance_valid(shark):
				var shark_pos := shark.global_position + Vector3(0.0, 0.2, 0.0)
				if not camera.is_position_behind(shark_pos):
					var s_pos := camera.unproject_position(shark_pos)
					var h_size := hint_hand.size
					if h_size == Vector2.ZERO and hint_hand.texture:
						h_size = hint_hand.texture.get_size()
					var bob := sin(Time.get_ticks_msec() * 0.006) * 10.0
					hint_hand.global_position = s_pos - h_size * 0.5 + Vector2(0.0, bob)
					hint_hand.modulate.a = 1.0
					hint_hand.show()
				else:
					hint_hand.hide()
		await get_tree().process_frame

	if is_instance_valid(hint_hand):
		hint_hand.hide()
	if is_instance_valid(label):
		label.hide()

	while is_inside_tree() and not _cancel_requested and is_dialogue_active():
		await get_tree().process_frame

	_intro_tutorial_running = false

	if _cancel_requested:
		return

	if is_inside_tree():
		shark = find_shark()
		if shark and shark.has_receipt_spawned and shark.drink_list.size() > 0:
			start_drink_tutorial(ui_node)

func start_drink_tutorial(ui_node: CanvasLayer) -> void:
	if _tutorial_running:
		return
	_cancel_requested = false
	_run_drink_steps(ui_node)

func _create_hint_hand(parent_node: Node) -> void:
	if is_instance_valid(hint_hand):
		hint_hand.queue_free()
	hint_hand = TextureRect.new()
	hint_hand.texture = preload("res://Assets/UI/Hand.png")
	hint_hand.z_index = 100
	hint_hand.hide()
	parent_node.add_child(hint_hand)

func find_glass() -> Glasses:
	var best: Glasses = null
	for node in get_tree().get_nodes_in_group("glass"):
		if node is Glasses and is_instance_valid(node) and not node.is_queued_for_deletion():
			var g := node as Glasses
			if g.is_consumed:
				continue
			if g.total_liquids > 0.0:
				return g
			best = g
	return best

func find_bottle() -> Drinks:
	if GameState.shelf_manager:
		var bottle = GameState.shelf_manager.get_bottle("gin")
		if bottle is Drinks and is_instance_valid(bottle):
			return bottle as Drinks
	if GameState.main_node:
		var gin_node = GameState.main_node.get_node_or_null("gin")
		if gin_node is Drinks and is_instance_valid(gin_node):
			return gin_node as Drinks
	return null

func find_receipt() -> Node3D:
	if GameState.main_node:
		for i in range(1, 4):
			var rec = GameState.main_node.get_node_or_null("ReciptPaper" + str(i))
			if rec is Node3D and is_instance_valid(rec) and "ordered" in rec and rec.ordered:
				return rec as Node3D
	return null

func find_shark() -> Base_NPC:
	if GameState.seat_manager:
		for npc in GameState.seat_manager.seats:
			if npc is Base_NPC and is_instance_valid(npc) and npc.unique_talk:
				return npc as Base_NPC
	return null

func update_hint_drag(camera: Camera3D, from_world: Variant, to_world: Variant, phase_time: float) -> void:
	if not is_instance_valid(hint_hand):
		return
	if not camera or not (from_world is Vector3) or not (to_world is Vector3):
		hint_hand.hide()
		return
	var p0: Vector3 = from_world
	var p1: Vector3 = to_world
	if camera.is_position_behind(p0) or camera.is_position_behind(p1):
		hint_hand.hide()
		return
	var hand_size := hint_hand.size
	if hand_size == Vector2.ZERO and hint_hand.texture:
		hand_size = hint_hand.texture.get_size()
	var s0 := camera.unproject_position(p0) - hand_size * 0.5
	var s1 := camera.unproject_position(p1) - hand_size * 0.5
	var cycle := fmod(phase_time, 1.5)
	if cycle < 0.8:
		var t := 0.5 - 0.5 * cos((cycle / 0.8) * PI)
		hint_hand.show()
		hint_hand.modulate.a = 1.0
		hint_hand.global_position = s0.lerp(s1, t)
	elif cycle < 1.0:
		hint_hand.show()
		hint_hand.modulate.a = 1.0 - ((cycle - 0.8) / 0.2)
		hint_hand.global_position = s1
	else:
		hint_hand.hide()

func _run_drink_steps(ui_node: CanvasLayer) -> void:
	_tutorial_running = true
	while is_inside_tree() and not _cancel_requested and is_dialogue_active():
		await get_tree().process_frame

	if _cancel_requested:
		_tutorial_running = false
		return

	_create_hint_hand(ui_node)
	var label := ui_node.get_node_or_null("Tutorial Label") as Label
	if is_instance_valid(label):
		label.show()

	var hint_elapsed: float = 0.0
	var camera: Camera3D = ui_node.get_viewport().get_camera_3d()

	while is_inside_tree() and not _cancel_requested:
		var delta := get_process_delta_time()
		hint_elapsed += delta

		if is_dialogue_active():
			if is_instance_valid(label):
				label.hide()
			if is_instance_valid(hint_hand):
				hint_hand.hide()
			await get_tree().process_frame
			continue
		elif is_instance_valid(label) and not label.visible:
			label.show()

		var shark := find_shark()
		var glass := find_glass()
		var bottle := find_bottle()
		var receipt := find_receipt()
		var in_pour: bool = GameState.player != null and GameState.player.in_game
		var has_liquid: bool = glass != null and glass.total_liquids > 0.0
		var needs_drink: bool = shark != null and not shark.is_leaving and shark.drink_list.size() > 0
		var is_down: bool = ui_node.get("down") if "down" in ui_node else false
		var is_trans: bool = ui_node.get("is_transitioning") if "is_transitioning" in ui_node else false

		# order completed: wait for player to talk to the shark again
		if not needs_drink:
			if is_instance_valid(hint_hand):
				hint_hand.hide()
			label.text = "Talk To Loan Shark Again"
			if is_dialogue_active() or shark == null or shark.is_leaving:
				break
			await get_tree().process_frame
			continue

		# currently holding down pour on the glass
		if in_pour:
			if is_instance_valid(hint_hand):
				hint_hand.hide()
			label.text = "Hold left click to pour the drink into the glass"
			await get_tree().process_frame
			continue

		# look down at counter to start making drink
		if (not is_down or is_trans) and not has_liquid:
			if is_instance_valid(hint_hand):
				hint_hand.hide()
			label.text = "Go to your Counter to make the drink"
			await get_tree().process_frame
			continue

		# grab an empty glass from shelf button
		if glass == null or glass.is_balls_dragging or glass._is_returning_to_counter or glass._waiting_for_working_area:
			label.text = "Left click the glass and drag it to the middle"
			if glass != null and glass.is_balls_dragging:
				if is_instance_valid(hint_hand):
					hint_hand.hide()
			else:
				var btn_pos: Variant = null
				if GameState.player and GameState.player.counter:
					var btn := GameState.player.counter.get_node_or_null("BeerGlass Button") as Node3D
					if btn:
						btn_pos = btn.global_position
				var center_pos: Variant = null
				var bounds = WorkingAreaService.get_working_area_bounds(self)
				if bounds is AABB:
					center_pos = (bounds as AABB).get_center()
				elif GameState.player and GameState.player.counter:
					center_pos = GameState.player.counter.global_position + Vector3(0.0, 1.5, 0.0)
				update_hint_drag(camera, btn_pos, center_pos, hint_elapsed)
			await get_tree().process_frame
			continue

		# pour liquor into glass
		if not has_liquid:
			label.text = "Grab the Liquid drop it on the glass"
			if bottle != null and bottle.is_balls_dragging:
				if is_instance_valid(hint_hand):
					hint_hand.hide()
			else:
				var b_pos: Variant = bottle.global_position if bottle else null
				update_hint_drag(camera, b_pos, glass.global_position, hint_elapsed)
			await get_tree().process_frame
			continue

		# deliver receipt to glass to complete order
		label.text = "Bring the recipt onto the drink"
		if (receipt != null and "is_balls_dragging" in receipt and receipt.is_balls_dragging) or glass.is_balls_dragging or glass.is_being_served or not is_down or is_trans:
			if is_instance_valid(hint_hand):
				hint_hand.hide()
		else:
			var r_pos: Variant = null
			if receipt != null:
				if "has_board_slot" in receipt and receipt.has_board_slot:
					r_pos = receipt.board_slot_position
				else:
					r_pos = receipt.global_position
			update_hint_drag(camera, r_pos, glass.global_position, hint_elapsed)
		await get_tree().process_frame

	if is_instance_valid(hint_hand):
		hint_hand.queue_free()
		hint_hand = null
	if is_instance_valid(label):
		label.hide()
	_tutorial_running = false
	