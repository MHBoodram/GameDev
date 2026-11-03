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

void fragment() {
	vec2 uv = UV;
	float node_alpha = COLOR.a;
	uv.y += sin((uv.x * 10.0) + TIME * wave_speed) * wave_strength;
	float alpha = texture(TEXTURE, uv).a;
	float outline = 0.0;
	float off_scale = outline_size / 100.0;
	for (int dx = -2; dx <= 2; dx++) {
		for (int dy = -2; dy <= 2; dy++) {
			vec2 off = vec2(float(dx), float(dy)) * off_scale;
			outline = max(outline, texture(TEXTURE, uv + off).a);
		}
	}
	outline = clamp(outline, 0.0, 1.0);

	// Solid color with an optional soft gradient between two colors
	float grad = 0.5 + 0.5 * sin(uv.y * 3.0 + TIME * 0.5);
	vec3 fill_base = mix(base_color.rgb, secondary_color.rgb, grad * gradient_amount);

	float shimmer_center = fract(TIME * 0.25);
	float shimmer = smoothstep(0.0, 1.0, 1.0 - abs(uv.x - shimmer_center) / shimmer_width);
	shimmer *= 0.6;
	float pulse = 0.5 + 0.5 * sin(TIME * 2.5);
	float glow_strength = glow_base * pulse;

		vec3 fill = fill_base + shimmer * vec3(1.0);

	// Brighter, more visible outline
	vec3 outline_color = fill_base * 0.35;
	vec3 color = mix(outline_color, fill, alpha);

	// Glow adds brightness instead of multiplying everything down
	color += fill_base * glow_strength * 0.5;

	float final_alpha = max(alpha, outline * outline_opacity);

	COLOR = vec4(color, final_alpha * node_alpha);
}