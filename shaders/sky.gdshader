shader_type sky;
// Céu procedural: gradiente + nebulosas animadas + estrelas cintilantes.
uniform vec3 top_color : source_color = vec3(0.012, 0.014, 0.06);
uniform vec3 horizon_color : source_color = vec3(0.07, 0.035, 0.16);
uniform vec3 nebula_a : source_color = vec3(0.42, 0.10, 0.62);
uniform vec3 nebula_b : source_color = vec3(0.05, 0.38, 0.70);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * noise(p);
		p *= 2.02;
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.6));
	float n1 = fbm(d * 2.5 + vec3(TIME * 0.012));
	float n2 = fbm(d * 4.0 - vec3(0.0, TIME * 0.018, 0.0) + 7.3);
	col += nebula_a * smoothstep(0.42, 0.85, n1) * 0.65;
	col += nebula_b * smoothstep(0.48, 0.90, n2) * 0.55;
	float n_cells = 420.0;
	vec3 gcell = floor(d * n_cells);
	vec3 fcell = fract(d * n_cells) - 0.5;
	float r = hash(gcell);
	float star = step(0.9975, r) * smoothstep(0.32, 0.0, length(fcell));
	float tw = 0.55 + 0.45 * sin(TIME * 2.0 + r * 60.0);
	col += vec3(star * tw * 2.0);
	COLOR = col;
}
