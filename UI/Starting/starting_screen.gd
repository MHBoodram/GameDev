extends Node3D

const TITLE_INTRO_FF_SCOPE := "title_intro"

@export var sub_viewport: SubViewport
@onready var start_menu = get_node("Menu2/Menu3/Viewport/SubViewport/StartMenu")
@onready var vp_sprite: Sprite3D = $Menu2/Menu3/Viewport
@onready var sub_viewport_node: SubViewport = $Menu2/Menu3/Viewport/SubViewport
@onready var play_area: Area3D = $Menu2/Menu3/Play
@onready var setting_area: Area3D = $Menu2/Menu3/Setting
@onready var quit_area: Area3D = $Menu2/Menu3/Quit
@onready var hand_sprite: Sprite2D = $Node2D/Setting/Hand

var _in_settings: bool = false
var _is_transitioning: bool = false

func _ready() -> void:
	if is_instance_valid(GameState.pause_menu) and GameState.pause_menu.visible:
		GameState.pause_menu.close_menu()
	if is_instance_valid(GameState.debug_menu):
		GameState.debug_menu.visible = false
	MusicPlayer.play_menu()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	ToolController.align_hand_hotspot(hand_sprite)
	_update_hand("idle")
	_connect_menu_hitbox_signals()
	call_deferred("_sync_menu_hitboxes")
	await SettingState._loading_setting()
	$Node2D/Setting._setting_dictionary_start()
	$AnimationPlayer.speed_scale = 0.4
	FastForward.begin_scope(TITLE_INTRO_FF_SCOPE, {
		"duration": 0.25,
		"priority": 30,
	})
	$AnimationPlayer.play("movement")
	FastForward.track_animation($AnimationPlayer, TITLE_INTRO_FF_SCOPE)
	$AnimationPlayer.animation_finished.connect(_on_intro_animation_finished, CONNECT_ONE_SHOT)
	$Menu_animation.play("menu_close")
	call_deferred("_sync_menu_hitboxes")

func _exit_tree() -> void:
	FastForward.end_scope(TITLE_INTRO_FF_SCOPE)

func _on_intro_animation_finished(_anim_name: StringName) -> void:
	FastForward.end_scope(TITLE_INTRO_FF_SCOPE)
	_sync_menu_hitboxes()

func _connect_menu_hitbox_signals() -> void:
	if not is_instance_valid(start_menu):
		return
	for btn_name in ["play_button", "setting_button", "quit_button"]:
		var btn := start_menu.get(btn_name) as Control
		if not is_instance_valid(btn):
			continue
		if not btn.item_rect_changed.is_connected(_sync_menu_hitboxes):
			btn.item_rect_changed.connect(_sync_menu_hitboxes)
		if not btn.visibility_changed.is_connected(_sync_menu_hitboxes):
			btn.visibility_changed.connect(_sync_menu_hitboxes)

func _sync_menu_hitboxes() -> void:
	if not is_instance_valid(start_menu) or not is_instance_valid(vp_sprite) or not is_instance_valid(sub_viewport_node):
		return
	var pairs := [
		[play_area, start_menu.get("play_button") as Control],
		[setting_area, start_menu.get("setting_button") as Control],
		[quit_area, start_menu.get("quit_button") as Control],
	]
	for pair in pairs:
		_sync_single_button_hitbox(pair[0] as Area3D, pair[1] as Control)

func _sync_single_button_hitbox(area: Area3D, btn: Control) -> void:
	if not is_instance_valid(area):
		return
	var col := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not is_instance_valid(btn) or not btn.is_visible_in_tree():
		area.input_ray_pickable = false
		if col:
			col.disabled = true
		return

	var rect := btn.get_global_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return

	var vp_size := Vector2(sub_viewport_node.size)
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return

	var px_size: float = vp_sprite.pixel_size
	var center_px := rect.get_center()
	var local_pos := Vector3(
		(center_px.x - vp_size.x * 0.5) * px_size,
		(vp_size.y * 0.5 - center_px.y) * px_size,
		0.0
	)
	area.transform = Transform3D(Basis.IDENTITY, vp_sprite.transform * local_pos)

	var can_click := not _in_settings and not _is_transitioning
	area.input_ray_pickable = can_click
	if col:
		col.transform = Transform3D.IDENTITY
		col.disabled = not can_click
		var box := col.shape as BoxShape3D
		if box == null:
			box = BoxShape3D.new()
			col.shape = box
		elif not box.has_meta("_unique_menu_hitbox"):
			box = box.duplicate() as BoxShape3D
			col.shape = box
		box.set_meta("_unique_menu_hitbox", true)
		box.size = Vector3(
			maxf(rect.size.x * px_size * absf(vp_sprite.scale.x), 0.01),
			maxf(rect.size.y * px_size * absf(vp_sprite.scale.y), 0.01),
			0.025
		)

