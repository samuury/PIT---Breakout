shader_type spatial;
// Blocos: bisel e painel interno calculados no espaço do objeto, brilho nas bordas,
// listras no obstáculo e pulso na bomba. Um único material para todos os blocos.
instance uniform vec4 base_color : source_color = vec4(0.8, 0.3, 0.3, 1.0);
instance uniform float flash = 0.0;
instance uniform float hp_glow = 0.0;
instance uniform float kind = 0.0; // 0 normal, 1 obstáculo, 2 bomba
instance uniform vec3 half_size = vec3(0.9, 0.35, 0.4);
varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float edge_distance(vec3 p, vec3 h) {
	vec3 d = h - abs(p);
	float m1 = min(min(d.x, d.y), d.z);
	float m3 = max(max(d.x, d.y), d.z);
	return d.x + d.y + d.z - m1 - m3;
}

void fragment() {
	float edge = edge_distance(lp, half_size);
	float rim = 1.0 - smoothstep(0.0, 0.07, edge);
	float inset = smoothstep(0.10, 0.14, edge);
	vec3 col = base_color.rgb;
	col = mix(col, vec3(0.92, 0.94, 1.0), clamp(hp_glow, 0.0, 1.0) * 0.4);
	float grad = 0.80 + 0.20 * clamp(lp.y / half_size.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 emis = vec3(0.0);
	float metallic = 0.25;
	float rough = 0.42;
	if (kind > 1.5) {
		float pulse = 0.5 + 0.5 * sin(TIME * 6.0);
		col = mix(col, vec3(0.45, 0.03, 0.03), 0.5);
		emis += vec3(1.0, 0.25, 0.08) * (0.25 + 0.7 * pulse) * (rim + 0.25);
	} else if (kind > 0.5) {
		metallic = 0.9;
		rough = 0.3;
		float front = step(0.8, ln.z);
		float stripe = step(0.5, fract((lp.x + lp.y) * 2.2));
		col = mix(col, col * 0.55, stripe * front);
	}
	ALBEDO = col * grad * mix(0.78, 1.0, inset);
	METALLIC = metallic;
	ROUGHNESS = rough;
	EMISSION = col * 0.12 * inset + col * rim * 0.7 + emis + vec3(flash);
}
