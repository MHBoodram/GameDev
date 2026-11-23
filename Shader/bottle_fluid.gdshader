shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform sampler2D gradient_texture : source_color, filter_nearest;
uniform float fill_amount : hint_range(0.0, 1.0) = 1.0;
uniform float slosh_angle : hint_range(-2.0, 2.0) = 0.0;
uniform float slosh_vertical_offset : hint_range(-0.5, 0.5) = 0.0;
uniform float wave_phase = 0.0;
uniform float wave_amplitude : hint_range(0.0, 0.2) = 0.0;
uniform float pixel_resolution : hint_range(8.0, 128.0) = 48.0;
uniform float inner_margin_top : hint_range(0.0, 0.5) = 0.12;
uniform float inner_margin_bottom : hint_range(0.5, 1.0) = 0.88;
uniform float liquid_transparency : hint_range(0.0, 1.0) = 0.92;
uniform float meniscus_curve : hint_range(0.0, 0.1) = 0.025;
uniform vec2 sprite_size = vec2(1.0, 1.0);
uniform bool flip_h = true;

varying vec2 v_norm_pos;
varying vec2 v_local_up;

float bayer4x4(ivec2 p) {
	int x0 = p.x & 1;
	int y0 = p.y & 1;
	int x1 = (p.x >> 1) & 1;
	int y1 = (p.y >> 1) & 1;
	int b0 = ((x0 ^ y0) << 1) | y0;
	int b1 = ((x1 ^ y1) << 1) | y1;
	return (float(b0 * 4 + b1) + 0.5) / 16.0;
}

void vertex() {
	v_norm_pos = VERTEX.xy / max(sprite_size, vec2(0.001));
	vec2 world_up_xy = vec2(MODEL_MATRIX[0][1], MODEL_MATRIX[1][1]);
	float len_up = length(world_up_xy);
	v_local_up = len_up > 0.0001 ? (world_up_xy / len_up) : vec2(0.0, 1.0);
}

void fragment() {
	vec2 pix_uv = (floor(UV * pixel_resolution) + 0.5) / pixel_resolution;
	vec4 mask_tex = texture(texture_albedo, pix_uv);
	if (mask_tex.a < 0.2 || fill_amount <= 0.002) {
		discard;
	}

	vec2 q_norm = vec2(
		(flip_h ? (0.5 - pix_uv.x) : (pix_uv.x - 0.5)),
		0.5 - pix_uv.y
	);

	float span = max(inner_margin_bottom - inner_margin_top, 0.01);
	vec2 up_dir = normalize(v_local_up);
	vec2 right_dir = vec2(up_dir.y, -up_dir.x);

	float proj_up = dot(q_norm, up_dir);
	float proj_right = dot(q_norm, right_dir);

	float bottom_lim = -0.5 + (1.0 - inner_margin_bottom);
	float top_lim = 0.5 - inner_margin_top;
	float tilt_extent = mix(0.32, 0.5 * span, abs(up_dir.y));

	float fill_h = mix(-tilt_extent, tilt_extent, fill_amount);
	float wave = sin(proj_right * 14.0 + wave_phase) * wave_amplitude;
	float slosh = proj_right * clamp(slosh_angle * 0.22, -0.18, 0.18);
	float meniscus = meniscus_curve * (proj_right * proj_right * 4.0);
	float surface_h = fill_h + slosh_vertical_offset + wave + slosh + meniscus;

	if (proj_up > surface_h) {
		discard;
	}

	float depth_below_surface = clamp((surface_h - proj_up) / max(tilt_extent * 1.4, 0.05), 0.0, 1.0);

	vec3 base_col = texture(gradient_texture, vec2(0.5, 0.5)).rgb;
	vec3 c_top = mix(base_col, vec3(1.0), 0.30);
	vec3 c_mid = base_col * vec3(0.92, 0.93, 0.96);
	vec3 c_deep = base_col * vec3(0.58, 0.62, 0.72);

	ivec2 p = ivec2(floor(UV * pixel_resolution));
	float bayer = bayer4x4(p);
	float t01 = clamp((depth_below_surface - 0.08) / 0.24, 0.0, 1.0);
	vec3 final_col = (t01 > bayer) ? c_mid : c_top;

	float t12 = clamp((depth_below_surface - 0.52) / 0.32, 0.0, 1.0);
	if (t12 > bayer) {
		final_col = c_deep;
	}

	ALBEDO = final_col;
	ALPHA = liquid_transparency * mask_tex.a;
}