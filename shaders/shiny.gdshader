shader_type canvas_item;
uniform float shine_amount : hint_range(0.0, 1.0) = 0.4;
uniform float speed : hint_range(0.0, 10.0) = 6.0;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	float shimmer = (sin(TIME * speed + UV.y * 25.0) + 1.0) / 2.0;
	shimmer = pow(shimmer, 4.0);
	vec4 shine_color = vec4(1.0, 1.0, 1.0, original_color.a);
	COLOR = mix(original_color, shine_color, shimmer * shine_amount);
}