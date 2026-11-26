extends Area3D
class_name GarnishDispenser

const GARNISH_ITEM_SCENE: PackedScene = preload("res://Player/Drink/garnish_item.tscn")

@export var garnish_id: String = "lemon_whole"
@export var max_stock: int = GarnishDefinitions.DEFAULT_DISPENSER_STOCK
@export var item_spawn_scale: Vector3 = Vector3(0.2, 0.2, 0.2)

@onready var sprite: Sprite3D = $Sprite3D
@onready var refill_timer: Timer = $RefillTimer

var counter_origin: Node3D = null
var original_position: Marker3D = null
var current_stock: int = GarnishDefinitions.DEFAULT_DISPENSER_STOCK
var _camera: Camera3D = null
var _is_hovered: bool = false
var _deny_tween: Tween = null
var _base_sprite_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if refill_timer and not refill_timer.timeout.is_connected(_on_refill_timer_timeout):
		refill_timer.timeout.connect(_on_refill_timer_timeout)
	_apply_passive_upgrades()
	_refresh_visual()

func setup(p_marker: Marker3D, p_counter: Node3D, p_garnish_id: String) -> void:
	original_position = p_marker
	counter_origin = p_counter
	garnish_id = GarnishDefinitions.normalize_id(p_garnish_id)
	if is_instance_valid(p_marker):
		global_position = p_marker.global_position
	_apply_passive_upgrades()
	current_stock = max_stock
	_refresh_visual()

func _apply_passive_upgrades() -> void:
	var size_bonus := 0
	var auto_bonus := 0
	if PlayerStats and "unlocks" in PlayerStats and PlayerStats.unlocks.has("Drinks Size Increase"):
		size_bonus = int(PlayerStats.unlocks["Drinks Size Increase"])
	if PlayerStats and "unlock_passive" in PlayerStats:
		if PlayerStats.unlock_passive.has("Drinks Size Increase"):
			size_bonus = maxi(size_bonus, int(PlayerStats.unlock_passive["Drinks Size Increase"]))
		if PlayerStats.unlock_passive.has("Drinks Auto Increase"):
			auto_bonus = int(PlayerStats.unlock_passive["Drinks Auto Increase"])

	max_stock = GarnishDefinitions.DEFAULT_DISPENSER_STOCK + size_bonus
	current_stock = clampi(current_stock, 0, max_stock)

	if is_instance_valid(refill_timer):
		refill_timer.wait_time = maxf(0.5, GarnishDefinitions.DEFAULT_REFILL_TIME - float(auto_bonus) * 0.25)
		if refill_timer.is_stopped():
			refill_timer.start()

func _process(_delta: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
	if _camera and is_instance_valid(sprite):
		var target_flat := _camera.global_position
		target_flat.y = sprite.global_position.y
		if target_flat.distance_squared_to(sprite.global_position) > 0.0001:
			sprite.look_at(target_flat, Vector3.UP)

func refill() -> void:
	current_stock = max_stock
	_refresh_visual()

func _on_refill_timer_timeout() -> void:
	if current_stock < max_stock:
		current_stock += 1
		_refresh_visual()

func _refresh_visual() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.texture = GarnishDefinitions.get_texture(garnish_id, false)
	if current_stock <= 0:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.35)
	elif _is_hovered:
		sprite.modulate = Color(1.5, 1.5, 0.4, 1.0)
	else:
		sprite.modulate = Color.WHITE

func _can_interact() -> bool:
	if GameState.is_dialogue_open or ShakerMinigame.active:
		return false
	if Ingredients.active_dragging_item != null:
		return false
	if GameState.player and "in_game" in GameState.player and GameState.player.in_game:
		return false
	return true

@warning_ignore("unused_parameter")
func _on_input_event(cam: Node, event: InputEvent, event_pos: Vector3, normal: Vector3, shape_idx: int) -> void:
	if not _can_interact():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_stock <= 0:
			_play_deny()
			get_viewport().set_input_as_handled()
			return
		_spawn_garnish_item()
		get_viewport().set_input_as_handled()

func _spawn_garnish_item() -> void:
	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return
	current_stock = maxi(0, current_stock - 1)
	_refresh_visual()

	var item := GARNISH_ITEM_SCENE.instantiate() as GarnishItem
	if not item:
		return
	item.scale = item_spawn_scale
	item._skip_initial_snap = true
	item.setup(garnish_id, counter_origin)
	parent_node.add_child(item)
	item.global_position = original_position.global_position if is_instance_valid(original_position) else global_position
	item.start_drag_from_spawn(get_viewport().get_mouse_position(), true)
	SFXAudio.play_mugpickup()

func _play_deny() -> void:
	if not is_instance_valid(sprite):
		return
	if _deny_tween and _deny_tween.is_valid():
		_deny_tween.kill()
	sprite.offset = _base_sprite_offset
	_deny_tween = create_tween()
	_deny_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(sprite):
			var wave := sin(t * 4.0 * TAU)
			sprite.offset = _base_sprite_offset + Vector2(wave * 6.0 * (1.0 - t), 0.0)
	, 0.0, 1.0, 0.28)
	_deny_tween.finished.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.offset = _base_sprite_offset
	)

func _on_mouse_entered() -> void:
	if Ingredients.active_dragging_item != null:
		return
	_is_hovered = true
	_refresh_visual()
	if GameState.player and current_stock > 0:
		GameState.player._update_hand("interact")

func _on_mouse_exited() -> void:
	_is_hovered = false
	_refresh_visual()
	if Ingredients.active_dragging_item == null and GameState.player:
		GameState.player._update_hand("idle")