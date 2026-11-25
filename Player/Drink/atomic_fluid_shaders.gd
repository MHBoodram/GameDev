class_name AtomicFluidShaders
extends RefCounted

const GRID_SIZE := 64
const GRID_CELLS := 4096
const MAX_PARTICLES := 16384
const WORKGROUP_SIZE := 64
const REFERENCE_CUP_SIZE := 10.0

const LIQUID_COLOR := {
	"gin": Color(0.0, 0.953, 0.0, 1.0),
	"beer": Color(0.98, 0.322, 0.051, 1.0),
	"spirit": Color(0.542, 0.691, 1.0, 1.0),
	"vodka": Color(0.137, 0.372, 1.0, 1.0),
	"rum": Color(0.458, 0.154, 0.014, 1.0),
	"tequila": Color(0.9, 0.85, 0.3, 1.0),
	"whiskey": Color(0.78, 0.42, 0.1, 1.0),
	"blood": Color(0.85, 0.05, 0.05, 1.0)
}

const LIQUID_BUOYANCY := {
	"spirit": 1.65,
	"beer": 1.42,
	"gin": 1.24,
	"vodka": 1.08,
	"tequila": 0.94,
	"whiskey": 0.80,
	"rum": 0.68,
	"blood": 0.52
}

const LIQUID_VISCOSITY := {
	"spirit": 0.0,
	"beer": 0.0,
	"gin": 0.0,
	"vodka": 0.0,
	"tequila": 0.0,
	"whiskey": 0.0,
	"rum": 0.0,
	"blood": 0.0
}

const LIQUID_PRICE_PER_CUP_PERCENT := {
	"gin": 0.1,
	"beer": 0.1,
	"rum": 0.1,
	"vodka": 0.1,
	"tequila": 0.1,
	"whiskey": 0.1,
	"spirit": 0.1,
	"blood": 0.1
}

static var _custom_buoyancy: Dictionary = {}
static var _custom_viscosity: Dictionary = {}
static var _custom_price_per_cup_percent: Dictionary = {}

static func register_liquid_price(id: String, price_val: float) -> void:
	if price_val >= 0.0:
		_custom_price_per_cup_percent[id] = price_val

static func get_liquid_price_per_cup_percent(id: String) -> float:
	if _custom_price_per_cup_percent.has(id):
		return float(_custom_price_per_cup_percent[id])
	if LIQUID_PRICE_PER_CUP_PERCENT.has(id):
		return float(LIQUID_PRICE_PER_CUP_PERCENT[id])
	return 0.1

static func register_liquid_buoyancy(id: String, buoyancy_val: float) -> void:
	if buoyancy_val > 0.0:
		_custom_buoyancy[id] = buoyancy_val

static func get_liquid_buoyancy(id: String) -> float:
	if _custom_buoyancy.has(id):
		return float(_custom_buoyancy[id])
	if LIQUID_BUOYANCY.has(id):
		return float(LIQUID_BUOYANCY[id])
	var h: int = abs(hash(id)) % 1000
	return 0.60 + (float(h) / 999.0) * 0.95

static func get_layer_buoyancy(layer: Array, buoyancy_overrides: Dictionary = {}) -> float:
	if layer.is_empty():
		return 1.0

	if not (layer[0] is Array or layer[0] is Dictionary):
		var id := str(layer[0])
		if buoyancy_overrides.has(id):
			return clampf(float(buoyancy_overrides[id]), 0.35, 2.5)
		return clampf(get_liquid_buoyancy(id), 0.35, 2.5)

	var ing_weights: Dictionary = {}
	if layer.size() > 3 and layer[3] is Dictionary and not (layer[3] as Dictionary).is_empty():
		ing_weights = layer[3]
	elif layer[0] is Dictionary:
		ing_weights = layer[0]
	elif layer[0] is Array:
		var arr: Array = layer[0]
		if arr.is_empty():
			return 1.0
		var amt := float(layer[1]) if layer.size() > 1 else 1.0
		var split_w := maxf(amt, 1.0) / float(arr.size())
		for k in arr:
			var ks := str(k)
			ing_weights[ks] = ing_weights.get(ks, 0.0) + split_w

	var w_sum := 0.0
	var rho_sum := 0.0
	for k in ing_weights.keys():
		var ks := str(k)
		var kw := maxf(float(ing_weights[k]), 0.0)
		if kw <= 0.0:
			continue
		var kb := float(buoyancy_overrides.get(ks, get_liquid_buoyancy(ks)))
		w_sum += kw
		rho_sum += kw * (1.0 / clampf(kb, 0.35, 2.5))

	if w_sum <= 0.0001:
		return 1.0
	return clampf(w_sum / rho_sum, 0.35, 2.5)

