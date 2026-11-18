class_name Moto
extends CharacterBody3D
## MOTO (v0.4). Física de bicicleta simplificada, hecha a mano (sin RigidBody: así se controla bien y
## no hace cosas raras): rumbo + velocidad, dirección que se cierra con la velocidad, inclinación en las
## curvas (la que equilibra la fuerza centrífuga), cambio de marchas, derrape con el freno de mano,
## saltos (sale despedida de las rampas), caídas y choques. Todo en studs (gravedad 35).
##
## La conduce el Jugador (Jugador.subir_moto): cada fotograma le pasa los mandos con paso(dt, mandos).
## Sin piloto se mueve sola (rueda hasta pararse y se cae si nadie la sujeta, o se queda en la pata).
## Atropellar: golpea a los "objetivos" (zombis, maniquíes) con su contrato (recibir_danio, derribar).
## Hace ruido (Ruido.emitir, tipo "motor") según las revoluciones: los zombis la oyen de lejos.
##
## Capa de colisión 1 (como el escenario): para las balas, la cámara y los zombis es un obstáculo más.
## El jugador, mientras la conduce, la excluye de sus rayos (Jugador._excluir).

const C = preload("res://scripts/config/zconfig.gd")
const GRUPO := "motos"

## Roblox tenía TopSpeed 72, Accel 19, Brake 48, CrashSpeed 40; a pedido de KangooG (2026-10-24) más lenta
const VMAX := 50.0             # ~56 km/h
const ACEL := 19.0             # par: arranca con fuerza en las marchas cortas (ver la curva en paso())
const FRENO := 40.0
const INCL_MAX := 48.0 * PI / 180.0
const CHOQUE := 30.0           # velocidad de impacto (studs/s) contra una pared que tira al piloto
## (2026-10-28) contra algo BAJO (bloque, bordillo alto, el canto de una rampa: más bajo que OBST_BAJO) hace falta
## bastante más: por debajo de CHOQUE_BAJO la moto rebota y frena, pero el piloto aguanta
const CHOQUE_BAJO := 40.0
const OBST_BAJO := 1.4          # (studs, ~43 cm) más bajo que esto, el piloto sale por encima del obstáculo
const ESCALON_RAPIDO := 0.78    # deprisa, algo más (~24 cm). (2026-10-29) Antes despacio solo subía 14 cm y deprisa 19: tras
								# chocar con un bloque de 20 cm a medias (una rueda arriba y otra abajo) ya no podía subirlo nunca
const ATRAS := 5.0             # marcha atrás (empujando con los pies)
const AGARRE_RUEDA := 0.95     # coeficiente de agarre del neumático (acelerando, la rueda de atrás lleva ~80 % del peso)
const BATALLA := 4.6           # distancia entre ejes
const GRAV := 35.0
const AGARRE := 160.0          # cuánto se frena el deslizamiento lateral (studs/s²)
const AGARRE_DERRAPE := 9.0   # con el freno de mano
const MARCHAS := [0.0, 11.0, 19.0, 28.0, 38.0, 54.0] # velocidad máxima de cada marcha
const RUIDO_RALENTI := 26.0    # radio del ruido del motor al ralentí (studs)
const RUIDO_MAX := 95.0        # a tope de vueltas
const ATROPELLO_MIN := 9.0     # velocidad mínima para atropellar (más despacio, solo empuja)
const ALCANCE_SUBIR := 7.0
const ESCALON_MAX := 0.72      # bordillo más alto que sube despacio (studs, ~22 cm, 0,7 del radio de la rueda); más alto = obstáculo
const LEVANTAR_DUR := 1.6      # s que se tarda en levantar la moto del suelo
const HUNDIDO := 0.07          # cuánto se aplastan los neumáticos con el peso (studs)

var piloto: Node = null        # el Jugador que la conduce
var rumbo := 0.0               # hacia dónde mira (yaw)
var vel_h := Vector3.ZERO      # velocidad horizontal
var vel_v := 0.0
var en_aire := false
var t_aire := 0.0
var direccion := 0.0           # ángulo del manillar
var inclinacion := 0.0         # + = hacia la izquierda (giro sobre el eje longitudinal)
var cabeceo := 0.0             # + = morro arriba
var yaw_rate := 0.0
var rpm := 0.0                 # 0..1
var marcha := 1
var gas := 0.0
const PAUSA_ATRAS := 0.35 # S frena primero; al parar hay una pausa antes de empujar hacia atrás
var _espera_atras := 0.0
var frenando := 0.0
var derrapando := 0.0          # 0..1
var aparcada := true           # sobre la pata de cabra
var caida := false             # tumbada en el suelo
var caida_k := 0.0             # 0..1 (animación de caer / levantarla)
var caida_lado := 1.0
var luces := true
var motor_on := false
var susp := 0.0                # compresión media de la suspensión (studs; para el aplastado de los neumáticos)
var susp_v := 0.0
## SUSPENSIÓN (2026-10-29): delante (horquilla) y detrás (basculante + amortiguadores), cada una un muelle con
## amortiguación. Compresión en studs (0 = extendida del todo). La aprietan: el peso (SUSP_SAG), las ruedas al subir de
## golpe (baches, bordillos, aterrizajes: la velocidad vertical del eje cambia de repente), frenar (se hunde delante),
## acelerar (se agacha detrás) y tumbarse en las curvas. Solo es visual: el cuerpo y el piloto se mueven sobre las ruedas
var sus_d := 0.0
var sus_dv := 0.0
var sus_t := 0.0
var sus_tv := 0.0
var _vf_prev := 0.0
var _acel_long := 0.0
var _eje_vy := {}             # velocidad vertical de cada eje (fotograma anterior)
var _eje_y := {}
const SUSP_SAG := 0.12         # compresión con el peso de la moto (con piloto, más)
const SUSP_SAG_PILOTO := 0.2
const SUSP_RECORRIDO := 0.6    # compresión máxima (hace tope)
const SUSP_K := 170.0          # rigidez (frecuencia ~2 Hz)
const SUSP_C := 10.0           # amortiguación (rebota un poco)
var cab_suelo := 0.0           # inclinación del suelo bajo las ruedas (suavizada)
var suelo_del := {}            # último apoyo de cada rueda {pos, normal} (para aplastar el neumático)
var suelo_tras := {}
var levantando := false        # el jugador la está levantando (Jugador.levantar_moto)
var lev_k := 0.0               # 0..1
var _contacto_t := -9.0        # último golpe contra una pared (para no repetir golpe/sonido cada fotograma)
var apoyo := 2                 # ruedas en el suelo: 2, 1 (pivota sobre una) o 0 (en el aire). Ver _mover()
var cab_w := 0.0               # velocidad de giro del cabeceo (rad/s)
var _toca_del := true
var _toca_tras := true
var _malo := false             # el último aterrizaje fue malo (mal alineada)
var _pend_del := 0.0           # cuesta bajo cada rueda (de su último apoyo)
var _w_del := 0.0              # velocidad vertical de cada rueda en el suelo (ver SUSP_ACEL)
var _w_tras := 0.0
var _pend_tras := 0.0
var _vel_antes := Vector3.ZERO # velocidad (mundo) al empezar el fotograma (choques: hacia dónde sale el piloto)
const K2 := 2.2                # (radio de giro)² de la moto para el cabeceo (studs²)
const SUSP_ACEL := 120.0       # lo más que la suspensión acelera hacia arriba una rueda (studs/s²): un canto no la lanza
var _formas := []              # [CollisionShape3D, transform original]: se inclinan con el cabeceo

var n := {}                    # nodos del modelo (ModeloMoto.construir)
var _giro_ruedas := 0.0
var _ruido_t := 0.0
var _golpeados := {}           # id del objetivo -> hora del último golpe
var _reloj := 0.0
var _audio_motor: AudioStreamPlayer3D
var _audio_derrape: AudioStreamPlayer3D
var _chispa_t := 0.0
var ultimo_choque := 0.0       # (para las pruebas y el HUD)
var atropellos := 0


func _ready() -> void:
	add_to_group(GRUPO)
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1
	rumbo = rotation.y
	rotation = Vector3(0, rumbo, 0)
	n = ModeloMoto.construir(self)
	# colisión: el cuerpo (desde la altura de los ejes) y una esfera en cada rueda. Las ruedas apoyan con
	# rayos; las esferas quedan por encima del suelo (no rozan) y chocan con lo que no se puede subir
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1.0, 1.9, 3.4)
	cs.shape = caja
	cs.position = Vector3(0, 2.0, 0.15)
	add_child(cs)
	_formas.append([cs, cs.transform])
	for z in [ModeloMoto.EJE_DEL.z, ModeloMoto.EJE_TRAS.z]:
		var cr := CollisionShape3D.new()
		var esf := SphereShape3D.new()
		esf.radius = 0.55
		cr.shape = esf
		cr.position = Vector3(0, ModeloMoto.R_RUEDA, z)
		add_child(cr)
		_formas.append([cr, cr.transform])
	_audio_motor = AudioStreamPlayer3D.new()
	_audio_motor.stream = _sonido_motor()
	_audio_motor.unit_size = 14.0
	_audio_motor.max_distance = 700.0
	_audio_motor.volume_db = -4.0
	add_child(_audio_motor)
	_audio_derrape = AudioStreamPlayer3D.new()
	_audio_derrape.stream = _sonido_derrape()
	_audio_derrape.unit_size = 10.0
	_audio_derrape.volume_db = -80.0
	add_child(_audio_derrape)
	_poner_en_el_suelo()
	_visual(0.0)


## ---------------------------------------------------------------- consultas (Jugador, animador, pruebas)
func adelante() -> Vector3:
	return Vector3(-sin(rumbo), 0, -cos(rumbo))


func derecha() -> Vector3:
	return Vector3(cos(rumbo), 0, -sin(rumbo))


## velocidad hacia delante (negativa = marcha atrás)
func velocidad() -> float:
	return vel_h.dot(adelante())


## velocidad de verdad en el mundo (con las dos ruedas en el suelo, vel_h hacia delante va a lo largo de la cuesta)
func vel_mundo() -> Vector3:
	if apoyo == 2:
		var f := adelante()
		var vf := vel_h.dot(f)
		return vel_h - f * vf + f * (vf * cos(cab_suelo)) + Vector3(0, vf * sin(cab_suelo), 0)
	return vel_h + Vector3(0, vel_v, 0)


## transform del cuerpo de la moto (con inclinación, cabeceo y suspensión)
func cuerpo_cf() -> Transform3D:
	return (n.cuerpo as Node3D).global_transform


## dónde va sentado el piloto: el centro de su cuerpo (HumanoidRootPart) sobre el asiento
func asiento_cf() -> Transform3D:
	return cuerpo_cf() * Transform3D(Basis.IDENTITY, ModeloMoto.ASIENTO + Vector3(0, 0.66, 0.05))


