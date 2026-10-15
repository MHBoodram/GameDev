extends Ingredients
class_name Glasses
@export var liquids : Array = []
@export var size : float = 1.0
@export var area_body : CollisionShape3D
@export var sprite : Sprite3D
var total_liquids : float = 0
var current_position = 0
var base_y_position = 1.6
var in_game: bool = false
const LIQUID_COLOR = {
	"gin" : Color(0.0, 0.953, 0.0, 1.0),
	"beer" : Color(0.98, 0.322, 0.051, 1.0),
	"spirit" : Color(0.542, 0.691, 1.0, 1.0),
	"vodka" : Color(0.137, 0.372, 1.0, 1.0),
	"rum" : Color(0.458, 0.154, 0.014, 1.0)
}

func ready() -> void:
	_look_at_sprite(camera.global_position)

func _delete():
	queue_free()

@export var dead_zone := 50.0      # pixels of mismatch allowed before correcting
@export var full_pull := 150.0     # pixels past the dead zone where the hand is fully on the glass

@export var max_hand_distance := 20.0   # max pixels the cursor can be from the glass

func _update_hand_position(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var glass_screen := camera.unproject_position(global_position)

	# Hard clamp: the cursor can't get farther than this from the glass
	var offset := mouse - glass_screen
	if offset.length() > max_hand_distance:
		mouse = glass_screen + offset.limit_length(max_hand_distance)
		get_viewport().warp_mouse(mouse)   # also pull the real mouse back (remove this line to only clamp the hand)

	var gap := mouse.x - glass_screen.x
	var excess := maxf(absf(gap) - dead_zone, 0.0)
	var pull := clampf(excess / full_pull, 0.0, 1.0)

	var goal := mouse.lerp(glass_screen, pull)
	var hand = GameState.player.hand_sprite
	hand.global_position = hand.global_position.lerp(goal, 1.0 - exp(-30.0 * delta))

func _get_drag_point(mouse_pos: Vector2, plane_y: float) -> Variant:
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	return Plane(Vector3.UP, plane_y).intersects_ray(from, dir)   # null if no hit

func _clamp_to_counter(p: Vector3) -> Vector3:
	p.x = clamp(p.x, counter_origin.global_position.x - 1.2, counter_origin.global_position.x + 1.4)
	p.z = clamp(p.z, counter_origin.global_position.z - 0.4, counter_origin.global_position.z + 0.4)
	return p

func _process(_delta: float) -> void:
	if not is_balls_dragging:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	#GameState.player._force_cursor_image(global_position)
	# First pass: resting height
	var hit = _get_drag_point(mouse_pos, base_y_position)
	if hit == null:
		return
	var p := _clamp_to_counter(hit)

	# Near the front of the counter the object is lifted, so re-project onto the lifted plane
	if p.z < 0.28:
		hit = _get_drag_point(mouse_pos, base_y_position + 0.2)
		if hit != null:
			p = _clamp_to_counter(hit)
			p.y = base_y_position + 0.2

	global_position = p
	_look_at_sprite(camera.global_position)

	if Input.is_action_just_released("Left_click"):
		GameState.player._update_hand("idle")
		is_balls_dragging = false
	_update_hand_position(_delta)

func _look_at_sprite(looking_at: Vector3) -> void:
	if(looking_at && sprite):
		sprite.look_at(looking_at)

func _pouring(id : String, liquids_num : float) -> void:
	if(len(liquids) != 0):
		var top_drink = liquids[len(liquids)-1]
		if(top_drink[0] == id):
			top_drink[1] += liquids_num
			_visuals_change(liquids_num,id,false)
		else:
			var temp_liquid = [id,liquids_num]
			liquids.push_back(temp_liquid)
			_visuals_change(liquids_num,id,true)
	else:
		var temp_liquid = [id,liquids_num]
		liquids.push_back(temp_liquid)
		_visuals_change(liquids_num,id,true)

func _pushing_glass(other_glass : Area3D) -> void:
	var push_dir = (global_position - other_glass.global_position)
	push_dir.y = 0
	if push_dir.length() < 0.001:
		push_dir = Vector3(1, 0, 0)
	push_dir = push_dir.normalized()
	var push_strength = 0.03
	global_position += push_dir * push_strength
	_look_at_sprite(camera.global_position)

func _in_game():
	in_game = true
	area_body.disabled = true

func _out_of_game():
	in_game = false
	area_body.disabled = false

func _visuals_change(liquids_num: float,liquid_name: String,new: bool) -> void:
	print(liquids_num)

func _dranked() -> void:
	queue_free()

func _return_drink() -> Array:
	return liquids
