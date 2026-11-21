shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D density_tex : filter_nearest, repeat_disable;
uniform sampler2D color_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : filter_nearest, repeat_disable;
uniform sampler2D scene_depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

uniform vec2 fluid_vp_size = vec2(320.0, 180.0);
uniform float max_fluid_depth = 25.0;
uniform float iso_threshold = 0.42;
uniform float outline_alpha = 0.82;

float bayer4x4(ivec2 p) {
	int x0 = p.x & 1;
	int y0 = p.y & 1;
	int x1 = (p.x >> 1) & 1;
	int y1 = (p.y >> 1) & 1;
	int b0 = ((x0 ^ y0) << 1) | y0;
	int b1 = ((x1 ^ y1) << 1) | y1;
	return (float(b0 * 4 + b1) + 0.5) / 16.0;
}

float unpack_fluid_depth(vec2 rg) {
	float d_hi = round(rg.r * 255.0);
	float d_lo = round(rg.g * 255.0);
	return ((d_hi * 256.0 + d_lo) / 65535.0) * max_fluid_depth;
}

float get_scene_view_dist(vec2 uv, mat4 inv_proj) {
	float depth_raw = texture(scene_depth_tex, uv).r;
	vec3 ndc;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ndc = vec3(uv, depth_raw) * 2.0 - 1.0;
#else
	ndc = vec3(uv * 2.0 - 1.0, depth_raw);
#endif
	vec4 view_pos = inv_proj * vec4(ndc, 1.0);
	view_pos.xyz /= max(view_pos.w, 0.0001);
	return -view_pos.z;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

void fragment() {
	ivec2 max_p = max(ivec2(fluid_vp_size) - ivec2(1), ivec2(0));
	ivec2 p = clamp(ivec2(floor(SCREEN_UV * fluid_vp_size)), ivec2(0), max_p);

	vec4 d_center = texelFetch(density_tex, p, 0);
	float d = d_center.r;
	float scene_dist = get_scene_view_dist(SCREEN_UV, INV_PROJECTION_MATRIX);

	if (d < iso_threshold) {
		ivec2 n_coords[4] = ivec2[4](
			clamp(p + ivec2(1, 0), ivec2(0), max_p),
			clamp(p + ivec2(-1, 0), ivec2(0), max_p),
			clamp(p + ivec2(0, 1), ivec2(0), max_p),
			clamp(p + ivec2(0, -1), ivec2(0), max_p)
		);
		bool has_fluid_neighbor = false;
		vec3 neighbor_col = vec3(0.0);
		float neighbor_depth = max_fluid_depth;
		float neighbor_alpha = 1.0;

		for (int i = 0; i < 4; i++) {
			vec4 dn = texelFetch(density_tex, n_coords[i], 0);
			if (dn.r >= iso_threshold) {
				float nd = unpack_fluid_depth(texelFetch(depth_tex, n_coords[i], 0).rg);
				if (scene_dist + 0.0015 >= nd) {
					has_fluid_neighbor = true;
					vec4 nc = texelFetch(color_tex, n_coords[i], 0);
					neighbor_col = nc.rgb / max(nc.a, 0.001);
					neighbor_depth = nd;
					float n_spec = clamp(dn.b / max(dn.r, 0.001), 0.0, 1.0);
					neighbor_alpha = mix(outline_alpha, outline_alpha * 0.6, n_spec);
					break;
				}
			}
		}

		if (!has_fluid_neighbor) {
			discard;
		}
		ALBEDO = neighbor_col * 0.24;
		ALPHA = neighbor_alpha;
	} else {
		float fluid_dist = unpack_fluid_depth(texelFetch(depth_tex, p, 0).rg);
		if (scene_dist + 0.0015 < fluid_dist) {
			discard;
		}

		vec4 c_raw = texelFetch(color_tex, p, 0);
		vec3 base_col = c_raw.rgb / max(c_raw.a, 0.001);

		float foam_ratio = clamp(d_center.g / max(d, 0.001), 0.0, 1.0);
		float spectral_ratio = clamp(d_center.b / max(d, 0.001), 0.0, 1.0);

		float d_up1 = texelFetch(density_tex, clamp(p - ivec2(0, 2), ivec2(0), max_p), 0).r;
		float d_up2 = texelFetch(density_tex, clamp(p - ivec2(0, 4), ivec2(0), max_p), 0).r;
		float d_up3 = texelFetch(density_tex, clamp(p - ivec2(0, 7), ivec2(0), max_p), 0).r;

		float surface_depth = clamp(
			(d - iso_threshold) * 0.38
			+ min(d_up1, d) * 0.24
			+ min(d_up2, d) * 0.24
			+ min(d_up3, d) * 0.22
			- foam_ratio * 0.28,
			0.0,
			1.0
		);

		vec3 c_top = mix(base_col, vec3(1.0), 0.30);
		c_top = mix(c_top, vec3(0.99, 0.96, 0.85), clamp(foam_ratio * 0.85, 0.0, 1.0));
		vec3 c_mid = base_col * vec3(0.92, 0.93, 0.96);
		vec3 c_deep = base_col * vec3(0.58, 0.62, 0.72);

		if (spectral_ratio > 0.01) {
			vec3 spec_tint = vec3(0.42, 0.92, 1.0);
			c_top = mix(c_top, vec3(0.72, 1.0, 1.0), spectral_ratio * 0.55);
			c_mid = mix(c_mid, spec_tint, spectral_ratio * 0.45);
			c_deep = mix(c_deep, spec_tint * 0.65, spectral_ratio * 0.45);
		}

		float bayer = bayer4x4(p);
		float t01 = clamp((surface_depth - 0.14) / 0.34, 0.0, 1.0);
		vec3 final_col = (t01 > bayer) ? c_mid : c_top;

		float t12 = clamp((surface_depth - 0.58) / 0.34, 0.0, 1.0);
		if (t12 > bayer) {
			final_col = c_deep;
		}

		if (spectral_ratio > 0.05) {
			float shimmer = fract(sin(dot(vec2(p), vec2(12.9898, 78.233)) + floor(TIME * 6.0) * 1.37) * 43758.5453);
			if (shimmer > 0.94) {
				final_col = mix(final_col, vec3(0.85, 1.0, 1.0), spectral_ratio * 0.75);
			}
		}

		ALBEDO = final_col;
		ALPHA = mix(0.95, 0.58, spectral_ratio);
	}
}