## puños del manillar y estriboss (para las manos y los pies del piloto), en el mundo
func puno(lado: String) -> Transform3D:
	var g: Node3D = n.giro
	var x := -0.82 if lado == "L" else 0.82
	return g.global_transform * Transform3D(Basis.IDENTITY, Vector3(x, 0.42, 0.2))


func estribo(lado: String) -> Vector3:
	var x := -ModeloMoto.ESTRIBO.x if lado == "L" else ModeloMoto.ESTRIBO.x
	return cuerpo_cf() * Vector3(x, ModeloMoto.ESTRIBO.y + 0.12, ModeloMoto.ESTRIBO.z)


## ¿está "pos" a un lado de la moto? (2026-10-29: para subirse o levantarla hay que ponerse a su lado, no delante
## ni detrás). Tumbada, a lo largo de su eje (el de las ruedas)
func de_lado(pos: Vector3) -> bool:
	var cpo := cuerpo_cf() if caida else global_transform
	var eje := Rbx.flat(cpo.basis.z)
	eje = eje.normalized() if eje.length() > 0.2 else Rbx.flat(global_transform.basis.z).normalized()
	var d := Rbx.flat(pos - cpo.origin)
	var a_lo_largo := absf(d.dot(eje))
	var al_lado := (d - eje * d.dot(eje)).length()
	return a_lo_largo < 2.1 and al_lado < ALCANCE_SUBIR and al_lado > 0.4


func se_puede_subir() -> bool:
	return piloto == null and not caida and not levantando and caida_k < 0.01


## ---------------------------------------------------------------- subir / bajar / caer
func subir(j: Node) -> void:
	_espera_atras = 0.0
	piloto = j
	aparcada = false
	motor_on = true
	if not _audio_motor.playing:
		_audio_motor.play()
	Efectos.sonido(self, "Draw", global_position, 0.6, 0.5)


## el piloto se baja (o sale despedido). Parada o casi: se queda en la pata de cabra
func bajar() -> void:
	piloto = null
	motor_on = false
	gas = 0.0
	# (despacio, o marcha atrás empujando con los pies: el piloto la deja en la pata)
	if velocidad() < 4.0 and velocidad() > -ATRAS - 1.0 and not en_aire:
		aparcada = true
		vel_h = Vector3.ZERO


## la moto se cae de lado (choque, o sin nadie que la sujete)
## La caída es FÍSICA: la moto pasa a ser un cuerpo rígido (RigidBody3D) con su forma (chasis, ruedas,
## manillar, estribos) y la velocidad que llevaba: vuelca, da vueltas, se arrastra soltando chispas y se
## para donde tenga que pararse (apoyada en el manillar y el estribo, como una moto de verdad).
func caer(lado := 0.0) -> void:
	if caida:
		return
	caida = true
	aparcada = false
	motor_on = false
	caida_lado = lado if lado != 0.0 else (signf(inclinacion) if absf(inclinacion) > 0.05 else (1.0 if randf() < 0.5 else -1.0))
	Ruido.emitir(self, global_position, 40.0, Ruido.GOLPE, self)
	_crear_fisica()


## levantarla del suelo: el jugador la va levantando (Jugador.levantar_moto pone lev_k de 0 a 1); al
## terminar se queda en la pata. Sin animación (trucos): levantar() la pone de pie al momento
func levantar() -> void:
	if not caida:
		return
	var de_pie := _pose_de_pie()
	_quitar_fisica()
	# la moto queda donde se paró, en la pata, mirando hacia donde apuntaba
	global_transform = Transform3D(Basis(Vector3.UP, de_pie[1]), de_pie[0])
	rumbo = de_pie[1]
	caida = false
	levantando = false
	lev_k = 0.0
	caida_k = 0.0
	aparcada = true
	vel_h = Vector3.ZERO
	vel_v = 0.0
	en_aire = false
	apoyo = 2
	_toca_del = true
	_toca_tras = true
	cab_w = 0.0
	cabeceo = 0.0
	cab_suelo = 0.0
	inclinacion = 0.2


func empezar_a_levantar() -> void:
	if caida and not levantando:
		levantando = true
		lev_k = 0.0
		vel_h = Vector3.ZERO
		# desde donde quedó tumbada hasta de pie en la pata (la física se para mientras la levantan)
		_lev_desde = cuerpo_cf()
		var de_pie := _pose_de_pie()
		_lev_hasta = Transform3D(Basis(Vector3.UP, de_pie[1]) * Basis(Vector3.BACK, 0.2), de_pie[0])
		if _fisica != null:
			_fisica.freeze = true
			_fisica.collision_layer = 0 # (no empuja al que la está levantando)
			_fisica.collision_mask = 0


## lado hacia el que apunta la parte de arriba de la moto tumbada (donde queda el asiento)
func lado_arriba() -> Vector3:
	return Rbx.flat(cuerpo_cf().basis.y).normalized()


## el piloto sale despedido (choque fuerte, aterrizaje imposible). Cómo sale y cómo cae la moto dependen del golpe
## (2026-10-28): contra algo bajo sale por encima del manillar con casi toda su velocidad (y la moto da una vuelta de
## campana sobre la rueda delantera); contra una pared alta se estrella contra ella y la moto rebota y cae de lado.
func _tirar_piloto(motivo: String, impacto: float, normal := Vector3.ZERO) -> void:
	ultimo_choque = impacto
	var j := piloto
	var v := _vel_antes if _vel_antes != Vector3.ZERO else vel_mundo()
	_golpe_caida = {"tipo": motivo, "v": v, "normal": normal, "impacto": impacto}
	if j == null:
		caer()
		return
	piloto = null
	motor_on = false
	var vh := Rbx.flat(v)
	var imp: Vector3
	match motivo:
		"choque_bajo":
			# por encima del manillar y del obstáculo: casi toda la velocidad que llevaba, y hacia arriba
			imp = vh * 0.9 + Vector3(0, 6.0 + vh.length() * 0.16, 0)
		"choque":
			# contra una pared alta: lo que iba hacia ella se frena (se estrella y cae al pie); lo de lado sigue
			imp = vh * 0.85 + Vector3(0, 4.0 + impacto * 0.08, 0)
			if normal != Vector3.ZERO:
				var hacia := minf(0.0, imp.dot(normal))
				imp -= normal * hacia * 0.85
		_:
			# aterrizaje imposible: sigue hacia donde iba
			imp = v * 0.8 + Vector3(0, 5.0 + impacto * 0.1, 0)
	var danio := maxf(0.0, impacto - 22.0) * 1.3
	caer()
	if j.has_method("expulsar_moto"):
		j.expulsar_moto(imp, danio, motivo)


## cómo empieza a caer el cuerpo físico de la moto según el golpe (si lo hubo hace nada)
func _caida_segun_golpe(b: RigidBody3D) -> void:
	if _golpe_caida.is_empty():
		return
	var g := _golpe_caida
	_golpe_caida = {}
	var vh := Rbx.flat(g.v as Vector3)
	var der := derecha()
	var adel := adelante()
	var azar := func(a: float, b2: float) -> float: return lerpf(a, b2, randf())
	match g.tipo:
		"choque_bajo":
			# vuelta de campana sobre la rueda delantera: el morro se clava y la cola sube
			b.linear_velocity = vh * azar.call(0.35, 0.55) + Vector3(0, azar.call(3.0, 6.0), 0)
			b.angular_velocity = -der * (vh.length() / BATALLA * azar.call(0.7, 1.15)) \
				+ adel * azar.call(-1.6, 1.6) + Vector3(0, azar.call(-1.2, 1.2), 0)
		"choque":
			# rebota contra la pared y cae de lado, girando
			var n: Vector3 = g.normal if (g.normal as Vector3) != Vector3.ZERO else -adel
			var rebote: Vector3 = vh - n * vh.dot(n) * float(azar.call(1.15, 1.35))
			b.linear_velocity = rebote * azar.call(0.25, 0.45) + Vector3(0, azar.call(1.0, 3.0), 0)
			b.angular_velocity = adel * (-caida_lado * azar.call(1.5, 3.5)) + der * azar.call(-2.0, 2.0) \
				+ Vector3(0, azar.call(-2.5, 2.5) * clampf(vh.length() / 30.0, 0.3, 1.0), 0)
		_:
			# mal aterrizaje: sigue rodando/deslizando con lo que llevaba y vuelca hacia un lado al azar
			b.linear_velocity = (g.v as Vector3) * azar.call(0.6, 0.85)
			b.angular_velocity = adel * (-caida_lado * azar.call(1.5, 4.0)) + der * azar.call(-2.5, 1.0) \
				+ Vector3(0, azar.call(-2.0, 2.0), 0)


## ---------------------------------------------------------------- cada fotograma
func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	# con piloto, el Jugador la mueve (paso) en su propio _process: así cuerpo y moto van a la vez
	if piloto != null and is_instance_valid(piloto):
		return
	piloto = null
	paso(dt, {})


