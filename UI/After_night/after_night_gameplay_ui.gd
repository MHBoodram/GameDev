extends CanvasLayer

# hud

@export var camera_movement_rotation: int = 10
@export var player: Node3D

var camera_rig: Camera = null
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
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam is Camera:
		camera_rig = cam as Camera
	$FishEye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Right_Button.disabled = true
	$Left_Button.disabled = true
	GameState.gameplay_ui = self
	_sync_money_display(PlayerStats.money)
	set_shift_hud_visible(false)
	_setup_hud_indicators()
	print(camera_rig.global_position)

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
	$"Mid Container/Money/Label".text = "Quota:\n" + str(int(quota_value)) + " {coin}"
	TextIcons.apply_to_control($"Mid Container/Money/Label")

func _update_night_display(night_number: int) -> void:
	$ColorRect3/Night.text = "Night " + str(night_number)

# toggle for camera rig
func bendover() -> void:
	if not camera_rig or camera_rig.is_transitioning or camera_rig.is_moving:
		return
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
			$Up_button.disabled = false
		else:
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
	if !GameState.player.in_shop:
		return
	
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