extends CanvasLayer
var mouse_side : bool = false
var mouse_entered: bool = false
@export var camera_movement_rotation = 10
@export var player : Node3D
var current_position : int = 3
var match_position_counter : Dictionary ={1 : 5.8,2:2.8,3: -0.2}
var camera : Camera3D
var down : bool = false
var up_down_checks : bool = false

var base_camera_rotation : Vector3 = Vector3(-16.3, 0.0, 0.0)
var current_tilt_yaw : float = 0.0
var current_tilt_pitch : float = 0.0
const MAX_TILT_YAW : float = 3.0
const MAX_TILT_PITCH : float = 2.0
var is_transitioning : bool = false
var is_moving : bool = false
var default_camera_local_pos : Vector3 = Vector3.ZERO

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	if camera:
		default_camera_local_pos = camera.position
	if player and match_position_counter.has(current_position):
		player.position.x = match_position_counter[current_position]
	$FishEye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.gameplay_ui = self
	set_shift_hud_visible(false)

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
	tween.tween_property(self, "base_camera_rotation", Vector3(-21.0, 180.0, 0.0), 0.5)
	tween.tween_property(camera, "global_position", back_position, 0.5)
	tween.chain().tween_callback(func():
		$Left_Button.disabled = true
		$Right_Button.disabled = true
		$Bottom_button.disabled = true
		$Up_button.disabled = false
		is_transitioning = false
	)
	
# Tweens camera back to front view
func _look_forward() -> void:
	up_down_checks = false
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "base_camera_rotation", Vector3(-16.3, 0.0, 0.0), 0.5)
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
	$"Right Container/Money/Label".text = str(new_value)
	await get_tree().create_timer(0.5).timeout
	$"Right Container/Money/CPUParticles2D".emitting = false

func _change_time(new_value:float) -> void:
	$"Left Container/Timer".value = new_value
	pass

# Returns from back view to front view
func _on_up_button_pressed() -> void:
	if down:
		bendover()


#func _camera_down_tween() -> void:
	#var tween = get_tree().create_tween().set_parallel(true)
	#tween.set_trans(Tween.TRANS_SINE)
	#tween.set_ease(Tween.EASE_OUT)
	#tween.tween_property(camera,"position:y",2.7,0.15)
	#tween.tween_property(camera,"position:z",1.5,0.15)
	#tween.tween_property(camera,"rotation_degrees:x",-16.3,0.15)
#
#func _camera_up_tween() -> void:
	#var tween = get_tree().create_tween().set_parallel(true)
	#tween.set_trans(Tween.TRANS_SINE)
	#tween.set_ease(Tween.EASE_OUT)
	#tween.tween_property(camera,"position:y",1.9,0.15)
	#tween.tween_property(camera,"position:z",1.3,0.15)
	#tween.tween_property(camera,"rotation_degrees:x",-55.3,0.15)
