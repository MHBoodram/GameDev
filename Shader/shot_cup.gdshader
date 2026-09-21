shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D texture_albedo : source_color;
uniform sampler2D gradient_texture : hint_default_black;
uniform float gradient_offset : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV;
    if (!FRONT_FACING) {
        uv.x = 1.0 - uv.x; // mirror horizontally when viewing the back
    }

    vec4 base_color = texture(texture_albedo, uv);

    float gradient_uv = clamp(uv.y + gradient_offset, 0.0, 1.0);
    vec4 gradient_color = texture(gradient_texture, vec2(gradient_uv, 0.0));

    ALBEDO = base_color.rgb * gradient_color.rgb;
    ALPHA = base_color.a;
}