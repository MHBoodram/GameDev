extends Node2D

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var marker_anchor: Control = $Marker

var num:bool = false
var tarNum:int = randi_range(33,100)
var originalSize:Vector2 = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	update_target_indicator(tarNum)
	$Label.text = str(tarNum)
	originalSize = $ProgressBar.size
	$ProgressBar.value = 0
	print(tarNum)
	pass # Replace with function body.

func update_target_indicator(new_target: int) -> void:
	var target_value = tarNum
	
	var barWidth : int = $ProgressBar.size.x
	
	var targetPixelX: int = remap(
		target_value,
		progress_bar.min_value,
		progress_bar.max_value,
		0,
		barWidth
	)
	marker_anchor.position.x = progress_bar.position.x + targetPixelX
	$ProgressBar/TargetIndicator.global_position.x = marker_anchor.global_position.x
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(num):
		return
	$ProgressBar.value += 1
	
	pass

func _input(event: InputEvent) -> void:
	var MarginofError = 4
	if(event.is_action_pressed("ui_accept")):
		if(tarNum-MarginofError <= $ProgressBar.value and tarNum+MarginofError >= $ProgressBar.value):
			print("target num hit")
		print("Hitted: " + str($ProgressBar.value))

		num = true


func _on_button_pressed() -> void:
	tarNum = randi_range(33,100)
	update_target_indicator(tarNum)
	$Label.text = str(tarNum)
	originalSize = $ProgressBar.size
	$ProgressBar.value = 0
	num = false
