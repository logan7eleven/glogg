shader_type canvas_item;

uniform float blur_amount : hint_range(0, 5) = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV, blur_amount);
	COLOR = color;
}