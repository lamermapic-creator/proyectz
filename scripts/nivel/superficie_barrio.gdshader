shader_type spatial;
uniform vec4 color_base : source_color;
uniform int acabado = 0;
varying vec3 local;
varying vec3 normal_local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(17.13, 93.71))) * 4375.19);
}
float ruido(vec2 p) {
	vec2 i = floor(p), f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)),hash(i+1.0),f.x),f.y);
}
void vertex() {
	local = VERTEX;
	normal_local = NORMAL;
}
void fragment() {
	vec3 n = abs(normal_local);
	vec2 p = n.y > 0.7 ? local.xz : (n.x > 0.7 ? local.zy : local.xy);
	float grano = (ruido(p*6.0)-0.5) * (1.0-smoothstep(0.2,1.0,length(fwidth(p*6.0))));
	float tono = 0.93 + ruido(p*0.32)*0.14 + grano*0.20;
	if (acabado > 0) {
		vec2 paso = acabado == 1 ? vec2(1.55,0.66) : (acabado == 2 ? vec2(4.0,4.0) : vec2(5.8,0.63));
		vec2 celda = p/paso;
		if (acabado != 2) { celda.x += mod(floor(celda.y),2.0)*0.5; }
		vec2 borde = min(fract(celda),1.0-fract(celda))*paso;
		float junta = smoothstep(0.012,0.04+max(fwidth(p.x),fwidth(p.y)),min(borde.x,borde.y));
		tono *= mix(0.69,0.88+0.22*hash(floor(celda)),junta);
		if (acabado == 3) { tono += 0.14*(ruido(p*vec2(0.7,13.0))-0.5); }
	}
	ALBEDO = color_base.rgb * tono;
	ROUGHNESS = 0.89;
}
