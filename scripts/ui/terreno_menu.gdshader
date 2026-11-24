shader_type spatial;
render_mode diffuse_burley;
varying vec3 mundo;
varying vec3 normal_mundo;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
		mix(hash(i+vec2(0,1)), hash(i+1.0), f.x), f.y);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = mundo.xz;
	float variacion = ruido(p * 0.18);
	float detalle = ruido(p * 3.8);
	float faceta = 1.0 - max(normal_mundo.y, 0.0);
	float piedra = smoothstep(0.19, 0.62, faceta + (variacion - 0.5) * 0.22);
	float nieve = smoothstep(71.0, 104.0, mundo.y + variacion * 18.0 - faceta * 39.0);
	vec3 hierba = mix(vec3(0.027, 0.059, 0.035), vec3(0.096, 0.114, 0.057), variacion);
	float estrato = sin(mundo.y * 1.8 + ruido(p * 0.31) * 4.0);
	vec3 roca = vec3(0.121, 0.109, 0.094) * (0.74 + 0.23 * variacion + 0.07 * estrato);
	vec3 color = mix(hierba, roca, max(piedra, smoothstep(43.0, 85.0, mundo.y)));
	color = mix(vec3(0.12, 0.115, 0.087), color, smoothstep(0.1, 2.5, mundo.y));
	ALBEDO = mix(color, vec3(0.61, 0.65, 0.68), nieve) * (0.82 + detalle * 0.27);
	ROUGHNESS = 0.86;
}
