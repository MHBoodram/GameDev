class_name FluidGridGLSL
extends RefCounted

const CLEAR_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer InVolume { ivec4 in_volume[]; };
layout(set = 0, binding = 1, std430) buffer OutVolume { ivec4 out_volume[]; };
layout(set = 0, binding = 2, std430) buffer Density { int density[]; };

void main() {
	uint idx = gl_GlobalInvocationID.x;
	if (idx >= 4096u) return;
	in_volume[idx] = ivec4(0);
	out_volume[idx] = ivec4(0);
	density[idx * 2u + 0u] = 0;
	density[idx * 2u + 1u] = 0;
}
"""

const GRID_OPS_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer InVolume { ivec4 in_volume[]; };
layout(set = 0, binding = 1, std430) buffer OutVolume { ivec4 out_volume[]; };
layout(set = 0, binding = 2, std430) buffer Density { int density[]; };
layout(set = 0, binding = 3, std430) readonly buffer WallSDF { vec4 wall_sdf[]; };

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

const int N = 64;
const float FIXED_SCALE = 16384.0;

void main() {
	uint idx = gl_GlobalInvocationID.x;
	if (idx >= uint(N * N)) return;

	float mass = float(density[idx * 2u + 1u]) / FIXED_SCALE;
	float cell_visc = clamp(pc.viscosity, 0.0, 1.0);
	vec2 v = vec2(0.0);
	if (mass > 0.001) {
		vec2 mom = vec2(in_volume[idx].xy) / FIXED_SCALE;
		float visc_mom = float(in_volume[idx].z) / FIXED_SCALE;
		cell_visc = clamp(max(pc.viscosity, visc_mom / mass), 0.0, 1.0);
		v = mom / mass;
		float base_damp = 0.25 + cell_visc * 8.0;
		v *= max(0.0, 1.0 - base_damp * pc.dt);
		v += pc.dt * vec2(pc.accel_x, pc.accel_y);
	}

	int x = int(idx % uint(N));
	int y = int(idx / uint(N));
	vec4 sdf = wall_sdf[idx];

	if (x <= 0 && v.x < 0.0) v.x = 0.0;
	if (x >= N - 1 && v.x > 0.0) v.x = 0.0;
	if (y <= 0 && v.y < 0.0) v.y = 0.0;
	if (y >= N - 1 && v.y > 0.0) v.y = 0.0;

	if (sdf.w < 0.5 || sdf.z < 0.5) {
		vec2 n = sdf.xy;
		float n_len = length(n);
		if (n_len > 0.001) {
			n /= n_len;
			float vn = dot(v, n);
			vec2 v_tan = v - n * vn;
			if (vn < 0.0) {
				vn = 0.0;
			}
			// No slip walls when cell_visc == 0.0
			float wall_rate = (sdf.w < 0.5) ? (cell_visc * 240.0) : (cell_visc * 90.0);
			v_tan *= exp(-pc.dt * wall_rate);
			if (sdf.w < 0.5 && sdf.z <= -3.0) {
				vn = 0.0;
				v_tan = vec2(0.0);
			}
			v = n * vn + v_tan;
		} else if (sdf.w < 0.5) {
			v = vec2(0.0);
		}
	}

	float speed = length(v);
	if (speed > 140.0) {
		v = (v / speed) * 140.0;
	}

	in_volume[idx] = ivec4(floatBitsToInt(v.x), floatBitsToInt(v.y), 0, 0);
	out_volume[idx] = ivec4(0);
	density[idx * 2u + 0u] = 0;
	density[idx * 2u + 1u] = 0;
}
"""

const DENSITY_SCATTER_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Particle {
	vec4 pos_props;
	vec4 color;
	vec4 init_vel;
};

layout(set = 0, binding = 0, std430) readonly buffer InVolume { ivec4 in_volume[]; };
layout(set = 0, binding = 1, std430) buffer Density { int density[]; };
layout(set = 0, binding = 2, std430) readonly buffer Particles { Particle particles[]; };
layout(set = 0, binding = 3, std430) readonly buffer WallSDF { vec4 wall_sdf[]; };

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

