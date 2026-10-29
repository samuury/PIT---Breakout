shader_type spatial;
// Chão neon: grade com linhas mestras, brilho sob as bolas e ondas de impacto.
uniform vec3 base_color : source_color = vec3(0.012, 0.010, 0.045);
uniform vec3 line_color : source_color = vec3(0.10, 0.34, 1.0);
uniform vec3 accent_color : source_color = vec3(1.0, 0.18, 0.65);
uniform float grid_size = 2.0;
uniform vec4 balls[6];
uniform vec4 ripple = vec4(0.0, 0.0, -100.0, 0.0);
uniform float game_time = 0.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xy;
	vec2 gp = p / grid_size;
	vec2 g = abs(fract(gp - 0.5) - 0.5) / max(fwidth(gp), vec2(0.0001));
	float line = 1.0 - clamp(min(g.x, g.y) * 0.7 - 0.4, 0.0, 1.0);
	vec2 gp2 = p / (grid_size * 4.0);
	vec2 g2 = abs(fract(gp2 - 0.5) - 0.5) / max(fwidth(gp2), vec2(0.0001));
	float major = 1.0 - clamp(min(g2.x, g2.y) * 0.5 - 0.3, 0.0, 1.0);

	float glow = 0.0;
	for (int i = 0; i < 6; i++) {
		float d = length(p - balls[i].xy);
		glow += balls[i].z * exp(-d * 0.38);
	}
	float age = game_time - ripple.z;
	float rr = length(p - ripple.xy);
	float ring = exp(-pow((rr - age * 16.0) * 0.8, 2.0)) * exp(-age * 2.4) * ripple.w * step(0.0, age);

	vec3 lines = mix(line_color, accent_color, clamp(major * 0.8 + ring * 0.5, 0.0, 1.0));
	ALBEDO = base_color;
	METALLIC = 0.7;
	ROUGHNESS = 0.1;
	EMISSION = lines * (line * (0.22 + glow * 1.4 + ring * 2.5) + major * 0.16)
		+ line_color * glow * 0.05 + accent_color * ring * 0.18;
}
