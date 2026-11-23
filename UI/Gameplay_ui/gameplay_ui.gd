extends CanvasLayer

# hud

@export var camera_movement_rotation: int = 10
@export var player: Node3D

var camera_rig: Camera = null
var tutorial_director: TutorialManager = TutorialManager.new()
var hud_indicators: HudIndicators = null

# patch to camera rig so existing scripts don't break
var down: bool:
	get: return camera_rig.down if camera_rig else false

var is_transitioning: bool:
	get: return camera_rig.is_transitioning if camera_rig else false

var current_position: int:
	get: return camera_rig.current_position if camera_rig else 3
	set(val):
		if camera_rig: camera_rig.current_position = val

func _ready() -> void:
	add_child(tutorial_director)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam is Camera:
		camera_rig = cam as Camera
	$FishEye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.gameplay_ui = self
	_sync_money_display(PlayerStats.money)
	set_shift_hud_visible(false)
	_setup_hud_indicators()
	if PlayerStats and not PlayerStats.money_changed.is_connected(_on_money_changed):
		PlayerStats.money_changed.connect(_on_money_changed)
	if not GameEvents.night_title_requested.is_connected(_on_night_title_requested):
		GameEvents.night_title_requested.connect(_on_night_title_requested)
	if not GameEvents.minigame_lock_changed.is_connected(_on_minigame_lock_changed):
		GameEvents.minigame_lock_changed.connect(_on_minigame_lock_changed)

func _exit_tree() -> void:
	if is_instance_valid(PlayerStats) and PlayerStats.money_changed.is_connected(_on_money_changed):
		PlayerStats.money_changed.disconnect(_on_money_changed)
	if GameEvents._bus:
		if GameEvents.night_title_requested.is_connected(_on_night_title_requested):
			GameEvents.night_title_requested.disconnect(_on_night_title_requested)
		if GameEvents.minigame_lock_changed.is_connected(_on_minigame_lock_changed):
			GameEvents.minigame_lock_changed.disconnect(_on_minigame_lock_changed)

func _on_minigame_lock_changed(locked: bool) -> void:
	if locked:
		_in_down_minigame()
	else:
		_out_down_minigame()

func _on_money_changed(new_value: float, _delta: float) -> void:
	_change_money(new_value)

func _on_night_title_requested(text: String) -> void:
	if text == "":
		_night_title_popup()
	else:
		$ColorRect3/Night/HeyPeter.hide()
		$ColorRect3/Night.text = text
		$AnimationPlayer.play("Night_Animation")

func _setup_hud_indicators() -> void:
	if hud_indicators and is_instance_valid(hud_indicators):
		return
	hud_indicators = HudIndicators.new()
	add_child(hud_indicators)
	call_deferred("_order_hud_indicators")

func _order_hud_indicators() -> void:
	if not is_instance_valid(hud_indicators):
		return
	var hand_node := get_node_or_null("Hand")
	if hand_node and hud_indicators.get_index() > hand_node.get_index():
		move_child(hud_indicators, hand_node.get_index())

func _sync_money_display(value: float) -> void:
	$"Right Container/Money/Label".text = str(int(value))

func set_shift_hud_visible(is_visible: bool) -> void:
	$"Left Container".visible = is_visible
	$"Mid Container".visible = is_visible

func _update_quota(quota_value: float) -> void:
	$"Mid Container/Money/Label".text = "Quota:\n" + str(int(quota_value))

func _update_night_display(night_number: int) -> void:
	$ColorRect3/Night.text = "Night " + str(night_number)

# toggle for camera rig
func bendover() -> void:
	if not camera_rig or camera_rig.is_transitioning or camera_rig.is_moving:
		return
	$Left_Button.disabled = true
	$Right_Button.disabled = true
	$Bottom_button.disabled = true
	$Up_button.disabled = true

	var was_down: bool = camera_rig.down if camera_rig else false
	camera_rig.bendover()

	var tree := get_tree()
	if tree:
		await tree.create_timer(0.5).timeout
	if is_inside_tree() and camera_rig:
		$Bottom_button.disabled = false
		if not was_down:
			$Left_Button.disabled = true
			$Right_Button.disabled = true
			$Up_button.disabled = false
		else:
			$Left_Button.disabled = false
			$Right_Button.disabled = false
			$Up_button.disabled = true

func moving_around(right: bool) -> void:
	if camera_rig:
		camera_rig.moving_around(right)

func _on_left_button_mouse_entered() -> void:
	if GameState.player:
		GameState.player._update_hand("interact")

func _on_right_button_mouse_entered() -> void:
	if GameState.player:
		GameState.player._update_hand("interact")

func _on_mouse_exited() -> void:
	if GameState.player:
		GameState.player._update_hand("idle")

func _on_left_button_pressed() -> void:
	moving_around(false)

func _on_right_button_pressed() -> void:
	moving_around(true)

func _on_bottom_button_pressed() -> void:
	if GameState.player and GameState.player.has_method("handle_counter_edge_action"):
		if GameState.player.handle_counter_edge_action():
			_in_down_minigame()
			return
	if down:
		return
	bendover()

func _on_up_button_pressed() -> void:
	if down:
		bendover()

func _in_down_minigame() -> void:
	$Bottom_button.disabled = true
	$Up_button.disabled = true
	$Bottom_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Up_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _out_down_minigame() -> void:
	$Bottom_button.disabled = false
	$Up_button.disabled = false
	$Bottom_button.mouse_filter = Control.MOUSE_FILTER_STOP
	$Up_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_bottom_button_mouse_entered() -> void:
	if GameState.player:
		GameState.player._update_hand("interact")

func _on_up_button_mouse_entered() -> void:
	pass

func _night_title_popup() -> void:
	var hey_peter := randi_range(1, 500)
	$ColorRect3/Night/HeyPeter.visible = (hey_peter == 67)
	$ColorRect3/Night.text = "Night " + str(GameState.night)
	$AnimationPlayer.play("Night_Animation")

func _night_title_finish() -> void:
	$ColorRect3/Night/HeyPeter.hide()
	$ColorRect3/Night.text = "Finish"
	$AnimationPlayer.play("Night_Animation")

func _change_money(new_value: float) -> void:
	var old_value := float($"Right Container/Money/Label".text)
	$"Right Container/Money/Label".text = str(int(new_value))
	if is_equal_approx(new_value, old_value):
		return
	$"Right Container/Money/CPUParticles2D".color = Color.RED if new_value < old_value else Color.WHITE
	$"Right Container/Money/CPUParticles2D".emitting = true
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree():
		$"Right Container/Money/CPUParticles2D".emitting = false

func _change_time(new_value: float) -> void:
	$"Left Container/Timer".value = new_value

# tutorial methods go to the tutorial helper
func start_tutorial(keys_node: Control = null) -> void:
	tutorial_director.start_tutorial(self, keys_node)

func _tutorial_find_shark() -> Base_NPC:
	return tutorial_director.find_shark()

func _tutorial_start_drink() -> void:
	tutorial_director.start_drink_tutorial(self)