const int N = 64;
const float eps = 1e-4;
const float FIXED_SCALE = 16384.0;

uint getIdx(ivec2 p) {
	return uint(p.x + p.y * N);
}

vec4 sampleSDF(vec2 pos) {
	vec2 clamped = clamp(pos - 0.5, vec2(0.0), vec2(float(N) - 1.001));
	ivec2 p0 = ivec2(floor(clamped));
	vec2 f = clamped - vec2(p0);
	vec4 s00 = wall_sdf[getIdx(p0)];
	vec4 s10 = wall_sdf[getIdx(p0 + ivec2(1, 0))];
	vec4 s01 = wall_sdf[getIdx(p0 + ivec2(0, 1))];
	vec4 s11 = wall_sdf[getIdx(p0 + ivec2(1, 1))];
	vec4 sx0 = mix(s00, s10, f.x);
	vec4 sx1 = mix(s01, s11, f.x);
	vec4 res = mix(sx0, sx1, f.y);
	float nlen = length(res.xy);
	if (nlen > 1e-4) res.xy /= nlen;
	return res;
}

vec2 constrainToContainer(vec2 pos) {
	pos = clamp(pos, vec2(0.5 + eps), vec2(float(N) - (1.5 + eps)));
	vec4 sdf = sampleSDF(pos);
	float min_dist = 0.1;
	if (sdf.z < min_dist) {
		pos += sdf.xy * (min_dist - sdf.z);
		pos = clamp(pos, vec2(0.5 + eps), vec2(float(N) - (1.5 + eps)));
	}
	return pos;
}

void main() {
	uint pid = gl_GlobalInvocationID.x;
	if (pid >= pc.count_a) return;

	Particle part = particles[pid];
	float vol_w = part.pos_props.w;
	if (vol_w <= 0.0) return;

	vec2 pos = constrainToContainer(part.pos_props.xy);

	ivec2 base_coord = ivec2(pos - 0.5);
	vec2 fx = pos - vec2(base_coord);

	vec2 w[3];
	w[0] = 0.5 * (1.5 - fx) * (1.5 - fx);
	w[1] = 0.75 - (fx - 1.0) * (fx - 1.0);
	w[2] = 0.5 * (fx - 0.5) * (fx - 0.5);

	vec2 v = vec2(0.0);
	if (part.init_vel.z > 0.5) {
		v = part.init_vel.xy;
	} else {
		for (int x = 0; x < 3; x++)
		for (int y = 0; y < 3; y++) {
			float weight = w[x].x * w[y].y;
			uint idx = getIdx(base_coord + ivec2(x, y));
			vec2 gv = vec2(intBitsToFloat(in_volume[idx].x), intBitsToFloat(in_volume[idx].y));
			v += weight * gv;
		}
	}

	pos += clamp(pc.dt * v, vec2(-0.9), vec2(0.9));
	pos = constrainToContainer(pos);

	base_coord = ivec2(pos - 0.5);
	fx = pos - vec2(base_coord);

	w[0] = 0.5 * (1.5 - fx) * (1.5 - fx);
	w[1] = 0.75 - (fx - 1.0) * (fx - 1.0);
	w[2] = 0.5 * (fx - 0.5) * (fx - 0.5);

	float mass_w = vol_w * max(part.pos_props.z, 0.25);

	for (int x = 0; x < 3; x++)
	for (int y = 0; y < 3; y++) {
		float weight = w[x].x * w[y].y;
		uint idx = getIdx(base_coord + ivec2(x, y));
		int ivol = int(round(weight * vol_w * FIXED_SCALE));
		int imass = int(round(weight * mass_w * FIXED_SCALE));
		if (ivol != 0) atomicAdd(density[idx * 2u + 0u], ivol);
		if (imass != 0) atomicAdd(density[idx * 2u + 1u], imass);
	}
}
"""