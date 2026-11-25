class_name NumberInterpolator
extends RefCounted

# animation for when a number changes

const DEFAULT_DURATION: float = 1.0
const DEFAULT_HUD_DURATION: float = 1.0
const DEFAULT_SUMMARY_DURATION: float = 2.0

const _META_TWEEN := "_number_interp_tween"
const _META_CURRENT := "_number_interp_current"
const _META_TARGET := "_number_interp_target"

static func set_number(label: Control, value: float, suffix: String = "", prefix: String = "", decimals: int = 0) -> void:
	if not is_instance_valid(label):
		return
	stop(label)
	label.set_meta(_META_CURRENT, value)
	label.set_meta(_META_TARGET, value)
	_apply_formatted_value(label, value, prefix, suffix, decimals)

static func stop(label: Control) -> void:
	if not is_instance_valid(label):
		return
	if label.has_meta(_META_TWEEN):
		var old_tween: Variant = label.get_meta(_META_TWEEN)
		if old_tween is Tween and (old_tween as Tween).is_valid():
			(old_tween as Tween).kill()
		label.remove_meta(_META_TWEEN)

static func get_current_value(label: Control, fallback: float = 0.0) -> float:
	if not is_instance_valid(label):
		return fallback
	if label.has_meta(_META_CURRENT):
		return float(label.get_meta(_META_CURRENT))
	return _parse_label_number(label, fallback)

static func get_target_value(label: Control, fallback: float = 0.0) -> float:
	if not is_instance_valid(label):
		return fallback
	if label.has_meta(_META_TARGET):
		return float(label.get_meta(_META_TARGET))
	return get_current_value(label, fallback)

static func interpolate(
	label: Control,
	to_value: float,
	from_value: Variant = null,
	duration: float = DEFAULT_DURATION,
	suffix: String = "",
	prefix: String = "",
	decimals: int = 0
) -> Tween:
	if not is_instance_valid(label):
		return null

	var start_val: float = float(from_value) if from_value != null else get_current_value(label, 0.0)
	stop(label)
	label.set_meta(_META_CURRENT, start_val)
	label.set_meta(_META_TARGET, to_value)

	if duration <= 0.0 or is_equal_approx(start_val, to_value) or not label.is_inside_tree():
		label.set_meta(_META_CURRENT, to_value)
		_apply_formatted_value(label, to_value, prefix, suffix, decimals)
		return null

	_apply_formatted_value(label, start_val, prefix, suffix, decimals)

	var tween := label.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	label.set_meta(_META_TWEEN, tween)

	tween.tween_method(
		func(val: float) -> void:
			if not is_instance_valid(label):
				return
			label.set_meta(_META_CURRENT, val)
			_apply_formatted_value(label, val, prefix, suffix, decimals),
		start_val,
		to_value,
		duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func() -> void:
		if is_instance_valid(label):
			label.set_meta(_META_CURRENT, to_value)
			_apply_formatted_value(label, to_value, prefix, suffix, decimals)
			label.remove_meta(_META_TWEEN)
	)
	return tween

static func _apply_formatted_value(label: Control, value: float, prefix: String, suffix: String, decimals: int) -> void:
	var num_str: String
	if decimals <= 0:
		num_str = str(roundi(value))
	else:
		var factor := pow(10.0, decimals)
		var rounded := roundf(value * factor) / factor
		num_str = ("%." + str(decimals) + "f") % rounded

	var formatted := prefix + num_str + suffix
	if formatted.contains("{") or label.has_meta("_text_icons_sentinel"):
		TextIcons.set_text(label, formatted)
	elif "text" in label:
		label.set("text", formatted)

static func _parse_label_number(label: Control, fallback: float = 0.0) -> float:
	var raw := ""
	if label.has_meta("_text_icons_raw_text"):
		raw = str(label.get_meta("_text_icons_raw_text", ""))
	elif "text" in label:
		raw = str(label.get("text"))
	raw = raw.strip_edges()
	if raw.is_valid_float():
		return raw.to_float()
	var parsed := raw.to_float()
	if not is_zero_approx(parsed) or raw.begins_with("0") or raw.begins_with("-0"):
		return parsed
	return fallback