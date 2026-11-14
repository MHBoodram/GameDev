extends Processor
class_name Shaker

const SHAKE_SCENE := preload("res://Player/Drink/ShakeMinigame.tscn")

@export var jiggle_strength : float = 0.02 #tweak this for more sway in the minigame

var liquid_stack: Array = []
var _shaking : bool = false
var _jiggle_nodes : Array[Node3D] = []
var _jiggle_home : Dictionary = {}
var _jiggle_tweens : Dictionary = {}

func ready() -> void:
	super.ready()
	add_to_group("shaker")

func can_be_shaken() -> bool:
	return false

func can_interact_with(target: Ingredients) -> bool:
	if not is_instance_valid(target) or in_game:
		return false
	if target is Glasses:
		return target.can_be_shaken()
	return false

func execute_interaction(target: Ingredients) -> void:
	if target is Glasses and can_interact_with(target):
		start_shake(target as Glasses)

func start_shake(glass: Glasses) -> void:
	if _shaking or ShakerMinigame.active:
		return
	if not is_instance_valid(glass) or not glass.can_be_shaken():
		return
	_shaking = true

	_in_game()
	glass._in_game()

	_jiggle_nodes.clear()
	var my_sprite := get_node_or_null("Sprite3D") as Node3D
	if my_sprite:
		_jiggle_nodes.append(my_sprite)
	var glass_sprite: Node3D = glass.sprite
	if glass_sprite == null:
		glass_sprite = glass.get_node_or_null("Inside") as Node3D
	if glass_sprite:
		_jiggle_nodes.append(glass_sprite)
	for n in _jiggle_nodes:
		_jiggle_home[n] = n.global_position

	var mini := SHAKE_SCENE.instantiate() as ShakerMinigame
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(mini)
	mini.pumped.connect(_on_shake_pumped)

	var success: bool = await mini.finished

	_end_jiggle()
	if is_instance_valid(glass):
		if success:
			glass.mark_mixed()
			print("[mixed]: ", glass.get_mixed_ingredients())
		glass._out_of_game()
	_out_of_game()
	_shaking = false

func _on_shake_pumped() -> void:
	for n in _jiggle_nodes:
		if not is_instance_valid(n):
			continue
		var home: Vector3 = _jiggle_home.get(n, n.global_position)
		var old: Tween = _jiggle_tweens.get(n)
		if old:
			old.kill()
		var offset := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * jiggle_strength
		var tween := create_tween()
		_jiggle_tweens[n] = tween
		tween.tween_property(n, "global_position", home + offset, 0.04)
		tween.tween_property(n, "global_position", home, 0.06)


func _end_jiggle() -> void:
	for n in _jiggle_nodes:
		if not is_instance_valid(n):
			continue
		var tween: Tween = _jiggle_tweens.get(n)
		if tween:
			tween.kill()
		n.global_position = _jiggle_home.get(n, n.global_position)
	_jiggle_nodes.clear()
	_jiggle_home.clear()
	_jiggle_tweens.clear()
