shader_type canvas_item;
render_mode unshaded;

float semilla(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float lluvia(vec2 uv, vec2 densidad, float rapidez) {
	vec2 c = vec2(uv.x + uv.y * 0.19, uv.y - TIME * rapidez) * densidad;
	vec2 id = floor(c);
	vec2 f = fract(c);
	float r = semilla(id);
	float fino = 1.0 - smoothstep(0.013, 0.064, abs(f.x - (0.1 + r * 0.8)));
	return fino * smoothstep(0.10, 0.24, f.y) * (1.0 - smoothstep(0.26, 0.73, f.y)) * step(0.66, r);
}

void fragment() {
	vec2 p = (UV - vec2(0.56, 0.46)) * vec2(1.08, 1.0);
	float borde = smoothstep(0.26, 0.79, length(p));
	float gotas = lluvia(UV, vec2(112.0, 14.0), 0.71) + 0.6 * lluvia(UV * 1.18, vec2(159.0, 17.0), 0.52);
	gotas *= smoothstep(0.30, 0.83, UV.x) * 0.20;
	float sombra = 0.035 + borde * 0.53;
	float grano = semilla(FRAGCOORD.xy) * 0.015;
	float alfa = clamp(sombra + gotas, 0.001, 0.85);
	COLOR = vec4((vec3(grano) * sombra + vec3(0.59, 0.71, 0.75) * gotas) / alfa, alfa);
}
