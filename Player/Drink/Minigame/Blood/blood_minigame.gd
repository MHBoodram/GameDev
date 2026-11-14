extends CanvasLayer
@onready var blood_cells_scene = load("res://Player/Drink/Minigame/Blood/blood_cells.tscn")
var blood_cells_obtain : float = 0
var blood_cells_total = 0
#@onready var inside_glass = $Inside
#@onready var outside_glass = $Inside/Outside


func _ready() -> void:
	SFXAudio.play_draw()
	$AnimationPlayer.play("hurt")
	await $AnimationPlayer.animation_finished
	for i in 10:
		_spawn_blood_drops()
		blood_cells_total += 1
		await get_tree().create_timer(randf_range(0.5,1)).timeout
	#_finish_game()

func _check_all_finished() -> void:
	#blood_cells_total -= 1
	if(blood_cells_total <= 0):
		_finish_game()
		if(GameState.player):
			GameState.player.gameplay_ui._out_down_minigame()

func _finish_game() -> void:
	if(GameState.main_node):
		$AnimationPlayer.play_backwards("hurt")
		await $AnimationPlayer.animation_finished
		GameState.main_node._add_blood(blood_cells_obtain)
		GameState.player.in_game = false
		
		queue_free()

func _return_nothing() -> void:
	blood_cells_total -= 1
	_check_all_finished()

func _return_blood(blood: float = 0,node_position: Vector2 = Vector2.ZERO) -> void:
	blood_cells_total -= 1
	var explosion = make_red_particles_2d_explsion()
	var particle = make_red_particles_2d()
	explosion.global_position = node_position
	particle.global_position = node_position
	add_child(explosion)
	add_child(particle)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(particle, "global_position", $Marker2D.global_position, 1.0)
	
	await tween.finished  # only if you need to do something after the whole sequence
	particle.queue_free()
	var shake_intensity = blood * 2
	var second_tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	second_tween.tween_property($Sprite2D, "rotation_degrees", shake_intensity, 0.1)
	second_tween.tween_property($Sprite2D, "rotation_degrees", -shake_intensity, 0.1)
	second_tween.tween_property($Sprite2D, "rotation_degrees", 0, 0.1)
	blood_cells_obtain += blood
	set_fill(blood_cells_obtain/100)
	$Label.text = "Total Blood: " + str(blood_cells_obtain)
	_check_all_finished()

var phase := 0.0

func _process(delta):
	phase += delta * 2.0
	var mat := $Sprite2D/Sprite2D.material as ShaderMaterial as ShaderMaterial
	mat.set_shader_parameter("wave_phase", phase)
	mat.set_shader_parameter("wave_amplitude", 0.01)

func set_fill(value: float):
	($Sprite2D/Sprite2D.material as ShaderMaterial).set_shader_parameter("fill_amount", value)

func make_red_particles_2d_explsion() -> CPUParticles2D:
	SFXAudio.play_stab()
	var p := CPUParticles2D.new()
	p.texture = make_tear_texture(16, 24)
	p.emitting = true
	p.amount = 15
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0

	# Burst outward in all directions
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 400)

	# Rotate each drop so it points along its movement
	p.particle_flag_align_y = true

	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	p.color = Color.RED

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp

	p.finished.connect(p.queue_free)
	return p

func make_tear_texture(w: int = 16, h: int = 24) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var r := w * 0.5 - 1.0        # radius of the round bottom
	var cx := w * 0.5 - 0.5       # horizontal center
	var cy := h - r - 1.0         # center of the round part
	for y in h:
		for x in w:
			var half: float
			if y < cy:
				# Tapered top: width grows from 0 at the tip to r
				half = r * pow(y / cy, 1.5)
			else:
				# Round bottom
				var dy := y - cy
				half = sqrt(maxf(r * r - dy * dy, 0.0))
			if absf(x - cx) <= half:
				img.set_pixel(x, y, Color.WHITE)

	return ImageTexture.create_from_image(img)

func make_red_particles_2d() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = make_circle_texture(32)
	p.emitting = true
	p.amount = 25
	p.lifetime = 0.6
	p.gravity = Vector2(0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.5
	# Fade from opaque red to transparent red over each particle's life
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0, 0, 1))
	ramp.set_color(1, Color(1, 0, 0, 0))
	p.color_ramp = ramp
	return p

func make_circle_texture(diameter: int = 32) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.set_offset(0, 0.9)  # solid until 90% of the radius, then a thin fade
	gradient.set_offset(1, 1.0)

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = diameter
	tex.height = diameter
	return tex

@export var min_distance := 150.0 
const MAX_ATTEMPTS := 50

func _spawn_blood_drops() -> void:
	var padding := 300.0
	var size := get_viewport().get_visible_rect().size
	var pos := Vector2.ZERO
	var found := false
	for i in MAX_ATTEMPTS:
		pos = Vector2(
			randf_range(padding, size.x - padding),
			randf_range(padding, size.y - padding)
		)
		if _is_position_free(pos):
			found = true
			break
	if not found:
		return  
	var inst = blood_cells_scene.instantiate()
	add_child(inst)
	inst.position = pos
	inst.add_to_group("blood_buttons")


func _is_position_free(pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("blood_buttons"):
		if node.position.distance_to(pos) < min_distance:
			return false
	return true