## mandos: gas, freno (0..1), giro (-1 izquierda .. 1 derecha), freno_mano (bool), inclinar (-1..1, en el aire)
func paso(dt: float, mandos: Dictionary) -> void:
	_reloj += dt
	if caida and (_fisica != null or levantando):
		_paso_fisica(dt)
		return
	var g_in := clampf(float(mandos.get("gas", 0.0)), 0.0, 1.0)
	var f_in := clampf(float(mandos.get("freno", 0.0)), 0.0, 1.0)
	var giro_in := clampf(float(mandos.get("giro", 0.0)), -1.0, 1.0)
	var mano: bool = mandos.get("freno_mano", false)
	gas = Rbx.damp(gas, g_in if motor_on else 0.0, 8.0, dt)
	frenando = f_in
	var f := adelante()
	var r := derecha()
	var v_f := vel_h.dot(f)
	var v_l := vel_h.dot(r)
	var va := absf(v_f)
	var vf_inicial := v_f
	var frenaba_avance := f_in > 0.05 and v_f > 0.5
	if f_in <= 0.05 or g_in > 0.05 or frenaba_avance:
		_espera_atras = 0.0

	if caida:
		# tumbada: se arrastra hasta pararse (chispas si va deprisa)
		caida_k = minf(1.0, caida_k + dt / 0.45) if not levantando else 1.0 - Rbx.smooth(lev_k)
		if levantando and lev_k >= 1.0:
			levantar()
		var vh := vel_h.length()
		vel_h = vel_h.move_toward(Vector3.ZERO, 26.0 * dt)
		if vh > 8.0:
			_chispa_t -= dt
			if _chispa_t <= 0.0:
				_chispa_t = 0.06
				Efectos.burst(self, global_position + Vector3(0, 0.3, 0), Vector3.UP - vel_h.normalized() * 0.5, Color(1.0, 0.75, 0.3), 5, 14.0, 0.25, 0.35, 35.0)
		direccion = Rbx.damp(direccion, 0.0, 4.0, dt)
		yaw_rate = 0.0
	else:
		caida_k = maxf(0.0, caida_k - dt / 0.8)
		if not en_aire:
			# --- motor y frenos
			if g_in > 0.05 and motor_on:
				if v_f < -0.5:
					v_f = minf(0.0, v_f + FRENO * g_in * dt)
				else:
					# curva de par: mucho empuje abajo (arranca y sube cuestas con fuerza) que se acaba en la punta
					var k_v := clampf(v_f / VMAX, 0.0, 1.0)
					var empuje := ACEL * gas * (1.0 - f_in) * (1.6 - 0.9 * k_v) * (1.0 - pow(k_v, 4.0))
					# (2026-10-29) la rueda no puede empujar más de lo que agarra: en una cuesta muy empinada patina
					# (cuesta arriba a más de ~40° ya no gana velocidad: si no, trepaba paredes de 50° como un cohete)
					if apoyo == 2:
						empuje = minf(empuje, AGARRE_RUEDA * GRAV * cos(cab_suelo) * 0.8)
					v_f += empuje * dt
			if f_in > 0.05:
				if v_f > 0.5:
					v_f = maxf(0.0, v_f - FRENO * f_in * dt)
				elif g_in < 0.05:
					# S no cambia de sentido en el instante de detenerse.
					if v_f > 0.1:
						v_f = maxf(0.0, v_f - FRENO * f_in * dt)
						_espera_atras = 0.0
					else:
						v_f = minf(v_f, 0.0) # absorber el pequeño avance numérico del apoyo
						var anterior := _espera_atras
						_espera_atras += dt
						var paso_atras := maxf(0.0, _espera_atras - maxf(anterior, PAUSA_ATRAS))
						v_f = move_toward(v_f, -ATRAS * f_in, 11.0 * paso_atras)
			if mano:
				v_f = move_toward(v_f, 0.0, 9.0 * dt)
			# rozamiento, aire y freno motor
			var roce := 1.0 + 0.0025 * v_f * v_f + (2.5 if (g_in < 0.05 and motor_on) else 0.0) + (4.0 if not motor_on and piloto == null else 0.0)
			v_f = move_toward(v_f, 0.0, roce * dt)
			# GRAVEDAD en las cuestas: cuesta arriba frena (y si no aceleras, se va hacia atrás); cuesta abajo empuja
			# (con una sola rueda, la gravedad ya va en vel_v: ver _mover)
			if not aparcada:
				if apoyo == 2:
					# (empujando hacia atrás con los pies, el piloto aguanta casi todo el peso: si no, con la rueda de
					# delante metida en un hueco no había forma de sacarla marcha atrás)
					var k_g := 0.25 if (piloto != null and f_in > 0.05 and g_in < 0.05 and v_f < 0.6) else 1.0
					v_f -= GRAV * sin(cab_suelo) * dt * k_g
					if f_in > 0.05 and g_in < 0.05 and _espera_atras > 0.0 and _espera_atras <= PAUSA_ATRAS:
						# Durante la pausa el freno sujeta la pendiente; no reinicia el temporizador por deriva.
						v_f = 0.0
				# parada sin tocar nada con alguien encima: el piloto la sujeta con el freno
				if piloto != null and g_in < 0.05 and f_in < 0.05 and absf(v_f) < 1.2:
					v_f = move_toward(v_f, 0.0, 30.0 * dt)
			_paso_direccion(dt, giro_in, mano, v_f, v_l, (v_f - vf_inicial) / maxf(dt, 0.0001))
		else:
			yaw_rate = Rbx.damp(yaw_rate, 0.0, 1.5, dt)
			rumbo = Rbx.wrap_a(rumbo + yaw_rate * dt)
			vel_h = vel_h.move_toward(Vector3.ZERO, 0.4 * dt)
			derrapando = 0.0

	# --- avance, suelo, cuestas, saltos, aterrizajes y choques
	_mover(dt)
	if caida and _fisica != null:
		return

	# --- inclinación: la que equilibra la curva; sin nadie y casi parada, se cae
	var v_now := velocidad()
	var incl_obj := 0.0
	var rate_i := 7.0 if not caida else 5.0
	if caida:
		incl_obj = lerpf(caida_lado * 1.36, 0.2, Rbx.smooth(lev_k)) if levantando else caida_lado * 1.36
		if levantando:
			rate_i = 25.0
	elif aparcada:
		incl_obj = 0.2 # apoyada en la pata (lado izquierdo)
	elif not en_aire:
		incl_obj = clampf(atan(v_now * yaw_rate / GRAV), -INCL_MAX, INCL_MAX)
		if derrapando > 0.0:
			incl_obj = clampf(incl_obj * (1.0 + 0.25 * derrapando), -INCL_MAX, INCL_MAX)
		if piloto == null and absf(v_now) < 6.0:
			caer()
	else:
		incl_obj = inclinacion * 0.98
	inclinacion = Rbx.damp(inclinacion, incl_obj, rate_i, dt)

	# --- motor: marchas, revoluciones, sonido y ruido para los zombis
	_paso_motor(dt, v_now, g_in)
	# --- atropellos
	if piloto != null or absf(v_now) > ATROPELLO_MIN:
		_atropellar()
	_visual(dt)


## Dirección progresiva y presupuesto de agarre compartido entre frenada/aceleración y curva.
## Con agarre se conserva el módulo de velocidad: proyectarla cada fotograma perdía energía según FPS.
func _paso_direccion(dt: float, giro_in: float, mano: bool, v_f: float, v_l: float, acel: float) -> void:
	var va := absf(v_f)
	var lim := lerpf(0.62, 0.075, Rbx.smooth(clampf(va / 55.0, 0.0, 1.0)))
	if va > 1.0:
		lim = minf(lim, atan(BATALLA * GRAV * tan(INCL_MAX) * 0.92 / (va * va)))
	if piloto == null:
		giro_in = 0.0
	var antes := direccion
	direccion = Rbx.damp(direccion, -giro_in * lim, 7.0, dt)
	# El ángulo medio integra el giro de este paso, en vez de usar solo el valor final.
	var media := (antes + direccion) * 0.5
	derrapando = Rbx.damp(derrapando, 1.0 if (mano and va > 10.0) else 0.0, 6.0, dt)
	var agarre := AGARRE_RUEDA * GRAV * maxf(0.2, cos(cab_suelo)) * (1.0 if apoyo == 2 else 0.65)
	var uso_long := minf(absf(acel), agarre * 0.92)
	var lateral := sqrt(maxf(0.0, agarre * agarre - uso_long * uso_long))
	var objetivo := v_f * tan(media) / BATALLA * (1.0 + 0.9 * derrapando)
	var max_giro := lateral / maxf(va, 1.0) * (1.0 + 0.35 * derrapando)
	objetivo = clampf(objetivo, -max_giro, max_giro)
	var giro_antes := yaw_rate
	yaw_rate = move_toward(yaw_rate, objetivo, 2.8 * dt)
	# El límite de neumático también se cumple tras un cambio de velocidad o de frenada.
	yaw_rate = clampf(yaw_rate, -max_giro, max_giro)
	var delta := (giro_antes + yaw_rate) * 0.5 * dt
	var vel := adelante() * v_f + derecha() * v_l
	rumbo = Rbx.wrap_a(rumbo + delta)
	vel = vel.rotated(Vector3.UP, delta * lerpf(1.0, 0.18, derrapando))
	var lat := move_toward(vel.dot(derecha()), 0.0, lerpf(lateral, AGARRE_DERRAPE, derrapando) * dt)
	vel_h = adelante() * vel.dot(adelante()) + derecha() * lat


