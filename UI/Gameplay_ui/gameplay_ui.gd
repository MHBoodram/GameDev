extends CanvasLayer
var mouse_side : bool = false
var mouse_entered: bool = false
@export var camera_movement_rotation = 10
@export var player : Node3D
var current_position : int = 3
var match_position_counter : Dictionary ={1 : 3.17, 2 : 0.17, 3 : -2.83}
var camera : Camera3D
var down : bool = false
var up_down_checks : bool = false

const CAMERA_Y_OFFSET : float = 0.3
const CAMERA_TILT_OFFSET : float = 5.0
const BASE_FRONT_CAMERA_ROTATION : Vector3 = Vector3(-16.3, 0.0, 0.0)
const BASE_BACK_CAMERA_ROTATION : Vector3 = Vector3(-21.0, 180.0, 0.0)

var base_camera_rotation : Vector3 = BASE_FRONT_CAMERA_ROTATION + Vector3(CAMERA_TILT_OFFSET, 0.0, 0.0)
var current_tilt_yaw : float = 0.0
var current_tilt_pitch : float = 0.0
const MAX_TILT_YAW : float = 3.0
const MAX_TILT_PITCH : float = 2.0
var is_transitioning : bool = false
var is_moving : bool = false
var default_camera_local_pos : Vector3 = Vector3.ZERO

var tutorial_mode : bool = false

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	var scene_root: Node = player.get_parent() if player else get_tree().current_scene
	if scene_root:
		var seat1 := scene_root.get_node_or_null("Seat1") as Node3D
		var seat2 := scene_root.get_node_or_null("Seat2") as Node3D
		var seat3 := scene_root.get_node_or_null("Seat3") as Node3D
		var cam_x_offset: float = camera.position.x if camera else 0.0
		if seat3:
			match_position_counter[1] = seat3.global_position.x - cam_x_offset
		if seat2:
			match_position_counter[2] = seat2.global_position.x - cam_x_offset
		if seat1:
			match_position_counter[3] = seat1.global_position.x - cam_x_offset
			if camera:
				var p_z: float = player.global_position.z if player else 0.0
				camera.position.z = (seat1.global_position.z + 1.6) - p_z
	if camera:
		camera.position.y += CAMERA_Y_OFFSET
		default_camera_local_pos = camera.position
	if player and match_position_counter.has(current_position):
		player.position.x = match_position_counter[current_position]
	$FishEye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.gameplay_ui = self
	_change_money(PlayerStats.money)
	set_shift_hud_visible(false)

func _input(event: InputEvent) -> void:
	if(event.is_action_pressed("ui_accept")):
		print(get_viewport().get_mouse_position())


func _process(delta: float) -> void:
	if not camera:
		return
	var viewport_rect = get_viewport().get_visible_rect()
	var center = viewport_rect.size * 0.5
	if center.x <= 0.0 or center.y <= 0.0:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var norm_x = clampf((mouse_pos.x - center.x) / center.x, -1.0, 1.0)
	var norm_y = clampf((mouse_pos.y - center.y) / center.y, -1.0, 1.0)
	var target_tilt_yaw = -norm_x * MAX_TILT_YAW
	var target_tilt_pitch = -norm_y * MAX_TILT_PITCH
	current_tilt_yaw = lerpf(current_tilt_yaw, target_tilt_yaw, 1.0 - exp(-10.0 * delta))
	current_tilt_pitch = lerpf(current_tilt_pitch, target_tilt_pitch, 1.0 - exp(-10.0 * delta))
	camera.rotation_degrees.x = base_camera_rotation.x + current_tilt_pitch
	camera.rotation_degrees.y = base_camera_rotation.y + current_tilt_yaw

func set_shift_hud_visible(is_visible: bool) -> void:
	$"Left Container".visible = is_visible
	$"Mid Container".visible = is_visible

# Update quota value in hud
func _update_quota(quota_value: float) -> void:
	$"Mid Container/Money/Label".text = "Quota:\n" + str(int(quota_value))

