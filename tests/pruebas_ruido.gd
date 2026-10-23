extends SceneTree
## PRUEBAS AUTOMÁTICAS del sistema de ruido y de los zombis, más regresión de lo que ya existía.
## Guía: docs/RUIDO_Y_ZOMBIS.md (sección "Pruebas").
##   Una prueba:  godot --headless --path . --fixed-fps 60 -s res://tests/pruebas_ruido.gd -- <modo>
##   Todas:       tests/ejecutar_pruebas.sh [ruta/a/godot]
## Cada prueba carga el nivel de pruebas real, simula teclas con Input.parse_input_event y comprueba el
## resultado. Escribe "OK <modo>" o "FALLO <modo>: ..." y sale con código 0 o 1.

const MODOS := ["unidad", "pasos", "disparo", "oye_disparo", "sigilo", "oclusion", "jauria", "navegacion",
	"ataque_y_muerte", "regeneracion", "danio_zombi", "maniqui", "andar", "cadencia", "completo", "rendimiento"]

var modo := ""
var nivel: Node3D
var J: Jugador
var dz: DirectorZombis
var fallos: Array[String] = []


## oyente de prueba: apunta todos los ruidos que le llegan
class Escucha extends Node:
	var eventos: Array = []

	func oir(ev: Ruido.Evento) -> void:
		eventos.append(ev)

	func filtrar(fuente: Node, tipo: String) -> Array:
		return eventos.filter(func(e): return e.fuente == fuente and e.tipo == tipo)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	modo = args[0] if args.size() > 0 else ""
	if not modo in MODOS:
		print("Modos: ", ", ".join(MODOS))
		quit(2)
		return
	_correr()


func _correr() -> void:
	print("== prueba: ", modo)
	match modo:
		"unidad": await _unidad()
		"pasos": await _pasos()
		"disparo": await _disparo()
		"oye_disparo": await _oye_disparo()
		"sigilo": await _sigilo()
		"oclusion": await _oclusion()
		"jauria": await _jauria()
		"navegacion": await _navegacion()
		"ataque_y_muerte": await _ataque_y_muerte()
		"regeneracion": await _regeneracion()
		"danio_zombi": await _danio_zombi()
		"maniqui": await _maniqui()
		"andar": await _andar()
		"cadencia": await _cadencia()
		"completo": await _completo()
		"rendimiento": await _rendimiento()
	if fallos.is_empty():
		print("OK ", modo)
		quit(0)
	else:
		print("FALLO ", modo, ": ", " | ".join(fallos))
		quit(1)


## ---------------------------------------------------------------- utilidades
func _cargar(con_zombis := false) -> void:
	nivel = (load("res://escenas/pruebas_movimiento.tscn") as PackedScene).instantiate()
	if not con_zombis:
		nivel.set_meta("sin_zombis", true)
	root.add_child(nivel)
	current_scene = nivel
	await _esperar(0.5) # el _ready del nivel (que crea el director) llega en el primer fotograma
	J = nivel.get_node("Jugador")
	dz = nivel.get_node("Zombis")


func _esperar(segundos: float) -> void:
	for i in maxi(1, int(segundos * 60.0)):
		await process_frame


