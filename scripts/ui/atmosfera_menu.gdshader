shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 p = (UV - vec2(0.52, 0.48)) * vec2(1.1, 1.0);
	float borde = smoothstep(0.28, 0.78, length(p));
	float grano = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3(grano * 0.018), 0.06 + borde * 0.54);
}
