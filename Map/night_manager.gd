class_name NightManager
extends Node

signal shift_started
signal shift_ended
signal night_concluded

@export var dusk_start_seconds: float = 0.0
@export var dusk_end_seconds: float = 60.0
@export var night_hdri_energy: float = 0.025
@export var night_sun_pitch_degrees: float = 45.0
@export var night_fog_albedo: Color = Color(0.04, 0.06, 0.12, 1.0)

var night_timer: Timer
var world_environment: WorldEnvironment
var sun: DirectionalLight3D

var initial_sun_transform: Transform3D
var initial_sun_energy: float = 1.5
var initial_hdri_energy: float = 0.5
var initial_fog_albedo: Color = Color(0.984, 0.741, 0.0, 1.0)
var sky_material: PanoramaSkyMaterial

var is_shift_active: bool = false
var is_shift_ended: bool = false
var is_night_concluded: bool = false

func setup(timer_node: Timer, env_node: WorldEnvironment, sun_node: DirectionalLight3D) -> void:
	night_timer = timer_node
	world_environment = env_node
	sun = sun_node
	is_shift_active = false
	is_shift_ended = false
	is_night_concluded = false
	_setup_lighting()
	if night_timer and not night_timer.timeout.is_connected(_on_night_timer_timeout):
		night_timer.timeout.connect(_on_night_timer_timeout)
	if not shift_started.is_connected(_on_shift_started_internal):
		shift_started.connect(_on_shift_started_internal)
	if not shift_ended.is_connected(_on_shift_ended_internal):
		shift_ended.connect(_on_shift_ended_internal)

func _process(_delta: float) -> void:
	if is_shift_active and night_timer and GameState.gameplay_ui:
		GameState.gameplay_ui._change_time(night_timer.time_left)
	update_day_night_cycle()

func _setup_lighting() -> void:
	if sun:
		initial_sun_transform = sun.transform
		initial_sun_energy = sun.light_energy
	if world_environment and world_environment.environment:
		world_environment.environment = world_environment.environment.duplicate()
		world_environment.set_meta("original_env", world_environment.environment)
		initial_fog_albedo = world_environment.environment.volumetric_fog_albedo
		if world_environment.environment.sky:
			world_environment.environment.sky = world_environment.environment.sky.duplicate()
			var mat = world_environment.environment.sky.sky_material
			if mat is PanoramaSkyMaterial:
				sky_material = mat.duplicate()
				world_environment.environment.sky.sky_material = sky_material
				initial_hdri_energy = sky_material.energy_multiplier

func setup_night_shift(main_root: Node3D) -> void:
	if GameState.gameplay_ui:
		GameState.gameplay_ui.set_shift_hud_visible(false)
	_configure_night_story(main_root)
	if not GameState.special_state and not GameState.night_paused:
		start_night_shift()

func start_night_shift() -> void:
	var active_quota := GameState.get_night_quota(GameState.night)
	start_shift(GameState.night_duration, active_quota)

func _configure_night_story(main_root: Node3D) -> void:
	match GameState.night:
		1:
			if GameState.seat_manager:
				GameState.seat_manager.spawn_customer("res://NPC/Resources/shark.tres", 180.0, "tutorial_walk")
			GameState.special_state = true
			GameState.pause_night()
			if GameState.gameplay_ui and GameState.gameplay_ui.has_method("start_tutorial"):
				GameState.gameplay_ui.start_tutorial(main_root.get_node_or_null("Keys"))
		2:
			_clean_tutorial_keys(main_root)
			if GameState.seat_manager:
				GameState.seat_manager.spawn_customer("res://NPC/Resources/shark.tres", 180.0, "night_2_introduction")
			GameState.special_state = true
			GameState.pause_night()
		_:
			_clean_tutorial_keys(main_root)
			GameState.special_state = false
			GameState.night_paused = false

