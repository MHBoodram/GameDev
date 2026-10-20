extends Ingredients

@onready var recipt_2d = get_node_or_null("Base_viewport/SubViewport/Recipt")
@export var recipt_marker : Marker3D
@export var seat_num : int = 1
var ordered : bool = false

func ready() -> void:
	base_y_position = 1.6

func _process(delta: float) -> void:
	super._process(delta)
	if not is_balls_dragging and ordered and recipt_marker:
		if global_position.distance_to(recipt_marker.global_position) > 0.01:
			var tween = get_tree().create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "global_position", recipt_marker.global_position, 0.3)

func _moving_to(to: Marker3D) -> void:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", to.global_position, 0.5)

func _write(words: String) -> void:
	if recipt_2d:
		recipt_2d._label_change(words)

func can_interact_with(target: Ingredients) -> bool:
	return ordered and target is Glasses and not (target is Drinks)

func execute_interaction(target: Ingredients) -> void:
	if can_interact_with(target):
		ordered = false
		target.set_highlight(false)
		if target is Glasses:
			target.is_being_served = true
		get_parent()._give_drink(self, target, seat_num)

func on_drop_failed() -> void:
	if ordered and recipt_marker:
		var tween = get_tree().create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "global_position", recipt_marker.global_position, 0.4)