class_name ImpactoCC
extends RefCounted
## SENSACIÓN DE IMPACTO Y AJUSTE AL BLANCO del combate cuerpo a cuerpo (2026-11-08, 6; KangooG: "que de verdad se
## sienta que le estoy pegando, no a una imagen" y "que el personaje se ajuste a la pegada: si el zombi está en el
## suelo, que se incline a pegarle"). Lo crea el Arsenal (`arsenal.impacto`); las reglas del golpe (contacto, daño,
## empuje, caída) siguen en Arsenal._cc_impacto / _resolver_golpe, que llaman a golpe() al tocar.
##
## 1) AL TOCAR (golpe):
##    - parón: el tiempo casi se detiene un instante (Engine.time_scale, 50-90 ms reales: más cuanto más fuerte);
##    - el miembro se queda en el punto de contacto (la acción se detiene DETENCION_*: no atraviesa el cuerpo) y luego
##      rebota hacia atrás (REBOTE_*);
##    - la pieza golpeada del otro se hunde (`reaccion_golpe(pieza, dir, fuerza)`, opcional en el contrato de objetivo:
##      cabeza, pecho, barriga o piernas reaccionan distinto);
##    - sacudida y golpe de zoom de la cámara, y el sonido sordo de la carne encima del golpe.
## 2) AJUSTE (preparar + paso): al empezar una acción se elige el blanco (también si está en el suelo) y la pieza a la
##    que va. Hasta el golpe el cuerpo baja la cadera, se inclina y mira hacia ella, y la mano / el arma / el pie se
##    desvían hasta ella (con topes). El Animador lo suma: _paso_cc → sumar_cuerpo, marco/mano_local (manos y arma) y
##    pie_offset (patada y pisotón). De pie y a la altura de siempre apenas cambia nada (ZONA_MUERTA).

const PARON_ESCALA := 0.12        # velocidad del tiempo durante el parón
const PARON_MIN := 0.05           # s reales (golpe flojo) ...
const PARON_MAX := 0.09           # ... (golpe fuerte)
const DETENCION_MIN := 0.04       # s de juego que el miembro se queda en el contacto
const DETENCION_MAX := 0.09
const REBOTE_DUR := 0.2
const REBOTE_MIN := 0.1           # studs que rebota la mano / el pie
const REBOTE_MAX := 0.32
const DV_FUERTE := 16.0           # Δv (studs/s) que cuenta como golpe "a tope"
const ZONA_MUERTA := 0.35         # studs: con el blanco de pie, diferencias menores no se corrigen
const BAJA_MAX := 1.6             # lo más que baja la cadera (studs)
const INCLINA_MAX := 1.0          # lo más que se inclina el tronco hacia delante (rad)
const MANO_X := 0.8               # topes de lo que se desvía la mano / el arma (studs)
const MANO_Y_ABAJO := 2.4
const MANO_Y_ARRIBA := 0.6
const PIE_XZ := 1.3               # topes del pie
const PIE_ARRIBA := 1.7

var ar          # Arsenal
var J:          # Jugador (el del Arsenal)
	get:
		return ar.J
var _ac = null                # la acción preparada (el mismo diccionario que Arsenal.cc.accion)
var _blanco = null
var _pieza := ""
var _caido := false
var _pg := {}                 # pose de la acción en el momento del golpe
var _golpe_u := 0.4
var _av_golpe := 0.0          # avance de la animación hasta el golpe
var _miembro := ""            # "mr_" / "ml_" (mano), "a_p" (arma) o "pie"
var _punto := Vector3.ZERO    # adónde va el golpe (mundo)
var _w := 0.0                 # cuánto manda el ajuste en este fotograma
var _cuerpo := {}             # ajuste del cuerpo (ya con su peso)
var _local := Vector3.ZERO    # desvío de la mano / el arma en el marco del pecho (ya con su peso y el rebote)
var _pecho_rel := Vector3(0, 1.0, 0)   # pecho respecto a la raíz sin ajuste (marco del rumbo)
var _paso_t := 0.0
var _w_resto := 0.0           # lo que queda del ajuste de la acción anterior (encadenando golpes)
var _rebote_t0 := -9.0
var _rebote_amp := 0.0
var _escala_prev := 1.0
var _paron_n := 0
var _en_paron := false
var ultimo := {}              # (para las pruebas) último golpe: {tipo, dv, pieza, paron, detencion}


func _init(arsenal) -> void:
	ar = arsenal


