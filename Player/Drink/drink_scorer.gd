class_name DrinkScorer
extends RefCounted

# handles base drink scoring and sends species and modifier drink rules to SpeciesRegistry

const SATISFACTORY_THRESHOLD := 0.6

const IDEAL_FILL_RATIO := 0.90
const UNDERFILL_EXPONENT := 3.0

const MAX_DIFF := 0.12
const PROPORTION_TOLERANCE_PENALTY := 0.25
const PROPORTION_EXCESS_WEIGHT := 0.75
const EXCESS_CHECK_RATIO_SCALE := 0.65
const MIN_EXCESS_DENOMINATOR := 0.25
const FLAT_PENALTY_WRONG_INGREDIENT := 0.40
const WRONG_INGREDIENT_RATIO_WEIGHT := 0.60
const FLAT_PENALTY_MISSING_INGREDIENT := 0.45

const PENALTY_WRONG_GLASS := 0.30
const PENALTY_MISSING_GARNISH := 0.15
const PENALTY_UNWANTED_GARNISH := 0.15
const PENALTY_WRONG_PROCESSING := 0.45
const PENALTY_PER_OVERFILL_PERCENT := 0.012
const PENALTY_ICE_MISMATCH := 0.10
const MAX_FINISH_DEDUCTION := 0.35

