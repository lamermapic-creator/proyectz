class_name PantallaCarga
extends CanvasLayer
## Pantalla de carga entre escenas (menú → nivel y nivel → menú).
## Uso: PantallaCarga.ir_a(get_tree(), "res://escenas/....tscn")
## 1) carga la escena en segundo plano (barra hasta el 60 %), 2) cambia de escena: el nivel se
## construye y hornea su navegación en su _ready (la pantalla lo tapa, barra hasta el 100 %),
## 3) se desvanece y desaparece. Vive en la raíz del árbol, así que sobrevive al cambio de escena.

const CONSEJOS := [
	"Agachado haces mucho menos ruido: los zombis se guían por el oído.",
	"Apoya el arma (X) en un muro o en el suelo para disparar con mucha más precisión.",
	"Disparar se oye muy lejos. Una bala que golpea una pared lejana sirve para distraer.",
	"Colgado de una cornisa, Shift te mueve más rápido, pero cansa el doble.",
	"Con la rueda del ratón acercas o alejas la cámara.",
	"Corriendo se gasta estamina; cansado, el personaje anda más lento y encorvado.",
	"Pegado a una pared, el círculo rojo marca dónde va a dar la bala de verdad.",
	"Tumbado (Z) apenas te oyen; con Shift reptas más rápido.",
]

var ruta := ""
var _fase := 0          # 0 cargando archivo, 1 cambiando de escena, 2 esperando al nivel, 3 saliendo
var _progreso := 0.0
var _mostrado := 0.0
var _esperar := 0
var _t0 := 0
var _vieja: Node = null
var _visto := 0.0 # segundos que lleva en pantalla
var _raiz: Control
var _barra: ColorRect
var _barra_fondo: ColorRect
var _texto: Label


static func ir_a(arbol: SceneTree, ruta_escena: String) -> void:
	var p := PantallaCarga.new()
	p.ruta = ruta_escena
	arbol.root.add_child(p)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.theme = EstiloUI.tema()
	add_child(_raiz)
	var fondo := ColorRect.new()
	fondo.color = Color(0.035, 0.037, 0.035)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(fondo)
	# título y consejo, abajo a la izquierda (como el menú principal)
	var caja := VBoxContainer.new()
	caja.anchor_top = 1.0
	caja.anchor_bottom = 1.0
	caja.anchor_right = 1.0
	caja.offset_left = 70
	caja.offset_right = -70
	caja.offset_top = -230
	caja.offset_bottom = -60
	caja.add_theme_constant_override("separation", 10)
	_raiz.add_child(caja)
	caja.add_child(EstiloUI.titulo("PROYECTO Z · %s" % ProjectSettings.get_setting("application/config/version"), 48))
	var consejo := Label.new()
	consejo.text = "Consejo: " + str(CONSEJOS[randi() % CONSEJOS.size()])
	consejo.add_theme_color_override("font_color", EstiloUI.TEXTO_SUAVE)
	consejo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(consejo)
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 14)
	caja.add_child(esp)
	_texto = Label.new()
	_texto.text = "Cargando…"
	_texto.add_theme_font_size_override("font_size", 16)
	caja.add_child(_texto)
	# barra de progreso (fina, color de acento)
	_barra_fondo = ColorRect.new()
	_barra_fondo.color = Color(1, 1, 1, 0.1)
	_barra_fondo.custom_minimum_size = Vector2(0, 6)
	caja.add_child(_barra_fondo)
	_barra = ColorRect.new()
	_barra.color = EstiloUI.ACENTO
	_barra.size = Vector2(0, 6)
	_barra_fondo.add_child(_barra)
	if ResourceLoader.load_threaded_request(ruta) != OK:
		# si no se puede cargar en segundo plano, se carga de golpe
		_fase = 1


func _process(dt: float) -> void:
	_visto += dt
	match _fase:
		0:
			var p := []
			var st := ResourceLoader.load_threaded_get_status(ruta, p)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_progreso = 0.6 * float(p[0] if p.size() > 0 else 0.0)
			elif st == ResourceLoader.THREAD_LOAD_LOADED:
				_progreso = 0.6
				_fase = 1
			else:
				_fase = 1 # fallo: se intenta de forma normal
		1:
			# esperar a que la barra muestre la carga antes de congelar un instante al cambiar de escena
			if _mostrado >= _progreso - 0.02:
				var ps: PackedScene = ResourceLoader.load_threaded_get(ruta) if ResourceLoader.load_threaded_get_status(ruta) == ResourceLoader.THREAD_LOAD_LOADED else load(ruta)
				get_tree().paused = false
				_vieja = get_tree().current_scene
				get_tree().change_scene_to_packed(ps)
				_texto.text = "Volviendo al menú…" if ruta.contains("menu") else "Preparando el nivel…"
				_progreso = 0.75
				_fase = 2
				_esperar = 0
		2:
			# el nivel se construye en su _ready (geometría, navegación, muñecos, zombis): unos fotogramas
			var esc := get_tree().current_scene
			if esc != null and esc != _vieja:
				_esperar += 1
				_progreso = minf(1.0, 0.75 + _esperar * 0.05)
				# como mínimo se ve un momento (si no, un parpadeo)
				if _esperar >= 5 and _visto > 0.9:
					_fase = 3
					_texto.text = "Listo"
					var tw := create_tween()
					tw.tween_interval(0.15)
					tw.tween_property(_raiz, "modulate:a", 0.0, 0.5)
					tw.tween_callback(queue_free)
	_mostrado = move_toward(_mostrado, _progreso, dt * 2.5)
	_barra.size = Vector2(_barra_fondo.size.x * _mostrado, 6)
