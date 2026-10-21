shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

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
uniform float bottom_darkening : hint_range(0.0, 1.0) = 0.45;
uniform float liquid_transparency : hint_range(0.0, 1.0) = 0.9;
uniform float inner_margin_top : hint_range(0.0, 1.0) = 0.12;
uniform float inner_margin_bottom : hint_range(0.0, 1.0) = 0.88;
uniform float caustic_beam_strength : hint_range(0.0, 2.0) = 0.35;
uniform float sparkle_density : hint_range(0.0, 2.0) = 0.7;
uniform float glass_reflection_strength : hint_range(0.0, 1.0) = 0.28;
uniform float meniscus_curve : hint_range(0.0, 0.1) = 0.03;
uniform float gradient_offset = 0.0;
uniform bool flip_gradient = false;

void fragment() {
	vec4 glass_color = texture(texture_albedo, UV);

	if (glass_color.a < 0.02) {
		discard;
	}

	vec2 stepped_uv = floor(UV * pixel_resolution) / pixel_resolution;

	float wall_distance = abs(stepped_uv.x - 0.5) * 2.0;
	float wall_meniscus = pow(wall_distance, 3.5) * meniscus_curve;

	float base_surface_y = mix(inner_margin_bottom, inner_margin_top, clamp(fill_amount, 0.0, 1.0));
	float centered_x = stepped_uv.x - 0.5;
	float wave = sin(centered_x * 12.0 + wave_phase) * wave_amplitude + cos(centered_x * 24.0 - wave_phase * 1.6) * (wave_amplitude * 0.35);
	float surface_y = base_surface_y - centered_x * slosh_angle - slosh_vertical_offset - wall_meniscus + wave;
	float stepped_surface = floor(surface_y * pixel_resolution) / pixel_resolution;

	vec4 final_color = glass_color;

	if (fill_amount > 0.001 && stepped_uv.y >= stepped_surface && stepped_uv.y <= inner_margin_bottom) {
		float liquid_depth_ratio = clamp((stepped_uv.y - stepped_surface) / max(inner_margin_bottom - stepped_surface, 0.001), 0.0, 1.0);
		vec4 liquid_sample = texture(gradient_texture, vec2(clamp(liquid_depth_ratio, 0.01, 0.99), 0.5));

		vec3 liquid_rgb = liquid_sample.rgb * mix(1.15, 1.0 - bottom_darkening, liquid_depth_ratio);

		float beam_one = sin(stepped_uv.x * 28.0 + wave_phase * 0.4) * 0.5 + 0.5;
		float beam_two = sin(stepped_uv.x * 52.0 - wave_phase * 0.7) * 0.5 + 0.5;
		float caustic_shafts = pow(beam_one * beam_two, 2.0) * caustic_beam_strength * exp(-liquid_depth_ratio * 2.2);
		liquid_rgb += vec3(caustic_shafts);

		float pixel_random = fract(sin(dot(floor(stepped_uv * pixel_resolution), vec2(12.9898, 78.233))) * 43758.5453);
		float sparkle_cycle = fract(pixel_random * 7.0 + TIME * 0.9);
		if (pixel_random > 0.92) {
			float sparkle_pulse = smoothstep(0.3, 0.5, sparkle_cycle) * (1.0 - smoothstep(0.5, 0.7, sparkle_cycle));
			liquid_rgb += vec3(sparkle_pulse * sparkle_density);
		}

		float highlight_band = surface_highlight_thickness / pixel_resolution;
		if (stepped_uv.y < stepped_surface + highlight_band) {
			liquid_rgb = mix(liquid_rgb, surface_highlight_color.rgb, surface_highlight_color.a);
		} else if (stepped_uv.y < stepped_surface + highlight_band * 2.0) {
			liquid_rgb = mix(liquid_rgb, secondary_highlight_color.rgb, secondary_highlight_color.a * 0.6);
		}

		float diagonal_glare = clamp(1.0 - abs((stepped_uv.x * 1.3 + stepped_uv.y * 0.7) - 0.75) * 5.0, 0.0, 1.0);
		diagonal_glare = pow(diagonal_glare, 3.0) * glass_reflection_strength;
		liquid_rgb += vec3(diagonal_glare);

		vec3 blended_rgb = mix(liquid_rgb, glass_color.rgb, glass_color.a * 0.35);
		float blended_alpha = mix(liquid_transparency, 1.0, glass_color.a);
		final_color = vec4(blended_rgb, blended_alpha);
	} else if (glass_color.a > 0.02) {
		float diagonal_glare = clamp(1.0 - abs((stepped_uv.x * 1.3 + stepped_uv.y * 0.7) - 0.75) * 5.0, 0.0, 1.0);
		final_color.rgb += vec3(pow(diagonal_glare, 3.0) * glass_reflection_strength * 0.5);
	}

	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}