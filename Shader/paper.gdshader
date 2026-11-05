shader_type canvas_item;

// Set automatically by paper_rect.gd
uniform vec2 rect_size = vec2(512.0, 768.0); // pixels
uniform vec2 light_pos = vec2(0.25, 0.2);    // UV space (top-left origin)

uniform float relief : hint_range(0.0, 1.0) = 0.55;
uniform float fibers : hint_range(0.0, 1.0) = 0.5;
uniform float grain  : hint_range(0.0, 1.0) = 0.45;
uniform float tone   : hint_range(0.0, 1.0) = 0.3; // 0 = white, 1 = kraft
uniform vec3 white_color : source_color = vec3(0.965, 0.962, 0.945);
uniform vec3 kraft_color : source_color = vec3(0.90, 0.82, 0.67);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}