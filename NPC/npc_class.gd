class_name NPC
extends Resource

@export var sprite_sheet: Texture2D
@export var race: String = "HUMAN"
@export var dialogue_resource: DialogueResource
@export var hframe: int = 1
@export var patience_time: float = 30.0

@export_group("Scripting & Defaults")
@export var npc_name: String = ""
@export var is_named: bool = true
@export var expressions: Dictionary = {} # ex. {"happy": 2, "mad": 4}
@export var default_orders: Array[String] = [] # Optional fixed drinks