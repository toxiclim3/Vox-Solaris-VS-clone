shader_type canvas_item;

uniform float start_margin = 16.0; // In texture pixels (e.g. 30)
uniform float end_margin = 16.0;   // In texture pixels (e.g. 26)
uniform float total_length = 100.0; // Physical length of line
uniform vec2 texture_size = vec2(64.0, 16.0); // Size of texture
uniform float texture_scale = 1.0; // Scale of the texture being drawn (e.g. 0.7)
uniform bool tile_middle = true;  // If true, tiles the middle section instead of stretching
uniform bool hide_caps = false;   // If true, hides the start and end margins (to use rigid sprites)

void fragment() {
	float pixel_x = UV.x * total_length;
	float tex_pixel_x = pixel_x / texture_scale; // Convert local units to texture pixels!
	float total_tex_len = total_length / texture_scale;
	
	if (hide_caps && (tex_pixel_x < start_margin || tex_pixel_x > total_tex_len - end_margin)) {
		discard;
	}
	
	float tex_x = 0.0;
	
	if (tex_pixel_x < start_margin) {
		tex_x = tex_pixel_x;
	} else if (tex_pixel_x > total_tex_len - end_margin) {
		tex_x = texture_size.x - (total_tex_len - tex_pixel_x);
	} else {
		float mid_tex_pixel_x = tex_pixel_x - start_margin;
		float mid_tex_len = texture_size.x - start_margin - end_margin;
		
		if (tile_middle) {
			tex_x = start_margin + mod(mid_tex_pixel_x, mid_tex_len);
		} else {
			float mid_line_len = total_tex_len - start_margin - end_margin;
			tex_x = start_margin + (mid_tex_pixel_x / mid_line_len) * mid_tex_len;
		}
	}
	
	// Final texture fetch
	// UV.y is preserved (distributes width)
	COLOR = texture(TEXTURE, vec2(tex_x / texture_size.x, UV.y)) * COLOR;
}
