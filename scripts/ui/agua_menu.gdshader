shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec2 posicion_agua;

void vertex() {
	posicion_agua = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = posicion_agua;
	float torsion = sin(p.x * 0.14 + p.y * 0.037) * 2.3 + cos(p.y * 0.15 - p.x * 0.043) * 1.4;
	float fase_a = p.x * 0.51 + p.y * 1.47 + TIME * 0.8 + torsion;
	float a = sin(fase_a) * (1.0 - smoothstep(0.25, 1.8, fwidth(fase_a)));
	float fase_b = p.x * 1.64 - p.y * 0.91 - TIME * 1.1 - torsion * 0.7;
	float b = sin(fase_b) * (1.0 - smoothstep(0.25, 1.8, fwidth(fase_b)));
	float c = sin(p.x * 0.68 + p.y * 1.21 + TIME * 0.55);
	NORMAL = normalize(NORMAL + TANGENT * (a * 0.027 + c * 0.016) + BINORMAL * (b * 0.022 + c * 0.013));
	float reflejo = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.0);
	ALBEDO = mix(vec3(0.025, 0.067, 0.070), vec3(0.29, 0.34, 0.42), reflejo * 0.65);
	ROUGHNESS = 0.21 + c * 0.026;
	SPECULAR = 0.76;
}
