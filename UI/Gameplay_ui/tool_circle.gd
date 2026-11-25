extends Control

signal option_selected(option: WheelOption)

const ICON_PATH := "res://Assets/Items/Ingreidents/%s.png"

# Ingredient key -> icon file name (without .png)
# Anything not listed here uses the key itself as the file name.
const ICON_OVERRIDES := {
	"Blood": "knife",
	"Mag": "Mag",
	"Fishing_Rod": "fishing_rod",
}

@export var outer_radius := 200.0
@export var inner_radius := 60.0
@export var line_width := 3.0
@export var bg_color := Color(0.1, 0.1, 0.1, 0.8)
@export var line_color := Color.WHITE
@export var highlight_color := Color(0.4, 0.4, 0.4, 0.9)

var options: Array[WheelOption] = []
var selection := -1  # -1 = nothing highlighted

func _ready():
	hide()

func _input(event):
	if event.is_action_pressed("Right_click"):
		_build_options()
		position = get_viewport().get_mouse_position()
		selection = -1
		show()
	elif event.is_action_released("Right_click") and visible:
		hide()
		if selection != -1 and selection < options.size():
			print("Selected: ", options[selection].id, " (index ", selection, ")")
			if GameState.player:
				GameState.player._change_tool(options[selection].id)
			option_selected.emit(options[selection])

func _build_options() -> void:
	options.clear()

	# Hand is always available
	options.append(_make_option("Hand", "Hand", "Hand"))

	# Only unlocked ingredients
	var ingredients: Dictionary = PlayerStats.unlocks["Ingredients"]
	for key in ingredients:
		if ingredients[key]:
			var icon_name: String = ICON_OVERRIDES.get(key, key)
			options.append(_make_option(key, key.replace("_", " "), icon_name))

func _make_option(id: StringName, label: String, icon_name: String) -> WheelOption:
	var opt := WheelOption.new()
	opt.id = id
	opt.label = label
	var path := ICON_PATH % icon_name
	if ResourceLoader.exists(path):
		opt.icon = load(path)
	else:
		push_warning("Missing wheel icon: " + path)
	return opt

func _process(_delta):
	if not visible or options.is_empty():
		return
	var m := get_local_mouse_position()
	var dist := m.length()
	if dist < inner_radius or dist > outer_radius:
		selection = -1
	else:
		var angle := fposmod(m.angle() + PI / 2.0, TAU)  # 0 at top, clockwise
		selection = int(angle / (TAU / options.size()))
	queue_redraw()

# _draw() stays exactly the same as before
