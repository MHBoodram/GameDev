extends CanvasLayer

func _ready() -> void:
	ToolController.align_hand_hotspot($AnimatedSprite2D)

func _process(_delta: float) -> void:
	$AnimatedSprite2D.global_position = get_viewport().get_mouse_position()

func _update_hand(change: String) -> void:
	var target_anim := "Interact" if change == "interact" else "Idle"
	if $AnimatedSprite2D.animation != target_anim or not $AnimatedSprite2D.is_playing():
		$AnimatedSprite2D.play(target_anim)