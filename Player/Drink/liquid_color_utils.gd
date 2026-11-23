class_name LiquidColorUtils
extends RefCounted

static func format_layer_name(layer_id) -> String:
	if layer_id is Array:
		var names: Array = layer_id.duplicate()
		names.sort()
		return " + ".join(names)
	elif layer_id is Dictionary:
		var names: Array = layer_id.keys()
		names.sort()
		return " + ".join(names)
	return str(layer_id)

static func get_layer_color(layer: Array) -> Color:
	if layer.size() > 2 and layer[2] is Color:
		return layer[2]
	if layer[0] is Array or layer[0] is Dictionary:
		return get_layer_hsv_color(layer)
	return LiquidProperties.get_liquid_color(str(layer[0]))

static func get_layer_hsv_color(layer: Array) -> Color:
	if layer.size() > 2 and layer[2] is Color:
		return layer[2]
	var weights: Array = []
	if layer.size() > 3 and layer[3] is Dictionary:
		for ing in layer[3]:
			weights.append([LiquidProperties.get_liquid_color(str(ing)), float(layer[3][ing])])
	elif layer[0] is Array:
		for ing in layer[0]:
			weights.append([LiquidProperties.get_liquid_color(str(ing)), 1.0])
	elif layer[0] is Dictionary:
		for ing in layer[0]:
			weights.append([LiquidProperties.get_liquid_color(str(ing)), float(layer[0][ing])])
	else:
		return LiquidProperties.get_liquid_color(str(layer[0]))
	return average_hsv_color(weights)

static func average_hsv_color(color_weights: Array) -> Color:
	if color_weights.is_empty():
		return Color.WHITE

	var total_weight: float = 0.0
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_s: float = 0.0
	var sum_v: float = 0.0
	var sum_a: float = 0.0

	for item in color_weights:
		var c: Color = item[0]
		var w: float = float(item[1])
		if w <= 0.0:
			continue
		total_weight += w
		var angle := c.h * TAU
		var sat_w := maxf(c.s, 0.01) * w
		sum_x += cos(angle) * sat_w
		sum_y += sin(angle) * sat_w
		sum_s += c.s * w
		sum_v += c.v * w
		sum_a += c.a * w

	if total_weight <= 0.0:
		return Color.WHITE

	var avg_h: float = 0.0
	if absf(sum_x) > 0.0001 or absf(sum_y) > 0.0001:
		var avg_angle := atan2(sum_y, sum_x)
		if avg_angle < 0.0:
			avg_angle += TAU
		avg_h = avg_angle / TAU
	else:
		avg_h = color_weights[0][0].h

	var avg_s := clampf(sum_s / total_weight, 0.35, 1.0)
	var avg_v := clampf(sum_v / total_weight, 0.5, 1.0)
	var avg_a := clampf(sum_a / total_weight, 0.0, 1.0)
	return Color.from_hsv(avg_h, avg_s, avg_v, avg_a)