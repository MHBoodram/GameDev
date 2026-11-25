shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float depth_range = 12.0;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r2 = dot(p, p);
	if (r2 > 0.92) {
		discard;
	}
	float linear_d = clamp((-VERTEX.z) / max(depth_range, 0.1), 0.0, 1.0);
	ALBEDO = vec3(linear_d, 0.0, 1.0);
	ALPHA = 1.0;
}