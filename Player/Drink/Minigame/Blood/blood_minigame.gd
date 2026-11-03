extends CanvasLayer
@onready var blood_cells_scene = load("res://Player/Drink/Minigame/Blood/blood_cells.tscn")
var blood_cells_obtain : float = 0
var blood_cells_total = 0
#@onready var inside_glass = $Inside
#@onready var outside_glass = $Inside/Outside


func _ready() -> void:
	$AnimationPlayer.play("hurt")
	await $AnimationPlayer.animation_finished
	for i in 10:
		_spawn_blood_drops()
		blood_cells_total += 1
		await get_tree().create_timer(randf_range(0.5,1)).timeout
	#_finish_game()

func _check_all_finished() -> void:
	blood_cells_total -= 1
	if(blood_cells_total <= 0):
		_finish_game()
		GameState.player.gameplay_ui._out_down_minigame()

func _finish_game() -> void:
	GameState.main_node._add_blood(blood_cells_obtain)
	GameState.player.in_game = false
	queue_free()

func _return_blood(blood: float = 0,node_position: Vector2 = Vector2.ZERO) -> void:
	var particle = make_red_particles_2d()
	particle.global_position = node_position
	add_child(particle)
	var tween = create_tween()
	tween.tween_property(particle,"global_position",$Marker2D.global_position,2)
	await tween.finished
	particle.queue_free()
	blood_cells_obtain += blood
	$Label.text = "Total Blood: " + str(blood_cells_obtain)
	
func make_red_particles_2d() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	
	p.emitting = true
	#p.scale = Vector2(5,5)
	p.amount = 15
	p.lifetime = 0.6
	p.direction = Vector2(0, 0)
	#p.spread = 8.0
	#p.initial_velocity_min = 100.0
	#p.initial_velocity_max = 150.0
	#p.gravity = Vector2(0, 400)
	p.scale_amount_min = 15.0
	p.color = Color.RED
	
	return p

func _spawn_blood_drops()-> void:
	var padding := 50.0
	var size := get_viewport().get_visible_rect().size
	var inst = blood_cells_scene.instantiate()
	add_child(inst)
	inst.position = Vector2(
		randf_range(padding, size.x - padding),
		randf_range(padding, size.y - padding)
	)
