extends Control

@onready var timer : ProgressBar = get_node("HBoxContainer/Timer")
@onready var patience_face : Sprite2D = get_node("HBoxContainer/Patience_Face")
@onready var race_face : Sprite2D = get_node("HBoxContainer/Race_Face")

func _setup(max_value: float, type: String) -> void:
	_change_max_progress(max_value)
	var sp := SpeciesRegistry.get_species_or_default(type)
	if sp and race_face:
		race_face.frame = sp.logo_frame

func _recipt_obtain() -> void:
	$HBoxContainer/TextureRect.show()

func _recipt_hide() -> void:
	$HBoxContainer/TextureRect.hide()

func _change_max_progress(change: float) -> void:
	timer.max_value = change
	timer.value = change

func _change_curent(change: float) -> void:
	timer.value = change
	if(timer.max_value/5 > change):
		var fill: StyleBoxFlat = timer.get_theme_stylebox("fill").duplicate()
		fill.bg_color = Color("8d0700ff")
		timer.add_theme_stylebox_override("fill", fill)
		patience_face.frame = 6
	elif(2*timer.max_value/5 > change):
		var fill: StyleBoxFlat = timer.get_theme_stylebox("fill").duplicate()
		fill.bg_color = Color("d47300ff")
		timer.add_theme_stylebox_override("fill", fill)
		patience_face.frame = 5
	elif(3*timer.max_value/5 > change):
		var fill: StyleBoxFlat = timer.get_theme_stylebox("fill").duplicate()
		fill.bg_color = Color("fee100ff")
		timer.add_theme_stylebox_override("fill", fill)
		patience_face.frame = 4
	elif(4*timer.max_value/5 > change):
		var fill: StyleBoxFlat = timer.get_theme_stylebox("fill").duplicate()
		fill.bg_color = Color("acb700ff")
		timer.add_theme_stylebox_override("fill", fill)
		patience_face.frame = 3
	else:
		var fill: StyleBoxFlat = timer.get_theme_stylebox("fill").duplicate()
		fill.bg_color = Color("00ae2e")
		timer.add_theme_stylebox_override("fill", fill)
		patience_face.frame = 2
		
