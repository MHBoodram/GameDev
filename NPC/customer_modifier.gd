# Backward-compatible bridge for customer modifiers to ModifierRegistry
class_name CustomerModifier
extends ModifierBase

enum ModifierType { NONE, GHOST, WANTED }

static func roll_modifier(species: String, is_unique: bool = false) -> ModifierBase:
	return ModifierRegistry.roll_modifier(species, is_unique, PlayerStats)

static func clear_visuals(npc: Sprite3D) -> void:
	ModifierRegistry.clear_npc_visuals(npc)