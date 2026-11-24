shader_type canvas_item;
render_mode unshaded;

float semilla(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - vec2(0.56, 0.46)) * vec2(1.08, 1.0);
	float borde = smoothstep(0.26, 0.79, length(p));
	float grano = semilla(FRAGCOORD.xy) * 0.018;
	COLOR = vec4(vec3(grano), 0.025 + borde * 0.49);
}
