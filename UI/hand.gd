extends CanvasLayer

func _process(delta: float) -> void:
	$AnimatedSprite2D.global_position = get_viewport().get_mouse_position()

func _update_hand(change: String) -> void:
	match change:
		"interact":
			if($AnimatedSprite2D.animation == "Interact"):
				$Node2D/Setting/Hand/AnimationPlayer.play("interact")
			return
		_:
			if(!$Node2D/Setting/Hand/AnimationPlayer.current_animation == "idle"):
				$Node2D/Setting/Hand/AnimationPlayer.play("idle")
			return