# Updates night counter display text
func _update_night_display(night_number: int) -> void:
	$ColorRect3/Night.text = "Night " + str(night_number)

# Toggles camera between forward and behind views
func bendover() -> void:
	if is_transitioning or is_moving:
		return
	is_transitioning = true
	$Left_Button.disabled = true
	$Right_Button.disabled = true
	$Bottom_button.disabled = true
	$Up_button.disabled = true
	if(down):
		_look_forward()
	else:
		_look_behind()
	down = !down

# Tweens camera to back view
func _look_behind() -> void:
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var back_position = Vector3(3.28, 2.75, 0.85)
	var camera_mark = get_tree().get_first_node_in_group("counter_mark") as Node3D
	if not camera_mark and player and "counter" in player and player.counter:
		camera_mark = player.counter.get_node_or_null("Camera mark") as Node3D
	if camera_mark:
		back_position = camera_mark.global_position
	back_position.y += CAMERA_Y_OFFSET
	var target_rot = BASE_BACK_CAMERA_ROTATION + Vector3(CAMERA_TILT_OFFSET, 0.0, 0.0)
	tween.tween_property(self, "base_camera_rotation", target_rot, 0.5)
	tween.tween_property(camera, "global_position", back_position, 0.5)
	tween.chain().tween_callback(func():
		$Left_Button.disabled = true
		$Right_Button.disabled = true
		$Bottom_button.disabled = false
		$Up_button.disabled = false
		is_transitioning = false
	)

# Tweens camera back to front view
func _look_forward() -> void:
	up_down_checks = false
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var target_rot = BASE_FRONT_CAMERA_ROTATION + Vector3(CAMERA_TILT_OFFSET, 0.0, 0.0)
	tween.tween_property(self, "base_camera_rotation", target_rot, 0.5)
	tween.tween_property(camera, "position", default_camera_local_pos, 0.5)
	tween.chain().tween_callback(func():
		$Left_Button.disabled = false
		$Right_Button.disabled = false
		$Bottom_button.disabled = false
		$Up_button.disabled = true
		is_transitioning = false
	)

# Shifts player between bar stools
func moving_around(right : bool) -> void:
	if down or is_transitioning or is_moving:
		return
	if(right):
		if(current_position > 1):
			current_position -= 1
			var new_position = match_position_counter[current_position]
			is_moving = true
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(player,"position:x",new_position,0.15)
			tween.finished.connect(func(): is_moving = false)
	else:
		if(current_position < 3):
			current_position += 1
			var new_position = match_position_counter[current_position]
			is_moving = true
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(player,"position:x",new_position,0.15)
			tween.finished.connect(func(): is_moving = false)
#what anti anaing: sample rate under


func mouse_screen(looking: String) -> void:
	if(looking == "down"):
		GameState.player._update_hand("interact")
	else:
		GameState.player._update_hand("idle")

func _on_left_button_mouse_entered() -> void:
	GameState.player._update_hand("interact")

func _on_right_button_mouse_entered() -> void:
	GameState.player._update_hand("interact")

func _on_mouse_exited() -> void:
	mouse_screen("none")

func _on_left_button_pressed() -> void:
	moving_around(false)

func _on_right_button_pressed() -> void:
	moving_around(true)

func _on_bottom_button_pressed() -> void:
	if(GameState.player):
		if(GameState.player.return_tool() == "knife" && down && !GameState.player.in_game):
			GameState.main_node._period_game()
			_in_down_minigame()
			return
	if(down):
		return
	bendover()

func _out_down_minigame() -> void:
	$Bottom_button.disabled = false
	$Up_button.disabled = false
	$Bottom_button.mouse_filter = Control.MOUSE_FILTER_STOP
	$Up_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _in_down_minigame() -> void:
	$Bottom_button.disabled = true
	$Up_button.disabled = true
	$Bottom_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Up_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_bottom_button_mouse_entered() -> void:
	GameState.player._update_hand("interact")

func _on_up_button_mouse_entered() -> void:
	pass

