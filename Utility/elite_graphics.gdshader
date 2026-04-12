shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float ghosting_strength : hint_range(0.0, 1.0) = 0.5;
uniform float blur_strength : hint_range(0.0, 5.0) = 1.0;
uniform vec2 motion_offset;
uniform int trail_mode : hint_range(0, 2) = 2;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Check if any effects are active
    if (blur_strength < 0.01 && ghosting_strength < 0.01) {
        COLOR = texture(screen_texture, uv);
    } else {
        // --- Gaussian Blur Kernel ---
        vec3 blur_color = vec3(0.0);
        float offset = blur_strength * 0.001;
        
        // Tap weights
        blur_color += texture(screen_texture, uv + vec2(-offset, -offset)).rgb * 0.0625;
        blur_color += texture(screen_texture, uv + vec2(0.0, -offset)).rgb * 0.125;
        blur_color += texture(screen_texture, uv + vec2(offset, -offset)).rgb * 0.0625;
        
        blur_color += texture(screen_texture, uv + vec2(-offset, 0.0)).rgb * 0.125;
        blur_color += texture(screen_texture, uv + vec2(0.0, 0.0)).rgb * 0.25;
        blur_color += texture(screen_texture, uv + vec2(offset, 0.0)).rgb * 0.125;
        
        blur_color += texture(screen_texture, uv + vec2(-offset, offset)).rgb * 0.0625;
        blur_color += texture(screen_texture, uv + vec2(0.0, offset)).rgb * 0.125;
        blur_color += texture(screen_texture, uv + vec2(offset, offset)).rgb * 0.0625;
        
        // --- Afterimages (Trail) ---
        vec3 trail_color = vec3(0.0);
        float weight_sum = 0.0;
        
        // Mode 0: Clean Single Tap Double-Vision
        if (trail_mode == 0) {
            vec2 trail_uv = uv + (motion_offset * 0.1); 
            trail_color = texture(screen_texture, trail_uv).rgb;
            weight_sum = 1.0;
        }
        // Mode 1: Heavy 5-Tap Smudge
        else if (trail_mode == 1) {
            for (int i = 1; i <= 5; i++) {
                float weight = 1.0 / float(i + 1);
                vec2 trail_uv = uv + (motion_offset * float(i) * 0.05); 
                trail_color += texture(screen_texture, trail_uv).rgb * weight;
                weight_sum += weight;
            }
        }
        // Mode 2: The "Rainbow" Chromatic Aberration Trail
        else if (trail_mode == 2) {
            for (int i = 1; i <= 20; i++) {
                float weight = 2.0 / float(i + 1);
                vec2 trail_uv = uv + (motion_offset * float(i) * 0.05); 
                vec3 chromatic;
                chromatic.r = texture(screen_texture, trail_uv + vec2(0.003, 0.0)).r;
                chromatic.g = texture(screen_texture, trail_uv).g;
                chromatic.b = texture(screen_texture, trail_uv - vec2(0.003, 0.0)).b;
                trail_color += chromatic * weight;
                weight_sum += weight;
            }
        }
        
        trail_color /= weight_sum;
        
        float motion_mag = length(motion_offset);
        // Only mix trail if there is actual motion, and clamp mix between 0 and 1
        float ghost_factor = clamp(ghosting_strength * clamp(motion_mag * 10.0, 0.0, 0.8), 0.0, 1.0);
        
        vec3 final_color = mix(blur_color, trail_color, ghost_factor);
        COLOR = vec4(final_color, 1.0);
    }
}
