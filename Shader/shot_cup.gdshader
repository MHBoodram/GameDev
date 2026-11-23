shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform sampler2D gradient_texture : source_color, filter_nearest;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;
uniform float slosh_angle = 0.0;
uniform float slosh_vertical_offset = 0.0;
uniform float wave_phase = 0.0;
uniform float wave_amplitude = 0.0;
uniform float pixel_resolution = 48.0;

uniform vec4 surface_highlight_color : source_color = vec4(1.4, 1.4, 1.5, 1.0);
uniform vec4 secondary_highlight_color : source_color = vec4(0.9, 0.4, 0.95, 0.85);
uniform float surface_highlight_thickness = 1.2;
uniform float bottom_darkening = 0.45;
uniform float liquid_transparency = 0.9;

uniform float inner_margin_top = 0.12;
uniform float inner_margin_bottom = 0.88;
uniform float caustic_beam_strength = 0.35;
uniform float sparkle_density = 0.7;
uniform float glass_reflection_strength = 0.28;
uniform float meniscus_curve = 0.03;
uniform float gradient_offset = 0.0;
uniform bool flip_gradient = false;

uniform sampler2D fluid_field_texture : source_color, filter_nearest;
uniform bool use_fluid_field = false;
uniform float fluid_density_threshold = 0.34;
uniform vec2 local_up_uv = vec2(0.0, -1.0);
uniform vec4 liquid_tint_color : source_color = vec4(0.45, 0.92, 1.0, 1.0);
uniform float liquid_tint_strength = 0.0;

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

vec3 shade_pixel_fluid(vec3 base_col, float surface_depth_px, ivec2 cell, float edge_density) {
	float dither = mix(bayer4x4(cell), hash21(vec2(cell)), 0.42);
	float band_noise = (hash21(vec2(cell) * 0.5 + vec2(3.1, 7.4)) - 0.5) * 0.65;

	vec3 surface_col = clamp(base_col * 1.24 + vec3(0.08, 0.10, 0.12), vec3(0.0), vec3(1.0));
	vec3 mid_col = base_col;
	vec3 deep_col = base_col * (1.0 - clamp(bottom_darkening, 0.0, 0.95) * 0.52);

	float s_depth = surface_depth_px + band_noise;
	if (edge_density < fluid_density_threshold * 1.32) {
		return surface_col;
	}

	float t_surf = clamp((s_depth - 1.2) / 2.6, 0.0, 1.0);
	float t_deep = clamp((s_depth - 4.8) / 5.5, 0.0, 1.0);

	vec3 col = (dither < t_surf) ? mid_col : surface_col;
	if (t_deep > 0.0) {
		col = (dither < t_deep) ? deep_col : col;
	}
	return col;
}

void fragment() {
	vec4 mask_tex = texture(texture_albedo, UV);
	if (mask_tex.a < 0.1) {
		discard;
	}

	float res = max(pixel_resolution, 8.0);
	vec2 grid_uv = (floor(UV * res) + vec2(0.5)) / res;
	ivec2 cell = ivec2(floor(UV * res));
	float step_uv = 1.0 / res;

	if (use_fluid_field) {
		vec2 d_uv = vec2(grid_uv.x * 0.5, grid_uv.y);
		vec2 c_uv = vec2(0.5 + grid_uv.x * 0.5, grid_uv.y);

		float density = texture(fluid_field_texture, d_uv).r;
		if (density < fluid_density_threshold) {
			discard;
		}

		vec3 col_sum = texture(fluid_field_texture, c_uv).rgb;
		vec3 base_col = clamp(col_sum / max(density, 0.001), vec3(0.0), vec3(1.0));
		if (liquid_tint_strength > 0.001) {
			base_col = mix(base_col, liquid_tint_color.rgb, clamp(liquid_tint_strength, 0.0, 1.0));
		}

		vec2 up_dir = normalize(local_up_uv);
		vec2 side_dir = vec2(-up_dir.y, up_dir.x);

		float air_depth = 0.0;
		for (int i = 1; i <= 10; i++) {
			vec2 probe = clamp(grid_uv + up_dir * (float(i) * step_uv), vec2(0.001), vec2(0.999));
			float p_mask = texture(texture_albedo, probe).a;
			float p_dens = texture(fluid_field_texture, vec2(probe.x * 0.5, probe.y)).r;
			if (p_mask < 0.1 || p_dens < fluid_density_threshold) {
				break;
			}
			air_depth += 1.0;
		}

		float left_d = texture(fluid_field_texture, vec2(clamp(grid_uv + side_dir * step_uv, vec2(0.001), vec2(0.999)).x * 0.5, clamp(grid_uv + side_dir * step_uv, vec2(0.001), vec2(0.999)).y)).r;
		float right_d = texture(fluid_field_texture, vec2(clamp(grid_uv - side_dir * step_uv, vec2(0.001), vec2(0.999)).x * 0.5, clamp(grid_uv - side_dir * step_uv, vec2(0.001), vec2(0.999)).y)).r;
		if (left_d < fluid_density_threshold || right_d < fluid_density_threshold) {
			air_depth = min(air_depth, 1.4);
		}

		vec3 final_col = shade_pixel_fluid(base_col, air_depth, cell, density);
		float glass_edge = smoothstep(0.18, 0.08, abs(grid_uv.x - 0.22));
		final_col = mix(final_col, vec3(1.0), glass_edge * glass_reflection_strength * 0.35);

		ALBEDO = final_col;
		ALPHA = clamp(liquid_transparency * mask_tex.a, 0.0, 1.0);
	} else {
		if (fill_amount <= 0.001) {
			discard;
		}

		float bottom_y = clamp(inner_margin_bottom, 0.05, 1.0);
		float top_y = clamp(inner_margin_top, 0.0, bottom_y - 0.05);
		float fill_line_y = mix(bottom_y, top_y, clamp(fill_amount, 0.0, 1.0));

		float x_off = grid_uv.x - 0.5;
		float slosh_y = x_off * tan(clamp(slosh_angle, -1.2, 1.2));
		float wave_y = sin(grid_uv.x * 14.0 + wave_phase) * wave_amplitude;
		float meniscus = -meniscus_curve * pow(abs(x_off) * 2.0, 2.0);
		float surface_y = fill_line_y + slosh_vertical_offset + slosh_y + wave_y + meniscus;

		if (grid_uv.y < surface_y) {
			discard;
		}

		float norm_h = clamp((bottom_y - grid_uv.y) / max(bottom_y - surface_y, 0.001), 0.0, 1.0);
		float grad_u = flip_gradient ? (1.0 - norm_h) : norm_h;
		grad_u = clamp(grad_u + gradient_offset, 0.0, 1.0);
		vec3 base_col = texture(gradient_texture, vec2(grad_u, 0.5)).rgb;
		if (liquid_tint_strength > 0.001) {
			base_col = mix(base_col, liquid_tint_color.rgb, clamp(liquid_tint_strength, 0.0, 1.0));
		}

		float depth_px = max(0.0, (grid_uv.y - surface_y) * res);
		vec3 final_col = shade_pixel_fluid(base_col, depth_px, cell, fluid_density_threshold * 1.5);
		float glass_edge = smoothstep(0.18, 0.08, abs(grid_uv.x - 0.22));
		final_col = mix(final_col, vec3(1.0), glass_edge * glass_reflection_strength * 0.35);

		ALBEDO = final_col;
		ALPHA = clamp(liquid_transparency * mask_tex.a, 0.0, 1.0);
	}
}