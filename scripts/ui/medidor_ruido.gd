class_name MedidorRuido
extends CanvasLayer
## Medidor de ruido del HUD (debajo de la estamina): enseña hasta dónde se oye lo que acabas de hacer.
## Es un oyente más del sistema Ruido (ver docs/RUIDO_Y_ZOMBIS.md): solo cuenta los ruidos del jugador.
## Verde = sigiloso (agachado, andando despacio) · amarillo = te oyen cerca · rojo = te oyen lejos.

const ESCALA := 40.0   # radio (studs) que llena la barra: correr ~32, andar ~13, agachado ~5
const ANCHO := 260.0

var _nivel := 0.0       # radio mostrado (sube al instante y baja despacio)
var _barra: ColorRect
var _fondo: ColorRect


func _ready() -> void:
	add_to_group(Ruido.GRUPO)
	_fondo = ColorRect.new()
	_fondo.position = Vector2(24, 62)
	_fondo.size = Vector2(ANCHO, 6)
	_fondo.color = Color(0, 0, 0, 0.45)
	add_child(_fondo)
	_barra = ColorRect.new()
	_barra.size = Vector2(0, 6)
	_fondo.add_child(_barra)
	var etiqueta := Label.new()
	etiqueta.text = "ruido"
	etiqueta.add_theme_font_size_override("font_size", 11)
	etiqueta.modulate = Color(1, 1, 1, 0.6)
	etiqueta.position = Vector2(24 + ANCHO + 8, 55)
	add_child(etiqueta)
	Arsenal._ignorar_raton(self)


func oir(ev: Ruido.Evento) -> void:
	if ev.fuente == get_parent():
		_nivel = maxf(_nivel, ev.radio)


func _process(dt: float) -> void:
	_nivel = maxf(0.0, _nivel - dt * maxf(12.0, _nivel * 1.5))
	var f := clampf(_nivel / ESCALA, 0.0, 1.0)
	_barra.size.x = ANCHO * f
	_barra.color = Color8(120, 190, 110) if f < 0.25 else (Color8(225, 190, 70) if f < 0.6 else Color8(215, 70, 50))
