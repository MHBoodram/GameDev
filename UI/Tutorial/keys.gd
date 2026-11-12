extends Panel
var up_tutorial = false
var down_tutorial = false
var left_tutorial = false
var right_tutorial = false

func _ready() -> void:
	$AnimationPlayer.play("new_animation")
	await $AnimationPlayer.animation_finished
	#set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("Up"):
			$Panel/up.modulate = Color(0.0, 1.0, 0.0, 1.0)
			up_tutorial = true
		if event.is_action_pressed("Down"):
			$Panel3/down.modulate = Color(0.0, 1.0, 0.0, 1.0)
			down_tutorial = true
		elif event.is_action_pressed("Left"):
			$Panel2/left.modulate = Color(0.0, 1.0, 0.0, 1.0)
			left_tutorial = true
		elif event.is_action_pressed("Right"):
			$Panel4/right.modulate = Color(0.0, 1.0, 0.0, 1.0)
			right_tutorial = true

func _bye_bye() -> void:
	$AnimationPlayer.play_backwards("new_animation")
	await $AnimationPlayer.animation_finished
	queue_free()

func _tutorial_finished() -> bool:
	if(right_tutorial and left_tutorial and up_tutorial and down_tutorial):
		return true
	return false
