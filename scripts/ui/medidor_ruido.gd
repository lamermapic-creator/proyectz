class_name MedidorRuido
extends CanvasLayer
## Medidores de sigilo del HUD (debajo de la estamina). Guía: docs/RUIDO_Y_ZOMBIS.md.
## · RUIDO: hasta dónde se oye lo que acabas de hacer. Es un oyente más del sistema Ruido y solo cuenta los
##   ruidos del jugador. Verde = sigiloso · amarillo = te oyen cerca · rojo = te oyen lejos.
## · VISTO: la sospecha del zombi que más te está viendo (0..1). Blanco = le pareces algo · naranja = va a
##   mirar · rojo = te ha visto. Solo aparece cuando algún zombi te está viendo.

const ESCALA := 40.0   # radio (studs) que llena la barra de ruido: correr ~32, andar ~13, agachado ~5
const ANCHO := 260.0
const C = preload("res://scripts/config/zconfig.gd")

var _nivel := 0.0       # radio mostrado (sube al instante y baja despacio)
var visto := 0.0        # sospecha mostrada (la máxima de los zombis vivos)
var _barra: ColorRect
var _fondo: ColorRect
var _barra_v: ColorRect
var _fondo_v: ColorRect
var _etiqueta_v: Label


func _ready() -> void:
	add_to_group(Ruido.GRUPO)
	_fondo = _fila(62, "ruido")
	_barra = _fondo.get_child(0) as ColorRect
	_fondo_v = _fila(74, "visto")
	_barra_v = _fondo_v.get_child(0) as ColorRect
	_etiqueta_v = _fondo_v.get_meta("etiqueta")
	Arsenal._ignorar_raton(self)


## una barra fina con su nombre a la derecha
func _fila(y: float, nombre: String) -> ColorRect:
	var fondo := ColorRect.new()
	fondo.position = Vector2(24, y)
	fondo.size = Vector2(ANCHO, 6)
	fondo.color = Color(0, 0, 0, 0.45)
	add_child(fondo)
	var barra := ColorRect.new()
	barra.size = Vector2(0, 6)
	fondo.add_child(barra)
	var etiqueta := Label.new()
	etiqueta.text = nombre
	etiqueta.add_theme_font_size_override("font_size", 11)
	etiqueta.modulate = Color(1, 1, 1, 0.6)
	etiqueta.position = Vector2(24 + ANCHO + 8, y - 7)
	add_child(etiqueta)
	fondo.set_meta("etiqueta", etiqueta)
	return fondo


func oir(ev: Ruido.Evento) -> void:
	if ev.fuente == get_parent():
		_nivel = maxf(_nivel, ev.radio)


func _process(dt: float) -> void:
	_nivel = maxf(0.0, _nivel - dt * maxf(12.0, _nivel * 1.5))
	var f := clampf(_nivel / ESCALA, 0.0, 1.0)
	_barra.size.x = ANCHO * f
	_barra.color = Color8(120, 190, 110) if f < 0.25 else (Color8(225, 190, 70) if f < 0.6 else Color8(215, 70, 50))
	# visto: la sospecha más alta de los zombis vivos
	var s := 0.0
	for z in get_tree().get_nodes_in_group("zombis"):
		if z.vivo():
			s = maxf(s, float(z.sospecha))
	visto = s
	var mostrar := s > 0.01
	_fondo_v.visible = mostrar
	_etiqueta_v.visible = mostrar
	_barra_v.size.x = ANCHO * s
	_barra_v.color = Color8(230, 60, 45) if s >= 1.0 else (Color8(235, 150, 60) if s >= float(C.ZOMBI.VistaSospecha) else Color8(225, 225, 215))
