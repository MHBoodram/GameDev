extends Node3D

@onready var player: Node3D = $Player
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $WorldEnvironment/Sun
@onready var night_timer: Timer = $Night_Time
@onready var counter: Node3D = $Coutner

func _ready() -> void:
	GameState.register_subsystems(self, player, night_timer, world_environment, sun, counter)
	$Viewport.modulate.a = 0
	await get_tree().create_timer(0.5).timeout
	$new_bar._open_light()
	var tween = get_tree().create_tween()
	tween.tween_property($Viewport,"modulate:a",1,0)

func _check_money() -> void:
	#$Player/Secondary.current = true
	$AnimationPlayer.play("check_money")
	await $Viewport/SubViewport/AfterNightMenu._display_recipt()
	#$Player/Secondary.current = true
	#$Player/Camera3D.current = false
	
func _open_light():
	await $new_bar._open_light()

func _close_light_bar():
	var tween = get_tree().create_tween()
	tween.tween_property($Viewport,"modulate:a",0,0)
	await $new_bar._close_light()

func _setup_shop_scene() -> void:
	$AnimationPlayer.play_backwards("check_money")
	await _close_light_bar()
	$AfternightNpc.queue_free()
	$ShopKeeper.show()
	$new_bar._setup_shop_scene()
	$Player.in_shop = true
	_open_light()
	

func _reset_night():
	if GameState.use_restart():
		PlayerStats.reset_night_reputation_gains()
		get_tree().change_scene_to_file("res://Main3D.tscn")

func _finished_night():
	GameState.advance_night()
	PlayerStats.reset_night_reputation_gains()
	Transition._changing_scene("res://Main3D.tscn")
