extends Node3D

# manages player mouse/physical actions

@onready var shot_glass := preload("res://Player/Drink/Glasses/shot_cup.tscn")
@onready var beer_glass := preload("res://Player/Drink/Glasses/beer_cup.tscn")
@onready var gameplay_ui := get_node("GameplayUi")
@onready var hand_sprite := get_node("GameplayUi/Hand")
@onready var camera_rig: Camera = get_node_or_null("Camera3D") as Camera

@export var counter: Node3D
var summoning: bool = false
var in_game: bool = false
var _pour_tween: Tween = null
var in_shop: bool = false
var tool_controller: ToolController = ToolController.new()

var in_game_drinks: Dictionary = {
	"Drink": {"Node": Node3D, "position": Vector3.ZERO},
	"Glass": {"Node": Node3D, "position": Vector3.ZERO}
}

@export var counter_min_x: float = -1.0
@export var counter_max_x: float = 1.184
@export var min_z: float = 0.28
@export var spawn_y: float = 5.0
@export var spawn_scale: Vector3 = Vector3(0.2, 0.2, 0.2)

var cup_offsets := {
	"shot_glass": Vector3.ZERO,
	"beer_glass": Vector3.ZERO,
}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	ToolController.align_hand_hotspot(hand_sprite)
	_update_hand("idle")
	print(global_position)
	global_position.x = -0.2

func _process(_delta: float) -> void:
	if hand_sprite:
		hand_sprite.global_position = get_viewport().get_mouse_position()

func _force_cursor_image(move_to: Vector3) -> void:
	if hand_sprite and camera_rig:
		hand_sprite.global_position = camera_rig.unproject_position(move_to)

func _force_mouse(move_to: Vector3) -> void:
	if camera_rig:
		get_viewport().warp_mouse(camera_rig.unproject_position(move_to))

func _change_tool(_change: String) -> void:
	pass

func return_tool() -> String:
	return "hand"

func _update_hand(change: String) -> void:
	var anim_player: AnimationPlayer = $GameplayUi/Hand/AnimationPlayer
	tool_controller.update_hand_visual(anim_player, change)

func handle_counter_edge_action() -> bool:
	return false

func get_mouse_world_position(cam: Camera3D, plane_y: float) -> Vector3:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mouse_pos)
	var ray_dir := cam.project_ray_normal(mouse_pos)
	var hit = Plane(Vector3.UP, plane_y).intersects_ray(ray_origin, ray_dir)
	return hit if hit != null else global_position

func _spawn_and_begin_drag(_scene: PackedScene, _cup_name: String, _spawn_world_pos: Variant = null) -> void:
	pass

func _perfect_pour(_drink: Drinks, _glass: Glasses) -> void:
	pass

func _out_of_game() -> void:
	pass

func _on_shot_glass_button_input_event(_cam: Node, _event: InputEvent, _pos: Vector3, _norm: Vector3, _shape_idx: int) -> void:
	pass

func _on_beer_glass_button_input_event(_cam: Node, _event: InputEvent, _pos: Vector3, _norm: Vector3, _shape_idx: int) -> void:
	pass

func _on_trash_area_entered(_area: Area3D) -> void:
	pass