func _night_title_popup()-> void:
	var hey_peter = randi_range(1,500)
	print(hey_peter)
	if(hey_peter == 67):
		$ColorRect3/Night/HeyPeter.show()
	else:
		$ColorRect3/Night/HeyPeter.hide()
	$ColorRect3/Night.text = "Night " + str(GameState.night)
	$AnimationPlayer.play("Night_Animation")

func _night_title_finish()->void:
	var hey_peter = randi_range(1,500)
	print(hey_peter)
	if(hey_peter == 67):
		$ColorRect3/Night/HeyPeter.show()
	else:
		$ColorRect3/Night/HeyPeter.hide()
	$ColorRect3/Night.text = "Finish"
	$AnimationPlayer.play("Night_Animation")


func _change_money(new_value: float) -> void:
	var old_value = float($"Right Container/Money/Label".text)
	if(new_value < old_value):
		$"Right Container/Money/CPUParticles2D".color = Color(1.0, 0.0, 0.0, 1.0)
	else:
		$"Right Container/Money/CPUParticles2D".color = Color(1.0, 1.0, 1.0, 1.0)
	$"Right Container/Money/CPUParticles2D".emitting = true
	$"Right Container/Money/Label".text = str(int(new_value))
	await get_tree().create_timer(0.5).timeout
	$"Right Container/Money/CPUParticles2D".emitting = false

func _change_time(new_value:float) -> void:
	$"Left Container/Timer".value = new_value
	pass

# Returns from back view to front view
func _on_up_button_pressed() -> void:
	if down:
		bendover()

var hint_hand: TextureRect
var _tutorial_running: bool = false

func _tutorial_start_drink():
	if _tutorial_running:
		return
	_tutorial_drink_on()

func _create_hint_hand() -> void:
	if is_instance_valid(hint_hand):
		hint_hand.queue_free()
	hint_hand = TextureRect.new()
	hint_hand.texture = preload("res://Assets/UI/Hand.png")
	hint_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_hand.z_index = 100
	hint_hand.hide()
	add_child(hint_hand)

func _tutorial_find_glass() -> Glasses:
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

func _tutorial_find_bottle() -> Drinks:
	if GameState.main_node:
		var gin_node = GameState.main_node.get_node_or_null("gin")
		if gin_node is Drinks and is_instance_valid(gin_node):
			return gin_node as Drinks
		for child in GameState.main_node.get_children():
			if child is Drinks and is_instance_valid(child):
				return child as Drinks
	return null

func _tutorial_find_receipt() -> Node3D:
	if GameState.main_node:
		for i in range(1, 4):
			var rec = GameState.main_node.get_node_or_null("ReciptPaper" + str(i))
			if rec is Node3D and is_instance_valid(rec) and "ordered" in rec and rec.ordered:
				return rec as Node3D
	return null

func _tutorial_find_shark() -> Base_NPC:
	if GameState.main_node and "seats" in GameState.main_node:
		for npc in GameState.main_node.seats:
			if npc is Base_NPC and is_instance_valid(npc) and npc.unique_talk:
				return npc as Base_NPC
	return null

func _update_tutorial_hint_drag(from_world: Variant, to_world: Variant, phase_time: float) -> void:
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
	var hand_size: Vector2 = hint_hand.size
	if hand_size == Vector2.ZERO and hint_hand.texture:
		hand_size = hint_hand.texture.get_size()
	var s0: Vector2 = camera.unproject_position(p0) - hand_size * 0.5
	var s1: Vector2 = camera.unproject_position(p1) - hand_size * 0.5
	var cycle: float = fmod(phase_time, 1.5)
	if cycle < 0.8:
		var t: float = 0.5 - 0.5 * cos((cycle / 0.8) * PI)
		hint_hand.show()
		hint_hand.modulate.a = 1.0
		hint_hand.global_position = s0.lerp(s1, t)
	elif cycle < 1.0:
		hint_hand.show()
		hint_hand.modulate.a = 1.0 - ((cycle - 0.8) / 0.2)
		hint_hand.global_position = s1
	else:
		hint_hand.hide()

