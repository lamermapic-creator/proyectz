shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensidad : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 radio = SCREEN_UV - vec2(0.5);
	vec2 paso = radio * 0.012 * intensidad;
	vec3 original = texture(pantalla, SCREEN_UV).rgb;
	vec3 difuso = original * 0.4;
	difuso += texture(pantalla, SCREEN_UV + paso).rgb * 0.2;
	difuso += texture(pantalla, SCREEN_UV - paso).rgb * 0.2;
	difuso += texture(pantalla, SCREEN_UV + paso * 2.0).rgb * 0.1;
	difuso += texture(pantalla, SCREEN_UV - paso * 2.0).rgb * 0.1;
	float gris = dot(difuso, vec3(0.2126, 0.7152, 0.0722));
	float borde = smoothstep(0.18, 0.70, length(radio));
	vec3 frio = mix(difuso, vec3(gris), 0.68) * vec3(0.87, 0.97, 1.06);
	COLOR = vec4(mix(original, frio * (0.84 - borde * 0.48), intensidad), 1.0);
}
