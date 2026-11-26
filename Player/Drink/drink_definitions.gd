class_name DrinkDefinitions
extends RefCounted

# - id / recipe_id (String)
# - display_name (String)
# - ingredients (Dictionary: ingredient_id -> ratio/amount)
# - garnishes (Array[String])
# - accepted_garnishes (Array[String])
# - processing_tags / processing (Array[String])
# - required_glass (String: "", "beer", "shot")
# - ice_preference (DrinkRecipe.IcePreference, defaults to DONT_CARE which allows Ice or No Ice)
# - is_alcoholic (bool)

const GARNISHES: Array[String] = [
	"herb",
	"cherry",
	"olive",
	"lemon_whole",
	"lemon_half",
	"lemon_sliced",
]

const DEFINITIONS: Array[Dictionary] = [
	{
		"id": "beer",
		"display_name": "Beer",
		"ingredients": {"beer": 1.0},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "gin",
		"display_name": "Gin",
		"ingredients": {"gin": 1.0},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "rum",
		"display_name": "Rum",
		"ingredients": {"rum": 1.0},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "vodka",
		"display_name": "Vodka",
		"ingredients": {"vodka": 1.0},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "spirit",
		"display_name": "Spirit",
		"ingredients": {"spirit": 1.0},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "tequila",
		"display_name": "Tequila",
		"ingredients": {"tequila": 1.0},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "whiskey",
		"display_name": "Whiskey",
		"ingredients": {"whiskey": 1.0},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "blood",
		"display_name": "Blood",
		"ingredients": {"blood": 1.0},
		"garnishes": [],
		"processing_tags": [],
		"is_alcoholic": false,
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},



	{
		"id": "gum",
		"display_name": "Gum",
		"ingredients": {"gin": 0.5, "rum": 0.5},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "exorcist",
		"display_name": "Exorcist",
		"ingredients": {"spirit": 0.5, "vodka": 0.5},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "ginger",
		"display_name": "Ginger",
		"ingredients": {"beer": 0.5, "gin": 0.5},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
	{
		"id": "martini",
		"display_name": "Martini",
		"ingredients": {"gin": 0.5, "vodka": 0.5},
		"garnishes": [],
		"processing_tags": [],
		"ice_preference": DrinkRecipe.IcePreference.DONT_CARE,
	},
]