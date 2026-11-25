class_name NameTag
extends Area3D

signal pressed
signal hovered(is_hovered: bool)

const UI_FONT: Font = preload("res://Assets/Font/Merchant Copy.ttf")

@export var tag_text: String = "":
	set(value):
		tag_text = value
		_refresh_tag()

@export var tag_icon: Texture2D = null:
	set(value):
		tag_icon = value
		_refresh_tag()

@export var interactive: bool = true:
	set(value):
		interactive = value
		_sync_collision_enabled()

@export var is_disabled: bool = false:
	set(value):
		is_disabled = value
		_update_button_visual()

@export var pixel_scale: float = 0.0026:
	set(value):
		pixel_scale = maxf(0.0005, value)
		_refresh_layout()

@export var face_camera: bool = true
@export var font_size: int = 56
@export var icon_size: int = 28
@export var border_width: int = 4
@export var bg_color: Color = Color.WHITE
@export var hover_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var pressed_color: Color = Color(0.75, 0.75, 0.75, 1.0)
@export var disabled_bg_color: Color = Color(0.92, 0.92, 0.92, 0.85)
@export var border_color: Color = Color.BLACK
@export var text_color: Color = Color.BLACK
@export var disabled_text_color: Color = Color(0.45, 0.45, 0.45, 1.0)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var sprite: Sprite3D = $Sprite3D
@onready var sub_viewport: SubViewport = $Sprite3D/SubViewport
@onready var tag_button: Button = $Sprite3D/SubViewport/TagButton

var _is_hovered: bool = false
var _is_pressed: bool = false
var _deny_tween: Tween = null
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _pressed_style: StyleBoxFlat
var _disabled_style: StyleBoxFlat

func _ready() -> void:
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	if sprite and sub_viewport:
		sprite.texture = sub_viewport.get_texture()

	_build_styles()
	_sync_collision_enabled()
	_refresh_tag()

	if not input_event.is_connected(_on_tag_input_event):
		input_event.connect(_on_tag_input_event)
	if not mouse_entered.is_connected(_on_tag_mouse_entered):
		mouse_entered.connect(_on_tag_mouse_entered)
	if not mouse_exited.is_connected(_on_tag_mouse_exited):
		mouse_exited.connect(_on_tag_mouse_exited)

func setup(p_text: String, p_icon: Texture2D = null, p_interactive: bool = true) -> void:
	tag_text = p_text
	tag_icon = p_icon
	interactive = p_interactive
	_refresh_tag()

func set_text(new_text: String) -> void:
	tag_text = new_text

func set_icon(new_icon: Texture2D) -> void:
	tag_icon = new_icon

func set_disabled(disabled: bool) -> void:
	is_disabled = disabled
	if is_disabled:
		_is_pressed = false
		if _is_hovered:
			_is_hovered = false
			if GameState.player and Ingredients.active_dragging_item == null:
				GameState.player._update_hand("idle")

func set_interactive(enabled: bool) -> void:
	interactive = enabled

func set_colors(p_bg_color: Color, p_border_color: Color, p_text_color: Color) -> void:
	bg_color = p_bg_color
	border_color = p_border_color
	text_color = p_text_color
	_build_styles()
	_update_button_visual()

func _process(_delta: float) -> void:
	if _is_pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_is_pressed = false
		_update_button_visual()

	if face_camera and visible:
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_squared_to(global_position) > 0.0001:
			look_at(cam.global_position, Vector3.UP, true)

func _build_styles() -> void:
	_normal_style = _make_style(bg_color)
	_hover_style = _make_style(hover_color)
	_pressed_style = _make_style(pressed_color)
	_disabled_style = _make_style(disabled_bg_color)

