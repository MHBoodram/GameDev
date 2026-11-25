class_name AtomicFluidShaders
extends RefCounted

# Compatibility

const GRID_SIZE := FluidComputeGLSL.GRID_SIZE
const GRID_CELLS := FluidComputeGLSL.GRID_CELLS
const MAX_PARTICLES := FluidComputeGLSL.MAX_PARTICLES
const WORKGROUP_SIZE := FluidComputeGLSL.WORKGROUP_SIZE

const LIQUID_COLOR := LiquidProperties.LIQUID_COLOR
const LIQUID_BUOYANCY := LiquidProperties.LIQUID_BUOYANCY
const LIQUID_VISCOSITY := LiquidProperties.LIQUID_VISCOSITY

const CLEAR_GLSL := FluidGridGLSL.CLEAR_GLSL
const GRID_OPS_GLSL := FluidGridGLSL.GRID_OPS_GLSL
const DENSITY_SCATTER_GLSL := FluidGridGLSL.DENSITY_SCATTER_GLSL
const FLUID_GLSL := FluidAdvectGLSL.FLUID_GLSL
const DISPLAY_CLEAR_GLSL := FluidDisplayGLSL.DISPLAY_CLEAR_GLSL
const DISPLAY_SPLAT_GLSL := FluidDisplayGLSL.DISPLAY_SPLAT_GLSL
const DISPLAY_RESOLVE_GLSL := FluidDisplayGLSL.DISPLAY_RESOLVE_GLSL
const CULL_HIST_GLSL := FluidCullGLSL.CULL_HIST_GLSL
const CULL_SCAN_GLSL := FluidCullGLSL.CULL_SCAN_GLSL
const CULL_COMPACT_GLSL := FluidCullGLSL.CULL_COMPACT_GLSL
const CULL_COPYBACK_GLSL := FluidCullGLSL.CULL_COPYBACK_GLSL
const BLEND_PARTICLES_GLSL := FluidAdvectGLSL.BLEND_PARTICLES_GLSL

static func register_liquid_buoyancy(id: String, buoyancy_val: float) -> void:
	LiquidProperties.register_liquid_buoyancy(id, buoyancy_val)

static func get_liquid_buoyancy(id: String) -> float:
	return LiquidProperties.get_liquid_buoyancy(id)

static func get_layer_buoyancy(layer: Array, buoyancy_overrides: Dictionary = {}) -> float:
	return LiquidProperties.get_layer_buoyancy(layer, buoyancy_overrides)

static func register_liquid_viscosity(id: String, viscosity_val: float) -> void:
	LiquidProperties.register_liquid_viscosity(id, viscosity_val)

static func get_liquid_viscosity(id: String) -> float:
	return LiquidProperties.get_liquid_viscosity(id)