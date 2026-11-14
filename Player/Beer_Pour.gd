extends Area3D
@onready var keg_sprite = get_node("CHUGCHUGBEER")
@onready var keg_water_particle = get_node("CPUParticles3D")
@onready var pour_zone = get_node("PourArea/PourZone")
#var in_pour_zone : Area3D
@onready var snap_point: Node3D = get_node_or_null("PourArea/SnapPoint")

@export_group("Glass Snapping")
@export var snap_pull_speed: float = 22.0
@export var snap_release_speed: float = 16.0
@export var snap_break_distance: float = 0.35

const IDLE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HOVER_COLOR := Color(1.0, 0.0, 0.0, 0.9)
const LOCKED_COLOR := Color(0.3, 1.0, 0.3, .9)

var in_pour_zone: Glasses = null
var _glasses_in_area: Array[Glasses] = []

func _snap_target() -> Node3D:
	return snap_point if snap_point else pour_zone

@warning_ignore("unused_parameter")
func _on_beer_keg_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		#var glass_array : Array = []
		keg_sprite.rotation_degrees.x = -64.5
		#var areas = $Coutner/PourArea.get_overlapping_areas()
		keg_water_particle.emitting = true
		while(Input.get_action_strength("Left_click")):

			#for x in areas:
				#print(x.is_in_group("glass"))
				#if(x.is_in_group("glass")):
					#glass_array.append(x)
			if(in_pour_zone):
				in_pour_zone._pouring("beer", 0.25)
			#for glasses in glass_array:
				#glasses.get_parent()._pouring("beer", 0.05)
			await get_tree().create_timer(0.1).timeout
		keg_sprite.rotation_degrees.x = -131.5
		keg_water_particle.emitting = false

func _process(_delta: float) -> void:
	if in_pour_zone and is_instance_valid(in_pour_zone):
		pour_zone.modulate = LOCKED_COLOR if in_pour_zone.is_snapped() else HOVER_COLOR
	else:
		pour_zone.modulate = IDLE_COLOR

func _on_pour_area_area_entered(area: Area3D) -> void:
	#if(area.is_in_group("glass") && !in_pour_zone):
		#var temp_global_position = Vector3($PourArea/CollisionShape3D.global_position.x,area.global_position.y,$PourArea/CollisionShape3D.global_position.z)
		#area.global_position = temp_global_position
		#in_pour_zone = area
		#pour_zone.modulate = Color(1, 0, 0)
	if not (area is Glasses) or not area.is_in_group("glass"):
		return
	if not _glasses_in_area.has(area):
		_glasses_in_area.append(area)
	if not in_pour_zone:
		_set_active_glass(area)


func _on_pour_area_area_exited(area: Area3D) -> void:
	#if(area == in_pour_zone):
		#area._remove_displaying_list()
		#in_pour_zone = null
		#pour_zone.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_glasses_in_area.erase(area)
	if area == in_pour_zone:
		if is_instance_valid(area):
			area.exit_snap_zone(_snap_target())
			area._remove_displaying_list()
		in_pour_zone = null
		for g in _glasses_in_area:
			if is_instance_valid(g):
				_set_active_glass(g)
				break

func _set_active_glass(glass: Glasses) -> void:
	in_pour_zone = glass
	glass.enter_snap_zone(_snap_target(), snap_pull_speed, snap_release_speed, snap_break_distance)