func _tutorial_drink_on() -> void:
	_tutorial_running = true
	_create_hint_hand()
	var label := $"Tutorial Label" as Label
	label.show()

	var hint_elapsed: float = 0.0
	var last_step: String = ""

	while is_inside_tree():
		var delta: float = get_process_delta_time()
		hint_elapsed += delta

		var shark := _tutorial_find_shark()
		var glass := _tutorial_find_glass()
		var bottle := _tutorial_find_bottle()
		var receipt := _tutorial_find_receipt()
		var in_pour: bool = GameState.player != null and GameState.player.in_game
		var has_liquid: bool = glass != null and glass.total_liquids > 0.0
		var needs_drink: bool = shark != null and not shark.is_leaving and shark.drink_list.size() > 0

		# Step 6: Once the drink has been served, wait for player to talk to Loan Shark again
		if not needs_drink:
			if is_instance_valid(hint_hand):
				hint_hand.hide()
			label.text = "Talk To Loan Shark Again"
			if GameState.is_dialogue_open or shark == null or shark.is_leaving:
				break
			await get_tree().process_frame
			continue

		# Step 4: Currently in pour minigame
		if in_pour:
			if last_step != "pour":
				last_step = "pour"
			if is_instance_valid(hint_hand):
				hint_hand.hide()
			label.text = "Hold left click to pour the drink into the glass"
			await get_tree().process_frame
			continue

		# Step 1: Look down at counter to prepare the drink
		if (not down or is_transitioning) and not has_liquid:
			if last_step != "counter":
				last_step = "counter"
			if is_instance_valid(hint_hand):
				hint_hand.hide()
			label.text = "Go to your Counter to make the drink"
			await get_tree().process_frame
			continue

		# Step 2: Spawn and place a glass onto the counter
		if glass == null or glass.is_balls_dragging or glass._is_returning_to_counter or glass._waiting_for_working_area:
			if last_step != "glass":
				last_step = "glass"
				hint_elapsed = 0.0
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
				var bounds = Ingredients.get_working_area_bounds(self)
				if bounds is AABB:
					center_pos = (bounds as AABB).get_center()
				elif GameState.player and GameState.player.counter:
					center_pos = GameState.player.counter.global_position + Vector3(0.0, 1.5, 0.0)
				_update_tutorial_hint_drag(btn_pos, center_pos, hint_elapsed)
			await get_tree().process_frame
			continue

		# Step 3: Drag bottle onto the glass
		if not has_liquid:
			if last_step != "liquid":
				last_step = "liquid"
				hint_elapsed = 0.0
			label.text = "Grab the Liquid drop it on the glass"
			if bottle != null and bottle.is_balls_dragging:
				if is_instance_valid(hint_hand):
					hint_hand.hide()
			else:
				var b_pos: Variant = bottle.global_position if bottle else null
				_update_tutorial_hint_drag(b_pos, glass.global_position, hint_elapsed)
			await get_tree().process_frame
			continue

		# Step 5: Serve via receipt -> glass (or directly cup -> NPC)
		if last_step != "receipt":
			last_step = "receipt"
			hint_elapsed = 0.0
		label.text = "Bring the recipt onto the drink"
		if (receipt != null and "is_balls_dragging" in receipt and receipt.is_balls_dragging) or glass.is_balls_dragging or glass.is_being_served or not down or is_transitioning:
			if is_instance_valid(hint_hand):
				hint_hand.hide()
		else:
			var r_pos: Variant = null
			if receipt != null:
				if "has_board_slot" in receipt and receipt.has_board_slot:
					r_pos = receipt.board_slot_position
				else:
					r_pos = receipt.global_position
			_update_tutorial_hint_drag(r_pos, glass.global_position, hint_elapsed)
		await get_tree().process_frame

	if is_instance_valid(hint_hand):
		hint_hand.queue_free()
		hint_hand = null
	if is_instance_valid(label):
		label.hide()
	_tutorial_running = false
