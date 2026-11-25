class_name LiquidProperties
extends RefCounted

const RESOURCE_BASE_PATH := "res://Player/Drink/Liquids/resource/"

const LIQUID_COLOR := {
	"gin": Color(0.0, 0.953, 0.0, 1.0),
	"beer": Color(0.98, 0.322, 0.051, 1.0),
	"spirit": Color(0.542, 0.691, 1.0, 1.0),
	"vodka": Color(0.137, 0.372, 1.0, 1.0),
	"rum": Color(0.458, 0.154, 0.014, 1.0),
	"tequila": Color(0.9, 0.85, 0.3, 1.0),
	"whiskey": Color(0.78, 0.42, 0.1, 1.0),
	"blood": Color(0.85, 0.05, 0.05, 1.0)
}

const LIQUID_BUOYANCY := {
	"spirit": 1.65,
	"beer": 1.42,
	"gin": 1.24,
	"vodka": 1.08,
	"tequila": 0.94,
	"whiskey": 0.80,
	"rum": 0.68,
	"blood": 0.52
}

const LIQUID_VISCOSITY := {
	"spirit": 0.0,
	"beer": 0.0,
	"gin": 0.0,
	"vodka": 0.0,
	"tequila": 0.0,
	"whiskey": 0.0,
	"rum": 0.0,
	"blood": 0.0
}

static var _custom_colors: Dictionary = {}
static var _custom_buoyancy: Dictionary = {}
static var _custom_viscosity: Dictionary = {}
static var _attempted_resource_ids: Dictionary = {}

static func register_from_liquid(liquid_res: Resource) -> void:
	if liquid_res == null or not ("id" in liquid_res):
		return
	var id := str(liquid_res.get("id")).strip_edges()
	if id == "":
		return
	_attempted_resource_ids[id] = true
	if "liquid_color" in liquid_res and liquid_res.get("liquid_color") is Color:
		var col: Color = liquid_res.get("liquid_color")
		if not LIQUID_COLOR.has(id) or col != Color.WHITE:
			register_liquid_color(id, col)
	if "buoyancy" in liquid_res:
		var buoy := float(liquid_res.get("buoyancy"))
		if buoy > 0.0:
			register_liquid_buoyancy(id, buoy)
	if "viscosity" in liquid_res:
		var visc := float(liquid_res.get("viscosity"))
		if visc >= 0.0:
			register_liquid_viscosity(id, visc)

static func _try_load_resource_for_id(id: String) -> void:
	if id == "" or _attempted_resource_ids.has(id):
		return
	_attempted_resource_ids[id] = true
	var res_path := RESOURCE_BASE_PATH + id + ".tres"
	if ResourceLoader.exists(res_path):
		var loaded := ResourceLoader.load(res_path)
		if loaded is Resource:
			register_from_liquid(loaded)

static func register_liquid_color(id: String, color_val: Color) -> void:
	if id != "":
		_custom_colors[id] = color_val

static func get_liquid_color(id: String, fallback: Color = Color.WHITE) -> Color:
	_try_load_resource_for_id(id)
	if _custom_colors.has(id):
		return _custom_colors[id]
	if LIQUID_COLOR.has(id):
		return LIQUID_COLOR[id]
	return fallback

static func register_liquid_buoyancy(id: String, buoyancy_val: float) -> void:
	if buoyancy_val > 0.0:
		_custom_buoyancy[id] = buoyancy_val

static func get_liquid_buoyancy(id: String) -> float:
	_try_load_resource_for_id(id)
	if _custom_buoyancy.has(id):
		return float(_custom_buoyancy[id])
	if LIQUID_BUOYANCY.has(id):
		return float(LIQUID_BUOYANCY[id])
	var h: int = abs(hash(id)) % 1000
	return 0.60 + (float(h) / 999.0) * 0.95

static func register_liquid_viscosity(id: String, viscosity_val: float) -> void:
	if viscosity_val >= 0.0:
		_custom_viscosity[id] = clampf(viscosity_val, 0.0, 1.0)

static func get_liquid_viscosity(id: String) -> float:
	_try_load_resource_for_id(id)
	if _custom_viscosity.has(id):
		return clampf(float(_custom_viscosity[id]), 0.0, 1.0)
	if LIQUID_VISCOSITY.has(id):
		return clampf(float(LIQUID_VISCOSITY[id]), 0.0, 1.0)
	return 0.0

static func get_layer_ingredients(layer: Array) -> Dictionary:
	var ing_weights: Dictionary = {}
	if layer.is_empty():
		return ing_weights
	var amt := float(layer[1]) if layer.size() > 1 else 1.0
	var eff_amt := amt if amt > 0.0001 else 1.0
	if layer.size() > 3 and layer[3] is Dictionary and not (layer[3] as Dictionary).is_empty():
		for k in (layer[3] as Dictionary).keys():
			ing_weights[str(k)] = float(layer[3][k])
	elif layer[0] is Dictionary:
		for k in (layer[0] as Dictionary).keys():
			ing_weights[str(k)] = float(layer[0][k])
	elif layer[0] is Array:
		var arr: Array = layer[0]
		if not arr.is_empty():
			var split_w := eff_amt / float(arr.size())
			for k in arr:
				var ks := str(k)
				ing_weights[ks] = float(ing_weights.get(ks, 0.0)) + split_w
	else:
		ing_weights[str(layer[0])] = eff_amt
	return ing_weights

static func get_layer_buoyancy(layer: Array, buoyancy_overrides: Dictionary = {}) -> float:
	var ing_weights := get_layer_ingredients(layer)
	if ing_weights.is_empty():
		return 1.0
	var w_sum := 0.0
	var rho_sum := 0.0
	for ks in ing_weights.keys():
		var kw := maxf(float(ing_weights[ks]), 0.0)
		if kw <= 0.0:
			continue
		var kb := float(buoyancy_overrides.get(ks, get_liquid_buoyancy(ks)))
		w_sum += kw
		rho_sum += kw * (1.0 / clampf(kb, 0.35, 2.5))
	if w_sum <= 0.0001:
		return 1.0
	return clampf(w_sum / rho_sum, 0.35, 2.5)

static func get_layer_viscosity(layer: Array, viscosity_overrides: Dictionary = {}) -> float:
	var ing_weights := get_layer_ingredients(layer)
	if ing_weights.is_empty():
		return 0.0
	var w_sum := 0.0
	var visc_sum := 0.0
	for ks in ing_weights.keys():
		var kw := maxf(float(ing_weights[ks]), 0.0)
		if kw <= 0.0:
			continue
		var kv := clampf(float(viscosity_overrides.get(ks, get_liquid_viscosity(ks))), 0.0, 1.0)
		w_sum += kw
		visc_sum += kw * kv
	return clampf(visc_sum / maxf(w_sum, 0.0001), 0.0, 1.0)