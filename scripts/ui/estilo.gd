class_name EstiloUI
## Tema común de los menús (oscuro, sobrio, acentos ocre).

const FONDO := Color(0.06, 0.065, 0.06, 0.92)
const ACENTO := Color8(214, 168, 78)
const TEXTO := Color8(230, 225, 212)
const TEXTO_SUAVE := Color8(160, 155, 142)

static var _tema: Theme = null


static func _caja(bg: Color, borde: Color = Color(0, 0, 0, 0), ancho := 0, radio := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = borde
	sb.set_border_width_all(ancho)
	sb.set_corner_radius_all(radio)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func tema() -> Theme:
	if _tema:
		return _tema
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXTO)
	# botones
	t.set_stylebox("normal", "Button", _caja(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.08), 1))
	t.set_stylebox("hover", "Button", _caja(Color(ACENTO, 0.22), ACENTO, 1))
	t.set_stylebox("pressed", "Button", _caja(Color(ACENTO, 0.4), ACENTO, 1))
	t.set_stylebox("focus", "Button", _caja(Color(0, 0, 0, 0), Color(ACENTO, 0.7), 1))
	t.set_stylebox("disabled", "Button", _caja(Color(1, 1, 1, 0.02)))
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 20)
	# deslizadores
	var riel := StyleBoxFlat.new()
	riel.bg_color = Color(1, 1, 1, 0.12)
	riel.content_margin_top = 3
	riel.content_margin_bottom = 3
	riel.set_corner_radius_all(2)
	var lleno := riel.duplicate() as StyleBoxFlat
	lleno.bg_color = ACENTO
	t.set_stylebox("slider", "HSlider", riel)
	t.set_stylebox("grabber_area", "HSlider", lleno)
	t.set_stylebox("grabber_area_highlight", "HSlider", lleno)
	# desplegables y casillas
	t.set_stylebox("normal", "OptionButton", _caja(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.1), 1))
	t.set_stylebox("hover", "OptionButton", _caja(Color(ACENTO, 0.18), ACENTO, 1))
	t.set_stylebox("pressed", "OptionButton", _caja(Color(ACENTO, 0.3), ACENTO, 1))
	t.set_stylebox("focus", "OptionButton", _caja(Color(0, 0, 0, 0), Color(ACENTO, 0.7), 1))
	t.set_color("font_color", "CheckBox", TEXTO)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_stylebox("panel", "PopupMenu", _caja(Color(0.1, 0.1, 0.09, 0.98), Color(1, 1, 1, 0.1), 1))
	t.set_stylebox("panel", "PanelContainer", _caja(FONDO, Color(1, 1, 1, 0.08), 1, 4))
	_tema = t
	return t


static func boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(300, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(accion)
	b.mouse_entered.connect(func(): b.grab_focus())
	return b


static func titulo(texto: String, tam := 56) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", TEXTO)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l
