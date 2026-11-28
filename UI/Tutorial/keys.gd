extends Panel

signal tutorial_completed

var up_tutorial: bool = false
var down_tutorial: bool = false
var left_tutorial: bool = false
var right_tutorial: bool = false
var _is_finishing: bool = false

func _ready() -> void:
	_apply_ink_paper_theme()
	if visible:
		popup()

func _apply_ink_paper_theme() -> void:
	InkTheme.apply_panel_variant(self, "cream", false, Vector4(8.0, 8.0, 8.0, 8.0))
	for keycap in [$Panel, $Panel2, $Panel3, $Panel4]:
		if is_instance_valid(keycap):
			InkTheme.apply_panel_variant(keycap, "paper", true, Vector4(4.0, 4.0, 4.0, 4.0))
	for caption in [$Panel/Label2, $Panel2/Label2, $Panel3/Label2, $Panel4/Label2]:
		if is_instance_valid(caption):
			caption.add_theme_color_override("font_color", InkTheme.INK_DARK)
			caption.add_theme_constant_override("outline_size", 0)
	for key_lbl in [$Panel/up/Label, $Panel2/left/Label, $Panel3/down/Label, $Panel4/right/Label]:
		if is_instance_valid(key_lbl):
			key_lbl.add_theme_color_override("font_color", Color.WHITE)
			key_lbl.add_theme_color_override("font_outline_color", InkTheme.INK_DARK)
			key_lbl.add_theme_constant_override("outline_size", 6)

func popup() -> void:
	show()
	_is_finishing = false
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("new_animation")
	#set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)

func _input(event: InputEvent) -> void:
	if not visible or _is_finishing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("Up"):
			$Panel/up.modulate = Color(0.0, 1.0, 0.0, 1.0)
			up_tutorial = true
		if event.is_action_pressed("Down"):
			$Panel3/down.modulate = Color(0.0, 1.0, 0.0, 1.0)
			down_tutorial = true
		if event.is_action_pressed("Left"):
			$Panel2/left.modulate = Color(0.0, 1.0, 0.0, 1.0)
			left_tutorial = true
		if event.is_action_pressed("Right"):
			$Panel4/right.modulate = Color(0.0, 1.0, 0.0, 1.0)
			right_tutorial = true

		if _tutorial_finished() and not _is_finishing:
			_is_finishing = true
			_finish_tutorial()

func _finish_tutorial() -> void:
	await get_tree().create_timer(0.35).timeout
	tutorial_completed.emit()
	_bye_bye()

func _bye_bye() -> void:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play_backwards("new_animation")
		await $AnimationPlayer.animation_finished
	queue_free()

func _tutorial_finished() -> bool:
	return right_tutorial and left_tutorial and up_tutorial and down_tutorial