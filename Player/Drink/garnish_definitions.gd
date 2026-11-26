class_name GarnishDefinitions
extends RefCounted

const MAX_GARNISH_STACK: int = 10
const ICE_CUBE_COUNT: int = 8
const DEFAULT_DISPENSER_STOCK: int = 5
const DEFAULT_REFILL_TIME: float = 2.0
const DEFAULT_REFILL_COST_PER_ITEM: int = 2
const MIN_REFILL_TIME: float = 0.5
const REFILL_TIME_STEP_PER_LEVEL: float = 0.25
const SIZE_UPGRADE_STEP_RATIO: float = 0.20

const CUT_TRANSITIONS: Dictionary = {
	"lemon_whole": "lemon_half",
	"lemon_half": "lemon_sliced",
}

const MARKER_MAP: Dictionary = {
	"lemons_marker": "lemon_whole",
	"herbs_marker": "herb",
	"olives_marker": "olive",
	"cherries_marker": "cherry",
	"ice_machine_marker": "ice",
}

const DEFINITIONS: Dictionary = {
	"lemon_whole": {
		"id": "lemon_whole",
		"display_name": "Lemon Whole",
		"category": "lemon",
		"placement": "rim_left",
		"max_count": MAX_GARNISH_STACK,
		"is_ice": false,
		# "texture_path": "res://Assets/Items/Ingreidents/Lemon_Whole.png",
	},
	"lemon_half": {
		"id": "lemon_half",
		"display_name": "Lemon Half",
		"category": "lemon",
		"placement": "rim_left",
		"max_count": MAX_GARNISH_STACK,
		"is_ice": false,
		# "texture_path": "res://Assets/Items/Ingreidents/Lemon_Half.png",
	},
	"lemon_sliced": {
		"id": "lemon_sliced",
		"display_name": "Lemon Sliced",
		"category": "lemon",
		"placement": "rim_left",
		"max_count": MAX_GARNISH_STACK,
		"is_ice": false,
		# "texture_path": "res://Assets/Items/Ingreidents/Lemon_Sliced.png",
	},
	"herb": {
		"id": "herb",
		"display_name": "Herb",
		"category": "herb",
		"placement": "surface_float",
		"max_count": MAX_GARNISH_STACK,
		"is_ice": false,
		# "texture_path": "res://Assets/Items/Ingreidents/Herb.png",
	},
	"cherry": {
		"id": "cherry",
		"display_name": "Cherry",
		"category": "cherry",
		"placement": "rim_right",
		"max_count": MAX_GARNISH_STACK,
		"is_ice": false,
		# "texture_path": "res://Assets/Items/Ingreidents/Cherry.png",
	},
	"olive": {
		"id": "olive",
		"display_name": "Olive",
		"category": "olive",
		"placement": "rim_right",
		"max_count": MAX_GARNISH_STACK,
		"is_ice": false,
		# "texture_path": "res://Assets/Items/Ingreidents/Olive.png",
	},
	"ice": {
		"id": "ice",
		"display_name": "Ice",
		"category": "ice",
		"placement": "liquid_float",
		"max_count": 1,
		"is_ice": true,
		# "texture_path": "res://Assets/Items/Ingreidents/Ice.png",
		# "cube_texture_path": "res://Assets/Items/Ingreidents/Ice_Cube.png",
	},
}

static var _white_square_tex: Texture2D = null
static var _texture_cache: Dictionary = {}

static func normalize_id(garnish_id: String) -> String:
	return garnish_id.to_lower().strip_edges()

static func get_definition(garnish_id: String) -> Dictionary:
	return DEFINITIONS.get(normalize_id(garnish_id), {})

static func is_known_id(garnish_id: String) -> bool:
	return DEFINITIONS.has(normalize_id(garnish_id))

static func is_ice(garnish_id: String) -> bool:
	return normalize_id(garnish_id) == "ice"

static func is_lemon(garnish_id: String) -> bool:
	var def := get_definition(garnish_id)
	return str(def.get("category", "")) == "lemon"

static func get_placement(garnish_id: String) -> String:
	var def := get_definition(garnish_id)
	return str(def.get("placement", ""))

static func get_base_stock(garnish_id: String) -> int:
	var def := get_definition(garnish_id)
	return maxi(1, int(def.get("base_stock", DEFAULT_DISPENSER_STOCK)))

static func get_refill_cost_per_item(garnish_id: String) -> int:
	var def := get_definition(garnish_id)
	return maxi(1, int(def.get("refill_cost", DEFAULT_REFILL_COST_PER_ITEM)))

static func get_next_cut_variation(garnish_id: String) -> String:
	return str(CUT_TRANSITIONS.get(normalize_id(garnish_id), ""))

static func get_lemon_count(mix: DrinkMix) -> int:
	if mix == null:
		return 0
	var count: int = 0
	for g in mix.garnishes:
		if is_lemon(str(g)):
			count += 1
	return count

static func can_add_to_mix(mix: DrinkMix, garnish_id: String) -> bool:
	if mix == null:
		return false
	var clean_id := normalize_id(garnish_id)
	if not is_known_id(clean_id):
		return false
	if is_ice(clean_id):
		return not mix.has_ice
	if is_lemon(clean_id):
		return get_lemon_count(mix) < MAX_GARNISH_STACK
	if clean_id == "cherry" or clean_id == "olive":
		return mix.get_garnish_count(clean_id) < MAX_GARNISH_STACK
	if clean_id == "herb":
		return mix.get_garnish_count(clean_id) < MAX_GARNISH_STACK
	return true

static func get_white_square_texture() -> Texture2D:
	if _white_square_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_square_tex = ImageTexture.create_from_image(img)
	return _white_square_tex

static func get_texture(garnish_id: String, for_cup_cube: bool = false) -> Texture2D:
	var clean_id := normalize_id(garnish_id)
	var cache_key := clean_id + ("_cube" if for_cup_cube else "")
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key] as Texture2D

	var def := get_definition(clean_id)
	var tex_path := ""
	if for_cup_cube and def.has("cube_texture_path"):
		tex_path = str(def["cube_texture_path"])
	elif def.has("texture_path"):
		tex_path = str(def["texture_path"])

	# Future texture loading
	# if tex_path != "" and ResourceLoader.exists(tex_path):
	#     var loaded := load(tex_path) as Texture2D
	#     if loaded:
	#         _texture_cache[cache_key] = loaded
	#         return loaded

	# Future per-garnish texture preloads
	# "lemon_whole": preload("res://Assets/Items/Ingreidents/Lemon_Whole.png")
	# "lemon_half": preload("res://Assets/Items/Ingreidents/Lemon_Half.png")
	# "lemon_sliced": preload("res://Assets/Items/Ingreidents/Lemon_Sliced.png")
	# "herb": preload("res://Assets/Items/Ingreidents/Herb.png")
	# "cherry": preload("res://Assets/Items/Ingreidents/Cherry.png")
	# "olive": preload("res://Assets/Items/Ingreidents/Olive.png")
	# "ice": preload("res://Assets/Items/Ingreidents/Ice.png")
	# "ice_cube": preload("res://Assets/Items/Ingreidents/Ice_Cube.png")

	var fallback := get_white_square_texture()
	_texture_cache[cache_key] = fallback
	return fallback