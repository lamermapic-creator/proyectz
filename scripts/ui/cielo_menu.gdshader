shader_type sky;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
		mix(hash(i+vec2(0,1)), hash(i+1.0), f.x), f.y);
}

void sky() {
	float altura = max(EYEDIR.y, 0.0);
	float cercania = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
	vec3 horizonte = vec3(0.67, 0.52, 0.40);
	vec3 alto = vec3(0.14, 0.23, 0.39);
	vec3 color = mix(horizonte, alto, smoothstep(0.0, 0.82, altura));
	vec2 p = EYEDIR.xz / max(0.16, altura + 0.12);
	p = p * 1.95 + vec2(1.2, 7.0);
	float nubes = 0.58 * ruido(p) + 0.26 * ruido(p * 2.15)
		+ 0.11 * ruido(p * 4.7) + 0.05 * ruido(p * 10.1);
	float densidad = smoothstep(0.42, 0.70, nubes) * smoothstep(0.005, 0.12, altura);
	vec3 nube = mix(vec3(0.22, 0.27, 0.36), vec3(0.92, 0.69, 0.48), pow(cercania, 6.0));
	color = mix(color, nube, densidad);
	color += vec3(1.0, 0.60, 0.32) * (pow(cercania, 36.0) * 0.62 + smoothstep(0.99965, 0.99991, cercania) * 2.3);
	COLOR = color;
}
