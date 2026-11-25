class_name FluidDisplayGLSL
extends RefCounted

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