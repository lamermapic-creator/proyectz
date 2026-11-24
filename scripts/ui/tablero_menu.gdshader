shader_type spatial;
render_mode diffuse_burley;
varying vec3 superficie;
varying vec3 cara;
uniform vec3 casquillos[3];

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
		mix(hash(i+vec2(0,1)), hash(i+1.0), f.x), f.y);
}

void vertex() {
	superficie = VERTEX;
	cara = NORMAL;
}

void fragment() {
	vec2 p = superficie.xz;
	// En el canto, la veta sigue la tabla sin proyectar las manchas hacia abajo.
	float tapa = step(0.9, cara.y);
	p.y += (1.0 - tapa) * superficie.y * 0.72;
	float veta = ruido(vec2(p.x * 1.1, p.y * 27.0 + ruido(p * 1.8) * 3.4));
	vec2 detalle = p * vec2(17.0, 120.0);
	float filtro = 1.0 - smoothstep(0.25, 1.15, length(fwidth(detalle)));
	float poro = mix(0.5, ruido(detalle), filtro);
	float ranura = (superficie.z + 0.35) * 1.6;
	float junta = smoothstep(0.008, 0.025 + fwidth(ranura), abs(fract(ranura) - 0.5));
	float tabla = hash(vec2(floor(ranura - 0.5), 0.2));
	// Anillos de crecimiento que se curvan alrededor de un nudo por tablón.
	vec2 nudo = vec2((p.x - (tabla * 10.0 - 5.0)) * 0.65, fract(ranura - 0.5) - 0.43);
	float radio = length(nudo * vec2(0.76, 1.8));
	float fase = p.y * 86.0 + 8.0 * exp(-radio * radio * 2.3) + veta * 2.5;
	float anillo = cos(fase) * (1.0 - smoothstep(0.6, 3.14, fwidth(fase)));
	float fibra = ruido(vec2(p.x * 3.1 + tabla * 9.0, p.y * 68.0));

	vec3 madera = mix(vec3(0.056, 0.026, 0.012), vec3(0.22, 0.108, 0.047), veta);
	madera *= (0.54 + tabla * 0.42 + poro * 0.17) * mix(0.24, 1.0, junta);
	madera *= (0.95 + anillo * 0.11 + (fibra - 0.5) * 0.30)
		* mix(0.52, 1.0, smoothstep(0.025, 0.19, radio));
	vec2 marca = p - vec2(1.46, 0.92);
	float borde = length(marca * vec2(0.70, 1.5)) + (ruido(p * 7.0) - 0.5) * 0.44;
	float charco = 1.0 - smoothstep(0.58, 0.69 + fwidth(borde), borde);
	float arrastre = 1.0 - smoothstep(0.10, 0.21, abs(marca.y + marca.x * 0.33) + ruido(p * 13.0) * 0.07);
	arrastre *= (1.0 - smoothstep(0.28, 1.89, abs(marca.x))) * smoothstep(0.26, 0.48, veta);
	vec2 celdas = (p - vec2(1.4, 0.85)) * 6.0;
	vec2 id = floor(celdas);
	float azar = hash(id);
	vec2 centro = vec2(hash(id + 19.0), hash(id - 7.0)) * 0.62 + 0.19;
	float gota = 1.0 - smoothstep(0.075 + azar * 0.16, 0.11 + azar * 0.16, length(fract(celdas) - centro));
	gota *= step(0.67, azar) * (1.0 - smoothstep(0.6, 1.7, length(marca)));
	float sangre = tapa * max(charco, max(arrastre * 0.82, gota));
	vec3 rojo = mix(vec3(0.075, 0.004, 0.005), vec3(0.30, 0.009, 0.013), ruido(p * 8.0));
	float contacto = 0.0;
	for (int i = 0; i < 3; i++) {
		vec3 pose = casquillos[i];
		vec2 eje = vec2(sin(pose.y), cos(pose.y));
		vec2 d = superficie.xz - pose.xz;
		d -= eje * clamp(dot(d, eje), -0.13, 0.13);
		contacto = max(contacto, 1.0 - smoothstep(0.025, 0.098, length(d)));
	}
	ALBEDO = mix(madera, rojo, sangre) * (1.0 - tapa * contacto * 0.42);
	ROUGHNESS = mix(0.64 + veta * 0.22, 0.25 + ruido(p * 3.6) * 0.09, tapa * charco);
	SPECULAR = mix(0.38, 0.56, sangre);
}