func _make_style(fill_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_col
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.anti_aliasing = false
	return sb

func _sync_collision_enabled() -> void:
	if collision_shape:
		collision_shape.disabled = not interactive
	input_ray_pickable = interactive

func _refresh_tag() -> void:
	if not is_node_ready() or not tag_button:
		return
	tag_button.icon = tag_icon
	tag_button.expand_icon = (tag_icon != null)
	tag_button.add_theme_font_override("font", UI_FONT)
	tag_button.add_theme_font_size_override("font_size", font_size)
	tag_button.add_theme_constant_override("icon_max_width", icon_size)
	tag_button.add_theme_constant_override("h_separation", 6)
	_update_button_visual()
	TextIcons.apply_to_control(tag_button, tag_text)
	_refresh_layout()

func _refresh_layout() -> void:
	if not is_node_ready() or not tag_button or not sub_viewport or not sprite:
		return
	var min_sz: Vector2 = tag_button.get_combined_minimum_size()
	var vp_w: int = maxi(ceili(min_sz.x), 36)
	var vp_h: int = maxi(ceili(min_sz.y), 28)
	sub_viewport.size = Vector2i(vp_w, vp_h)
	tag_button.position = Vector2.ZERO
	tag_button.size = Vector2(float(vp_w), float(vp_h))
	sprite.pixel_size = pixel_scale

	if collision_shape and collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		box.size = Vector3(float(vp_w) * pixel_scale, float(vp_h) * pixel_scale, 0.06)

func _update_button_visual() -> void:
	if not is_node_ready() or not tag_button:
		return
	var active_style: StyleBoxFlat = _normal_style
	var active_text_col: Color = text_color
	if is_disabled:
		active_style = _disabled_style
		active_text_col = disabled_text_color
	elif _is_pressed:
		active_style = _pressed_style
	elif _is_hovered:
		active_style = _hover_style

	tag_button.add_theme_stylebox_override("normal", active_style)
	tag_button.add_theme_color_override("font_color", active_text_col)
	TextIcons.sync_control_visuals(tag_button)

func _can_interact() -> bool:
	if not interactive or not visible:
		return false
	if GameState.is_dialogue_open or ShakerMinigame.active:
		return false
	if Ingredients.active_dragging_item != null:
		return false
	if GameState.player and "in_game" in GameState.player and GameState.player.in_game:
		return false
	if GameState.gameplay_ui and "down" in GameState.gameplay_ui and not GameState.gameplay_ui.down:
		return false
	return true

@warning_ignore("unused_parameter")
func _on_tag_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if not _can_interact():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not is_disabled:
				_is_pressed = true
				_update_button_visual()
				pressed.emit()
			get_viewport().set_input_as_handled()
		else:
			_is_pressed = false
			_update_button_visual()

func _on_tag_mouse_entered() -> void:
	if not _can_interact():
		return
	_is_hovered = true
	_update_button_visual()
	hovered.emit(true)
	if not is_disabled and GameState.player:
		GameState.player._update_hand("interact")

func _on_tag_mouse_exited() -> void:
	var was_hovered := _is_hovered
	_is_hovered = false
	_is_pressed = false
	_update_button_visual()
	if was_hovered:
		hovered.emit(false)
		if Ingredients.active_dragging_item == null and GameState.player:
			GameState.player._update_hand("idle")

func deny() -> void:
	if not is_inside_tree() or not sprite or not tag_button:
		return
	if _deny_tween and _deny_tween.is_valid():
		_deny_tween.kill()
	sprite.position = Vector3.ZERO
	tag_button.modulate = Color(1.0, 0.35, 0.35, 1.0)
	_deny_tween = create_tween().set_parallel(true)
	_deny_tween.tween_property(tag_button, "modulate", Color.WHITE, 0.3)
	_deny_tween.tween_method(_apply_deny_shake, 0.0, 1.0, 0.3)
	_deny_tween.chain().tween_callback(_finish_deny)

func _apply_deny_shake(t: float) -> void:
	if is_instance_valid(sprite):
		var wave := sin(t * 4.0 * TAU)
		var decay := 1.0 - t
		sprite.position.x = wave * 0.025 * decay

func _finish_deny() -> void:
	if is_instance_valid(sprite):
		sprite.position = Vector3.ZERO
	if is_instance_valid(tag_button):
		tag_button.modulate = Color.WHITE