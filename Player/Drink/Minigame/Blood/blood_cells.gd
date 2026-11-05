extends Button
var cutted : bool = false

func _ready() -> void:
	var parent = get_parent()
	$Button.scale = Vector2(4,4)
	var tween = get_tree().create_tween()
	tween.tween_property($Button,"scale",Vector2(0.5,0.5),2)
	await tween.finished
	if(!cutted):
		parent._return_nothing()
		parent._check_all_finished()
		queue_free()

func _on_pressed() -> void:
	cutted = true
	disabled =true
	var parent = get_parent()
	#print($Button.scale.x)
	#$AnimatedSprite2D.play("Cut")
	var blood_donation = maxf(0,5 - abs($Button.scale.x - 0.8)*2) #Screw the players
	parent._check_all_finished()
	parent._return_blood(blood_donation,global_position)
	#await $AnimatedSprite2D.animation_finished
	queue_free()