## ---------------------------------------------------------------- suelo, cuestas, saltos y aterrizajes
## La moto es un cuerpo rígido en el plano vertical (altura + cabeceo) apoyado en dos RUEDAS de verdad: cada
## rueda es un cilindro (radio de la rueda) que tantea el suelo donde va a estar, así "ve" una cuesta antes de
## llegar (sube rampas de hasta ~60° sin chocar con ellas), rueda por encima de un bordillo bajo y se para
## contra lo que es más alto (pared, bloque). Tres estados (apoyo):
##   2 = las dos ruedas en el suelo: la moto va pegada al suelo; vel_h hacia delante es la velocidad A LO LARGO
##       de la cuesta (la gravedad la frena cuesta arriba y la empuja cuesta abajo; al empezar una rampa no se
##       pierde velocidad) y vel_v la de la cuesta.
##   1 = una rueda: la moto pivota sobre ella (el peso baja la otra; cayendo de morro, el golpe la endereza).
##   0 = en el aire: balística (vel_h horizontal, vel_v vertical); el morro sigue la trayectoria (sube al
##       despegar, baja al caer) y el piloto lo mueve con Shift/Ctrl. Una cresta lanza la moto si va deprisa.
## Al tocar el suelo, lo que va contra el suelo es el golpe y lo que va a lo largo, la velocidad que sigue.
func _mover(dt: float) -> void:
	rotation = Vector3(0, rumbo, 0)
	var p0 := global_position
	var f := adelante()
	var r := derecha()
	_vel_antes = vel_mundo()
	var vf := vel_h.dot(f)
	var vl := vel_h.dot(r)
	var c0 := cabeceo
	var apoyo0 := apoyo
	var g2 := 0.5 * GRAV * dt * dt
	# la moto como una barra entre los dos ejes (punto medio m, cabeceo c)
	var m0 := _medio(p0, c0)
	var e_d0 := _eje_de(m0, c0, true)
	var e_t0 := _eje_de(m0, c0, false)
	# --- lo que haría cada rueda sin suelo
	var vh_f: float          # avance horizontal
	var vv: float            # velocidad vertical (del punto medio) tras la gravedad de este paso
	var wd := 0.0            # velocidad vertical de cada rueda (en el suelo: la de SU cuesta)
	var wt := 0.0
	var c_libre := c0
	var m_libre := m0
	if apoyo0 == 2:
		var cd0 := cos(_pend_del)
		var ct0 := cos(_pend_tras)
		vh_f = vf * (cd0 + ct0) * 0.5
		wd = _w_del
		wt = _w_tras
		vv = (wd + wt) * 0.5 - GRAV * dt
		cab_w = clampf((wd - wt) / (BATALLA * maxf(0.2, cos(c0))), -12.0, 12.0)
	else:
		vh_f = vf
		if apoyo0 == 0:
			_cabeceo_aire(dt, vh_f)
		vv = vel_v - GRAV * dt
		wd = vel_v + cab_w * _palanca_m(c0, true)
		wt = vel_v + cab_w * _palanca_m(c0, false)
	var d := (f * vh_f + r * vl) * dt
	var fin_d := e_d0 + d + Vector3(0, wd * dt - g2, 0)
	var fin_t := e_t0 + d + Vector3(0, wt * dt - g2, 0)
	if apoyo0 == 2:
		# en el suelo cada rueda avanza lo que le toca por su cuesta (la de atrás empuja; la de delante se ajusta)
		fin_t = e_t0 + f * (vf * cos(_pend_tras) * dt) + r * vl * dt + Vector3(0, wt * dt - g2, 0)
	# --- las ruedas tantean el suelo donde van a estar
	var h_del := _apoyo_rueda(true, e_d0, fin_d)
	var h_tras := _apoyo_rueda(false, e_t0, fin_t)
	# una rueda contra algo que no puede subir (bordillo alto, pared, cuesta de más de ~60°): no avanza más
	var frac := 1.0
	if h_del.has("bloq"):
		frac = minf(frac, float(h_del.bloq))
	if h_tras.has("bloq"):
		frac = minf(frac, float(h_tras.bloq))
	var impacto_rueda := 0.0
	var n_rueda := Vector3.ZERO
	if frac < 1.0:
		var dl := d.length()
		if dl > 1e-5:
			n_rueda = -d / dl
			impacto_rueda = maxf(0.0, -Rbx.flat(_vel_antes).dot(n_rueda))
		# lo que iba contra el obstáculo se para (no se acumula velocidad empujando)
		var plano := f * vh_f + r * vl
		var en_contra := plano.dot(-n_rueda)
		if en_contra > 0.0:
			plano += n_rueda * en_contra
		var k_f := (vh_f / vf) if absf(vf) > 0.01 else 1.0
		vh_f = plano.dot(f)
		vl = plano.dot(r)
		vf = vh_f / maxf(0.2, k_f) if apoyo0 == 2 else vh_f
		var d2 := d * frac
		fin_d += d2 - d
		fin_t = e_t0 + d2 + Vector3(0, wt * dt - g2, 0)
		d = d2
		h_del = _apoyo_rueda(true, e_d0, fin_d)
		h_tras = _apoyo_rueda(false, e_t0, fin_t)
		h_del.erase("bloq")
		h_tras.erase("bloq")
	if apoyo0 != 2:
		m_libre = m0 + d + Vector3(0, vel_v * dt - g2, 0)
		c_libre = c0 + cab_w * dt
		fin_d = _eje_de(m_libre, c_libre, true)
		fin_t = _eje_de(m_libre, c_libre, false)
	# --- ¿qué ruedas tocan? (en el suelo: si el suelo se aparta más deprisa de lo que la gravedad la baja, despega)
	var tol_d := 0.004 + g2 * 0.3 if _toca_del else 0.0
	var tol_t := 0.004 + g2 * 0.3 if _toca_tras else 0.0
	var cd := h_del.has("y") and float(h_del.y) >= fin_d.y - tol_d
	var ct := h_tras.has("y") and float(h_tras.y) >= fin_t.y - tol_t
	var m := m_libre
	var c := c_libre
	# una rueda: primero cómo pivotaría sobre ella; si con eso la otra se mete en el suelo, apoyan las dos
	var m1 := m
	var c1 := c
	var vv1 := vv
	var w1 := cab_w
	var golpe1 := 0.0
	var vh1 := vh_f
	if cd != ct:
		var h1: Dictionary = h_del if cd else h_tras
		if apoyo0 == 2:
			m1 = m0 + d + Vector3(0, (vv + GRAV * dt) * dt - g2, 0)
			c1 = c0 + cab_w * dt
		# en el plano de la moto (adelante, arriba): normal del suelo y "brazo" de la rueda (cómo se mueve su eje
		# al girar el cabeceo). El suelo empuja según su normal: en una cuesta, también hacia delante/atrás
		var nn := (h1.normal as Vector3)
		var n_f := nn.dot(f)
		var n_y := nn.y
		var nl := sqrt(n_f * n_f + n_y * n_y)
		if nl > 1e-4:
			n_f /= nl
			n_y /= nl
		var sg := 1.0 if cd else -1.0
		var l_f := sg * -BATALLA * 0.5 * sin(c1)
		var l_y := sg * BATALLA * 0.5 * cos(c1)
		var ln := l_f * n_f + l_y * n_y
		var den := K2 + ln * ln
		var pen := (float(h1.y) - _eje_de(m1, c1, cd).y) * n_y
		if pen > 0.0:
			m1 += (f * n_f + Vector3(0, n_y, 0)) * (pen * K2 / den)
			c1 += pen * ln / den
		var vn := (vh1 + w1 * l_f) * n_f + (vv1 + w1 * l_y) * n_y
		golpe1 = -vn
		if vn < 0.0:
			var j := -vn / (1.0 + ln * ln / K2)
			vh1 += j * n_f
			vv1 += j * n_y
			w1 += j * ln / K2
		var h2: Dictionary = h_tras if cd else h_del
		if h2.has("y") and _eje_de(m1, c1, not cd).y <= float(h2.y) + 0.002:
			cd = true
			ct = true
	if cd and ct:
		# --- las dos ruedas en el suelo: la de atrás donde ha llegado, la de delante a la distancia entre ejes por
		# su cuesta (cálculo exacto: en una rampa empinada el cabeceo es justo el de la rampa, sin bailar)
		var et := Vector3(fin_t.x, float(h_tras.y), fin_t.z)
		var ed := Vector3(fin_d.x, float(h_del.y), fin_d.z)
		var sd := _pendiente(h_del.normal)
		var a := (ed - et).dot(f)
		var b := ed.y - et.y
		var ux := cos(sd)
		var uy := sin(sd)
		var k := a * ux + b * uy
		var disc := k * k - (a * a + b * b) + BATALLA * BATALLA
		if disc >= 0.0:
			var s1 := -k + sqrt(disc)
			var s2 := -k - sqrt(disc)
			var sl := s1 if absf(s1) < absf(s2) else s2
			a += sl * ux
			b += sl * uy
		c = atan2(b, maxf(0.1, a))
		m = et + f * (BATALLA * 0.5 * cos(c)) + Vector3(0, BATALLA * 0.5 * sin(c), 0)
		var sdn := sd
		var stn := _pendiente(h_tras.normal)
		if apoyo0 != 2:
			# aterriza (o apoya la segunda rueda): lo que va a lo largo de la cuesta sigue; lo de contra el suelo es el golpe
			var golpe := -(vv * cos(c) - vh_f * sin(c))
			var v_largo := vh_f * cos(c) + vv * sin(c)
			if apoyo0 == 0:
				_aterrizar(golpe, c_libre - c, m.y)
			vf = v_largo * (0.8 if (_malo and apoyo0 == 0) else 1.0)
		else:
			# un bache: el suelo empuja la moto hacia arriba (la suspensión lo encaja)
			var subida := (float(h_del.y) - fin_d.y + float(h_tras.y) - fin_t.y) * 0.5
			if subida > 0.3 and (h_del.normal as Vector3).y > 0.95 and (h_tras.normal as Vector3).y > 0.95:
				# un escalón alto subido de golpe: frena y sacude
				vf *= 1.0 - minf(0.3, (subida - 0.3) * 0.6)
				if piloto != null and "shake" in piloto:
					piloto.shake = minf(1.0, piloto.shake + subida * 0.5)
		_pend_del = sdn
		_pend_tras = stn
		# velocidad vertical de cada rueda: la de su cuesta. Si el suelo la empuja hacia arriba de golpe (el canto
		# de una rampa, un bordillo) la suspensión se lo come: el cuerpo la coge poco a poco y no sale disparado
		var wd_n := vf * sin(sdn)
		var wt_n := vf * sin(stn)
		if apoyo0 == 2:
			_w_del = minf(wd_n, _w_del + SUSP_ACEL * dt)
			_w_tras = minf(wt_n, _w_tras + SUSP_ACEL * dt)
		else:
			_w_del = wd_n
			_w_tras = wt_n
		vel_v = (_w_del + _w_tras) * 0.5
		cab_w = clampf((_w_del - _w_tras) / (BATALLA * maxf(0.2, cos(c))), -12.0, 12.0)
		cab_suelo = c
		apoyo = 2
	elif cd or ct:
		# --- una rueda: pivota sobre ella (el resto del peso cae; el golpe se convierte en giro)
		var del := cd
		var h: Dictionary = h_del if del else h_tras
		vf = vh1
		m = m1
		c = c1
		vv = vv1
		cab_w = w1
		var pend := _pendiente(h.normal)
		if apoyo0 == 0:
			_aterrizar(golpe1, c - pend, m.y)
		vel_v = vv
		cab_suelo = pend
		if del:
			_pend_del = pend
		else:
			_pend_tras = pend
		apoyo = 1
		# sobre una rueda con la moto casi vertical: no hay quien la aguante
		if absf(c - pend) > 1.25 and piloto != null:
			_tirar_piloto("aterrizaje", CHOQUE)
	else:
		# --- en el aire
		if apoyo0 == 2:
			vf = vh_f
			m = m0 + d + Vector3(0, (vv + GRAV * dt) * dt - g2, 0)
			c = c0 + cab_w * dt
		vel_v = vv
		apoyo = 0
	if caida:
		return
	if apoyo == 0:
		if apoyo0 != 0:
			t_aire = 0.0
		t_aire += dt
	en_aire = apoyo == 0
	_toca_del = cd
	_toca_tras = ct
	suelo_del = {"pos": h_del.pos, "normal": h_del.normal} if cd else {}
	suelo_tras = {"pos": h_tras.pos, "normal": h_tras.normal} if ct else {}
	cabeceo = c
	vel_h = f * vf + r * vl
	var p1 := _raiz(m, c)
	var y := p1.y
	var mov := Vector3(p1.x - p0.x, 0, p1.z - p0.z)

	# --- desplazamiento horizontal (con choques contra paredes)
	global_position = Vector3(p0.x, y, p0.z)
	# las formas de choque siguen el cabeceo
	var b_cab := Basis(Vector3.RIGHT, cabeceo if caida_k < 0.5 else 0.0)
	for fm in _formas:
		(fm[0] as CollisionShape3D).transform = Transform3D(b_cab, Vector3.ZERO) * (fm[1] as Transform3D)
	velocity = mov / maxf(dt, 1e-4)
	move_and_slide()
	var impacto := impacto_rueda
	var n_choque := n_rueda
	var pared := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var cn := col.get_normal()
		# una cuesta que se puede subir no es un choque (de la altura se encargan las ruedas)
		if cn.y >= 0.5:
			continue
		pared = true
		var nf := Vector3(cn.x, 0, cn.z).normalized()
		var contra := -Rbx.flat(_vel_antes).dot(nf)
		if contra > impacto:
			impacto = contra
			n_choque = nf
	if not pared:
		global_position = Vector3(p1.x, y, p1.z)
	else:
		global_position.y = y
		# la velocidad es la que de verdad ha llevado (contra una pared no se acumula velocidad "fantasma")
		if dt > 0.0:
			var real := Rbx.flat(get_real_velocity())
			var vh_ahora := f * (vf * (cos(cab_suelo) if apoyo == 2 else 1.0)) + r * vl
			if real.length() < vh_ahora.length():
				var k_c := cos(cab_suelo) if apoyo == 2 else 1.0
				vel_h = f * (real.dot(f) / maxf(0.2, k_c)) + r * real.dot(r)
	if n_choque != Vector3.ZERO and not en_aire and not caida:
		# rozando una pared: la moto se endereza a lo largo de ella en vez de quedarse clavada
		var vh2 := vel_h.length()
		if vh2 > 2.0:
			var a_mov := atan2(-vel_h.x, -vel_h.z)
			if absf(Rbx.wrap_a(a_mov - rumbo)) < PI * 0.5:
				rumbo = Rbx.wrap_a(rumbo + Rbx.wrap_a(a_mov - rumbo) * minf(1.0, 5.0 * dt))
	var golpe_nuevo := impacto > 3.0 and _reloj - _contacto_t > 0.35
	if impacto > 3.0:
		_contacto_t = _reloj
	if golpe_nuevo:
		Efectos.sonido(self, "Crash", global_position + adelante() * 2.5 + Vector3(0, 1.5, 0), clampf(impacto / 25.0, 0.3, 1.4), 0.7)
		var bajo := impacto >= CHOQUE and _altura_obstaculo(-n_choque if n_choque != Vector3.ZERO else adelante()) < OBST_BAJO
		if impacto >= (CHOQUE_BAJO if bajo else CHOQUE) and piloto != null:
			_tirar_piloto("choque_bajo" if bajo else "choque", impacto, n_choque)
		else:
			vel_h *= clampf(1.0 - impacto / 70.0, 0.4, 0.95)
			Ruido.emitir(self, global_position, 10.0 + impacto, Ruido.GOLPE, self)
			if piloto != null and "shake" in piloto:
				piloto.shake = minf(1.0, piloto.shake + impacto / 30.0)
			if piloto == null and not aparcada and impacto > 12.0:
				caer()
	_paso_suspension(dt, vf)
	_no_atravesar_suelo()


