shader_type spatial;
render_mode cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform sampler2D fluid_texture : source_color, filter_linear;

uniform float pixel_resolution = 48.0;
uniform vec4 surface_highlight_color : source_color = vec4(1.4, 1.4, 1.5, 1.0);
uniform vec4 secondary_highlight_color : source_color = vec4(0.9, 0.4, 0.95, 0.85);
uniform float surface_highlight_thickness = 1.2;
uniform float bottom_darkening = 0.45;
uniform float liquid_transparency = 0.9;
uniform float caustic_beam_strength = 0.35;
uniform float sparkle_density = 0.7;
uniform float glass_reflection_strength = 0.28;
uniform float meniscus_curve = 0.03;
uniform float inner_margin_top = 0.12;
uniform float inner_margin_bottom = 0.88;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}

	vec4 mask_sample = texture(texture_albedo, UV);
	float mask_alpha = mask_sample.a;
	if (mask_alpha < 0.05) {
		discard;
	}

	float res = max(pixel_resolution, 16.0);
	vec2 pix_uv = (floor(UV * res) + 0.5) / res;
	vec4 fluid = texture(fluid_texture, pix_uv);

	// Diagonal glass specular sheen across the container interior
	float diag = (pix_uv.x * 0.85 + pix_uv.y * 0.45);
	float sheen_band = smoothstep(0.08, 0.0, abs(diag - 0.52)) * 0.75 + smoothstep(0.04, 0.0, abs(diag - 0.68)) * 0.45;
	float rim_sheen = smoothstep(0.42, 0.49, abs(pix_uv.x - 0.5)) * 0.35;
	float glass_sheen = clamp(sheen_band + rim_sheen, 0.0, 1.0) * glass_reflection_strength;

	if (fluid.a < 0.08) {
		ALBEDO = vec3(0.92, 0.96, 1.0);
		ALPHA = glass_sheen * mask_alpha;
	} else {
		float step_uv = max(1.0 / res, 1.0 / 64.0) * max(surface_highlight_thickness, 0.5);

		float mask_up = texture(texture_albedo, clamp(pix_uv + vec2(0.0, -step_uv), 0.0, 1.0)).a;
		float mask_dn = texture(texture_albedo, clamp(pix_uv + vec2(0.0, step_uv), 0.0, 1.0)).a;
		float mask_lf = texture(texture_albedo, clamp(pix_uv + vec2(-step_uv, 0.0), 0.0, 1.0)).a;
		float mask_rt = texture(texture_albedo, clamp(pix_uv + vec2(step_uv, 0.0), 0.0, 1.0)).a;

		float flu_up = texture(fluid_texture, clamp(pix_uv + vec2(0.0, -step_uv), 0.0, 1.0)).a;
		float flu_dn = texture(fluid_texture, clamp(pix_uv + vec2(0.0, step_uv), 0.0, 1.0)).a;
		float flu_lf = texture(fluid_texture, clamp(pix_uv + vec2(-step_uv, 0.0), 0.0, 1.0)).a;
		float flu_rt = texture(fluid_texture, clamp(pix_uv + vec2(step_uv, 0.0), 0.0, 1.0)).a;

		bool air_up = (flu_up < 0.25) && (mask_up > 0.1 || pix_uv.y <= step_uv * 1.5);
		bool air_dn = (flu_dn < 0.25) && (mask_dn > 0.1);
		bool air_lf = (flu_lf < 0.25) && (mask_lf > 0.1);
		bool air_rt = (flu_rt < 0.25) && (mask_rt > 0.1);
		float is_surface = (air_up || air_dn || air_lf || air_rt) ? 1.0 : 0.0;

		float depth_factor = clamp((pix_uv.y - inner_margin_top) / max(inner_margin_bottom - inner_margin_top, 0.1), 0.0, 1.0);
		vec3 base_col = fluid.rgb * mix(1.0, 1.0 - bottom_darkening, depth_factor);

		// Subtle animated caustics & sparkles
		float beam = sin(pix_uv.x * 14.0 + TIME * 1.4 + pix_uv.y * 5.0) * 0.5 + 0.5;
		base_col += base_col * pow(beam, 3.0) * caustic_beam_strength * (1.0 - depth_factor * 0.5);

		float sp_cell = hash12(floor(pix_uv * res) + floor(TIME * 2.5) * 0.17);
		if (sp_cell > (1.0 - sparkle_density * 0.045)) {
			base_col += vec3(0.28);
		}

		// Highlight on simulated air-liquid free surface / wave crest
		vec3 surf_tint = mix(secondary_highlight_color.rgb, surface_highlight_color.rgb, air_up ? 1.0 : 0.55);
		vec3 lit_col = mix(base_col, max(base_col, surf_tint * 0.85), is_surface * 0.72);
		lit_col = mix(lit_col, vec3(0.95, 0.98, 1.0), glass_sheen * 0.55);

		ALBEDO = lit_col;
		ALPHA = clamp(fluid.a * liquid_transparency + glass_sheen * 0.35 + is_surface * 0.12, 0.0, 1.0) * mask_alpha;
	}
}