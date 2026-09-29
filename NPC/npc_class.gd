class_name NPC
extends Resource
@export var sprite_sheet: Texture2D
@export_enum("HUMAN", "VAMPIRE", "SLIME", "TINY", "FISH") var race: String = "HUMAN"
@export var dialogue_resource: DialogueResource
@export var hframe : int = 1
@export var patience_time : float = 90
