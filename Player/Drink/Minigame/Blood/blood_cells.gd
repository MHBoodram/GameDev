extends Button

func _ready() -> void:
	var parent = get_parent()
	$Button.scale = Vector2(4,4)
	var tween = get_tree().create_tween()
	tween.tween_property($Button,"scale",Vector2(0.5,0.5),2)
	await tween.finished
	parent._check_all_finished()
	queue_free()

func _on_pressed() -> void:
	var parent = get_parent()
	#print($Button.scale.x)
	var blood_donation = maxf(0,5 - abs($Button.scale.x - 0.8)*2) #Screw the players
	parent._check_all_finished()

	parent._return_blood(blood_donation,global_position)
	queue_free()
