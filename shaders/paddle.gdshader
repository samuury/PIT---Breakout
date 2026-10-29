shader_type spatial;
// Raquete metálica com brilho de borda (fresnel) e faixa de luz na face de cima.
uniform vec3 color : source_color = vec3(0.35, 0.8, 1.0);
uniform float energy = 1.0;
varying vec3 ln;

void vertex() {
	ln = NORMAL;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float top = step(0.8, ln.y);
	ALBEDO = color * 0.55;
	METALLIC = 0.7;
	ROUGHNESS = 0.2;
	EMISSION = color * (0.35 + rim * 1.6 + top * 0.7) * energy;
}