static func score_drink(served: DrinkMix, wanted: DrinkOrder, scoring_params: Dictionary = {}) -> Dictionary:
	# completely empty drink or no order
	if wanted == null:
		print("[drink_scorer] No wanted order, SCORE: 0.000 | IS_SATISFACTORY: false")
		return {"score": 0.0, "is_satisfactory": false}

	var ideal_fill: float = float(scoring_params.get("ideal_fill_ratio", wanted.ideal_fill_ratio if wanted.ideal_fill_ratio >= 0.0 else IDEAL_FILL_RATIO))
	var underfill_exp: float = float(scoring_params.get("underfill_exponent", wanted.underfill_exponent if wanted.underfill_exponent >= 0.0 else UNDERFILL_EXPONENT))
	var max_diff: float = float(scoring_params.get("proportion_tolerance", wanted.proportion_tolerance if wanted.proportion_tolerance >= 0.0 else MAX_DIFF))
	var pen_scale: float = maxf(0.0, float(scoring_params.get("penalty_scale", wanted.penalty_scale)))
	var req_match: bool = bool(scoring_params.get("require_ingredient_match", wanted.require_ingredient_match))

	if req_match and wanted.ingredients.is_empty():
		print("[drink_scorer] No wanted order ingredients, SCORE: 0.000 | IS_SATISFACTORY: false")
		return {"score": 0.0, "is_satisfactory": false}
	if served == null or served.is_empty():
		print("[drink_scorer] Served drink is empty, SCORE: 0.000 | IS_SATISFACTORY: false")
		return {"score": 0.0, "is_satisfactory": false}

	var drink_score: float = 1.0
	var have := served.get_normalized_ingredients()
	var want := wanted.get_normalized_ingredients()
	if have.is_empty() or (req_match and want.is_empty()):
		print("[drink_scorer] Normalized ingredients empty, SCORE: 0.000 | IS_SATISFACTORY: false")
		return {"score": 0.0, "is_satisfactory": false}

	var want_count: float = maxf(float(want.size()), 1.0)
	var missing_penalty: float = maxf(FLAT_PENALTY_MISSING_INGREDIENT, 1.0 / want_count)
	var matched_count: int = 0

	var proportion_deduction: float = 0.0
	var missing_deduction: float = 0.0
	var wrong_deduction: float = 0.0
	var glass_deduction: float = 0.0
	var processing_deduction: float = 0.0
	var missing_garnish_deduction: float = 0.0
	var unwanted_garnish_deduction: float = 0.0
	var ice_deduction: float = 0.0

	var missing_names: Array[String] = []
	var wrong_names: Array[String] = []
	var missing_processing: Array[String] = []

	if req_match and not want.is_empty():
		# check each requested ingredient
		for check_name in want.keys():
			var check_amount: float = float(want[check_name])
			if have.has(check_name):
				matched_count += 1
				var actual_amount: float = float(have[check_name])
				var difference: float = absf(check_amount - actual_amount)
				var proportion_penalty: float = 0.0

				if difference <= max_diff:
					proportion_penalty = PROPORTION_TOLERANCE_PENALTY * (difference / maxf(max_diff, 0.0001))
				else:
					var excess := (difference - max_diff) / maxf(check_amount * EXCESS_CHECK_RATIO_SCALE, MIN_EXCESS_DENOMINATOR)
					proportion_penalty = PROPORTION_TOLERANCE_PENALTY + PROPORTION_EXCESS_WEIGHT * clampf(excess, 0.0, 1.0)

				var weighted_prop_penalty := (proportion_penalty / want_count) * pen_scale
				proportion_deduction += weighted_prop_penalty
				drink_score -= weighted_prop_penalty
			else:
				missing_names.append(str(check_name))
				var scaled_missing := missing_penalty * pen_scale
				missing_deduction += scaled_missing
				drink_score -= scaled_missing

		# heavily punish any extra ingredients they didn't ask for
		for have_name in have.keys():
			if not want.has(have_name):
				var wrong_ratio: float = float(have[have_name])
				var item_wrong_penalty := (FLAT_PENALTY_WRONG_INGREDIENT + WRONG_INGREDIENT_RATIO_WEIGHT * wrong_ratio) * pen_scale
				wrong_names.append("%s(%.0f%%)" % [str(have_name), wrong_ratio * 100.0])
				wrong_deduction += item_wrong_penalty
				drink_score -= item_wrong_penalty

		# zero base score if none of the requested ingredients are present
		if matched_count == 0:
			drink_score = 0.0

	# optional glass check (only penalize if the order actually specified a glass)
	if wanted.required_glass != "" and served.glass_type != "":
		if wanted.required_glass.to_lower() != served.glass_type.to_lower():
			glass_deduction = PENALTY_WRONG_GLASS * pen_scale
			drink_score -= glass_deduction

	# optional processing check (shaken, spectral, etc)
	for tag in wanted.required_processing:
		if not served.has_processing(tag):
			missing_processing.append(str(tag))
			processing_deduction += PENALTY_WRONG_PROCESSING
			drink_score -= PENALTY_WRONG_PROCESSING

	# finishes: missing garnishes, unwanted garnishes, and ice preference (capped)
	var wanted_garnish_counts: Dictionary = wanted.get_garnish_counts()
	var served_garnish_counts: Dictionary = served.get_garnish_counts()

	var accepted_garnishes_lower: Array[String] = []
	for g in wanted.accepted_garnishes:
		var clean_g := str(g).to_lower().strip_edges()
		if clean_g != "" and not accepted_garnishes_lower.has(clean_g):
			accepted_garnishes_lower.append(clean_g)

	for g_key in wanted_garnish_counts.keys():
		var req_count := int(wanted_garnish_counts[g_key])
		var have_count := int(served_garnish_counts.get(g_key, 0))
		if have_count < req_count:
			missing_garnish_deduction += float(req_count - have_count) * PENALTY_MISSING_GARNISH

	for g_key in served_garnish_counts.keys():
		var have_count := int(served_garnish_counts[g_key])
		var req_count := int(wanted_garnish_counts.get(g_key, 0))
		if have_count > req_count and not accepted_garnishes_lower.has(g_key):
			unwanted_garnish_deduction += float(have_count - req_count) * PENALTY_UNWANTED_GARNISH

	if wanted.ice_preference == DrinkRecipe.IcePreference.REQUIRED and not served.has_ice:
		ice_deduction = PENALTY_ICE_MISMATCH
	elif wanted.ice_preference == DrinkRecipe.IcePreference.FORBIDDEN and served.has_ice:
		ice_deduction = PENALTY_ICE_MISMATCH

	var raw_finish_deduction := (missing_garnish_deduction + unwanted_garnish_deduction + ice_deduction) * pen_scale
	var applied_finish_deduction := minf(raw_finish_deduction, MAX_FINISH_DEDUCTION)
	drink_score -= applied_finish_deduction

	var pre_fill_score := clampf(drink_score, 0.0, 1.0)
	drink_score = pre_fill_score

	# strict underfill check (ideal amount is parameterized, defaulting to 90% full)
	var fill_ratio := served.get_fill_ratio()
	var fill_factor := 1.0
	if ideal_fill > 0.0001 and fill_ratio < ideal_fill:
		fill_factor = pow(clampf(fill_ratio / ideal_fill, 0.0, 1.0), underfill_exp)
		drink_score *= fill_factor

	var post_fill_score := drink_score
	var underfill_deduction := pre_fill_score - post_fill_score

	# cumulative overfill / spill penalty (persists even after pouring out in the sink)
	var overfill_deduction := 0.0
	if served.overfill_percent > 0.0:
		overfill_deduction = served.overfill_percent * PENALTY_PER_OVERFILL_PERCENT * pen_scale
		drink_score -= overfill_deduction

	var pre_hooks_score := clampf(drink_score, 0.0, 1.0)
	var result := {
		"score": pre_hooks_score,
		"is_satisfactory": false
	}

	SpeciesRegistry.apply_drink_scoring_hooks(served, wanted, result)

	var final_score := clampf(float(result["score"]), 0.0, 1.0)
	var hook_delta := final_score - pre_hooks_score
	result["score"] = final_score
	result["is_satisfactory"] = final_score >= SATISFACTORY_THRESHOLD

	print("drink_scorer")
	print("  matched_ingredients: %d/%d | proportion_penalty: -%.3f | missing_penalty: -%.3f (%s) | wrong_penalty: -%.3f (%s)" % [
		matched_count, want.size(), proportion_deduction, missing_deduction,
		", ".join(PackedStringArray(missing_names)) if not missing_names.is_empty() else "none",
		wrong_deduction,
		", ".join(PackedStringArray(wrong_names)) if not wrong_names.is_empty() else "none"
	])
	print("  glass_penalty: -%.3f (want='%s', got='%s') | processing_penalty: -%.3f (missing: %s)" % [
		glass_deduction, wanted.required_glass, served.glass_type, processing_deduction,
		", ".join(PackedStringArray(missing_processing)) if not missing_processing.is_empty() else "none"
	])
	print("  finish_penalty: -%.3f (raw: -%.3f, missing_garnish: -%.3f, unwanted_garnish: -%.3f, ice: -%.3f)" % [
		applied_finish_deduction, raw_finish_deduction, missing_garnish_deduction, unwanted_garnish_deduction, ice_deduction
	])
	print("  fill_ratio: %.3f (amt=%.2f / cap=%.2f, ideal>=%.2f) | fill_factor: %.3f | underfill_penalty: -%.3f" % [
		fill_ratio, served.get_total_amount(), served.cup_capacity, ideal_fill, fill_factor, underfill_deduction
	])
	print("  overfill_penalty: -%.3f (spilled=%.2f%%) | pre_fill: %.3f | post_fill: %.3f | pre_hooks: %.3f | hook_delta: %+.3f" % [
		overfill_deduction, served.overfill_percent, pre_fill_score, post_fill_score, pre_hooks_score, hook_delta
	])
	print("  Final score: %.3f | is_satisfactory (>= %.2f): %s" % [final_score, SATISFACTORY_THRESHOLD, str(result["is_satisfactory"])])
	return result

# bridge for the old nested arrays so we don't break anything right now
static func score_legacy(drink_layers: Array, want_array: Array, cup_capacity: float = 0.0) -> Dictionary:
	var served := DrinkMix.from_legacy_layers(drink_layers, cup_capacity)
	var wanted := DrinkOrder.from_legacy_want(want_array)
	return score_drink(served, wanted)