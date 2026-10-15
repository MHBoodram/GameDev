extends Node3D
@onready var shot_glass = preload("res://Player/Drink/Glasses/shot_cup.tscn")
@onready var beer_glass = preload("res://Player/Drink/Glasses/beer_cup.tscn")
@onready var gameplay_ui = get_node("GameplayUi")
@onready var hand_sprite = get_node("GameplayUi/Hand")
@export var counter : Node3D
#@onready var counter = get_node("Coutner/Lower_counter")
var summoning : bool = false
var icup_spawn : String = "shot_glass"
var in_pour_zone : Area3D
var in_game : bool = false
var in_game_drinks : Dictionary = \
{
	"Drink" : {"Node" : Node3D, "position" : Vector3.ZERO},
	"Glass" : {"Node" : Node3D, "position" : Vector3.ZERO}
}
@export var counter_min_x: float = -1.0
@export var counter_max_x: float = 1.184
@export var min_z: float = 0.28
@export var spawn_y: float = 5
@export var spawn_scale: Vector3 = Vector3(0.2, 0.2, 0.2)

var cup_offsets := {
	"shot_glass": Vector3(0, 0, 0),
	"beer_glass": Vector3(0, 0, 0),
}

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_update_hand("idle")

func _process(delta: float) -> void:
	if($GameplayUi/Hand/AnimationPlayer.current_animation == "hold"):
		return
	$GameplayUi/Hand.global_position = get_viewport().get_mouse_position()

func _force_cursor_image(move_to: Vector3) -> void:
	$GameplayUi/Hand.global_position = $Camera3D.unproject_position(move_to)

func _force_mouse(move_to: Vector3) -> void:
	get_viewport().warp_mouse($Camera3D.unproject_position(move_to))

func _update_hand(change: String) -> void:
	match change:
		"interact":
			if(!$GameplayUi/Hand/AnimationPlayer.current_animation == "interact"):
				$GameplayUi/Hand/AnimationPlayer.play("interact")
			return
		"holding":
			if(!$GameplayUi/Hand/AnimationPlayer.current_animation == "hold"):
				$GameplayUi/Hand/AnimationPlayer.play("hold")
			return
		_:
			if(!$GameplayUi/Hand/AnimationPlayer.current_animation == "idle"):
				$GameplayUi/Hand/AnimationPlayer.play("idle")
			return

func get_mouse_world_position(camera: Camera3D, plane_y: float) -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, plane_y)
	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		return hit
	return global_position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and summoning:
		summoning = false
		match icup_spawn:
			"shot_glass":
				_spawn_cup(shot_glass, "shot_glass")
			"beer_glass":
				_spawn_cup(beer_glass, "beer_glass")
		icup_spawn = ""
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		summoning = false
		if(in_game):
			gameplay_ui._out_down_minigame()
			_out_of_game()



func _spawn_cup(scene: PackedScene, cup_name: String) -> void:
	var pos := get_mouse_world_position($Camera3D, spawn_y)
	var min_x : float = counter.global_position.x + counter_min_x
	var max_x : float = counter.global_position.x + counter_max_x
	pos.x = clamp(pos.x , min_x, max_x)
	pos.z = max(pos.z, min_z)
	pos += cup_offsets.get(cup_name, Vector3.ZERO)
	var new_instance = scene.instantiate()
	new_instance.scale = spawn_scale
	new_instance._instiate(counter)
	get_parent().add_child(new_instance)
	new_instance.global_position = pos  # set after add_child so it's in world space

func _perfect_pour(drink : Drinks, glass : Glasses) -> void: #minigame Section
	var tween = get_tree().create_tween().set_parallel(true)
	gameplay_ui._in_down_minigame()
	in_game = true
	in_game_drinks["Drink"]["Node"] = drink
	in_game_drinks["Drink"]["position"] = drink.global_position
	in_game_drinks["Drink"]["position"].x = drink.global_position.x + 0.5
	in_game_drinks["Glass"]["Node"] = glass
	in_game_drinks["Glass"]["position"] = glass.global_position
	drink._in_game()
	glass._in_game()
	tween.tween_property(drink,"global_position",$Camera3D/drink_mark.global_position,0.5)
	tween.tween_property(glass,"global_position",$Camera3D/glass_mark.global_position,0.5)
	tween.tween_property(glass,"rotation_degrees:y",0,0.5)

	await tween.finished
	await get_tree().process_frame
	drink.look_at($Camera3D.global_position)
	#glass.look_at($Camera3D.global_position)


func _out_of_game() -> void:
	in_game = false
	var drink = in_game_drinks["Drink"]["Node"]
	var glass = in_game_drinks["Glass"]["Node"]
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(drink,"global_position",in_game_drinks["Drink"]["position"],0.5)
	tween.tween_property(glass,"global_position",in_game_drinks["Glass"]["position"],0.5)
	await tween.finished
	drink._out_of_game()
	glass._out_of_game()

@warning_ignore("unused_parameter")
func _on_shot_glass_button_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		icup_spawn = "shot_glass"
		await get_tree().create_timer(0.2).timeout
		summoning = true

@warning_ignore("unused_parameter")
func _on_beer_glass_button_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		print("working beer")
		icup_spawn = "beer_glass"
		await get_tree().create_timer(0.2).timeout
		summoning = true

func _on_trash_area_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		area._delete()
