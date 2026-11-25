extends Resource
class_name Liquid

@export var sprite: Texture2D
@export var outside_Sprite: Texture2D
@export var alchol: bool = false
@export var id: String = "gin":
	set(value):
		id = value
		_schedule_register()
@export var liquid_size = 50
@export var liquid_color : Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		liquid_color = value
		_schedule_register()
@export var buoyancy: float = -1.0:
	set(value):
		buoyancy = value
		_schedule_register()
@export var viscosity: float = -1.0:
	set(value):
		viscosity = value
		_schedule_register()

var _register_queued: bool = false

func _schedule_register() -> void:
	if Engine.is_editor_hint() or _register_queued:
		return
	_register_queued = true
	call_deferred("register_properties")

func register_properties() -> void:
	_register_queued = false
	if Engine.is_editor_hint():
		return
	LiquidProperties.register_from_liquid(self)