func _clean_tutorial_keys(main_root: Node3D) -> void:
	if not is_instance_valid(main_root):
		return
	var keys_node := main_root.get_node_or_null("Keys")
	if keys_node:
		keys_node.queue_free()

func start_shift(duration: float, quota: float) -> void:
	is_shift_active = true
	is_shift_ended = false
	is_night_concluded = false
	GameState.night_paused = false
	GameState.special_state = false
	if GameState.gameplay_ui:
		GameState.gameplay_ui.set_shift_hud_visible(true)
		GameState.gameplay_ui._update_quota(quota)
		GameState.gameplay_ui._update_night_display(GameState.night)
		GameState.gameplay_ui._night_title_popup()
	if night_timer:
		night_timer.wait_time = duration
		night_timer.start()
	shift_started.emit()

func pause_shift() -> void:
	GameState.night_paused = true
	if night_timer and not night_timer.is_stopped():
		night_timer.paused = true

func resume_shift() -> void:
	GameState.night_paused = false
	if night_timer:
		if night_timer.is_stopped():
			night_timer.start()
		else:
			night_timer.paused = false

func end_shift() -> void:
	is_shift_active = false
	is_shift_ended = true
	if night_timer and not night_timer.is_stopped():
		night_timer.stop()
	shift_ended.emit()

# interpolates sun across the shift
func update_day_night_cycle() -> void:
	if not night_timer or night_timer.is_stopped() or night_timer.paused or not sun:
		return
	var elapsed := night_timer.wait_time - night_timer.time_left
	var raw_progress := (elapsed - dusk_start_seconds) / maxf(dusk_end_seconds - dusk_start_seconds, 0.001)
	var smooth_weight := smoothstep(0.0, 1.0, clampf(raw_progress, 0.0, 1.0))

	# rotate sun downward and fade out sunlight
	var pitch_offset := Basis(Vector3.RIGHT, deg_to_rad(night_sun_pitch_degrees * smooth_weight))
	sun.transform.basis = initial_sun_transform.basis * pitch_offset
	sun.light_energy = lerpf(initial_sun_energy, 0.0, smooth_weight)
	sun.visible = sun.light_energy > 0.001

	if sky_material:
		sky_material.energy_multiplier = lerpf(initial_hdri_energy, night_hdri_energy, smooth_weight)
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_albedo = initial_fog_albedo.lerp(night_fog_albedo, smooth_weight)

func _on_night_timer_timeout() -> void:
	is_shift_active = false
	is_shift_ended = true
	shift_ended.emit()

func _on_shift_started_internal() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.start_spawning()

func _on_shift_ended_internal() -> void:
	if GameState.seat_manager:
		GameState.seat_manager.stop_spawning()
		check_night_concluded(GameState.seat_manager.is_completely_empty())

# triggers night transition once shift timer ends and all seats are completely cleared
func check_night_concluded(all_seats_empty: bool) -> void:
	if not is_shift_ended or not all_seats_empty or not GameState.can_end_night or GameState.night_paused or is_night_concluded:
		return
	is_night_concluded = true
	night_concluded.emit()
	conclude_night()

func conclude_night() -> void:
	if is_instance_valid(GameState.main_node):
		var anim: AnimationPlayer = GameState.main_node.get_node_or_null("AnimationPlayer")
		if anim:
			anim.play_backwards("opening")
		var bar_setting = GameState.main_node.get_node_or_null("BarSetting")
		if bar_setting and bar_setting.has_method("_spotlight_dim"):
			bar_setting._spotlight_dim()
		var counter_spot = GameState.main_node.get_node_or_null("Coutner/SpotLight3D")
		if counter_spot and is_inside_tree():
			var tween := create_tween()
			tween.tween_property(counter_spot, "light_energy", 0.0, 0.5)

	if is_inside_tree():
		await get_tree().create_timer(1.5).timeout
	Transition._changing_scene("res://UI/After_night/afternight.tscn")
