class_name HudDanio
extends CanvasLayer
## Interfaz de DAÑO y MUERTE (2026-10-27). La crea el Jugador (_crear_hud).
##  · Viñeta roja en los bordes: un fogonazo al recibir un golpe (según el daño) y, con poca vida, un latido
##    que no se va hasta que te curas.
##  · Indicadores de dirección: un arco rojo alrededor de la mira que apunta hacia DE DÓNDE vino el golpe
##    (gira con la cámara mientras dura); los golpes sin origen (caídas) no lo muestran.
##  · Pantalla de muerte: se oscurece, "HAS MUERTO" y la cuenta atrás hasta volver a empezar.

const VIÑETA_SHADER := """
shader_type canvas_item;
uniform float fuerza = 0.0;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.6, 1.0);
	float r = length(d);
	float a = smoothstep(0.42, 0.95, r) * fuerza;
	COLOR = vec4(0.55, 0.0, 0.0, clamp(a, 0.0, 0.85));
}
"""

var _vineta: ColorRect
var _mat: ShaderMaterial
var _flecha: Control
var _pulso := 0.0          # fogonazo del último golpe (se apaga solo)
var _vida_k := 1.0         # vida / vida máxima
var _golpes: Array = []    # {dir: Vector3 (del jugador hacia el atacante, plana), t: segundos restantes, k: fuerza}
var _yaw_cam := 0.0
var _muerte: Control
var _muerte_titulo: Label
var _muerte_sub: Label
var _muerte_k := 0.0
var _reloj := 0.0


func _ready() -> void:
	layer = 5
	_vineta = ColorRect.new()
	_vineta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIÑETA_SHADER
	_mat.shader = sh
	_vineta.material = _mat
	add_child(_vineta)
	_flecha = Control.new()
	_flecha.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flecha.draw.connect(_dibujar_flechas)
	add_child(_flecha)
	# pantalla de muerte
	_muerte = ColorRect.new()
	(_muerte as ColorRect).color = Color(0.05, 0.0, 0.0, 0.0)
	_muerte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_muerte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_muerte.visible = false
	add_child(_muerte)
	_muerte_titulo = Label.new()
	_muerte_titulo.text = "HAS MUERTO"
	_muerte_titulo.add_theme_font_size_override("font_size", 64)
	_muerte_titulo.add_theme_color_override("font_color", Color8(200, 40, 35))
	_muerte_titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_muerte_titulo.add_theme_constant_override("outline_size", 10)
	_muerte_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_muerte_titulo.set_anchors_preset(Control.PRESET_CENTER)
	_muerte_titulo.anchor_left = 0.0
	_muerte_titulo.anchor_right = 1.0
	_muerte_titulo.offset_top = -70
	_muerte_titulo.offset_bottom = 10
	_muerte.add_child(_muerte_titulo)
	_muerte_sub = Label.new()
	_muerte_sub.add_theme_font_size_override("font_size", 22)
	_muerte_sub.add_theme_color_override("font_color", Color8(225, 220, 210))
	_muerte_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_muerte_sub.add_theme_constant_override("outline_size", 6)
	_muerte_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_muerte_sub.set_anchors_preset(Control.PRESET_CENTER)
	_muerte_sub.anchor_left = 0.0
	_muerte_sub.anchor_right = 1.0
	_muerte_sub.offset_top = 20
	_muerte_sub.offset_bottom = 60
	_muerte.add_child(_muerte_sub)


## un golpe: cantidad de daño y, si se sabe, desde dónde (posición del atacante)
func golpe(cantidad: float, jugador_pos: Vector3, desde = null) -> void:
	_pulso = minf(1.0, _pulso + 0.25 + cantidad / 60.0)
	if desde != null:
		var d := Vector3((desde as Vector3).x - jugador_pos.x, 0, (desde as Vector3).z - jugador_pos.z)
		if d.length() > 0.05:
			_golpes.append({"dir": d.normalized(), "t": 1.6, "k": clampf(0.5 + cantidad / 40.0, 0.5, 1.0)})
			while _golpes.size() > 6:
				_golpes.pop_front()


## cada fotograma (lo llama el Jugador): vida 0..1, yaw de la cámara y, si ha muerto, segundos que faltan
func actualizar(dt: float, vida_k: float, yaw_cam: float, muerto: bool, falta := 0.0) -> void:
	_reloj += dt
	_vida_k = vida_k
	_yaw_cam = yaw_cam
	_pulso = maxf(0.0, _pulso - dt * 1.6)
	var poca := clampf((0.4 - vida_k) / 0.4, 0.0, 1.0) if not muerto else 0.0
	var latido := poca * (0.45 + 0.25 * sin(_reloj * (5.0 + 4.0 * poca)))
	_mat.set_shader_parameter("fuerza", clampf(_pulso * 1.2 + latido, 0.0, 1.4))
	for g in _golpes:
		g.t -= dt
	_golpes = _golpes.filter(func(g): return g.t > 0.0)
	_flecha.queue_redraw()
	# muerte
	if muerto:
		_muerte.visible = true
		_muerte_k = minf(1.0, _muerte_k + dt / 1.5)
		(_muerte as ColorRect).color = Color(0.05, 0.0, 0.0, 0.72 * _muerte_k)
		_muerte_titulo.modulate.a = clampf(_muerte_k * 1.6 - 0.3, 0.0, 1.0)
		_muerte_sub.modulate.a = clampf(_muerte_k * 1.6 - 0.6, 0.0, 1.0)
		_muerte_sub.text = "Volviendo a empezar en %d…" % maxi(1, ceili(falta))
	else:
		_muerte.visible = false
		_muerte_k = 0.0


func _dibujar_flechas() -> void:
	if _golpes.is_empty():
		return
	var c := _flecha.size * 0.5
	var r := minf(_flecha.size.x, _flecha.size.y) * 0.17
	for g in _golpes:
		# ángulo del atacante respecto a hacia dónde mira la cámara (0 = delante, arriba en pantalla)
		var d: Vector3 = g.dir
		var a := atan2(-d.x, -d.z) - _yaw_cam
		var ang_pantalla := -a - PI * 0.5
		var alfa := clampf(float(g.t) / 0.6, 0.0, 1.0) * float(g.k)
		var col := Color(0.85, 0.08, 0.05, 0.85 * alfa)
		_flecha.draw_arc(c, r, ang_pantalla - 0.32, ang_pantalla + 0.32, 18, col, 7.0, true)
		# punta hacia fuera
		var p := c + Vector2(cos(ang_pantalla), sin(ang_pantalla)) * (r + 16.0)
		var lado := Vector2(cos(ang_pantalla + PI * 0.5), sin(ang_pantalla + PI * 0.5)) * 9.0
		var base := c + Vector2(cos(ang_pantalla), sin(ang_pantalla)) * (r + 4.0)
		_flecha.draw_colored_polygon(PackedVector2Array([p, base + lado, base - lado]), col)
