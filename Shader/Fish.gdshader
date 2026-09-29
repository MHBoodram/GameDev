shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(-5.0, 5.0) = 1.0;

uniform vec2 focus = vec2(0.5, 0.5);


void fragment() {
    vec2 p = (SCREEN_UV - focus) * 2.0;

    float r = length(p);

    vec2 uv = SCREEN_UV + (p * r * r * strength * 0.1);

    uv = clamp(uv, vec2(0.0), vec2(1.0));

    COLOR = texture(SCREEN_TEXTURE, uv);
}
