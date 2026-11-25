extends Area3D
var recipt_clicked : bool = true
var recipt_spawned : bool = false
@export var base_npc : Base_NPC

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton && recipt_spawned:
		var tween = get_tree().create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(base_npc.recipt,"global_position", base_npc.recipt_marker.global_position,0.5)
		tween.tween_property(base_npc.recipt,"rotation_degrees:x", 0,0.5)
		recipt_clicked = !recipt_clicked
	
func interact():
	if(recipt_clicked):
		var tween = get_tree().create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(base_npc.recipt,"global_position", base_npc.camera.global_position - Vector3(0,0.2,0.8),0.5)
		tween.tween_property(base_npc.recipt,"rotation_degrees:x", 90,0.5)
	else:
		var tween = get_tree().create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(base_npc.recipt,"global_position", base_npc.recipt_marker.global_position,0.5)
		tween.tween_property(base_npc.recipt,"rotation_degrees:x", 0,0.5)
	recipt_clicked = !recipt_clicked
