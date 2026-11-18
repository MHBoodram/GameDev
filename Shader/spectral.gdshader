shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_disable;
uniform vec4 spectral_color : source_color = vec4(0.45, 0.92, 1.0, 1.0);
uniform vec4 secondary_glow_color : source_color = vec4(0.55, 0.65, 1.0, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.56;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.65;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.45;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.6;
uniform float wisp_strength : hint_range(0.0, 0.5) = 0.14;
uniform float bottom_fade_strength : hint_range(0.0, 1.0) = 0.35;
uniform float float_amplitude : hint_range(0.0, 0.2) = 0.03;
uniform float sway_amplitude : hint_range(0.0, 0.2) = 0.018;
uniform float use_vertex_color : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float bob = sin(TIME * wave_speed) * float_amplitude;
	float sway = sin(TIME * (wave_speed * 1.35) + VERTEX.y * 4.5) * sway_amplitude;
	VERTEX.y += bob;
	VERTEX.x += sway;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	if (tex.a <= 0.01) {
		discard;
	}

	vec3 vert_rgb = mix(vec3(1.0), COLOR.rgb, use_vertex_color);
	float vert_alpha = mix(1.0, COLOR.a, use_vertex_color);

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	// Animated wisps without shifting UV.x across sprite-sheet frames
	float wisp_a = sin(UV.y * 18.0 + TIME * wave_speed * 1.4 + sin(UV.x * 12.0 + TIME));
	float wisp_b = cos(UV.y * 9.0 - TIME * wave_speed * 0.9 + UV.x * 8.0);
	float wisp = 0.5 + 0.5 * (wisp_a * 0.6 + wisp_b * 0.4);

	vec3 aura_tint = mix(spectral_color.rgb, secondary_glow_color.rgb, wisp * 0.45);
	vec3 tinted_rgb = aura_tint * mix(0.55, 1.35, luma);
	vec3 final_rgb = mix(tex.rgb, tinted_rgb, tint_strength) * vert_rgb;

	float top_factor = smoothstep(0.0, 0.35, 1.0 - UV.y);
	float bottom_fade = mix(1.0 - bottom_fade_strength, 1.0, top_factor);
	float pulse = 1.0 + (wisp - 0.5) * 2.0 * wisp_strength;

	ALBEDO = final_rgb;
	EMISSION = final_rgb * (emission_strength * (0.75 + 0.5 * wisp));
	ALPHA = clamp(tex.a * vert_alpha * base_alpha * bottom_fade * pulse, 0.0, 0.92);
}