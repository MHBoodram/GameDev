class_name FluidCullGLSL
extends RefCounted

const CULL_HIST_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Particle {
	vec4 pos_props;
	vec4 color;
	vec4 init_vel;
};

layout(set = 0, binding = 0, std430) readonly buffer Particles { Particle particles[]; };
layout(set = 0, binding = 1, std430) buffer CullMeta {
	uint hist[64];
	uint cutoff_bin;
	uint cutoff_quota;
	uint cutoff_taken;
	uint out_count;
} meta;

layout(push_constant, std430) uniform PushConstants {
	float dt;
	float accel_x;
	float accel_y;
	float viscosity;
	float gravity;
	float stiffness;
	float rest_density;
	uint count_a;
} pc;

int getProjBin(vec2 pos, float rho_p, vec2 down_dir) {
	vec2 centered = (pos - vec2(32.0)) / 32.0;
	float proj_up = dot(centered, -down_dir);
	float buoy_bias = clamp((rho_p - 1.0) * 0.05, -0.06, 0.06);
	float norm = clamp(0.5 - proj_up * 0.45 + buoy_bias, 0.0, 0.9999);
	return clamp(int(norm * 64.0), 0, 63);
}

void main() {
	uint pid = gl_GlobalInvocationID.x;
	if (pid >= pc.count_a) return;

	vec2 accel_vec = vec2(pc.accel_x, pc.accel_y);
	float alen = length(accel_vec);
	vec2 down_dir = (alen > 0.01) ? (accel_vec / alen) : vec2(0.0, 1.0);
	int bin = getProjBin(particles[pid].pos_props.xy, particles[pid].pos_props.z, down_dir);
	atomicAdd(meta.hist[bin], 1u);
}
"""

const CULL_SCAN_GLSL := """#version 450
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer CullMeta {
	uint hist[64];
	uint cutoff_bin;
	uint cutoff_quota;
	uint cutoff_taken;
	uint out_count;
} meta;

layout(push_constant, std430) uniform PushConstants {
	float dt;
	float accel_x;
	float accel_y;
	float viscosity;
	float gravity;
	float stiffness;
	float rest_density;
	uint count_a;
} pc;

void main() {
	uint remove_count = pc.count_a;
	uint accum = 0u;
	uint cut_b = 64u;
	uint cut_q = 0u;

	for (uint b = 0u; b < 64u; b++) {
		uint h = meta.hist[b];
		if (accum + h >= remove_count) {
			cut_b = b;
			cut_q = remove_count - accum;
			break;
		}
		accum += h;
	}

	meta.cutoff_bin = cut_b;
	meta.cutoff_quota = cut_q;
	meta.cutoff_taken = 0u;
	meta.out_count = 0u;
}
"""

const CULL_COMPACT_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Particle {
	vec4 pos_props;
	vec4 color;
	vec4 init_vel;
};

layout(set = 0, binding = 0, std430) readonly buffer Particles { Particle particles[]; };
layout(set = 0, binding = 1, std430) buffer CullMeta {
	uint hist[64];
	uint cutoff_bin;
	uint cutoff_quota;
	uint cutoff_taken;
	uint out_count;
} meta;
layout(set = 0, binding = 2, std430) writeonly buffer Scratch { Particle scratch[]; };

layout(push_constant, std430) uniform PushConstants {
	float dt;
	float accel_x;
	float accel_y;
	float viscosity;
	float gravity;
	float stiffness;
	float rest_density;
	uint count_a;
} pc;

int getProjBin(vec2 pos, float rho_p, vec2 down_dir) {
	vec2 centered = (pos - vec2(32.0)) / 32.0;
	float proj_up = dot(centered, -down_dir);
	float buoy_bias = clamp((rho_p - 1.0) * 0.05, -0.06, 0.06);
	float norm = clamp(0.5 - proj_up * 0.45 + buoy_bias, 0.0, 0.9999);
	return clamp(int(norm * 64.0), 0, 63);
}

void main() {
	uint pid = gl_GlobalInvocationID.x;
	if (pid >= pc.count_a) return;

	vec2 accel_vec = vec2(pc.accel_x, pc.accel_y);
	float alen = length(accel_vec);
	vec2 down_dir = (alen > 0.01) ? (accel_vec / alen) : vec2(0.0, 1.0);
	uint bin = uint(getProjBin(particles[pid].pos_props.xy, particles[pid].pos_props.z, down_dir));

	if (bin < meta.cutoff_bin) {
		return;
	}
	if (bin == meta.cutoff_bin) {
		uint taken = atomicAdd(meta.cutoff_taken, 1u);
		if (taken < meta.cutoff_quota) {
			return;
		}
	}

	uint dst = atomicAdd(meta.out_count, 1u);
	scratch[dst] = particles[pid];
}
"""

const CULL_COPYBACK_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Particle {
	vec4 pos_props;
	vec4 color;
	vec4 init_vel;
};

layout(set = 0, binding = 0, std430) writeonly buffer Particles { Particle particles[]; };
layout(set = 0, binding = 1, std430) readonly buffer Scratch { Particle scratch[]; };

layout(push_constant, std430) uniform PushConstants {
	float dt;
	float accel_x;
	float accel_y;
	float viscosity;
	float gravity;
	float stiffness;
	float rest_density;
	uint count_a;
} pc;

void main() {
	uint pid = gl_GlobalInvocationID.x;
	if (pid >= pc.count_a) return;
	particles[pid] = scratch[pid];
}
"""