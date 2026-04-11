shader_type canvas_item;

uniform float start_margin = 16.0; // Pixels from the start of the texture to protect
uniform float end_margin = 16.0;   // Pixels from the end of the texture to protect
uniform float total_length = 100.0; // The current physical length of the Line2D
uniform vec2 texture_size = vec2(64.0, 16.0); // The actual pixel size of the texture
uniform bool tile_middle = true;  // If true, tiles the middle section instead of stretching
uniform bool hide_caps = false;   // If true, hides the start and end margins (to use rigid sprites)

void fragment() {
	// UV.x goes from 0 to 1 along the line
	// Convert it to physical pixels along the line
	float pixel_x = UV.x * total_length;
	
	if (hide_caps && (pixel_x < start_margin || pixel_x > total_length - end_margin)) {
		discard;
	}
	
	float tex_x = 0.0;
	
	if (pixel_x < start_margin) {
		// Start cap (1:1 mapping)
		tex_x = pixel_x;
	} else if (pixel_x > total_length - end_margin) {
		// End cap (1:1 mapping from the end of the texture)
		tex_x = texture_size.x - (total_length - pixel_x);
	} else {
		// Middle section
		float mid_pixel_x = pixel_x - start_margin;
		float mid_tex_len = texture_size.x - start_margin - end_margin;
		
		if (tile_middle) {
			// Tile the middle section
			tex_x = start_margin + mod(mid_pixel_x, mid_tex_len);
		} else {
			// Stretch the middle section
			float mid_line_len = total_length - start_margin - end_margin;
			tex_x = start_margin + (mid_pixel_x / mid_line_len) * mid_tex_len;
		}
	}
	
	// Final texture fetch
	// UV.y is preserved (distributes width)
	COLOR = texture(TEXTURE, vec2(tex_x / texture_size.x, UV.y));
}
