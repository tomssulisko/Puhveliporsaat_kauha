shader_type canvas_item;
render_mode unshaded, blend_mix;

## Force a flat bright yellow wherever the sprite has alpha.
uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.15, 1.0);

void fragment() {
	float a = texture(TEXTURE, UV).a;
	if (a < 0.5) {
		discard;
	}
	COLOR = outline_color;
}