## red de seguridad (2026-10-29): si la moto ha atravesado el suelo (cae deprisa y justo encima hay una superficie
## que debería estar debajo), vuelve encima de ella parada. Antes, mal levantada, caía al vacío con el piloto
var _vacio_t := 0.0
func _no_atravesar_suelo() -> void:
	if apoyo != 0 or vel_v > -12.0:
		return
	_vacio_t += 1.0
	if int(_vacio_t) % 8 != 0:
		return
	var p := global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.3, 0), p + Vector3(0, 40.0, 0), 1)
	q.exclude = [get_rid()]
	q.hit_from_inside = true
	q.hit_back_faces = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	# ¿hay suelo "de verdad" justo encima? (desde arriba del todo hacia abajo)
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 60.0, p.z), Vector3(p.x, p.y + 0.3, p.z), 1)
	q2.exclude = [get_rid()]
	var r2 := get_world_3d().direct_space_state.intersect_ray(q2)
	if r2.is_empty() or (r2.normal as Vector3).y < 0.6:
		return
	global_position = (r2.position as Vector3) + Vector3(0, 0.05, 0)
	vel_v = 0.0
	vel_h = Vector3.ZERO
	cabeceo = 0.0
	cab_w = 0.0
	apoyo = 2
	en_aire = false
	_toca_del = true
	_toca_tras = true


func _golpe_susp(del: float, tras: float) -> void:
	sus_dv += del
	sus_tv += tras


func _paso_suspension(dt: float, vf: float) -> void:
	if dt <= 0.0:
		return
	var sag := SUSP_SAG_PILOTO if piloto != null else SUSP_SAG
	var obj_d := sag
	var obj_t := sag
	if apoyo == 0:
		# en el aire se estira del todo
		obj_d = 0.0
		obj_t = 0.0
	else:
		# frenar hunde la horquilla; acelerar agacha la parte de atrás
		_acel_long = lerpf(_acel_long, (vf - _vf_prev) / dt, 1.0 - exp(-10.0 * dt))
		var tr := clampf(_acel_long * 0.011, -0.32, 0.32)
		obj_d -= tr
		obj_t += tr * 0.6
		# tumbada en una curva, la fuerza aprieta las dos
		var g_lat := 1.0 / maxf(0.5, cos(inclinacion)) - 1.0
		obj_d += g_lat * 0.18
		obj_t += g_lat * 0.18
	_vf_prev = vf
	# las ruedas que suben de golpe (bache, bordillo, aterrizaje) aprietan su muelle; las que caen lo estiran
	for del in [true, false]:
		var y_e := _eje_mundo(del).y
		var vy := (y_e - float(_eje_y.get(del, y_e))) / dt
		var dvy := vy - float(_eje_vy.get(del, vy))
		_eje_y[del] = y_e
		_eje_vy[del] = vy
		if apoyo == 0:
			continue
		var imp := clampf(dvy, -8.0, 45.0) * (0.55 if dvy > 0.0 else 0.25)
		if del:
			sus_dv += imp
		else:
			sus_tv += imp
	sus_dv += (-(sus_d - obj_d) * SUSP_K - sus_dv * SUSP_C) * dt
	sus_tv += (-(sus_t - obj_t) * SUSP_K - sus_tv * SUSP_C) * dt
	sus_d += sus_dv * dt
	sus_t += sus_tv * dt
	# topes: extendida del todo y comprimida del todo (el golpe seco se lo come el tope)
	if sus_d < 0.0:
		sus_d = 0.0
		sus_dv = maxf(sus_dv, 0.0)
	if sus_d > SUSP_RECORRIDO:
		sus_d = SUSP_RECORRIDO
		sus_dv = minf(sus_dv, 0.0)
	if sus_t < 0.0:
		sus_t = 0.0
		sus_tv = maxf(sus_tv, 0.0)
	if sus_t > SUSP_RECORRIDO:
		sus_t = SUSP_RECORRIDO
		sus_tv = minf(sus_tv, 0.0)
	susp = (sus_d + sus_t) * 0.5 - sag


## en el aire: el morro sigue la trayectoria (como un dardo: sube al despegar y baja al caer) y el piloto lo
## mueve echando el cuerpo atrás (Shift, morro arriba) o adelante (Ctrl, morro abajo)
func _cabeceo_aire(dt: float, vh_f: float) -> void:
	var tray := atan2(vel_v, maxf(8.0, absf(vh_f)))
	if vh_f < 0.0:
		tray = -tray
	var obj := clampf(tray * 0.7, -0.7, 0.6)
	var inc := 0.0
	if piloto != null and piloto.has_method("_mando_inclinar"):
		inc = float(piloto.call("_mando_inclinar"))
	var k := 4.0 if absf(inc) < 0.01 else 1.0
	cab_w += (k * (obj - cabeceo) - 2.4 * cab_w + inc * 3.2) * dt
	cab_w = clampf(cab_w, -2.5, 2.5)
	# (nadie da la vuelta a una moto en el aire)
	if (cabeceo > 1.1 and cab_w > 0.0) or (cabeceo < -1.1 and cab_w < 0.0):
		cab_w *= 0.5


## primer contacto con el suelo después de volar: golpe (velocidad contra el suelo) y desalineación (cabeceo de la
## moto respecto a la cuesta donde cae). Mal alineada y con golpe, o con un golpe enorme, el piloto sale despedido
func _aterrizar(golpe: float, desal: float, y: float) -> void:
	golpe = clampf(golpe, 0.0, 80.0)
	_malo = absf(desal) > 0.95 or absf(inclinacion) > 0.9
	if piloto != null and "shake" in piloto:
		piloto.shake = minf(1.0, piloto.shake + golpe / 60.0)
	if golpe > 6.0:
		Efectos.sonido(self, "Blunt", Vector3(global_position.x, y + 0.5, global_position.z), clampf(golpe / 30.0, 0.3, 1.5), 0.6)
		Ruido.emitir(self, global_position, Ruido.radio_aterrizaje(golpe), Ruido.ATERRIZAJE, self)
	if piloto != null and (golpe > 58.0 or (_malo and golpe > 14.0) or (absf(desal) > 1.25 and golpe > 4.0)):
		_tirar_piloto("aterrizaje", maxf(golpe, CHOQUE))


## la moto como una barra entre los ejes: punto medio de los ejes (m) <-> raíz del nodo (en el suelo, entre las ruedas)
func _medio(raiz: Vector3, c: float) -> Vector3:
	var ey := ModeloMoto.EJE_DEL.y
	return raiz + Basis(Vector3.UP, rumbo) * Vector3(0, ey * cos(c), ey * sin(c))


func _raiz(m: Vector3, c: float) -> Vector3:
	var ey := ModeloMoto.EJE_DEL.y
	return m - Basis(Vector3.UP, rumbo) * Vector3(0, ey * cos(c), ey * sin(c))


## eje de una rueda con el punto medio en m y cabeceo c
func _eje_de(m: Vector3, c: float, delantera: bool) -> Vector3:
	var hb := BATALLA * 0.5
	var lz := -hb if delantera else hb
	return m + Basis(Vector3.UP, rumbo) * Vector3(0, -lz * sin(c), lz * cos(c))


## cuánto sube el eje de una rueda por radián de cabeceo (girando sobre el punto medio)
func _palanca_m(c: float, delantera: bool) -> float:
	return (1.0 if delantera else -1.0) * BATALLA * 0.5 * cos(c)


## posición del eje de una rueda en el mundo (raíz en p, cabeceo c; sin la inclinación lateral)
func _eje_en(p: Vector3, c: float, delantera: bool) -> Vector3:
	return _eje_de(_medio(p, c), c, delantera)


func _eje_mundo(delantera: bool) -> Vector3:
	return _eje_en(global_position, cabeceo, delantera)


## inclinación de la cuesta (hacia delante, + = sube) con esa normal del suelo
func _pendiente(nn: Vector3) -> float:
	return atan2(-nn.dot(adelante()), maxf(0.05, nn.y))


