class_name CustomerModifier
extends RefCounted

# handles special customer conditions ex. ghosts and wanted

enum ModifierType { NONE, GHOST, WANTED }

var modifier_type: ModifierType = ModifierType.NONE
var is_ghost: bool = false
var is_wanted: bool = false
var ghost_fell_through: bool = false

# species comes from each species file via SpeciesRegistry
static func roll_modifier(species: String, is_unique: bool = false) -> CustomerModifier:
	var mod := CustomerModifier.new()
	if is_unique:
		return mod

	var sp := SpeciesRegistry.get_species(species)
	var can_be_ghost := sp.can_be_ghost if sp else true
	var can_be_wanted := sp.can_be_wanted if sp else true

	# 10 percent chance for ghost modifier if eligible
	#if can_be_ghost and randf() < 0.10:
	#	mod.modifier_type = ModifierType.GHOST
	#	mod.is_ghost = true
	#	return mod

	# 5 percent chance for wanted criminal modifier
	if can_be_wanted and randf() < 0.05:
		mod.modifier_type = ModifierType.WANTED
		mod.is_wanted = true
		return mod

	return mod

# adjusts sprite opacity for ghosts
func apply_visuals(npc: Sprite3D) -> void:
	if not is_instance_valid(npc):
		return
	#if is_ghost:
	#	npc.modulate.a = 0.55

# checks if a drink given to a ghost is spectral or falls through
func check_ghost_drink(_served_mix: DrinkMix) -> bool:
	#if not is_ghost:
	#	return true
	#if served_mix and served_mix.has_processing("spectral"):
	#	ghost_fell_through = false
	#	return true
	#ghost_fell_through = true
	#return false
	return true

# calculates tip modifiers for wanted bonuses or ghost penalties
func calculate_tip_modifier(base_tip: float) -> float:
	#if is_ghost and ghost_fell_through:
	#	return 0.0
	#if is_ghost and not ghost_fell_through:
	#	return base_tip * 1.5
	if is_wanted:
		return base_tip * 1.4
	return base_tip