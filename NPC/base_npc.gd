extends Sprite3D
@export var npc_resource : NPC
enum State { SEAT, SIT, EXIT }
var current_state : State = State.SEAT
var camera = null
func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	self.texture = npc_resource.sprite_sheet
	_tween_bounce()


func _moving_to(to: Marker3D) -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"position",to.position,0.8)
	current_state = State.SIT

#Sprite Checking
#func _process(delta: float) -> void:
	#if !camera:
		#return
	#
	#var cam_pos = -(global_position - camera.global_position)
	#var foward = global_transform.basis.z
	#
	#var angle = foward.signed_angle_to(cam_pos, Vector3.UP)
	#
	#if !(angle > PI/6 && angle < 5*PI/6) :
		#if $AnimationPlayer.current_animation != "1":
			#$AnimationPlayer.play("1")
	#else:
		#if $AnimationPlayer.current_animation != "2":
			#$AnimationPlayer.play("2")

func _tween_bounce() -> void:
	var tween = get_tree().create_tween()
	var rand_time = randf_range(0.503,0.505)
	tween.tween_property(self, "scale", Vector3(0.505,rand_time,0.5), 0.5)
	#await tween.finished
	#tween.stop()
	tween.tween_property(self, "scale", Vector3(0.5,0.5,0.5), 0.4)
	await tween.finished
	await get_tree().create_timer(0.1).timeout
	_tween_bounce()