## ---------------------------------------------------------------- 2) AJUSTE AL BLANCO
## al empezar una acción (empujón, patada, pisotón, puñetazo o golpe con arma de los de Blender)
func preparar(ac: Dictionary, a: Dictionary) -> void:
	_ac = ac
	_golpe_u = float(a.golpe)
	_pg = CombateCC.pose(a, _golpe_u)
	_av_golpe = CombateCC._abierta(a.canales.avance, _golpe_u) if a.canales.has("avance") else 0.0
	var tipo := str(ac.tipo)
	if tipo == "patada" or tipo == "pisoton":
		_miembro = "pie"
	elif tipo == "golpe" and _pg.has("a_px"):
		_miembro = "a_p"
	elif _pg.has("ml_z") and float(_pg.get("ml_z", 0.0)) < float(_pg.get("mr_z", 0.0)):
		_miembro = "ml_"
	else:
		_miembro = "mr_"
	_w_resto = _w # (encadenando golpes, el cuerpo no salta: sale de donde estaba)
	_blanco = null
	var b: Array = ar.cc_blanco(4.6)  # (los de pie primero: Arsenal.cc_blanco)
	if b.is_empty():
		return
	var o = b[1]
	_caido = not o.en_pie()
	if _caido and tipo == "empujon":
		return # (a uno en el suelo no se le empuja)
	_blanco = o
	_pieza = _elegir_pieza(tipo, a)
	_actualizar_punto()