func _set_menu_buttons_interactive(enabled: bool) -> void:
	for pair in [
		[play_area, start_menu.get("play_button") as Control if is_instance_valid(start_menu) else null],
		[setting_area, start_menu.get("setting_button") as Control if is_instance_valid(start_menu) else null],
		[quit_area, start_menu.get("quit_button") as Control if is_instance_valid(start_menu) else null],
	]:
		var area := pair[0] as Area3D
		var btn := pair[1] as Control
		if not is_instance_valid(area):
			continue
		var allow := enabled and is_instance_valid(btn) and btn.is_visible_in_tree()
		area.input_ray_pickable = allow
		var col := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col:
			col.disabled = not allow

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	hand_sprite.global_position = get_viewport().get_mouse_position()

func _moving_3d_to_2d():
	if _in_settings or _is_transitioning:
		return
	_in_settings = true
	_set_menu_buttons_interactive(false)
	_update_hand("idle")
	if is_instance_valid(start_menu):
		start_menu._remove_hover("Play")
		start_menu._remove_hover("Setting")
		start_menu._remove_hover("Quit")
	$Node2D/Setting._setting_dictionary_start()
	$AnimationPlayer.play("move_setting")
	$Node2D/Setting._moving(false)
	await $AnimationPlayer.animation_finished
	#$Node2D/Camera2D.make_current()

func _update_hand(change: String) -> void:
	ToolController.apply_hand_animation($Node2D/Setting/Hand/AnimationPlayer, change)

func _moving_2d_to_3d():
	if not _in_settings:
		return
	$AnimationPlayer.play_backwards("move_setting")
	$Node2D/Setting._moving(true)
	await $AnimationPlayer.animation_finished
	_in_settings = false
	_set_menu_buttons_interactive(true)

@warning_ignore("unused_parameter")
func _on_area_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if _in_settings or _is_transitioning:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_is_transitioning = true
		_set_menu_buttons_interactive(false)
		UIAudio.play_click()
		var tween = get_tree().create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property($Menu2/Menu3/Viewport,"modulate:a",0,0.3)
		#tween.tween_property($Menu2,"modulate:a",0,0.5)
		tween.tween_property($WorldEnvironment.environment,"background_energy_multiplier",0,0.5)
		tween.tween_property($SpotLight3D,"light_energy",0,0.3)
		await tween.finished
		await get_tree().create_timer(1).timeout
		$Menu2/Menu3/Viewport/SubViewport/StartMenu._on_play_pressed()

func _on_play_mouse_entered() -> void:
	if _in_settings or _is_transitioning:
		return
	_update_hand("interact")
	start_menu._change_hover("Play")

func _on_setting_mouse_entered() -> void:
	if _in_settings or _is_transitioning:
		return
	_update_hand("interact")
	start_menu._change_hover("Setting")

func _on_play_mouse_exited() -> void:
	_update_hand("idle")
	start_menu._remove_hover("Play")

func _on_setting_mouse_exited() -> void:
	_update_hand("idle")
	start_menu._remove_hover("Setting")

@warning_ignore("unused_parameter")
func _on_setting_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if _in_settings or _is_transitioning:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		UIAudio.play_click()
		_moving_3d_to_2d()

@warning_ignore("unused_parameter")
func _on_quit_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if _in_settings or _is_transitioning:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_is_transitioning = true
		_set_menu_buttons_interactive(false)
		UIAudio.play_click()
		start_menu._on_quit_pressed()

func _on_quit_mouse_entered() -> void:
	if _in_settings or _is_transitioning:
		return
	_update_hand("interact")
	start_menu._change_hover("Quit")

func _on_quit_mouse_exited() -> void:
	_update_hand("idle")
	start_menu._remove_hover("Quit")