## dónde se apoya una rueda que va del eje eje0 (donde está) al eje1 (donde estaría sin suelo). Devuelve:
##   {"y": altura del eje apoyado, "pos", "normal"} si hay suelo a su alcance,
##   {} si no hay suelo debajo (en el aire, o el final de una rampa),
##   {"bloq": fracción del avance} si choca con algo que no puede subir.
## En el suelo avanza a pasitos (≤ 0.3 studs) siguiendo el suelo: así sube cuestas de hasta ~60° y rueda por
## encima de un bordillo bajo, pero un bloque o una pared la paran (no depende de los FPS ni de la velocidad).
func _apoyo_rueda(delantera: bool, eje0: Vector3, eje1: Vector3) -> Dictionary:
	var toca := _toca_del if delantera else _toca_tras
	if apoyo == 0 or not toca:
		# en el aire: ¿toca (o atraviesa) el suelo donde va a estar?
		var ini := maxf(eje0.y, eje1.y) + 0.05
		var h := _tantear(eje1, ini, eje1.y - 0.05)
		if h.has("dentro"):
			# cayendo sobre una cuesta empinada (la rueda ya estaría dentro): buscarla desde más arriba
			var mov_h := Rbx.flat(eje1 - eje0).length()
			h = _tantear(eje1, ini + 2.5 + mov_h * 2.0, eje1.y - 0.05)
			if h.has("dentro"):
				return {}
			# (2026-10-28) pero no encima de algo mucho más alto que la rueda: parada de frente contra un bloque de
			# 40 cm, la rueda delantera "aparecía" encima y la moto lo trepaba a paso de tortuga
			if not h.is_empty() and float(h.y) > ini + 0.4 + mov_h * 1.5:
				return {}
		if h.is_empty() or (h.normal as Vector3).y < 0.42:
			return {}
		return h
	var dist := Rbx.flat(eje1 - eje0).length()
	var n_p := maxi(1, ceili(dist / 0.3))
	var paso_h := dist / float(n_p)
	var dir := Rbx.flat(eje1 - eje0) / maxf(dist, 1e-5)
	var y := eje0.y
	var ult := {}
	for i in range(1, n_p + 1):
		var xz := eje0.lerp(eje1, float(i) / float(n_p))
		var ini := y + _escalon() + paso_h * 1.8
		var fin := minf(y, eje1.y) - 0.6 - paso_h * 2.2
		var h := _tantear(xz, ini, fin)
		if h.has("dentro"):
			return {"bloq": float(i - 1) / float(n_p)}
		# (2026-10-29) la rueda apoyada en el CANTO de un escalón que puede subir: el contacto "mira" muy inclinado
		# (normal.y = 1 - altura/radio) pero no es una pared: rueda por encima del canto. Antes eso la paraba en seco
		# y la moto se quedaba atascada a medio subir un bloque de 20 cm
		var canto_subible := false
		if not h.is_empty() and (h.normal as Vector3).y < 0.45 and (h.normal as Vector3).dot(dir) < 0.0:
			var alto_c: float = (h.pos as Vector3).y - (y - ModeloMoto.R_RUEDA)
			canto_subible = alto_c <= _escalon() + 0.02 and (h.normal as Vector3).y > 1.0 - (_escalon() + 0.05) / ModeloMoto.R_RUEDA
		if not h.is_empty() and (h.normal as Vector3).y < 0.45 and not canto_subible:
			# demasiado empinado: si da la cara (pared, bordillo alto) la para; si mira hacia donde va (el borde
			# de una rampa o de un escalón por el que se cae) la rueda se queda sin suelo
			if (h.normal as Vector3).dot(dir) < 0.0:
				return {"bloq": float(i - 1) / float(n_p)}
			return {}
		if h.is_empty():
			return {}
		# (2026-10-28) ¿es el canto de un escalón (no una cuesta)? Justo detrás del punto de contacto el suelo está
		# mucho más bajo: entonces solo se sube si el escalón no pasa de _escalon() (antes, deprisa, la rueda "subía"
		# por el canto bloques de 40 cm)
		var pc: Vector3 = h.pos
		if pc.y > y - ModeloMoto.R_RUEDA + 0.2:
			var atras := pc - dir * 0.15
			var q := PhysicsRayQueryParameters3D.create(atras + Vector3(0, 0.05, 0), atras - Vector3(0, 3.0, 0), 1)
			q.exclude = _q_rueda.exclude
			var r := get_world_3d().direct_space_state.intersect_ray(q)
			if not r.is_empty():
				var escalon := pc.y - (r.position as Vector3).y
				if escalon > 0.15 * 1.8 + 0.25 and escalon > _escalon() + 0.05:
					return {"bloq": float(i - 1) / float(n_p)}
		y = float(h.y)
		ult = h
	return ult


## escalón que la rueda puede subir: despacio un bordillo bajo; deprisa algo más alto (de un golpe)
func _escalon() -> float:
	return lerpf(ESCALON_MAX, ESCALON_RAPIDO, clampf((absf(velocidad()) - 8.0) / 17.0, 0.0, 1.0))


## altura (sobre el suelo de la moto) de lo que tiene justo delante de la rueda delantera
func _altura_obstaculo(dir: Vector3) -> float:
	var del := global_position + adelante() * (BATALLA * 0.5 + ModeloMoto.R_RUEDA * 0.6)
	var mejor := 0.0
	for k: float in [0.4, 1.0, 1.7]:
		var p := del + dir * k
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 40.0, 0), p + Vector3(0, -2.0, 0), 1)
		q.exclude = [get_rid()]
		q.hit_from_inside = true
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			mejor = maxf(mejor, (r.position as Vector3).y - global_position.y)
	return mejor


var _cil_rueda: CylinderShape3D
var _q_rueda: PhysicsShapeQueryParameters3D


## baja el cilindro de una rueda (de canto, en la dirección de la moto) por la vertical de xz, de la altura y_ini a
## y_fin (del eje). {} = nada; {"dentro": true} = empieza metida en algo; si no, {"y", "pos", "normal"}
func _tantear(xz: Vector3, y_ini: float, y_fin: float) -> Dictionary:
	if _q_rueda == null:
		_cil_rueda = CylinderShape3D.new()
		_cil_rueda.radius = ModeloMoto.R_RUEDA
		_cil_rueda.height = 0.36
		_q_rueda = PhysicsShapeQueryParameters3D.new()
		_q_rueda.shape = _cil_rueda
		_q_rueda.collision_mask = 1
	# las ruedas pisan el escenario: ni personas ni otras motos (con esas chocan las formas de la moto)
	var ex: Array[RID] = []
	for g in [GRUPO, "jugador"]:
		for o in get_tree().get_nodes_in_group(g):
			if o is CollisionObject3D:
				ex.append((o as CollisionObject3D).get_rid())
	if piloto != null and piloto is CollisionObject3D:
		ex.append((piloto as CollisionObject3D).get_rid())
	_q_rueda.exclude = ex
	var b := Basis(Vector3.UP, rumbo) * Basis(Vector3.BACK, PI * 0.5)
	_q_rueda.transform = Transform3D(b, Vector3(xz.x, y_ini, xz.z))
	_q_rueda.motion = Vector3.ZERO
	var space := get_world_3d().direct_space_state
	# (el barrido no ve lo que ya está metido en la rueda al empezar: eso se mira aparte)
	if not space.intersect_shape(_q_rueda, 1).is_empty():
		return {"dentro": true}
	_q_rueda.motion = Vector3(0, y_fin - y_ini, 0)
	var res := space.cast_motion(_q_rueda)
	if res.size() < 2 or res[1] >= 1.0:
		return {}
	if res[1] <= 0.0:
		return {"dentro": true}
	var y := y_ini + (y_fin - y_ini) * float(res[0])
	_q_rueda.transform = Transform3D(b, Vector3(xz.x, y_ini + (y_fin - y_ini) * float(res[1]), xz.z))
	_q_rueda.motion = Vector3.ZERO
	var info := space.get_rest_info(_q_rueda)
	# (2026-10-28) a veces el punto de contacto no sale a la primera: se mira un pelín más abajo. Antes se suponía
	# suelo plano, y el canto de un bloque (tocado con el "ecuador" de la rueda) se tomaba por suelo y la moto se subía
	for extra in [0.01, 0.03]:
		if not info.is_empty():
			break
		_q_rueda.transform = Transform3D(b, Vector3(xz.x, y_ini + (y_fin - y_ini) * float(res[1]) - extra, xz.z))
		info = space.get_rest_info(_q_rueda)
	if info.is_empty():
		return {"y": y, "pos": Vector3(xz.x, y - ModeloMoto.R_RUEDA, xz.z), "normal": Vector3.UP}
	return {"y": y, "pos": info.point, "normal": info.normal}


## coloca la moto sobre el suelo (al crearla)
func _poner_en_el_suelo() -> void:
	if not is_inside_tree():
		return
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 6, 0), global_position - Vector3(0, 30, 0), 1)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		global_position = r.position


