shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D fluid_density_tex : source_color, filter_nearest;
uniform sampler2D fluid_color_tex : source_color, filter_nearest;
uniform sampler2D fluid_depth_tex : source_color, filter_nearest;

uniform vec2 grid_resolution = vec2(320.0, 180.0);
uniform float density_threshold = 0.34;
uniform float fluid_alpha = 0.92;
uniform float depth_range = 12.0;
uniform float depth_bias = 0.045;

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

float bayer4x4(ivec2 p) {
	int x = ((p.x % 4) + 4) % 4;
	int y = ((p.y % 4) + 4) % 4;
	int idx = x + y * 4;
	const float m[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0
	);
	return m[idx] / 16.0;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 res = max(grid_resolution, vec2(32.0));
	vec2 q_uv = (floor(SCREEN_UV * res) + vec2(0.5)) / res;
	ivec2 cell = ivec2(floor(SCREEN_UV * res));

	float density = texture(fluid_density_tex, q_uv).r;
	if (density < density_threshold) {
		discard;
	}

	vec4 d_sample = texture(fluid_depth_tex, q_uv);
	if (d_sample.b > 0.5) {
		float fluid_dist = d_sample.r * depth_range;
		float raw_d = texture(depth_tex, SCREEN_UV).r;
		vec4 p_zero = INV_PROJECTION_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
		vec4 p_one = INV_PROJECTION_MATRIX * vec4(0.0, 0.0, 1.0, 1.0);
		bool reverse_z = abs(p_one.z / p_one.w) < abs(p_zero.z / p_zero.w);
		float ndc_z = reverse_z ? raw_d : (raw_d * 2.0 - 1.0);
		vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, ndc_z, 1.0);
		float scene_dist = -scene_view.z / scene_view.w;
		if (fluid_dist > scene_dist + depth_bias) {
			discard;
		}
	}

	vec3 col_sum = texture(fluid_color_tex, q_uv).rgb;
	vec3 base_col = clamp(col_sum / max(density, 0.001), vec3(0.0), vec3(1.0));

	float step_y = 1.0 / res.y;
	float step_x = 1.0 / res.x;
	float air_depth = 0.0;
	for (int i = 1; i <= 10; i++) {
		vec2 probe = vec2(q_uv.x, q_uv.y - float(i) * step_y);
		if (probe.y < 0.0 || texture(fluid_density_tex, probe).r < density_threshold) {
			break;
		}
		air_depth += 1.0;
	}

	float left_d = texture(fluid_density_tex, vec2(q_uv.x - step_x, q_uv.y)).r;
	float right_d = texture(fluid_density_tex, vec2(q_uv.x + step_x, q_uv.y)).r;
	if (left_d < density_threshold || right_d < density_threshold) {
		air_depth = min(air_depth, 1.4);
	}

	vec3 surface_col = clamp(base_col * 1.24 + vec3(0.08, 0.10, 0.12), vec3(0.0), vec3(1.0));
	vec3 mid_col = base_col;
	vec3 deep_col = base_col * 0.76;

	float dither = mix(bayer4x4(cell), hash21(vec2(cell)), 0.42);
	float band_noise = (hash21(vec2(cell) * 0.5 + vec2(3.1, 7.4)) - 0.5) * 0.65;
	float s_depth = air_depth + band_noise;

	vec3 final_col;
	if (density < density_threshold * 1.32) {
		final_col = surface_col;
	} else {
		float t_surf = clamp((s_depth - 1.2) / 2.6, 0.0, 1.0);
		float t_deep = clamp((s_depth - 4.8) / 5.5, 0.0, 1.0);
		final_col = (dither < t_surf) ? mid_col : surface_col;
		if (t_deep > 0.0) {
			final_col = (dither < t_deep) ? deep_col : final_col;
		}
	}

	ALBEDO = final_col;
	ALPHA = fluid_alpha;
}