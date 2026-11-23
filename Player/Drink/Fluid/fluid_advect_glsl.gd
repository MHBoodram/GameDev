class_name FluidAdvectGLSL
extends RefCounted

const FLUID_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Particle {
	vec4 pos_props;
	vec4 color;
	vec4 init_vel;
};

layout(set = 0, binding = 0, std430) readonly buffer InVolume { ivec4 in_volume[]; };
layout(set = 0, binding = 1, std430) buffer OutVolume { ivec4 out_volume[]; };
layout(set = 0, binding = 2, std430) readonly buffer Density { int density[]; };
layout(set = 0, binding = 3, std430) buffer Particles { Particle particles[]; };
layout(set = 0, binding = 4, std430) readonly buffer WallSDF { vec4 wall_sdf[]; };

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

	float p_visc = clamp(max(part.init_vel.w, pc.viscosity), 0.0, 1.0);
	vec2 pos = constrainToContainer(part.pos_props.xy);

	ivec2 base_coord = ivec2(pos - 0.5);
	vec2 fx = pos - vec2(base_coord);

	vec2 w[3];
	w[0] = 0.5 * (1.5 - fx) * (1.5 - fx);
	w[1] = 0.75 - (fx - 1.0) * (fx - 1.0);
	w[2] = 0.5 * (fx - 0.5) * (fx - 0.5);

	vec2 v = vec2(0.0);
	mat2 C = mat2(0.0);
	if (part.init_vel.z > 0.5) {
		v = part.init_vel.xy;
		particles[pid].init_vel.z = 0.0;
	} else {
		for (int x = 0; x < 3; x++)
		for (int y = 0; y < 3; y++) {
			vec2 dpos = vec2(float(x), float(y)) - fx;
			float weight = w[x].x * w[y].y;
			uint idx = getIdx(base_coord + ivec2(x, y));
			vec2 gv = vec2(intBitsToFloat(in_volume[idx].x), intBitsToFloat(in_volume[idx].y));
			vec2 vel = weight * gv;
			v += vel;
			C += 4.0 * outerProduct(vel, dpos);
		}
	}

	pos += clamp(pc.dt * v, vec2(-0.9), vec2(0.9));
	pos = constrainToContainer(pos);

	base_coord = ivec2(pos - 0.5);
	fx = pos - vec2(base_coord);

	w[0] = 0.5 * (1.5 - fx) * (1.5 - fx);
	w[1] = 0.75 - (fx - 1.0) * (fx - 1.0);
	w[2] = 0.5 * (fx - 0.5) * (fx - 0.5);

	float vol_den = 0.0;
	float mass_den = 0.0;
	for (int x = 0; x < 3; x++)
	for (int y = 0; y < 3; y++) {
		float weight = w[x].x * w[y].y;
		uint idx = getIdx(base_coord + ivec2(x, y));
		vol_den += weight * (float(density[idx * 2u + 0u]) / FIXED_SCALE);
		mass_den += weight * (float(density[idx * 2u + 1u]) / FIXED_SCALE);
	}

	float rho_p = max(part.pos_props.z, 0.25);
	vec2 accel_vec = vec2(pc.accel_x, pc.accel_y);
	float accel_len = length(accel_vec);
	if (vol_den > 0.25 && accel_len > 0.1) {
		float local_rho = mass_den / max(vol_den, 0.001);
		vec2 down_dir = accel_vec / accel_len;
		float rel_diff = clamp((rho_p - local_rho) / rho_p, -1.0, 1.0);
		float buoy_speed = max(0.0, 40.0 - p_visc * 34.0);
		vec2 slip = down_dir * (rel_diff * buoy_speed);
		pos += clamp(pc.dt * slip, vec2(-0.45), vec2(0.45));
		pos = constrainToContainer(pos);

		base_coord = ivec2(pos - 0.5);
		fx = pos - vec2(base_coord);
		w[0] = 0.5 * (1.5 - fx) * (1.5 - fx);
		w[1] = 0.75 - (fx - 1.0) * (fx - 1.0);
		w[2] = 0.5 * (fx - 0.5) * (fx - 0.5);
	}

	particles[pid].pos_props.xy = pos;

	float d_rho = max(0.0, vol_den - pc.rest_density);
	float pressure = clamp(pc.stiffness * (d_rho + 1.2 * d_rho * d_rho), 0.0, 40000.0);
	float m_p = vol_w * rho_p;

	// Stop divergence
	mat2 C_t = transpose(C);
	mat2 C_sym = 0.5 * (C + C_t);
	mat2 C_rot = 0.5 * (C - C_t);
	float div_v = C[0][0] + C[1][1];
	mat2 C_dev = C_sym - mat2(0.5 * div_v, 0.0, 0.0, 0.5 * div_v);

	float shear_keep = exp(-pc.dt * mix(2.5, 450.0, p_visc));
	float rot_keep = exp(-pc.dt * mix(1.0, 200.0, p_visc));
	mat2 C_eff = C_dev * shear_keep + C_rot * rot_keep;

	float stress_p = 4.0 * pc.dt * vol_w * pressure;
	mat2 affine = mat2(stress_p, 0.0, 0.0, stress_p) + m_p * C_eff;

	for (int x = 0; x < 3; x++)
	for (int y = 0; y < 3; y++) {
		vec2 dpos = vec2(float(x), float(y)) - fx;
		float weight = w[x].x * w[y].y;
		uint idx = getIdx(base_coord + ivec2(x, y));
		vec2 vel_x_mass = weight * (m_p * v + affine * dpos);
		int imx = int(round(vel_x_mass.x * FIXED_SCALE));
		int imy = int(round(vel_x_mass.y * FIXED_SCALE));
		int ivisc = int(round(weight * m_p * p_visc * FIXED_SCALE));
		if (imx != 0) atomicAdd(out_volume[idx].x, imx);
		if (imy != 0) atomicAdd(out_volume[idx].y, imy);
		if (ivisc != 0) atomicAdd(out_volume[idx].z, ivisc);
	}
}
"""

const BLEND_PARTICLES_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Particle {
	vec4 pos_props;
	vec4 color;
	vec4 init_vel;
};

layout(set = 0, binding = 0, std430) buffer Particles { Particle particles[]; };

layout(push_constant, std430) uniform PushConstants {
	float color_r;
	float color_g;
	float color_b;
	float target_density;
	float target_viscosity;
	float stiffness;
	float rest_density;
	uint count_a;
} pc;

void main() {
	uint pid = gl_GlobalInvocationID.x;
	if (pid >= pc.count_a) return;
	particles[pid].pos_props.z = pc.target_density;
	particles[pid].color = vec4(pc.color_r, pc.color_g, pc.color_b, 1.0);
	particles[pid].init_vel.w = pc.target_viscosity;
}
"""