extends CanvasLayer
var scene_going : String = ""
var progress : Array = []
#
#func _unhandled_input(event: InputEvent) -> void:
	#if(event.is_action("Left_click")):
		#_changing_scene()
	#if(event.is_action("ui_accept")):
		#_got_to_scene()
func _process(delta: float) -> void:
	var status = ResourceLoader.load_threaded_get_status(scene_going,progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			print("Loading: ",progress[0] * 100,"%")
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			var new_scene = ResourceLoader.load_threaded_get(scene_going)
			get_tree().change_scene_to_packed(new_scene)
			_got_to_scene()

func _changing_scene(scene_to):
	scene_going = scene_to
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var gradient : Gradient = ($ColorRect.texture as GradientTexture2D).gradient
	tween.tween_method(func(v): gradient.set_offset(1,v),gradient.get_offset(1),1,0.75)
	await tween.finished
	ResourceLoader.load_threaded_request(scene_going)
	set_process(true)

func _got_to_scene():
	await get_tree().create_timer(0.3).timeout
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var gradient : Gradient = ($ColorRect.texture as GradientTexture2D).gradient
	tween.tween_method(func(v): gradient.set_offset(1,v),gradient.get_offset(1),0,0.75)
