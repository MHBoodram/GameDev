class_name DrinkScorer
extends RefCounted

# handles base drink scoring and delegates species and modifier drink rules to their registries

const SATISFACTORY_THRESHOLD := 0.6
const MAX_DIFF := 0.15
const FLAT_PENALTY_WRONG_INGREDIENT := 0.3
const FLAT_PENALTY_MISSING_INGREDIENT := 0.4
const PENALTY_WRONG_GLASS := 0.25
const PENALTY_MISSING_GARNISH := 0.15
const PENALTY_WRONG_PROCESSING := 0.3

static func score_drink(served: DrinkMix, wanted: DrinkOrder) -> Dictionary:
	# completely empty drink or no order
	if wanted == null or wanted.ingredients.is_empty():
		return {"score": 0.0, "is_satisfactory": false}
	if served == null or served.is_empty():
		return {"score": 0.0, "is_satisfactory": false}

	var drink_score: float = 1.0
	var have := served.get_normalized_ingredients()
	var want := wanted.get_normalized_ingredients()

	var want_count: float = maxf(float(want.size()), 1.0)
	var missing_penalty: float = maxf(FLAT_PENALTY_MISSING_INGREDIENT, 1.0 / want_count)

	# check each requested ingredient
	for check_name in want.keys():
		var check_amount: float = float(want[check_name])
		if have.has(check_name):
			var actual_amount: float = float(have[check_name])
			var difference: float = absf(check_amount - actual_amount)
			var proportion_penalty: float = 0.0

			if difference <= MAX_DIFF:
				proportion_penalty = 0.3 * (difference / MAX_DIFF)
			else:
				var excess = (difference - MAX_DIFF) / maxf(check_amount - MAX_DIFF, 0.45)
				proportion_penalty = 0.3 + 0.7 * clampf(excess, 0.0, 1.0)

			drink_score -= proportion_penalty / want_count
		else:
			drink_score -= missing_penalty

	# check for extra ingredients they didn't ask for
	for have_name in have.keys():
		if not want.has(have_name):
			drink_score -= FLAT_PENALTY_WRONG_INGREDIENT

	# optional glass check (only penalize if the order actually specified a glass)
	if wanted.required_glass != "" and served.glass_type != "":
		if wanted.required_glass.to_lower() != served.glass_type.to_lower():
			drink_score -= PENALTY_WRONG_GLASS

	# optional processing check (shaken, spectral, etc)
	for tag in wanted.required_processing:
		if not served.has_processing(tag):
			drink_score -= PENALTY_WRONG_PROCESSING

	# optional garnishes
	for g in wanted.garnishes:
		if not served.garnishes.has(g):
			drink_score -= PENALTY_MISSING_GARNISH

	var result := {
		"score": clampf(drink_score, 0.0, 1.0),
		"is_satisfactory": false
	}

	SpeciesRegistry.apply_drink_scoring_hooks(served, wanted, result)
	ModifierRegistry.apply_drink_scoring_hooks(served, wanted, result)

	result["score"] = clampf(float(result["score"]), 0.0, 1.0)
	result["is_satisfactory"] = float(result["score"]) >= SATISFACTORY_THRESHOLD
	print("SCORE: ", result["score"])
	print("IS_SATISIFACTORY: ", result["is_satisfactory"])
	return result

# bridge for the old nested arrays so we don't break anything right now
static func score_legacy(drink_layers: Array, want_array: Array) -> Dictionary:
	var served := DrinkMix.from_legacy_layers(drink_layers)
	var wanted := DrinkOrder.from_legacy_want(want_array)
	return score_drink(served, wanted)
	