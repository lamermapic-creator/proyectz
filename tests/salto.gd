extends Node
## Mide la distancia horizontal de un salto andando y corriendo.
var j: Jugador
var t := 0.0
var fase := 0
var p0 := Vector3.ZERO
var casos := [false, true]
var i := 0
var salto_hecho := false

func _key(k: int, p: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = p
	Input.parse_input_event(ev)

func _ready() -> void:
	j = get_parent().get_node("Jugador")
	_empezar()

func _empezar() -> void:
	j.global_position = Vector3(-100, 3.2, 100)
	j.velocity = Vector3.ZERO
	j.cur_move = 0
	t = 0
	salto_hecho = false
	p0 = Vector3.ZERO
	_key(KEY_W, true)
	if casos[i]:
		_key(KEY_SHIFT, true)

func _process(dt: float) -> void:
	t += dt
	if t > 1.5 and not salto_hecho:
		salto_hecho = true
		_key(KEY_SPACE, true)
	if t > 1.55:
		_key(KEY_SPACE, false)
	if salto_hecho and p0 == Vector3.ZERO and not j.en_suelo:
		p0 = j.global_position
	if p0 != Vector3.ZERO and j.en_suelo and t > 1.7:
		var d := Vector2(j.global_position.x - p0.x, j.global_position.z - p0.z).length()
		print("SALTO correr=", casos[i], " distancia=%.2f studs" % d)
		_key(KEY_W, false)
		_key(KEY_SHIFT, false)
		i += 1
		if i >= casos.size():
			get_tree().quit()
			return
		_empezar()
	if t > 6:
		print("SALTO sin aterrizar")
		get_tree().quit()