static func register_liquid_viscosity(id: String, viscosity_val: float) -> void:
	if viscosity_val >= 0.0:
		_custom_viscosity[id] = clampf(viscosity_val, 0.0, 1.0)

static func get_liquid_viscosity(id: String) -> float:
	if _custom_viscosity.has(id):
		return clampf(float(_custom_viscosity[id]), 0.0, 1.0)
	if LIQUID_VISCOSITY.has(id):
		return clampf(float(LIQUID_VISCOSITY[id]), 0.0, 1.0)
	return 0.0

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
		v *= exp(-base_damp * pc.dt);
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
			// Slip-free walls when cell_visc == 0.0
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
	float max_pressure = min(40000.0, 35.0 / max(4.0 * pc.dt * vol_w, 0.0001));
	float pressure = clamp(pc.stiffness * (d_rho + 1.2 * d_rho * d_rho), 0.0, max_pressure);
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

const DISPLAY_CLEAR_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer InVolume { ivec4 in_volume[]; };
layout(set = 0, binding = 1, std430) buffer MouthState { uint mouth_data[4]; };

void main() {
	uint idx = gl_GlobalInvocationID.x;
	if (idx >= 4096u) return;
	in_volume[idx] = ivec4(0);
	if (idx == 0u) {
		mouth_data[0] = 0u;
		mouth_data[1] = 0u;
		mouth_data[2] = 0u;
		mouth_data[3] = 0u;
	}
}
"""

const DISPLAY_SPLAT_GLSL := """#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Particle {
	vec4 pos_props;
	vec4 color;
	vec4 init_vel;
};

layout(set = 0, binding = 0, std430) buffer InVolume { ivec4 in_volume[]; };
layout(set = 0, binding = 1, std430) readonly buffer Particles { Particle particles[]; };

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

void main() {
	uint pid = gl_GlobalInvocationID.x;
	if (pid >= pc.count_a) return;

	Particle part = particles[pid];
	if (part.pos_props.w <= 0.0) return;

	vec2 pos = part.pos_props.xy;
	vec3 col = part.color.rgb;
	ivec2 center = ivec2(floor(pos));
	const float radius = 1.05;
	const float r2 = radius * radius;

	for (int dy = -1; dy <= 1; dy++) {
		int py = center.y + dy;
		if (py < 0 || py >= N) continue;
		for (int dx = -1; dx <= 1; dx++) {
			int px = center.x + dx;
			if (px < 0 || px >= N) continue;
			vec2 d = pos - (vec2(float(px), float(py)) + 0.5);
			float dist2 = dot(d, d);
			if (dist2 < r2) {
				float w = 1.0 - dist2 / r2;
				w *= w;
				int iw = int(round(w * 1024.0));
				if (iw > 0) {
					uint idx = uint(px + py * N);
					atomicAdd(in_volume[idx].x, int(round(col.r * w * 1024.0)));
					atomicAdd(in_volume[idx].y, int(round(col.g * w * 1024.0)));
					atomicAdd(in_volume[idx].z, int(round(col.b * w * 1024.0)));
					atomicAdd(in_volume[idx].w, iw);
				}
			}
		}
	}
}
"""

const DISPLAY_RESOLVE_GLSL := """#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) readonly buffer InVolume { ivec4 in_volume[]; };
layout(set = 0, binding = 1, std430) readonly buffer WallSDF { vec4 wall_sdf[]; };
layout(rgba8, set = 0, binding = 2) uniform writeonly image2D out_image;
layout(set = 0, binding = 3, std430) buffer MouthState { uint mouth_data[4]; };

const int N = 64;

void main() {
	ivec2 xy = ivec2(gl_GlobalInvocationID.xy);
	if (xy.x >= N || xy.y >= N) return;

	uint idx = uint(xy.x + xy.y * N);
	float inside = wall_sdf[idx].w;
	ivec4 acc = in_volume[idx];

	if (inside < 0.5 || acc.w <= 16) {
		imageStore(out_image, xy, vec4(0.0));
		return;
	}

	if (inside > 1.5 && acc.w >= 40) {
		atomicAdd(mouth_data[0], 1u);
		atomicAdd(mouth_data[1], uint(acc.w));
		atomicMax(mouth_data[2], uint(acc.w));
	}

	vec3 rgb = clamp(vec3(acc.xyz) / float(acc.w), 0.0, 1.0);
	float alpha = clamp((float(acc.w) / 1024.0) * 1.65, 0.0, 1.0);
	imageStore(out_image, xy, vec4(rgb, alpha));
}
"""

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