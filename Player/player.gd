extends Node3D
@onready var shot_glass = preload("res://Player/Drink/Glasses/shot_cup.tscn")
@onready var beer_glass = preload("res://Player/Drink/Glasses/beer_cup.tscn")
@onready var counter = get_node("Coutner/Lower_counter")
var summoning : bool = false
var icup_spawn : String = "shot_glass"
var in_pour_zone : Area3D
#default camera pos = 0.22, 2.77, 1.56
#default camera rotation = -16.3, 0.0, 0.0

@export var counter_min_x: float = -1.0   
@export var counter_max_x: float = 1.184  
@export var min_z: float = 0.28
@export var spawn_y: float = 1.2
@export var spawn_scale: Vector3 = Vector3(0.2, 0.2, 0.2)
var cup_offsets := {
	"shot_glass": Vector3(0, 0, 0),
	"beer_glass": Vector3(0, 0, 0),
}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	add_child(new_instance)
	new_instance.global_position = pos  # set after add_child so it's in world space

func _summon_beer():
	icup_spawn = "beer_glass"
	await get_tree().create_timer(0.2).timeout
	summoning = true
	
func _summon_shotglass():
	icup_spawn = "shot_glass"
	await get_tree().create_timer(0.2).timeout
	summoning = true

@warning_ignore("unused_parameter")
func _on_shot_glass_button_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		icup_spawn = "shot_glass"
		await get_tree().create_timer(0.2).timeout
		summoning = true

@warning_ignore("unused_parameter")
func _on_beer_glass_button_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		icup_spawn = "beer_glass"
		await get_tree().create_timer(0.2).timeout
		summoning = true
		
func _on_trash_area_entered(area: Area3D) -> void:
	if(area.is_in_group("glass")):
		area.get_parent()._delete()
