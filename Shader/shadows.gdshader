shader_type canvas_item;

uniform vec2 shadow_offset = vec2(0.0, 8.0); // offset in pixels
uniform float shadow_width = 1.5;            // horizontal stretch
uniform float shadow_height = 0.5;           // vertical squash
uniform vec4 shadow_color : source_color = vec4(0.0,0.0,0.0,0.5);

void fragment() {
    // Normal frame UV (Godot passes UV already cropped if "Region Enabled")
    vec4 tex = texture(TEXTURE, UV);
    COLOR = tex;

    // Only do shadow if this pixel is transparent
    if (tex.a == 0.0) {
        // Sample sprite alpha from shifted down position
        vec2 shifted_uv = UV - shadow_offset * TEXTURE_PIXEL_SIZE;
        vec4 shadow_sample = texture(TEXTURE, shifted_uv);

        if (shadow_sample.a > 0.0) {
            // Place oval centered at bottom of frame
            vec2 uv = UV - vec2(0.5, 1.0);

            // Scale into ellipse space
            uv.x /= shadow_width * 0.5;
            uv.y /= shadow_height * 0.5;

            float d = dot(uv, uv);
            if (d <= 1.0) {
                float a = 1.0 - d/3.0;
                a = smoothstep(0.0, 0.9, a);
                COLOR = vec4(shadow_color.rgb, shadow_color.a * a);
            }
        }
    }
}