func _elegir_pieza(tipo: String, a: Dictionary) -> String:
	if _caido:
		var quiere := "UpperTorso"
		if tipo == "pisoton":
			quiere = "Head" if randf() < 0.35 else "UpperTorso"
		elif str(a.get("pieza", "")) == "Head":
			quiere = "Head"
		# si el pecho / la cabeza quedan lejos (se tiene delante las piernas), a la pieza que se alcance
		var root: Vector3 = J.root_cf().origin
		var q: Node3D = _blanco.rig.P.get(quiere)
		if q and Rbx.flat(q.global_position - root).length() < 3.6:
			return quiere
		var mejor := quiere
		var md := INF
		for pn in ["Head", "UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]:
			var nd: Node3D = _blanco.rig.P.get(pn)
			if nd:
				var dd := Rbx.flat(nd.global_position - root).length()
				if dd < md:
					md = dd
					mejor = pn
		return mejor
	if tipo == "patada":
		return "LowerTorso"
	return str(a.get("pieza", "UpperTorso"))


func _actualizar_punto() -> void:
	if _blanco == null or not is_instance_valid(_blanco):
		return
	var nd: Node3D = _blanco.rig.P.get(_pieza)
	if nd == null:
		nd = _blanco.rig.P.UpperTorso
	_punto = nd.global_position
	if _caido:
		# tumbado: a la cara de arriba de la pieza (lo más fino de la caja es lo que queda de alto)
		var sz: Vector3 = nd.get_meta("size", Vector3.ONE)
		_punto.y += minf(sz.x, minf(sz.y, sz.z)) * 0.5


func _rumbo() -> Basis:
	var lk: Vector3 = Rbx.flat(Rbx.look(J.root_cf()))
	lk = lk.normalized() if lk.length() > 0.01 else Vector3(0, 0, -1)
	return Basis.looking_at(lk, Vector3.UP)


func _canal(eje: String) -> float:
	var k := ("a_p" + eje) if _miembro == "a_p" else (_miembro + eje)
	return float(_pg.get(k, 0.0))


func _restante() -> float:
	# lo que aún avanzará el cuerpo hasta el golpe (el blanco parece más cerca de lo que estará)
	if _ac == null:
		return 0.0
	return maxf(0.0, _av_golpe + float(_ac.get("extra", 0.0)) - float(_ac.get("avance_prev", 0.0)))


## cada fotograma (Arsenal._cc_paso): sigue al blanco hasta el golpe y calcula el ajuste del cuerpo
func paso(now: float) -> void:
	var ac = ar.cc.accion
	var root: Transform3D = J.root_cf()
	var yb := _rumbo()
	var dt := clampf(now - _paso_t, 0.0, 0.1)
	_paso_t = now
	if ac == null or not is_same(ac, _ac):
		# acabada la acción, el cuerpo vuelve suave (no de golpe) a como estaba
		_w = Rbx.damp(_w, 0.0, 7.0, dt) if _w > 0.01 else 0.0
		if _w == 0.0:
			_cuerpo = {}
			_blanco = null
		if ac == null and _w == 0.0 and ar.cc_puede():
			# (sin acción: dónde queda el pecho respecto a la raíz, para saber a qué altura pega cada golpe)
			var ut: Node3D = J.rig.P.get("UpperTorso")
			if ut:
				_pecho_rel = _pecho_rel.lerp(yb.inverse() * (ut.global_position - root.origin), 0.2)
		return
	var u := (now - float(ac.t0)) / maxf(0.01, float(ac.dur))
	if u < _golpe_u + 0.04:
		_actualizar_punto()
	_w_resto = Rbx.damp(_w_resto, 0.0, 7.0, dt)
	if _blanco == null:
		_w = _w_resto
		return
	# entra hasta el golpe y sale poco a poco después (en segundos: igual de suave en acciones cortas y largas)
	var tras := (u - _golpe_u) * float(ac.dur)
	_w = maxf(_w_resto, Rbx.smooth(u / maxf(0.05, _golpe_u * 0.85)) * (1.0 - 0.6 * Rbx.smooth((tras - 0.08) / 0.35)))
	_cuerpo = {}
	if _miembro == "pie" and str(ac.tipo) == "patada":
		return # (la patada de pie solo desvía el pie)
	var rel: Vector3 = yb.inverse() * (_punto - root.origin)
	var nat := _pecho_rel + Vector3(_canal("x"), _canal("y"), _canal("z") - _restante())
	# (lo que la propia animación ya baja e inclina el cuerpo: p. ej. las de suelo van agachadas)
	var pa := absf(float(_pg.get("cin_p", 0.0)))
	nat += Vector3(0, float(_pg.get("cad_y", 0.0)) - 0.7 * (1.0 - cos(pa)), float(_pg.get("cad_z", 0.0)) - 0.7 * sin(pa) * signf(-float(_pg.get("cin_p", 0.0))))
	if _miembro == "pie":
		# pisotón: la cadera ya baja en la animación; si el cuerpo está más bajo de lo previsto, algo más
		nat = Vector3(0, -2.0 - 0.27 - 0.5, -1.7)
		rel.y += 0.3 # (el tobillo, por encima de lo que pisa)
	var dy: float = rel.y - nat.y
	if not _caido:
		dy = signf(dy) * maxf(absf(dy) - ZONA_MUERTA, 0.0)
	var c := {}
	if dy < -0.05:
		var baja := clampf(dy * (0.25 if _miembro == "pie" else 0.5), -BAJA_MAX, 0.0)
		var resto: float = dy - baja
		var inclina := clampf(-resto * 0.4, 0.0, INCLINA_MAX)
		c = {"cad_y": baja, "cad_z": -baja * 0.18, "cin_p": -inclina, "cue_p": -inclina * 0.45, "pel_p": -inclina * 0.15}
	var dx: float = rel.x - nat.x
	if absf(dx) > 0.2:
		c["cin_y"] = clampf(-dx * 0.2, -0.3, 0.3)
	_cuerpo = c


## Animador._paso_cc: suma el ajuste del cuerpo a los canales de este fotograma
func sumar_cuerpo(pose: Dictionary) -> void:
	for k in _cuerpo:
		pose[k] = float(pose.get(k, 0.0)) + float(_cuerpo[k]) * _w


## Animador, con el marco del pecho de este fotograma (girado solo con el rumbo): calcula el desvío de la mano / el arma
func marco(m: Transform3D) -> void:
	_local = Vector3.ZERO
	if _w > 0.001 and _blanco != null and _miembro != "pie":
		var loc := m.affine_inverse() * _punto
		loc.z += _restante()
		var d := loc - Vector3(_canal("x"), _canal("y"), _canal("z"))
		if _caido:
			d.z = clampf(d.z, -0.9, 0.6)
		else:
			# de pie: solo la altura y el lado (la distancia la pone el avance del cuerpo), con zona muerta
			d.z = 0.0
			d.x = signf(d.x) * maxf(absf(d.x) - ZONA_MUERTA, 0.0)
			d.y = signf(d.y) * maxf(absf(d.y) - ZONA_MUERTA, 0.0)
		d.x = clampf(d.x, -MANO_X, MANO_X)
		d.y = clampf(d.y, -MANO_Y_ABAJO, MANO_Y_ARRIBA)
		_local = d * _w
	if _miembro != "pie":
		_local.z += _rebote(ar.ahora())


## ¿la acción en curso va a uno que está en el suelo? (Arsenal._cc_impacto: solo entonces cuentan los cuerpos del suelo)
func va_al_suelo() -> bool:
	return _blanco != null and is_instance_valid(_blanco) and _caido and is_same(ar.cc.accion, _ac)


## desvío (marco del pecho) de la mano k ("mr_" / "ml_") o del arma ("a_p")
func mano_local(k: String) -> Vector3:
	if k == _miembro:
		return _local
	return _local * 0.6


## desvío del pie que patea / pisa (mundo), con la cadera de este fotograma
func pie_offset(hip: Vector3, yb: Basis) -> Vector3:
	var atras := yb * Vector3(0, 0, 1)
	var reb := atras * _rebote(ar.ahora()) if _miembro == "pie" else Vector3.ZERO
	if _miembro != "pie" or _w <= 0.001 or _blanco == null:
		return reb
	var nat := hip + yb * Vector3(float(_pg.get("pie_x", 0.0)), float(_pg.get("pie_y", -2.0)), float(_pg.get("pie_z", -1.7)) - _restante())
	var obj := _punto
	var d := Vector3.ZERO
	if str(_ac.tipo) == "pisoton":
		obj.y += 0.3 # (el tobillo, por encima de la suela)
		d = obj - nat
		d.x = clampf(d.x, -PIE_XZ, PIE_XZ)
		d.z = clampf(d.z, -PIE_XZ, PIE_XZ)
		d.y = clampf(d.y, -0.3, PIE_ARRIBA)
	else:
		# patada a uno de pie: solo hacia el lado y la altura, poco
		var l := yb.inverse() * (obj - nat)
		l.z = 0.0
		l.x = clampf(signf(l.x) * maxf(absf(l.x) - ZONA_MUERTA, 0.0), -0.5, 0.5)
		l.y = clampf(signf(l.y) * maxf(absf(l.y) - ZONA_MUERTA, 0.0), -0.5, 0.5)
		d = yb * l
	return d * _w + reb


func _rebote(now: float) -> float:
	var t := now - _rebote_t0
	if t <= 0.0 or t >= REBOTE_DUR:
		return 0.0
	return _rebote_amp * sin(PI * t / REBOTE_DUR)


## ---------------------------------------------------------------- 1) AL TOCAR
## lo llaman Arsenal._cc_impacto y _resolver_golpe cuando el golpe llega al cuerpo de alguien
func golpe(tipo: String, man, pieza: String, punto: Vector3, dv: float, dir: Vector3) -> void:
	var f := clampf(dv / DV_FUERTE, 0.0, 1.0)
	var paron := lerpf(PARON_MIN, PARON_MAX, f)
	_paron(paron)
	# el miembro se queda un instante en el contacto: la acción se detiene (y lo que venga después, también)
	var det := lerpf(DETENCION_MIN, DETENCION_MAX, f)
	var now: float = ar.ahora()
	var ac = ar.cc.accion
	if ac != null:
		ac.t0 = float(ac.t0) + det
		ar._cc_listo_t += det
	elif ar.anim and ar.anim.melee_st != null:
		ar.anim.melee_st.start = float(ar.anim.melee_st.start) + det
	_rebote_t0 = now + det
	_rebote_amp = lerpf(REBOTE_MIN, REBOTE_MAX, f)
	# la pieza golpeada se hunde
	if man != null and is_instance_valid(man) and man.has_method("reaccion_golpe"):
		man.reaccion_golpe(pieza, dir, dv)
	# cámara: sacudida y un pequeño golpe de zoom
	J.shake = minf(1.0, J.shake + 0.08 + 0.22 * f)
	J.cam_fov -= 0.6 + 2.2 * f
	# sonido sordo de la carne bajo el golpe
	Efectos.sonido(J, "Flesh", punto, 0.4 + 0.45 * f, 0.7 + 0.15 * randf())
	var suelo: bool = man != null and is_instance_valid(man) and not (man.vivo() and man.en_pie())
	ultimo = {"tipo": tipo, "dv": dv, "pieza": pieza, "paron": paron, "detencion": det, "t": now, "suelo": suelo}


func _paron(dur: float) -> void:
	var arbol: SceneTree = J.get_tree()
	if arbol == null:
		return
	if not _en_paron:
		_escala_prev = Engine.time_scale
	_en_paron = true
	Engine.time_scale = _escala_prev * PARON_ESCALA
	_paron_n += 1
	var n := _paron_n
	# (temporizador en tiempo real: no le afecta la escala)
	arbol.create_timer(dur, true, false, true).timeout.connect(func():
		if n == _paron_n:
			Engine.time_scale = _escala_prev
			_en_paron = false)


## (al salir de la escena con un parón a medias)
func soltar() -> void:
	if _en_paron:
		Engine.time_scale = _escala_prev
		_en_paron = false
		_paron_n += 1
