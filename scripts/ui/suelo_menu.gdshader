shader_type spatial;
render_mode diffuse_burley;
varying vec3 mundo;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float ruido(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { mundo=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=mundo.xz;
 float grano=ruido(p*95.0);
 float humedad=smoothstep(0.47,0.64,ruido(p*.29)+ruido(p*.8)*.16);
 ALBEDO=mix(vec3(.055,.065,.068),vec3(.023,.032,.037),humedad)*(0.75+grano*.5);
 ROUGHNESS=mix(.92,.16,humedad); SPECULAR=.55;
 NORMAL_MAP=vec3(.5+(grano-.5)*.11,.5+(ruido(p*84.0)-.5)*.11,1.0);
}
