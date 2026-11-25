class_name FluidComputeGLSL
extends RefCounted

const GRID_SIZE := 64
const GRID_CELLS := 4096
const MAX_PARTICLES := 16384
const WORKGROUP_SIZE := 64

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

static func get_shader_sources() -> Dictionary:
	return {
		"clear": FluidGridGLSL.CLEAR_GLSL,
		"grid_ops": FluidGridGLSL.GRID_OPS_GLSL,
		"density_scatter": FluidGridGLSL.DENSITY_SCATTER_GLSL,
		"fluid": FluidAdvectGLSL.FLUID_GLSL,
		"display_clear": FluidDisplayGLSL.DISPLAY_CLEAR_GLSL,
		"display_splat": FluidDisplayGLSL.DISPLAY_SPLAT_GLSL,
		"display_resolve": FluidDisplayGLSL.DISPLAY_RESOLVE_GLSL,
		"cull_hist": FluidCullGLSL.CULL_HIST_GLSL,
		"cull_scan": FluidCullGLSL.CULL_SCAN_GLSL,
		"cull_compact": FluidCullGLSL.CULL_COMPACT_GLSL,
		"cull_copyback": FluidCullGLSL.CULL_COPYBACK_GLSL,
		"blend": FluidAdvectGLSL.BLEND_PARTICLES_GLSL,
	}