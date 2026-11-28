shader_type canvas_item;

uniform float wave_strength : hint_range(0.0, 0.1) = 0.03;
uniform float wave_speed : hint_range(0.0, 15.0) = 1.2;
uniform float outline_size : hint_range(0.0, 4.0) = 2.5;
uniform float shimmer_width : hint_range(0.0, 0.3) = 0.15;
uniform float glow_base : hint_range(0.0, 1.0) = 0.35;
uniform float outline_opacity : hint_range(0.0, 1.0) = 0.9;
uniform vec4 base_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float gradient_amount : hint_range(0.0, 1.0) = 0.3;
uniform float highlight_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 highlight_glow_color : source_color = vec4(1.0, 0.96, 0.55, 1.0);

void fragment() {
	vec2 uv = UV;
	float node_alpha = COLOR.a;
	uv.y += sin((uv.x * 10.0) + TIME * wave_speed) * wave_strength;
	float alpha = texture(TEXTURE, uv).a;
	float outline = 0.0;
	float glow_outline = 0.0;
	float off_scale = outline_size / 100.0;
	float glow_scale = (outline_size + highlight_amount * 2.4) / 100.0;
	for (int dx = -2; dx <= 2; dx++) {
		for (int dy = -2; dy <= 2; dy++) {
			vec2 off = vec2(float(dx), float(dy)) * off_scale;
			outline = max(outline, texture(TEXTURE, clamp(uv + off, vec2(0.0), vec2(1.0))).a);
			if (highlight_amount > 0.001) {
				vec2 g_off = vec2(float(dx), float(dy)) * glow_scale;
				glow_outline = max(glow_outline, texture(TEXTURE, clamp(uv + g_off, vec2(0.0), vec2(1.0))).a);
			}
		}
	}
	outline = clamp(outline, 0.0, 1.0);
	glow_outline = clamp(glow_outline, 0.0, 1.0);

	// Solid color with an optional soft gradient between two colors
	float grad = 0.5 + 0.5 * sin(uv.y * 3.0 + TIME * 0.5);
	vec3 fill_base = mix(base_color.rgb, secondary_color.rgb, grad * gradient_amount);

	float shimmer_center = fract(TIME * 0.25);
	float shimmer = smoothstep(0.0, 1.0, 1.0 - abs(uv.x - shimmer_center) / shimmer_width);
	shimmer *= 0.6;
	float pulse = 0.5 + 0.5 * sin(TIME * 2.5);
	float glow_strength = glow_base * pulse;

	vec3 fill = fill_base + shimmer * vec3(1.0);
	float hl = clamp(highlight_amount, 0.0, 1.0);
	float hl_pulse = 1.0 + 0.18 * sin(TIME * 6.0);
	vec3 outer_glow_col = highlight_glow_color.rgb * (1.35 * hl_pulse);

	// Outline transitions into outer glow when highlighted
	vec3 outline_color = mix(fill_base * 0.35, outer_glow_col, hl);
	vec3 color = mix(outline_color, fill + outer_glow_col * (0.18 * hl), alpha);

	color += fill_base * glow_strength * 0.5;

	float glow_halo = clamp(glow_outline - outline, 0.0, 1.0) * hl;
	color = mix(color, outer_glow_col, glow_halo * (1.0 - alpha));

	float eff_outline_opacity = mix(outline_opacity, 1.0, hl);
	float final_alpha = max(max(alpha, outline * eff_outline_opacity), glow_halo * 0.92);

	COLOR = vec4(color, final_alpha * node_alpha);
}