## ---------------------------------------------------------------- motor
func _paso_motor(dt: float, v_f: float, g_in: float) -> void:
	var va := absf(v_f)
	# cambio automático con histéresis
	# (sube solo acelerando y baja con margen: girando despacio no está cambiando todo el rato)
	while marcha < MARCHAS.size() - 1 and va > float(MARCHAS[marcha]) * 0.97 and g_in > 0.05:
		marcha += 1
	while marcha > 1 and va < float(MARCHAS[marcha - 1]) * 0.7:
		marcha -= 1
	var lo := float(MARCHAS[marcha - 1]) * 0.7 if marcha > 1 else 0.0
	var hi := float(MARCHAS[marcha])
	var frac := clampf((va - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
	var rpm_obj := 0.16 + 0.84 * frac
	if g_in > 0.05 and motor_on and (en_aire or derrapando > 0.3):
		rpm_obj = 0.95 # acelerando en el aire o derrapando: la rueda gira loca
	elif g_in < 0.05:
		rpm_obj = 0.12 + 0.6 * frac
	if not motor_on:
		rpm_obj = 0.0
	rpm = Rbx.damp(rpm, rpm_obj, 5.0 if rpm_obj > rpm else 3.0, dt)
	if motor_on:
		if not _audio_motor.playing:
			_audio_motor.play()
		_audio_motor.pitch_scale = 0.6 + rpm * 1.05
		_audio_motor.volume_db = -10.0 + gas * 5.0 + rpm * 2.0
		_ruido_t -= dt
		if _ruido_t <= 0.0:
			_ruido_t = 0.35
			var radio := lerpf(RUIDO_RALENTI, RUIDO_MAX, clampf(rpm * 0.7 + gas * 0.3, 0.0, 1.0))
			Ruido.emitir(self, global_position + Vector3(0, 1.5, 0), radio, "motor", piloto if piloto != null else self)
	elif _audio_motor.playing:
		_audio_motor.stop()
	# derrape (y frenazo fuerte)
	var chirrido := 0.0
	if not en_aire and not caida:
		chirrido = maxf(derrapando, clampf((frenando - 0.5) * 2.0, 0.0, 1.0) * clampf(va / 30.0, 0.0, 1.0))
	if chirrido > 0.05:
		if not _audio_derrape.playing:
			_audio_derrape.play()
		_audio_derrape.volume_db = linear_to_db(chirrido) - 4.0
		_audio_derrape.pitch_scale = 0.8 + va / 120.0
	elif _audio_derrape.playing:
		_audio_derrape.stop()


## ---------------------------------------------------------------- atropellos
func _atropellar() -> void:
	var va := vel_h.length()
	if va < 2.0 or caida:
		return
	var dir_mov := vel_h / va
	var p := global_position
	for o in get_tree().get_nodes_in_group("objetivos"):
		if not o.vivo():
			continue
		var c: Vector3 = o.centro()
		var rel := c - p
		if rel.y < -1.0 or rel.y > 6.5:
			continue
		var long := rel.dot(dir_mov)
		var lat := absf(rel.dot(Vector3(-dir_mov.z, 0, dir_mov.x)))
		var id := o.get_instance_id()
		if _reloj - float(_golpeados.get(id, -9.0)) < 0.7:
			continue
		if o.en_pie():
			# de pie, delante de la rueda delantera
			if long > 1.5 and long < 4.2 and lat < 1.5:
				_golpeados[id] = _reloj
				if va < ATROPELLO_MIN:
					o.empujar(dir_mov * va * 1.2, 0.5)
					vel_h *= 0.7
					continue
				var danio := (va - 6.0) * 1.7
				var imp := dir_mov * va * 0.9 + Vector3(0, va * 0.35, 0)
				var murio: bool = o.recibir_danio(danio, "UpperTorso", imp)
				if not murio and o.en_pie():
					o.derribar(imp, 2.5)
				atropellos += 1
				vel_h *= clampf(1.0 - 9.0 / maxf(va, 1.0), 0.6, 0.92)
				_golpe_susp(3.0, 2.0)
				Efectos.blood_at(self, c, -dir_mov)
				Efectos.sonido(self, "Blunt", c, 1.4, 0.75)
				Efectos.sonido(self, "Flesh", c, 1.0, 0.8)
				Ruido.emitir(self, c, C.RUIDO.GolpeContundente, Ruido.GOLPE, piloto if piloto != null else self)
				if piloto != null:
					piloto.shake = minf(1.0, piloto.shake + 0.35)
					if piloto.get("arsenal") != null:
						piloto.arsenal._confirmar(murio, false)
				# a mucha velocidad, el golpe desestabiliza (un bache fuerte)
				inclinacion += (randf() - 0.5) * 0.2
		else:
			# caído en el suelo: las ruedas le pasan por encima (bache y algo de daño)
			if long > -2.6 and long < 2.6 and lat < 1.0 and va > 4.0:
				_golpeados[id] = _reloj
				o.recibir_danio(va * 0.6, "UpperTorso", dir_mov * 4.0)
				_golpe_susp(4.0 + va * 0.08, 4.0 + va * 0.08)
				Efectos.sonido(self, "Flesh", c, 0.8, 0.7)
				if piloto != null:
					piloto.shake = minf(1.0, piloto.shake + 0.2)


## ---------------------------------------------------------------- aspecto
func _visual(dt: float) -> void:
	if n.is_empty():
		return
	var cuerpo: Node3D = n.cuerpo
	# cabeceo (morro arriba +) y giro sobre el eje longitudinal (+ inclinación = arriba hacia la izquierda)
	# el peso aplasta los neumáticos (más con piloto y al comprimirse la suspensión); el aplastado lo hace el
	# shader del neumático contra el plano del suelo
	var hundido := 0.0
	if not en_aire and caida_k < 0.5:
		hundido = HUNDIDO * (1.6 if piloto != null else 1.0) + clampf(susp, -0.1, 0.4) * 0.12
	if not caida:
		cuerpo.transform = Transform3D(Basis(Vector3.RIGHT, cabeceo) * Basis(Vector3.BACK, inclinacion), Vector3(0, -hundido, 0)) * _susp_cf()
		_susp_ruedas()
	_neumatico(n.get("neu_del"), suelo_del)
	_neumatico(n.get("neu_tras"), suelo_tras)
	(n.giro as Node3D).rotation = Vector3(0, direccion, 0)
	_giro_ruedas += velocidad() / ModeloMoto.R_RUEDA * dt * (0.0 if caida_k > 0.5 else 1.0)
	if en_aire and gas > 0.3:
		_giro_ruedas -= 25.0 * dt * gas # en el aire, la rueda de atrás gira loca al acelerar
	(n.rueda_tras as Node3D).rotation.x = -_giro_ruedas
	(n.rueda_del as Node3D).rotation.x = -_giro_ruedas * (1.0 if not en_aire else 0.98)
	(n.pata as Node3D).visible = aparcada
	(n.luz as Light3D).visible = luces and motor_on
	# cartel "[F] Subir" cuando el jugador está cerca a pie
	var cartel: Label3D = n.cartel
	var mostrar := false
	if piloto == null and not levantando and is_inside_tree():
		var j := get_tree().get_first_node_in_group("jugador") as Node3D
		if j and j.get("moto") == null and (j.global_position - global_position).length() < ALCANCE_SUBIR and de_lado(j.global_position):
			mostrar = true
			cartel.text = "[F] Levantar la moto" if caida else "[F] Subir a la moto"
	cartel.visible = mostrar
	cartel.global_position = global_position + Vector3(0, 4.8, 0)


## lo que la suspensión baja y cabecea el cuerpo (chasis, depósito, piloto) sobre las ruedas, en el sistema de la moto.
## Respecto a la moto "de catálogo" (la del modelo), que es como queda con el peso del piloto
func _susp_cf() -> Transform3D:
	if caida or caida_k > 0.01:
		return Transform3D.IDENTITY
	var sag := SUSP_SAG_PILOTO
	var cd := sus_d - sag
	var ct := sus_t - sag
	var ey := ModeloMoto.EJE_DEL.y
	var th := (ct - cd) / BATALLA
	return Transform3D(Basis.IDENTITY, Vector3(0, ey - (cd + ct) * 0.5, 0)) * Transform3D(Basis(Vector3.RIGHT, th), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, Vector3(0, -ey, 0))


## las ruedas se quedan en el suelo: la de delante sube por las barras de la horquilla y la de atrás con el basculante
func _susp_ruedas() -> void:
	var s_inv := _susp_cf().affine_inverse()
	var desl = n.get("deslizante")
	if desl != null:
		var u := (ModeloMoto.PIPA - ModeloMoto.EJE_DEL).normalized()
		var q_d := s_inv * ModeloMoto.EJE_DEL
		(desl as Node3D).position = Vector3(0, (q_d - ModeloMoto.EJE_DEL).dot(u), 0)
	var basc = n.get("basculante")
	if basc != null:
		var v0 := ModeloMoto.EJE_TRAS - ModeloMoto.PIVOTE_BASC
		var v1 := s_inv * ModeloMoto.EJE_TRAS - ModeloMoto.PIVOTE_BASC
		(basc as Node3D).rotation = Vector3(atan2(v0.y, v0.z) - atan2(v1.y, v1.z), 0, 0)
		for am in n.get("amortiguadores", []):
			ModeloMoto.amortiguador(am, basc)


## parámetros del shader del neumático: el plano del suelo bajo esa rueda y el giro (para el dibujo)
func _neumatico(neu, sup: Dictionary) -> void:
	if neu == null:
		return
	var mat := (neu as MeshInstance3D).material_override as ShaderMaterial
	if sup.is_empty() or en_aire or caida_k > 0.3:
		# en el aire (o tumbada): sin aplastar
		mat.set_shader_parameter("plano", Vector4(0, 1, 0, -100000.0))
	else:
		var nn: Vector3 = (sup.normal as Vector3).normalized()
		mat.set_shader_parameter("plano", Vector4(nn.x, nn.y, nn.z, nn.dot(sup.pos)))
	mat.set_shader_parameter("giro", _giro_ruedas)


## ---------------------------------------------------------------- sonidos sintetizados (bucles)
const RATE := 22050


static func _wav_bucle(datos: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(datos.size() * 2)
	for i in datos.size():
		bytes.encode_s16(i * 2, int(clampf(datos[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = datos.size()
	return w


## motor monocilíndrico: una explosión por ciclo (golpe grave con armónicos) + algo de ruido mecánico.
## Se repite exactamente (bucle sin cortes) y el tono se sube con pitch_scale según las revoluciones.
static func _sonido_motor() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ciclo := 1.0 / 38.0 # 38 explosiones por segundo al tono base
	var ciclos := 16
	var n_m := int(ciclo * ciclos * RATE)
	var out := PackedFloat32Array()
	out.resize(n_m)
	var lp := 0.0
	for i in n_m:
		var t := float(i) / RATE
		var tc := fmod(t, ciclo)
		var k := floori(t / ciclo)
		var var_k := 0.85 + 0.3 * sin(float(k) * 2.3) * 0.5
		var golpe := exp(-tc * 70.0) * var_k
		var v := sin(TAU * 38.0 * t) * 0.35 + sin(TAU * 76.0 * t) * 0.22 * golpe + sin(TAU * 114.0 * t) * 0.12
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		v += lp * golpe * 0.9 + lp * 0.08
		v = clampf(v * 1.1, -1.0, 1.0)
		out[i] = v * 0.8
	return _wav_bucle(out)


static func _sonido_derrape() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n_d := int(0.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(n_d)
	var lp := 0.0
	var hp := 0.0
	for i in n_d:
		var t := float(i) / RATE
		var r := rng.randf_range(-1.0, 1.0)
		lp += (r - lp) * 0.35
		hp = lp - hp * 0.2
		out[i] = (hp * 0.55 + sin(TAU * 900.0 * t + sin(TAU * 7.0 * t) * 3.0) * 0.18)
	return _wav_bucle(out)


## ---------------------------------------------------------------- caída con física
var _fisica: RigidBody3D = null
var _fisica_quieta := 0.0
var _lev_desde := Transform3D.IDENTITY
var _lev_hasta := Transform3D.IDENTITY
var _giro_fisica := 0.0
var _fis_v_prev := Vector3.ZERO
var _golpe_caida := {}          # el golpe que la tira (para caer según él): {tipo, v, normal, impacto}
var _fis_w_prev := Vector3.ZERO


func _crear_fisica() -> void:
	if _fisica != null:
		return
	var cpo := cuerpo_cf()
	var b := RigidBody3D.new()
	b.name = "MotoFisica"
	b.top_level = true
	b.mass = 25.0
	b.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	b.center_of_mass = Vector3(0, 1.7, 0.1)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.55
	mat.bounce = 0.12
	b.physics_material_override = mat
	b.linear_damp = 0.05
	b.angular_damp = 0.4
	b.continuous_cd = true
	b.collision_layer = 1
	b.collision_mask = 1 | 4 | 16
	# forma: chasis, las dos ruedas, el manillar y los estribos (de eso se apoya una moto tumbada)
	_forma_caja(b, Vector3(0.95, 1.6, 3.2), Vector3(0, 2.1, 0.2))
	for z in [ModeloMoto.EJE_DEL.z, ModeloMoto.EJE_TRAS.z]:
		var cs := CollisionShape3D.new()
		var cil := CylinderShape3D.new()
		cil.radius = ModeloMoto.R_RUEDA
		cil.height = 0.42
		cs.shape = cil
		cs.transform = Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, ModeloMoto.R_RUEDA, z))
		b.add_child(cs)
	_forma_caja(b, Vector3(1.95, 0.16, 0.3), Vector3(0, 3.42, -1.5))
	_forma_caja(b, Vector3(1.6, 0.14, 0.3), Vector3(0, ModeloMoto.ESTRIBO.y, ModeloMoto.ESTRIBO.z))
	b.transform = cpo
	add_child(b)
	_fisica = b
	# sin las formas de la moto "conducible" (chocarían con la física)
	for fm in _formas:
		(fm[0] as CollisionShape3D).disabled = true
	# la velocidad que llevaba, y un giro hacia el lado al que cae (y el de la curva)
	var adel := adelante()
	b.linear_velocity = vel_mundo()
	_fis_v_prev = b.linear_velocity
	b.angular_velocity = adel * (-caida_lado * clampf(1.2 + vel_h.length() * 0.04, 1.2, 3.0) * lerpf(0.8, 1.25, randf())) \
		+ derecha() * lerpf(-0.6, 0.6, randf()) + Vector3(0, yaw_rate + lerpf(-0.5, 0.5, randf()), 0)
	_caida_segun_golpe(b)
	_fis_v_prev = b.linear_velocity
	_fisica_quieta = 0.0
	_fisica_t = 0.0
	_giro_fisica = velocidad() / ModeloMoto.R_RUEDA
	vel_h = Vector3.ZERO
	vel_v = 0.0


func _forma_caja(b: RigidBody3D, tam: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = tam
	cs.shape = bx
	cs.position = pos
	b.add_child(cs)


func _quitar_fisica() -> void:
	if _fisica != null:
		_fisica.queue_free()
		_fisica = null
	for fm in _formas:
		(fm[0] as CollisionShape3D).disabled = false
	(n.cuerpo as Node3D).transform = Transform3D.IDENTITY


## dónde y hacia dónde queda de pie (en la pata) si la levantan: [posición en el suelo, rumbo]
func _pose_de_pie() -> Array:
	var cpo := cuerpo_cf()
	var p := cpo * Vector3(0, 0, 0.1)
	var adel := Rbx.flat(-cpo.basis.z)
	if adel.length() < 0.2:
		adel = adelante()
	adel = adel.normalized()
	var giro := atan2(-adel.x, -adel.z)
	# (2026-10-29) de pie tiene que caber: las dos ruedas sobre algo (no metidas en un bloque) y sin mucho desnivel
	# entre ellas. Se prueba donde está y, si no cabe, un poco más adelante/atrás y algo girada. Antes, tumbada en el
	# hueco entre dos bloques, se ponía de pie con una rueda dentro del bloque, daba vueltas y atravesaba el suelo
	var rumbo0 := rumbo
	var mejor := []
	for dg in [0.0, 0.35, -0.35, 0.7, -0.7, PI * 0.5, -PI * 0.5, PI]:
		var g2: float = giro + dg
		rumbo = g2
		var f2 := Vector3(-sin(g2), 0, -cos(g2))
		for dd in [0.0, 0.8, -0.8, 1.6, -1.6, 2.6, -2.6]:
			var c := p + f2 * float(dd)
			var hd := _tantear(c + f2 * (BATALLA * 0.5), p.y + 3.0, p.y - 4.0)
			var ht := _tantear(c - f2 * (BATALLA * 0.5), p.y + 3.0, p.y - 4.0)
			if hd.is_empty() or ht.is_empty() or hd.has("dentro") or ht.has("dentro"):
				continue
			if (hd.normal as Vector3).y < 0.8 or (ht.normal as Vector3).y < 0.8:
				continue
			if absf(float(hd.y) - float(ht.y)) > 0.5:
				continue
			mejor = [Vector3(c.x, minf(float(hd.y), float(ht.y)) - ModeloMoto.R_RUEDA, c.z), g2]
			break
		if not mejor.is_empty():
			break
	rumbo = rumbo0
	if not mejor.is_empty():
		return mejor
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 4.0, p.z), Vector3(p.x, p.y - 8.0, p.z), 1)
	var ex: Array[RID] = [get_rid()]
	if _fisica != null:
		ex.append(_fisica.get_rid())
	q.exclude = ex
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var y: float = (r.position as Vector3).y if not r.is_empty() else p.y
	return [Vector3(p.x, y, p.z), giro]


## tumbada (con física) o mientras la levantan
func _paso_fisica(dt: float) -> void:
	var cuerpo: Node3D = n.cuerpo
	if levantando:
		# el jugador la levanta: de la postura en que quedó a de pie en la pata
		caida_k = 1.0 - Rbx.smooth(lev_k)
		var k := Rbx.smooth(lev_k)
		var t := _lev_desde.interpolate_with(_lev_hasta, k)
		var raiz := Transform3D(Basis(Vector3.UP, atan2(-_lev_hasta.basis.z.x, -_lev_hasta.basis.z.z)), _lev_hasta.origin)
		global_transform = raiz
		cuerpo.global_transform = t
		if lev_k >= 1.0:
			levantar()
		_visual_ruedas(dt)
		return
	var b := _fisica
	var bt := b.global_transform
	# la moto "lógica" (para el cartel, el jugador y las pruebas) va donde está el cuerpo
	var pie := _pose_de_pie()
	global_transform = Transform3D(Basis(Vector3.UP, pie[1]), pie[0])
	rumbo = pie[1]
	cuerpo.global_transform = bt
	# (+ = arriba hacia la izquierda, como al conducir)
	inclinacion = asin(clampf(-(Basis(Vector3.UP, rumbo).inverse() * bt.basis.y).x, -1.0, 1.0))
	caida_k = 1.0
	# chispas al arrastrarse deprisa por el suelo
	var v := b.linear_velocity
	# (2026-10-28) el jugador es un cuerpo cinemático (masa infinita): si se solapa con la moto caída (al levantarse
	# a su lado) la lanzaba por los aires a 30-80 studs/s. Un cambio de velocidad así de brusco con el jugador al lado
	# no es un golpe de verdad: se recorta
	if (v - _fis_v_prev).length() > 10.0:
		for jg in get_tree().get_nodes_in_group("jugador"):
			if ((jg as Node3D).global_position - bt.origin).length() < 8.0:
				v = _fis_v_prev + (v - _fis_v_prev).limit_length(2.5)
				b.linear_velocity = v
				b.angular_velocity = b.angular_velocity.limit_length(maxf(_fis_w_prev.length(), 2.0))
				break
	_fis_v_prev = v
	_fis_w_prev = b.angular_velocity
	if v.length() > 7.0 and _cerca_del_suelo(bt):
		_chispa_t -= dt
		if _chispa_t <= 0.0:
			_chispa_t = 0.05
			var pos := bt * Vector3(0, 0.6, 0)
			Efectos.burst(self, Vector3(pos.x, pie[0].y + 0.2, pos.z), Vector3.UP - v.normalized() * 0.6, Color(1.0, 0.75, 0.3), 6, 16.0, 0.25, 0.35, 35.0)
		if not _audio_derrape.playing:
			_audio_derrape.play()
		_audio_derrape.volume_db = linear_to_db(clampf(v.length() / 25.0, 0.2, 1.0)) - 2.0
		_audio_derrape.pitch_scale = 0.55
	elif _audio_derrape.playing:
		_audio_derrape.stop()
	if _audio_motor.playing:
		_audio_motor.stop()
	# golpes contra el suelo (ruido de chapa)
	var dv := (v - _v_fisica_prev).length()
	if dv > 6.0 and _reloj - _contacto_t > 0.2:
		_contacto_t = _reloj
		Efectos.sonido(self, "Blunt", bt * Vector3(0, 1.5, 0), clampf(dv / 15.0, 0.3, 1.5), 0.45 + randf() * 0.15)
	_v_fisica_prev = v
	# las ruedas siguen girando y se van frenando
	_giro_fisica = move_toward(_giro_fisica, 0.0, 6.0 * dt)
	_giro_ruedas += _giro_fisica * dt
	_visual_ruedas(dt)
	# sin nadie que la sujete, de pie no se aguanta: el peso la vence hacia un lado (equilibrio inestable;
	# la simulación sola podría dejarla en equilibrio sobre las dos ruedas)
	_fisica_t += dt
	# parada: se queda como esté. Si después de caer sigue de pie (encajada contra algo), se pone en la pata
	if v.length() < 0.4 and b.angular_velocity.length() < 0.4:
		_fisica_quieta += dt
		if _fisica_quieta > 0.6 and _fisica_t > 3.0 and bt.basis.y.y > 0.85:
			levantar()
	else:
		_fisica_quieta = 0.0
	(n.luz as Light3D).visible = false
	(n.pata as Node3D).visible = false


var _v_fisica_prev := Vector3.ZERO


## (en el paso de física: sin nadie que la sujete, de pie no se aguanta y el peso la vence hacia un lado)
func _physics_process(_dt: float) -> void:
	if _fisica == null or _fisica.freeze:
		return
	var bt := _fisica.global_transform
	if bt.basis.y.y > 0.5:
		var eje := -bt.basis.z.normalized()
		_fisica.apply_torque(eje * (-caida_lado) * _fisica.mass * 14.0 * clampf((bt.basis.y.y - 0.5) * 3.0, 0.3, 1.0))
var _fisica_t := 0.0


func _cerca_del_suelo(bt: Transform3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(bt * Vector3(0, 1.5, 0), bt * Vector3(0, 1.5, 0) + Vector3(0, -2.6, 0), 1)
	q.exclude = [get_rid(), _fisica.get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _visual_ruedas(_dt: float) -> void:
	(n.rueda_tras as Node3D).rotation.x = -_giro_ruedas
	(n.rueda_del as Node3D).rotation.x = -_giro_ruedas
	_neumatico(n.get("neu_del"), {})
	_neumatico(n.get("neu_tras"), {})
	var cartel: Label3D = n.cartel
	var mostrar := false
	if not levantando and is_inside_tree():
		var j := get_tree().get_first_node_in_group("jugador") as Node3D
		if j and j.get("moto") == null and (j.global_position - (n.cuerpo as Node3D).global_position).length() < ALCANCE_SUBIR + 1.0 \
				and de_lado(j.global_position):
			mostrar = true
			cartel.text = "[F] Levantar la moto"
	cartel.visible = mostrar
	cartel.global_position = (n.cuerpo as Node3D).global_position + Vector3(0, 3.5, 0)
