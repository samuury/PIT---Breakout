shader_type spatial;
// Paredes de neon com fluxo de luz e pulso quando a bola bate.
uniform vec3 neon : source_color = vec3(0.35, 0.55, 1.0);
instance uniform float pulse = 0.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float flow = 0.5 + 0.5 * sin((wp.x + wp.y) * 0.9 - TIME * 2.4);
	ALBEDO = vec3(0.04, 0.05, 0.12);
	METALLIC = 0.85;
	ROUGHNESS = 0.25;
	EMISSION = neon * (0.35 + 0.45 * flow + pulse * 3.0);
}
