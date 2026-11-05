extends Ingredients
class_name Processor

var in_game: bool = false
@export var area_body: CollisionShape3D

func ready() -> void:
	super.ready()
	if area_body == null:
		area_body = get_node_or_null("CollisionShape3D")

func _in_game() -> void:
	in_game = true
	if area_body:
		area_body.disabled = true

func _out_of_game() -> void:
	in_game = false
	if area_body:
		area_body.disabled = false

func _on_hover(hovered: bool) -> void:
	set_highlight(hovered)

func can_interact_with(target: Ingredients) -> bool:
	if not is_instance_valid(target) or in_game:
		return false
	if target is Glasses:
		return target.can_be_shaken()
	return false

func execute_interaction(target: Ingredients) -> void:
	if target is Glasses and can_interact_with(target):
		start_shake(target as Glasses)

func start_shake(_glass: Glasses) -> void:
	pass