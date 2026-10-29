shader_type canvas_item;
// Pós-processamento leve: vinheta e aberração cromática nas bordas.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.5;
uniform float aberration = 0.0016;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = dot(c, c);
	vec2 off = c * aberration * d * 4.0;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	col *= 1.0 - smoothstep(0.12, 0.72, d) * vignette;
	COLOR = vec4(col, 1.0);
}
