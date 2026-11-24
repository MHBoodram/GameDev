class_name DrinkScorer
extends RefCounted

# handles base drink scoring and sends species and modifier drink rules to SpeciesRegistry

const SATISFACTORY_THRESHOLD := 0.6
const IDEAL_FILL_RATIO := 0.90
const UNDERFILL_EXPONENT := 3.0

const MAX_DIFF := 0.12
const PROPORTION_TOLERANCE_PENALTY := 0.25
const PROPORTION_EXCESS_WEIGHT := 0.75
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

static func score_drink(served: DrinkMix, wanted: DrinkOrder) -> Dictionary:
	# completely empty drink or no order
	if wanted == null or wanted.ingredients.is_empty():
		return {"score": 0.0, "is_satisfactory": false}
	if served == null or served.is_empty():
		return {"score": 0.0, "is_satisfactory": false}

	var drink_score: float = 1.0
	var have := served.get_normalized_ingredients()
	var want := wanted.get_normalized_ingredients()
	if want.is_empty() or have.is_empty():
		return {"score": 0.0, "is_satisfactory": false}

	var want_count: float = maxf(float(want.size()), 1.0)
	var missing_penalty: float = maxf(FLAT_PENALTY_MISSING_INGREDIENT, 1.0 / want_count)
	var matched_count: int = 0

	# check each requested ingredient
	for check_name in want.keys():
		var check_amount: float = float(want[check_name])
		if have.has(check_name):
			matched_count += 1
			var actual_amount: float = float(have[check_name])
			var difference: float = absf(check_amount - actual_amount)
			var proportion_penalty: float = 0.0

			if difference <= MAX_DIFF:
				proportion_penalty = PROPORTION_TOLERANCE_PENALTY * (difference / MAX_DIFF)
			else:
				var excess := (difference - MAX_DIFF) / maxf(check_amount * 0.65, 0.25)
				proportion_penalty = PROPORTION_TOLERANCE_PENALTY + PROPORTION_EXCESS_WEIGHT * clampf(excess, 0.0, 1.0)

			drink_score -= proportion_penalty / want_count
		else:
			drink_score -= missing_penalty

	# heavily punish any extra ingredients they didn't ask for
	for have_name in have.keys():
		if not want.has(have_name):
			var wrong_ratio: float = float(have[have_name])
			drink_score -= FLAT_PENALTY_WRONG_INGREDIENT + WRONG_INGREDIENT_RATIO_WEIGHT * wrong_ratio

	# zero base score if none of the requested ingredients are present
	if matched_count == 0:
		drink_score = 0.0

	# optional glass check (only penalize if the order actually specified a glass)
	if wanted.required_glass != "" and served.glass_type != "":
		if wanted.required_glass.to_lower() != served.glass_type.to_lower():
			drink_score -= PENALTY_WRONG_GLASS

	# optional processing check (shaken, spectral, etc)
	for tag in wanted.required_processing:
		if not served.has_processing(tag):
			drink_score -= PENALTY_WRONG_PROCESSING

	# finishes: missing garnishes, unwanted garnishes, and ice preference (capped)
	var finish_deduction: float = 0.0
	var wanted_garnishes_lower: Array[String] = []
	for g in wanted.garnishes:
		var clean_g := str(g).to_lower().strip_edges()
		if clean_g != "":
			wanted_garnishes_lower.append(clean_g)
			if not served.garnishes.has(clean_g):
				finish_deduction += PENALTY_MISSING_GARNISH

	var accepted_garnishes_lower: Array[String] = []
	for g in wanted.accepted_garnishes:
		var clean_g := str(g).to_lower().strip_edges()
		if clean_g != "":
			accepted_garnishes_lower.append(clean_g)

	for g in served.garnishes:
		var clean_g := str(g).to_lower().strip_edges()
		if clean_g != "" and not wanted_garnishes_lower.has(clean_g) and not accepted_garnishes_lower.has(clean_g):
			finish_deduction += PENALTY_UNWANTED_GARNISH

	if wanted.ice_preference == DrinkRecipe.IcePreference.REQUIRED and not served.has_ice:
		finish_deduction += PENALTY_ICE_MISMATCH
	elif wanted.ice_preference == DrinkRecipe.IcePreference.FORBIDDEN and served.has_ice:
		finish_deduction += PENALTY_ICE_MISMATCH

	drink_score -= minf(finish_deduction, MAX_FINISH_DEDUCTION)
	drink_score = clampf(drink_score, 0.0, 1.0)

	# strict underfill check (ideal amount is 90% full; punish giving too little)
	var fill_ratio := served.get_fill_ratio()
	if fill_ratio < IDEAL_FILL_RATIO:
		var fill_factor := pow(clampf(fill_ratio / IDEAL_FILL_RATIO, 0.0, 1.0), UNDERFILL_EXPONENT)
		drink_score *= fill_factor

	# cumulative overfill / spill penalty (persists even after pouring out in the sink)
	if served.overfill_percent > 0.0:
		drink_score -= served.overfill_percent * PENALTY_PER_OVERFILL_PERCENT

	var result := {
		"score": clampf(drink_score, 0.0, 1.0),
		"is_satisfactory": false
	}

	SpeciesRegistry.apply_drink_scoring_hooks(served, wanted, result)

	result["score"] = clampf(float(result["score"]), 0.0, 1.0)
	result["is_satisfactory"] = float(result["score"]) >= SATISFACTORY_THRESHOLD
	print("SCORE: ", result["score"])
	print("IS_SATISIFACTORY: ", result["is_satisfactory"])
	return result

# bridge for the old nested arrays so we don't break anything right now
static func score_legacy(drink_layers: Array, want_array: Array, cup_capacity: float = 0.0) -> Dictionary:
	var served := DrinkMix.from_legacy_layers(drink_layers, cup_capacity)
	var wanted := DrinkOrder.from_legacy_want(want_array)
	return score_drink(served, wanted)