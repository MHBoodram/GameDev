shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled;

uniform bool is_color_pass = true;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r2 = dot(p, p);
	if (r2 >= 1.0) {
		discard;
	}
	float w = 1.0 - r2;
	w = w * w * 0.85;
	if (is_color_pass) {
		ALBEDO = COLOR.rgb * w;
	} else {
		ALBEDO = vec3(w);
	}
	ALPHA = 1.0;
}