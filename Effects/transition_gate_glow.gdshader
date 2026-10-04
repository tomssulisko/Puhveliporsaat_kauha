shader_type canvas_item;

## Soft-clip glow to level bounds (world space).
uniform vec2 clip_min = vec2(-99999.0, -99999.0);
uniform vec2 clip_max = vec2(99999.0, 99999.0);
uniform float clip_feather: hint_range(0.0, 64.0) = 12.0;

varying vec2 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	float inside_x = smoothstep(clip_min.x, clip_min.x + clip_feather, v_world.x)
		* (1.0 - smoothstep(clip_max.x - clip_feather, clip_max.x, v_world.x));
	float inside_y = smoothstep(clip_min.y, clip_min.y + clip_feather, v_world.y)
		* (1.0 - smoothstep(clip_max.y - clip_feather, clip_max.y, v_world.y));
	col.a *= inside_x * inside_y;
	if (col.a < 0.001) {
		discard;
	}
	COLOR = col;
}