func _tecla(k: Key, pulsada: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = pulsada
	Input.parse_input_event(e)


func _comprobar(cond: bool, texto: String) -> void:
	print(("  [bien] " if cond else "  [MAL]  ") + texto)
	if not cond:
		fallos.append(texto)


func _pies() -> Vector3:
	return J.global_position - Vector3(0, J.center_cur, 0)


## zombi quieto (no deambula) a "lejos" studs del jugador en la dirección "dir"
func _zombi_a(dir: Vector3, lejos: float) -> Zombi:
	return dz.crear_zombi(_pies() + dir.normalized() * lejos, 0.0, false)


## pared (capa 1, escenario). mirando = hacia dónde mira su cara ancha (por defecto, eje Z)
func _pared(centro: Vector3, tam: Vector3, mirando := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = tam
	cs.shape = bx
	sb.add_child(cs)
	nivel.add_child(sb)
	sb.global_position = centro
	if mirando.length() > 0.01:
		sb.global_basis = Basis.looking_at(mirando)
	return sb


## gira la cámara (yaw/pitch del jugador) para que la mira apunte a "p", como haría el ratón. La cámara
## va al hombro, así que se repite unas veces hasta que se asienta.
func _apuntar_a(p: Vector3) -> void:
	for i in 4:
		var d := p - J.camara.global_position
		J.yaw = atan2(-d.x, -d.z)
		J.pitch = asin(clampf(d.normalized().y, -1.0, 1.0))
		await _esperar(0.4)


func _escucha() -> Escucha:
	var e := Escucha.new()
	e.add_to_group(Ruido.GRUPO)
	nivel.add_child(e)
	return e


func _media_radio(evs: Array) -> float:
	if evs.is_empty():
		return 0.0
	var s := 0.0
	for e in evs:
		s += e.radio
	return s / evs.size()


## ---------------------------------------------------------------- pruebas
func _unidad() -> void:
	await _cargar()
	var agachado := Ruido.radio_paso(0.075)
	var andando := Ruido.radio_paso(0.34)
	var corriendo := Ruido.radio_paso(1.0)
	_comprobar(agachado < andando and andando < corriendo, "pisada: agachado %.1f < andando %.1f < corriendo %.1f" % [agachado, andando, corriendo])
	_comprobar(is_equal_approx(corriendo, 32.0), "pisada corriendo = PasoMax (32)")
	_comprobar(is_equal_approx(Ruido.radio_paso(0.34, true), andando * 0.4), "pasito de ajuste = 40 % de la pisada")
	_comprobar(Ruido.radio_aterrizaje(5.0) == 0.0, "aterrizaje suave (5 studs/s) no suena")
	var salto := Ruido.radio_aterrizaje(12.1)
	_comprobar(salto > 8.0 and salto < 15.0, "aterrizaje de un salto normal ~10 studs (%.1f)" % salto)
	_comprobar(is_equal_approx(Ruido.radio_aterrizaje(60.0), 45.0), "caída fuerte = AterrizajeMax (45)")
	# radio percibido: campo abierto, con pared, fuera de alcance
	var p := _pies() + Vector3(0, 1, 0)
	var ev := Ruido.Evento.new(p, 20.0, Ruido.PASO, null)
	var mundo := J.get_world_3d()
	_comprobar(is_equal_approx(Ruido.radio_percibido(ev, p + Vector3(10, 0, 0), mundo), 20.0), "sin pared llega entero")
	_pared(p + Vector3(5, 0, 0), Vector3(0.5, 10, 10))
	await _esperar(0.1)
	_comprobar(is_equal_approx(Ruido.radio_percibido(ev, p + Vector3(10, 0, 0), mundo), 9.0), "con pared llega al 45 % (9)")
	# quien hace el ruido no se lo oye a sí mismo; los demás sí
	var e1 := _escucha()
	var e2 := _escucha()
	Ruido.emitir(J, p, 10.0, Ruido.GOLPE, e1)
	_comprobar(e1.eventos.is_empty() and e2.eventos.size() == 1, "la fuente no se oye a sí misma")


func _pasos() -> void:
	await _cargar()
	var e := _escucha()
	J.yaw = PI / 2 # hacia -X: camino despejado
	# andando
	_tecla(KEY_W, true)
	await _esperar(3.0)
	_tecla(KEY_W, false)
	var andar: Array = e.filtrar(J, Ruido.PASO)
	_comprobar(andar.size() >= 4, "andando 3 s: %d pisadas (>= 4)" % andar.size())
	# parado (tras asentarse)
	await _esperar(2.0)
	e.eventos.clear()
	await _esperar(2.0)
	var quieto: Array = e.filtrar(J, Ruido.PASO)
	_comprobar(quieto.is_empty(), "parado 2 s: %d pisadas (0)" % quieto.size())
	# agachado
	_tecla(KEY_C, true)
	_tecla(KEY_C, false)
	await _esperar(1.0)
	e.eventos.clear()
	_tecla(KEY_W, true)
	await _esperar(3.0)
	_tecla(KEY_W, false)
	var agachado: Array = e.filtrar(J, Ruido.PASO)
	_tecla(KEY_C, true)
	_tecla(KEY_C, false)
	await _esperar(1.5)
	# corriendo
	e.eventos.clear()
	_tecla(KEY_SHIFT, true)
	_tecla(KEY_W, true)
	await _esperar(3.0)
	_tecla(KEY_W, false)
	_tecla(KEY_SHIFT, false)
	var correr: Array = e.filtrar(J, Ruido.PASO)
	var ra := _media_radio(agachado)
	var rn := _media_radio(andar)
	var rc := _media_radio(correr)
	print("  radios medios: agachado %.1f · andando %.1f · corriendo %.1f studs" % [ra, rn, rc])
	_comprobar(agachado.size() >= 2, "agachado también pisa (%d)" % agachado.size())
	_comprobar(ra < rn and rn < rc, "agachado < andando < corriendo")
	_comprobar(rc > 25.0, "correr se oye a más de 25 studs (%.1f)" % rc)


func _disparo() -> void:
	await _cargar()
	var e := _escucha()
	J.arsenal.select_slot(0) # pistola
	await _esperar(1.5)
	J.arsenal.shoot()
	await _esperar(0.2)
	var disparos: Array = e.filtrar(J, Ruido.DISPARO)
	_comprobar(disparos.size() == 1, "un disparo = un ruido de disparo (%d)" % disparos.size())
	if disparos.size() > 0:
		_comprobar(is_equal_approx(disparos[0].radio, 180.0), "radio = Alert de la pistola (180)")
	var impactos: Array = e.filtrar(null, Ruido.IMPACTO)
	_comprobar(impactos.size() == 1, "la bala suena donde impacta, sin fuente (%d)" % impactos.size())


func _oye_disparo() -> void:
	await _cargar()
	var z := _zombi_a(Vector3(1, 0, 0), 60.0)
	await _esperar(2.0)
	_comprobar(z.estado == Zombi.Estado.DEAMBULAR and z.alerta == 0.0, "con el jugador quieto, el zombi no se entera")
	var d0 := z.global_position.distance_to(J.global_position)
	J.arsenal.select_slot(0)
	await _esperar(1.5)
	J.arsenal.shoot()
	await _esperar(0.1)
	_comprobar(z.estado == Zombi.Estado.INVESTIGAR or z.estado == Zombi.Estado.PERSEGUIR, "oye el disparo a 60 studs (%s)" % z.nombre_estado())
	await _esperar(5.0)
	var d1 := z.global_position.distance_to(J.global_position)
	_comprobar(d0 - d1 > 10.0, "se acerca: %.1f -> %.1f studs" % [d0, d1])


func _sigilo() -> void:
	await _cargar()
	# todo en la zona despejada (hacia -X); ojo: un obstáculo en medio amortiguaría el ruido (oclusión)
	var z := _zombi_a(Vector3(0, 0, 1), 22.0)
	await _esperar(0.5)
	J.yaw = PI / 2 # hacia -X (de lado respecto al zombi)
	_tecla(KEY_C, true)
	_tecla(KEY_C, false)
	await _esperar(1.2)
	_tecla(KEY_W, true)
	await _esperar(3.0)
	_tecla(KEY_W, false)
	_comprobar(z.alerta == 0.0 and z.estado == Zombi.Estado.DEAMBULAR, "agachado a ~22 studs: no le oye (alerta %.2f)" % z.alerta)
	_tecla(KEY_C, true)
	_tecla(KEY_C, false)
	await _esperar(1.5)
	_tecla(KEY_W, true)
	await _esperar(1.0)
	_tecla(KEY_W, false)
	await _esperar(0.5)
	_comprobar(z.alerta == 0.0, "andando a ~25 studs: no le oye (alerta %.2f)" % z.alerta)
	# corriendo: otro zombi a 15 studs del camino que va a recorrer (lo pasa de largo)
	var z2 := dz.crear_zombi(_pies() + Vector3(-20, 0, 0) + Vector3(0, 0, 15), 0.0, false)
	await _esperar(0.5)
	_tecla(KEY_SHIFT, true)
	_tecla(KEY_W, true)
	await _esperar(2.5)
	_tecla(KEY_W, false)
	_tecla(KEY_SHIFT, false)
	_comprobar(z2.pista != null and z2.estado != Zombi.Estado.DEAMBULAR, "corriendo a ~15 studs: le oye y va a por él (%s, alerta %.2f)" % [z2.nombre_estado(), z2.alerta])


func _oclusion() -> void:
	await _cargar()
	var z := _zombi_a(Vector3(1, 0, 0), 20.0)
	# pared larga entre los dos, paralela a la carrera del jugador
	_pared(_pies() + Vector3(10, 6, -20), Vector3(1, 12, 80))
	await _esperar(0.5)
	J.yaw = 0.0
	_tecla(KEY_SHIFT, true)
	_tecla(KEY_W, true)
	await _esperar(2.5)
	_tecla(KEY_W, false)
	_tecla(KEY_SHIFT, false)
	await _esperar(0.3)
	_comprobar(z.alerta == 0.0 and z.estado == Zombi.Estado.DEAMBULAR, "corriendo a 20 studs tras una pared: no le oye (alerta %.2f)" % z.alerta)


func _jauria() -> void:
	await _cargar()
	var a := _zombi_a(Vector3(1, 0, 0), 6.0)
	var b := _zombi_a(Vector3(1, 0, 0), 41.0)
	await _esperar(0.5)
	# un ruido fuerte del jugador que solo llega al zombi A
	Ruido.emitir(J, J.global_position, 25.0, Ruido.DISPARO, J)
	await _esperar(0.1)
	_comprobar(a.estado == Zombi.Estado.PERSEGUIR, "A oye al jugador y persigue (%s)" % a.nombre_estado())
	_comprobar(b.estado == Zombi.Estado.INVESTIGAR, "B oye el gruñido de A y va a mirar (%s)" % b.nombre_estado())
	_comprobar(b.pista != null and not b.pista.del_jugador, "B no sabe que es el jugador: va hacia A")


func _navegacion() -> void:
	await _cargar()
	print("  malla de navegación: %d polígonos, horneada en %d ms" % [dz.region.navigation_mesh.get_polygon_count(), int(dz.tiempo_horneado_ms)])
	_comprobar(dz.region.navigation_mesh.get_polygon_count() > 50, "hay malla de navegación")
	# zombi detrás de la pared alta del nivel (z = 20 m, 16 m de ancho): tiene que rodearla
	var m := 1.0 / 0.31
	var z := dz.crear_zombi(Vector3(0, 0, 24) * m, 0.0, false)
	var destino := Vector3(0, 0, 15) * m
	await _esperar(0.5)
	z._percibir(destino, 0.5, false)
	var mejor := 999.0
	var max_x := 0.0
	for i in 30:
		await _esperar(1.0)
		mejor = minf(mejor, Vector2(z.global_position.x - destino.x, z.global_position.z - destino.z).length())
		max_x = maxf(max_x, absf(z.global_position.x))
		if mejor < 4.0:
			break
	_comprobar(mejor < 4.0, "llega al otro lado de la pared (a %.1f studs del destino)" % mejor)
	_comprobar(max_x > 20.0, "la rodea en vez de atravesarla (se separa %.1f studs del centro)" % max_x)


func _ataque_y_muerte() -> void:
	await _cargar()
	var z := _zombi_a(Vector3(1, 0, 0), 14.0)
	J.arsenal.select_slot(0)
	await _esperar(1.5)
	J.arsenal.shoot()
	var herido := false
	for i in 120:
		await _esperar(0.1)
		if J.health < 100.0:
			herido = true
			break
	_comprobar(herido, "el zombi llega y ataca (vida %.0f, estado %s)" % [J.health, z.nombre_estado()])
	var escena := current_scene
	J.recibir_danio(500.0, z.global_position)
	_comprobar(J.health == 0.0, "con vida 0 el jugador muere")
	await _esperar(J.MUERTE_REINICIO + 1.0)
	_comprobar(current_scene != escena and current_scene != null, "el nivel se reinicia solo tras morir")


func _regeneracion() -> void:
	await _cargar()
	J.recibir_danio(30.0)
	_comprobar(is_equal_approx(J.health, 70.0), "recibe 30 de daño (vida %.0f)" % J.health)
	await _esperar(5.0)
	_comprobar(is_equal_approx(J.health, 70.0), "no regenera antes de RegenDelay")
	await _esperar(7.0)
	_comprobar(J.health > 70.0, "pasado RegenDelay regenera (vida %.1f)" % J.health)


func _danio_zombi() -> void:
	await _cargar()
	var adelante := Rbx.look(J.root_cf())
	# bala: apuntando con la pistola a un zombi de frente
	var z1 := _zombi_a(adelante, 15.0)
	J.arsenal.select_slot(0)
	J.aiming = true
	await _esperar(1.5)
	await _apuntar_a(z1.centro())
	J.arsenal.shoot()
	await _esperar(0.2)
	_comprobar(z1.health < 100.0, "las balas le hacen daño (vida %.0f)" % z1.health)
	_comprobar(z1.alerta >= 0.9, "nota el impacto y se pone furioso (alerta %.2f)" % z1.alerta)
	# qué pieza toca la bala (un solo cuerpo de impacto por zombi + cálculo por piezas)
	var lado := Rbx.right(z1.global_transform)
	var o_centro := z1.global_position + Vector3(0, 0.9, 0) - Rbx.look(z1.global_transform) * 6.0 # a la altura del pecho
	var dentro: Dictionary = z1.impacto_bala(o_centro, Rbx.look(z1.global_transform))
	var fuera: Dictionary = z1.impacto_bala(o_centro + lado * 1.25, Rbx.look(z1.global_transform))
	_comprobar(not dentro.is_empty(), "una bala por el centro toca una pieza (%s)" % dentro.get("pieza", "-"))
	_comprobar(fuera.is_empty(), "una bala que pasa por el costado no toca nada (sigue su camino)")
	# muerte
	var muerto: bool = z1.recibir_danio(500.0, "UpperTorso", adelante * 45.0)
	_comprobar(muerto and z1.estado == Zombi.Estado.MUERTO, "con vida 0 muere")
	_comprobar(not z1.is_in_group(Ruido.GRUPO), "muerto ya no oye")
	await _esperar(1.0)
	# disparo a la cabeza: la pistola (34 x 3) lo mata de un tiro
	var z4 := _zombi_a(adelante, 15.0)
	await _esperar(0.5)
	await _apuntar_a((z4.rig.P.Head as Node3D).global_position)
	J.arsenal.shoot()
	await _esperar(0.2)
	_comprobar(z4.estado == Zombi.Estado.MUERTO, "disparo a la cabeza: muere de un tiro (%s, vida %.0f)" % [z4.nombre_estado(), z4.health])
	J.aiming = false
	await _esperar(1.0)
	# golpe con el bate
	var z2 := _zombi_a(adelante, 5.0)
	await _esperar(0.3)
	J.arsenal._resolver_golpe("Bate")
	_comprobar(z2.health < 100.0, "el bate le golpea (vida %.0f)" % z2.health)
	z2.queue_free()
	await _esperar(0.3)
	# con una pared en medio, el golpe no pasa (AUDITORIA §7.1)
	var z3 := _zombi_a(adelante, 5.0)
	_pared(_pies() + adelante * 2.5 + Vector3(0, 5, 0), Vector3(10, 10, 0.5), adelante)
	await _esperar(0.3)
	J.arsenal._resolver_golpe("Bate")
	_comprobar(is_equal_approx(z3.health, 100.0), "a través de una pared no le golpea (vida %.0f)" % z3.health)


func _maniqui() -> void:
	await _cargar()
	var adelante := Rbx.look(J.root_cf())
	var m := Maniqui.new()
	m.position = _pies() + adelante * 5.0
	nivel.add_child(m)
	await _esperar(0.3)
	var zona := m.get_node("Rig").find_children("Zona_Head", "StaticBody3D", true, false)
	_comprobar(not zona.is_empty() and zona[0].has_meta("objetivo"), "las zonas del maniquí cumplen el contrato de objetivo")
	J.arsenal._resolver_golpe("Bate")
	_comprobar(m.health < 100.0, "el bate golpea al maniquí (vida %.0f)" % m.health)


## regresión de la auditoría: andar 4 s desde parado (antes de estos cambios: 17,97 studs a 60 FPS)
func _andar() -> void:
	await _cargar()
	# igual que la medición de la auditoría: hacia donde mira al empezar (-Z), sin girar
	var p0 := J.global_position
	var t0 := J.reloj
	_tecla(KEY_W, true)
	while J.reloj - t0 < 4.0: # con el reloj del juego, como la auditoría
		await process_frame
	_tecla(KEY_W, false)
	var d := Vector2(J.global_position.x - p0.x, J.global_position.z - p0.z).length()
	_comprobar(absf(d - 17.97) < 0.1, "andando 4 s recorre lo mismo que antes (%.2f studs, antes 17.97)" % d)


## regresión de la auditoría: cadencia del rifle a 60 FPS (antes: 31 disparos en 3 s)
func _cadencia() -> void:
	await _cargar()
	J.arsenal.select_slot(1)
	J.arsenal.balas_infinitas = true
	await _esperar(2.0)
	var n := 0
	var ultimo: float = J.arsenal.last_shot
	J.firing = true
	for i in 180:
		await process_frame
		if J.arsenal.last_shot != ultimo:
			n += 1
			ultimo = J.arsenal.last_shot
	J.firing = false
	_comprobar(absi(n - 31) <= 1, "rifle: %d disparos en 3 s (antes 31)" % n)


## partida corta con los zombis del nivel: disparar los alerta y no sale ningún error
func _completo() -> void:
	await _cargar(true)
	_comprobar(dz.zombis().size() == 4, "el nivel trae 4 zombis (%d)" % dz.zombis().size())
	await _esperar(3.0)
	J.arsenal.select_slot(0)
	await _esperar(1.5)
	J.arsenal.shoot()
	await _esperar(0.2)
	var alertados := 0
	for z in dz.zombis():
		if z.estado != Zombi.Estado.DEAMBULAR:
			alertados += 1
	_comprobar(alertados >= 1, "el disparo alerta a algún zombi del nivel (%d de 4)" % alertados)
	J.yaw = PI / 2
	_tecla(KEY_SHIFT, true)
	_tecla(KEY_W, true)
	await _esperar(3.0)
	_tecla(KEY_W, false)
	_tecla(KEY_SHIFT, false)
	await _esperar(12.0)
	for z in dz.zombis():
		print("  %s: %s, alerta %.2f" % [z.name, z.nombre_estado(), z.alerta])


## coste por fotograma (tiempo real, informativo): el nivel sin zombis y con 30 zombis deambulando.
## Sin pantalla (headless): no incluye el coste de dibujar (las ~50 mallas de cada zombi en la GPU).
func _rendimiento() -> void:
	await _cargar()
	await _esperar(1.0)
	var base: float = await _medir(4.0)
	for i in 30:
		var a := TAU * i / 30.0
		dz.crear_zombi(_pies() + Vector3(cos(a), 0, sin(a)) * (60.0 + 4.0 * (i % 5)), 0.0, true)
	await _esperar(1.0)
	var con: float = await _medir(4.0)
	print("  sin zombis: %.2f ms por fotograma · con 30 zombis: %.2f ms (~%.3f ms por zombi)" % [base, con, (con - base) / 30.0])
	_comprobar(dz.zombis().size() == 30, "30 zombis activos")
	_comprobar((con - base) / 30.0 < 0.5, "cada zombi cuesta menos de 0,5 ms de CPU por fotograma")


## tiempo real medio por fotograma (ms); el juego corre sin esperar (headless + --fixed-fps)
func _medir(segundos: float) -> float:
	await process_frame
	var n := int(segundos * 60.0)
	var t0 := Time.get_ticks_usec()
	for i in n:
		await process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n
