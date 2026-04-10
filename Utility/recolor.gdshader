shader_type canvas_item;

uniform vec4 target_color : source_color = vec4(1.0);
uniform bool mix_hue = true;
uniform bool mix_saturation = false;
uniform bool mix_value = false;

// Standard RGB to HSV conversion
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Standard HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Skip transparent pixels
    if (tex_color.a < 0.01) {
        discard;
    }
    
    vec3 hsv_src = rgb2hsv(tex_color.rgb);
    vec3 hsv_target = rgb2hsv(target_color.rgb);
    
    vec3 final_hsv = hsv_src;
    
    // Replace components based on flags
    if (mix_hue) {
        final_hsv.x = hsv_target.x;
    }
    if (mix_saturation) {
        final_hsv.y = hsv_target.y;
    }
    if (mix_value) {
        final_hsv.z = hsv_target.z;
    }
    
    vec3 final_rgb = hsv2rgb(final_hsv);
    COLOR = vec4(final_rgb, tex_color.a);
}
