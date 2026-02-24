shader_type canvas_item;

// --- UNIFORMS ---
uniform bool is_flashing = false;
uniform bool fear_active = false;
uniform bool frail_active = false;
uniform bool deflect_active = false;

uniform vec4 fear_color;

void fragment() {
	vec4 final_color = texture(TEXTURE, UV);
	
	// --- Sprite Tinting Logic ---
	if (final_color.a > 0.1) {
		
		// 1. Frail correctly reduces the alpha.
		if (frail_active) { 
			final_color.a *= 0.6; 
		}
		
		if (deflect_active) {
			float shimmer = pow((sin(TIME * 6.0 + UV.y * 25.0) + 1.0) / 2.0, 4.0);
			final_color = mix(final_color, vec4(1.0, 1.0, 1.0, final_color.a), shimmer * 0.4);
		}
		
		// 2. Fear now ONLY mixes the RGB, leaving the alpha from Frail intact.
		if (fear_active) {
			// --- THIS IS THE FIX ---
			// OLD LINE: final_color = mix(final_color, vec4(fear_color.rgb, final_color.a), fear_color.a);
			// NEW LINE:
			final_color.rgb = mix(final_color.rgb, fear_color.rgb, fear_color.a);
		}
	}
	
	// --- Universal Damage Flash (Overlay) ---
	if (is_flashing && texture(TEXTURE, UV).a > 0.1) {
		final_color = vec4(0.0, 0.0, 0.0, 1.0);
	}

	COLOR = final_color;
}