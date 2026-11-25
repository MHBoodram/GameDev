extends Area3D
@onready var sprite = $Sprite3D
var parent_node : Node3D
var id: String = ""
var type: String = ""
var cost: int = 0

func setup(parent : Node3D,_id: String,_type: String,_Cost: int = 0) -> void:
	print("ID: ",_id)
	print("Type: ",_type)
	print("Cost: ",_Cost)
	parent_node = parent
	self.id = _id
	self.type = _type
	self.cost = _Cost
	if(type == "Ingredients"):
		$Sprite3D.texture = load("res://Assets/Items/Ingreidents/" +id+".png")
	elif(type == "Drinks"):
		$Sprite3D.texture = load("res://Assets/Items/Drinks/"+str(id)+".png")
	elif(type == "Upgrades"):
		$Sprite3D.texture = load("res://Assets/Upgrades/" +str(id)+".png")
	if(cost!=0):
		$Label3D.text = str(id) + "\nCost: " + str(cost)
	else:
		$Label3D.text = str(id)

func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if cost <= PlayerStats.money:
			_disable()
			remove_from_group("Choice")  # main won't process or free us

			PlayerStats._change_money(PlayerStats.money - cost)
			PlayerStats.unlocks[type][id] = true
			if type == "Ingredients":
				SpeciesRegistry.on_ingredient_unlocked(id, PlayerStats)
			if(type == "Upgrades"):
				pass
				if(PlayerStats.unlock_passive.has(id)):
					PlayerStats.unlocks[type][id] = false
					#print(PlayerStats.unlock_passive[id])
					PlayerStats.unlock_passive[id] = PlayerStats.unlock_passive[id] + 1


			var player_camera_pos = GameState.player.camera_rig.global_position
			player_camera_pos.z += 3

			var tween = create_tween()  # bound to this node
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "global_position", player_camera_pos, 0.25)
			tween.finished.connect(queue_free)  # free only after the animation

			parent_node._go_next()
		else:
			deny()
		#queue_free()
	
var _base_offset: Vector2
var _tween: Tween
@export var deny_shake_strength := 8.0   # pixels (Sprite3D offset units)
@export var deny_shake_duration := 0.35
@export var deny_shake_count := 4.0      # number of left-right wiggles
@export var deny_flash_color := Color(3.0, 0.3, 0.3)

func deny() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	$Sprite3D.offset = _base_offset

	$Sprite3D.modulate = deny_flash_color
	_tween = create_tween().set_parallel(true)
	_tween.tween_property($Sprite3D, "modulate", Color.WHITE, deny_shake_duration)
	_tween.tween_method(_apply_deny_shake, 0.0, 1.0, deny_shake_duration)
	_tween.chain().tween_callback(func(): $Sprite3D.offset = _base_offset)

func _apply_deny_shake(t: float) -> void:
	# Sine wave left/right that fades out over time
	var wave := sin(t * deny_shake_count * TAU)
	var decay := 1.0 - t
	$Sprite3D.offset = _base_offset + Vector2(wave * deny_shake_strength * decay, 0)

func _disable():
	$CollisionShape3D.disabled = true

func _on_mouse_entered() -> void:
	$OmniLight3D.light_energy = 0.25

func _on_mouse_exited() -> void:
	$OmniLight3D.light_energy = 0