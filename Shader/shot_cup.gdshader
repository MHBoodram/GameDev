shader_type spatial;
render_mode unshaded;

uniform sampler2D texture_albedo : source_color;
uniform sampler2D gradient_texture : hint_default_black;

void fragment() {
    vec4 base_color = texture(texture_albedo, UV);
    vec4 gradient_color = texture(gradient_texture, vec2(UV.y, 0.0));

    ALBEDO = base_color.rgb * gradient_color.rgb;
    ALPHA = base_color.a; // keep original sprite transparency untouched
}