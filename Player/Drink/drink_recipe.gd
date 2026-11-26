class_name DrinkRecipe
extends Resource

# set recipes for cocktails so we can mix set drinks and random orders
@export var recipe_id: String = ""
@export var display_name: String = ""
@export var required_glass: String = "" # "shot", "beer"
@export var ingredients: Dictionary = {} # "gin": 2.0, "vermouth": 0.5
@export var garnishes: Array[String] = [] # "olive", "lemon_whole", "lemon_half", "lemon_sliced"
@export var processing: Array[String] = [] # "shaken", "spectral"
@export var is_alcoholic: bool = true
@export var allowed_species: Array[String] = []

enum IcePreference {DONT_CARE, REQUIRED, FORBIDDEN}

@export var accepted_garnishes: Array[String] = []
@export var ice_preference: IcePreference = IcePreference.DONT_CARE