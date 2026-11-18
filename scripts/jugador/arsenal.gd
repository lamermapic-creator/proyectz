class_name Arsenal
extends Node
## Armas del jugador (port de la parte de armas de ZClient + WeaponServer + InventoryServer):
## · 4 huecos (1-4): arma corta, arma larga, blanca corta, blanca larga. Cargamento inicial:
##   pistola, rifle, cuchillo y bate. Las que no están en la mano se ven en el cuerpo.
## · Cambiar de arma: se guarda la de la mano (0.42 s) y se saca la otra (tiempo de desenfundar).
## · Disparar (clic izq.), apuntar (clic der.), recargar (R), apoyar el arma (X), golpear con armas
##   blancas, recoger armas del suelo (F: coger otra del mismo tipo suelta la que llevabas).
## · Dispersión (apuntar, moverse, postura, en el aire, ráfaga), retroceso, caída de daño.
## Las animaciones las hace el Animador (poses, recarga, golpes, sacar/guardar).

const C = preload("res://scripts/config/zconfig.gd")

var J: Jugador
var anim: Animador

var inventario := {}            # hueco -> {name, mag, reserve}
var equipado := ""              # nombre del arma en la mano ("" = manos vacías)
var modelo_mano: Node3D = null
var enfundadas := {}            # nombre -> modelo en el cuerpo
var switching = null            # {t0, next}
var draw_until := 0.0
var recargando := 0.0           # hora en que termina la recarga (0 = no)
var last_shot := -9.0
var last_melee := -9.0
var spread_bloom := 0.0
var pending_shot = null
var mira_esc := 1.0             # tamaño de la mira (más pequeña con el arma apoyada)
var rest = null                 # arma apoyada {top, point, gap, ground, yaw0, stance, t0}
var rest_avail = null
var rest_scan_t := 0.0
var aim_blocked := false
var aim_block_reason := ""
var hit_t := -9.0
var hit_color := Color.WHITE
var rest_motivo := ""
var balas_infinitas := false      # F5: pruebas
var golpes_pendientes := []     # [hora, arma]
var suelo := []                 # armas en el suelo: {name, mag, reserve, nodo, etiqueta}

var _hud := {}
var impacto := ImpactoCC.new(self)   # sensación de impacto y ajuste del cuerpo al blanco (scripts/jugador/impacto_cc.gd)


func _exit_tree() -> void:
	if impacto:
		impacto.soltar()


func _ready() -> void:
	J = get_parent() as Jugador
	anim = J.get_node("Animador") as Animador
	for nombre in Armas.LOADOUT:
		dar_arma(nombre, false)
	_crear_hud()
	# un machete en el suelo cerca del punto de partida (arma blanca larga: si lo coges, sueltas el bate)
	call_deferred("_soltar_inicial")


func _soltar_inicial() -> void:
	var p := J.global_position + Vector3(6, 0, -4)
	var g := J.raycast(p + Vector3(0, 4, 0), Vector3(0, -60, 0))
	if not g.is_empty():
		p = g.position
	soltar_en_suelo({"name": "Machete", "mag": 0, "reserve": 0}, p, 0.6)


func ahora() -> float:
	return J.reloj


func cfg() -> Dictionary:
	return Armas.WEAPONS.get(equipado, {})


func armado() -> bool:
	return equipado != ""


func es_arma_fuego() -> bool:
	return armado() and cfg().Kind == "Gun"


func _hueco_de(nombre: String) -> String:
	return Armas.WEAPONS[nombre].Slot


func arma_en_hueco(id: String) -> String:
	var it = inventario.get(id)
	return it.name if it != null else ""


func datos_equipado() -> Dictionary:
	return inventario.get(_hueco_de(equipado), {}) if armado() else {}


## ---------------------------------------------------------------- inventario
func dar_arma(nombre: String, soltar_vieja: bool, mag := -1, reserve := -1) -> void:
	var w: Dictionary = Armas.WEAPONS[nombre]
	var hueco: String = w.Slot
	var vieja = inventario.get(hueco)
	if vieja != null:
		if equipado == vieja.name:
			_desequipar_ya()
		if soltar_vieja:
			var root := J.root_cf()
			var p := J.global_position + Rbx.look(root) * 1.6 + Rbx.right(root) * 0.8
			var g := J.raycast(p + Vector3(0, 4, 0), Vector3(0, -60, 0))
			soltar_en_suelo(vieja, g.position if not g.is_empty() else p - Vector3(0, J.center_cur, 0), randf() * TAU)
	var m: int = mag if mag >= 0 else (w.get("Mag", 0) as int)
	var r: int = reserve if reserve >= 0 else (w.get("StartReserve", 0) as int)
	inventario[hueco] = {"name": nombre, "mag": m, "reserve": r}
	_refrescar_enfundadas()


func _refrescar_enfundadas() -> void:
	var tiene := {}
	for h in inventario:
		tiene[inventario[h].name] = true
	for n in enfundadas.keys():
		if not tiene.has(n):
			(enfundadas[n] as Node3D).queue_free()
			enfundadas.erase(n)
	for n in tiene:
		if not enfundadas.has(n):
			var spot := Armas.holster(n)
			var parte: Node3D = J.rig.P.get(spot.Part)
			if parte == null:
				continue
			var mdl := Armas.construir_modelo(n)
			mdl.name = "Enfundada_" + n
			mdl.transform = spot.CF
			# funda de cuero para el cuchillo
			if n == "Cuchillo":
				var sh := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.08, 0.24, 0.72)
				sh.mesh = bm
				sh.material_override = Armas.material(Color8(55, 40, 28), "Leather")
				sh.position = Vector3(0, 0, -0.62)
				mdl.add_child(sh)
			parte.add_child(mdl)
			enfundadas[n] = mdl


## el Animador dice si el arma de la mano se ve (al ir a buscarla sigue en la funda)
func mostrar(arma_visible: bool) -> void:
	if modelo_mano:
		modelo_mano.visible = arma_visible
	for n in enfundadas:
		(enfundadas[n] as Node3D).visible = not (arma_visible and n == equipado)


func _equipar(nombre: String) -> void:
	if modelo_mano:
		modelo_mano.queue_free()
		modelo_mano = null
	equipado = nombre
	if nombre == "":
		return
	modelo_mano = Armas.construir_modelo(nombre)
	modelo_mano.name = "EnLaMano"
	modelo_mano.transform = Armas.handle_en_mano(nombre)
	(J.rig.P.RightHand as Node3D).add_child(modelo_mano)
	modelo_mano.visible = false
	draw_until = ahora() + float(Armas.WEAPONS[nombre].DrawTime)
	Efectos.sonido(J, "Draw", J.global_position, 0.4, 1.0)


func _desequipar_ya() -> void:
	recargando = 0.0
	anim.cancelar_recarga()
	_equipar("")
	J.L.holster = null
	switching = null


## trepar (encaramarse o colgarse): el arma se guarda para subir con las dos manos y al terminar se vuelve a sacar
var rearmar := ""


func recordar_para_trepar() -> void:
	if armado() and rearmar == "":
		rearmar = equipado if switching == null else String(switching.next)


func guardar_para_trepar() -> void:
	if not armado():
		return
	recordar_para_trepar()
	if recargando > 0.0:
		recargando = 0.0
		anim.cancelar_recarga()
	end_rest()
	J.firing = false
	J.aiming = false
	if switching == null:
		switching = {"t0": ahora(), "next": ""}
		J.L.holster = {"name": equipado, "t0": ahora()}
	else:
		switching.next = ""


func sacar_tras_trepar() -> void:
	var w := rearmar
	rearmar = ""
	if w == "" or armado() or switching != null or not Armas.WEAPONS.has(w):
		return
	if arma_en_hueco(_hueco_de(w)) != w:
		return
	for i in Armas.SLOTS.size():
		if Armas.SLOTS[i].Id == _hueco_de(w):
			select_slot(i)
			return


## teclas 1-4: guardar la de la mano y sacar la otra (o guardar si es la misma)
## guardar el arma de golpe (colgarse de una cornisa: hacen falta las dos manos)
func guardar_ya() -> void:
	if armado() or switching != null:
		_desequipar_ya()
	J.firing = false
	J.aiming = false
	end_rest()


func select_slot(i: int) -> void:
	if recogiendo != null:
		return
	if i < 0 or i >= Armas.SLOTS.size() or switching != null or J.health <= 0 or J.colgado != null:
		return
	if J.L.knocked or J.L.gettingUp or J.vaulting != null:
		return
	if recargando > 0.0:
		return
	var target := arma_en_hueco(Armas.SLOTS[i].Id)
	# en la moto solo armas de una mano (la otra va en el manillar)
	if J.moto != null and target != "" and target != equipado and not Armas.en_moto(target):
		J.notify("En la moto solo puedes usar armas de una mano")
		return
	# tumbado solo se puede sacar el cuchillo como arma blanca
	if target != "" and target != equipado and (J.stance == 2 or J.prone_p > 0.001) and Armas.es_larga_blanca(target):
		J.notify("Tumbado solo puedes usar el arma blanca corta")
		return
	if armado():
		if target == equipado:
			target = ""
		switching = {"t0": ahora(), "next": target}
		J.L.holster = {"name": equipado, "t0": ahora()}
		J.firing = false
	elif target != "":
		_equipar(target)


## al tirarse al suelo con un arma blanca larga en la mano, se guarda primero
func al_cambiar_postura(n: int) -> void:
	if n == 2:
		if armado() and Armas.es_larga_blanca(equipado) and switching == null:
			switching = {"t0": ahora(), "next": ""}
			J.L.holster = {"name": equipado, "t0": ahora()}
			J.firing = false
		elif switching != null and Armas.es_larga_blanca(switching.next):
			switching.next = ""


## ---------------------------------------------------------------- armas en el suelo
func soltar_en_suelo(datos: Dictionary, pos: Vector3, yaw: float) -> void:
	var mdl := Armas.construir_modelo(datos.name)
	mdl.name = "Suelo_" + datos.name
	J.get_parent().add_child(mdl)
	# tumbada en el suelo
	mdl.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), PI / 2), pos + Vector3(0, 0.12, 0))
	var et := Label3D.new()
	et.text = "[F] Recoger: " + Armas.WEAPONS[datos.name].Tip
	et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	et.font_size = 40
	et.pixel_size = 0.008
	et.outline_size = 8
	et.visible = false
	J.get_parent().add_child(et)
	et.global_position = pos + Vector3(0, 1.4, 0)
	suelo.append({"name": datos.name, "mag": datos.mag, "reserve": datos.reserve, "nodo": mdl, "etiqueta": et})


## RECOGER (F): si el arma está un poco lejos, se acerca andando; luego se agacha (o, tumbado, estira
## el brazo), la coge con la mano libre, se incorpora y la lleva a donde se guarda (funda, espalda...).
const RECOGER_DUR := 1.25        # de pie / agachado
const RECOGER_DUR_TUMBADO := 0.9
const RECOGER_ALCANCE := 2.1     # distancia (horizontal) desde la que se agacha a cogerla

var recogiendo = null            # {t0, dur, item, mano, cogida}
var ir_a_recoger = null          # {item, t0}


func _recoger() -> void:
	if recogiendo != null or J.colgado != null or J.vaulting != null or J.health <= 0:
		return
	var cerca = null
	var mejor := 9.0
	for s in suelo:
		var d: float = ((s.nodo as Node3D).global_position - (J.global_position - Vector3(0, J.center_cur, 0))).length()
		if d < mejor:
			mejor = d
			cerca = s
	if cerca == null:
		return
	ir_a_recoger = {"item": cerca, "t0": ahora()}


func _dist_h(item: Dictionary) -> float:
	var p: Vector3 = (item.nodo as Node3D).global_position
	return Vector2(p.x - J.global_position.x, p.z - J.global_position.z).length()


## llamado por el jugador cada fotograma antes de moverse: lleva al personaje hasta el arma
func dirigir() -> void:
	if ir_a_recoger == null:
		return
	var item: Dictionary = ir_a_recoger.item
	if not suelo.has(item) or ahora() - float(ir_a_recoger.t0) > (10.0 if J.stance == 2 else 3.5) or J.colgado != null or J.vaulting != null:
		ir_a_recoger = null
		return
	# si el jugador se mueve por su cuenta, se cancela
	if J.move_direction.length() > 0.1:
		ir_a_recoger = null
		return
	var alcance := RECOGER_ALCANCE * (0.75 if J.stance == 2 else 1.0)
	if _dist_h(item) > alcance:
		var p: Vector3 = (item.nodo as Node3D).global_position
		J.move_direction = Rbx.flat(p - J.global_position).normalized()
		return
	ir_a_recoger = null
	_empezar_recoger(item)


func _empezar_recoger(item: Dictionary) -> void:
	# con un arma en la mano derecha se coge con la izquierda
	var mano := "L" if (armado() and switching == null) else "R"
	recogiendo = {"t0": ahora(), "dur": RECOGER_DUR_TUMBADO if J.stance == 2 else RECOGER_DUR, "item": item,
		"mano": mano, "cogida": false, "pos": (item.nodo as Node3D).global_position}
	J.firing = false
	J.aiming = false
	end_rest()
	(item.etiqueta as Node3D).visible = false


func _paso_recoger() -> void:
	var r: Dictionary = recogiendo
	var p := (ahora() - float(r.t0)) / float(r.dur)
	var item: Dictionary = r.item
	# la mano llega al arma: se queda pegada a la mano
	if not r.cogida and p >= 0.42:
		r.cogida = true
		var nodo := item.nodo as Node3D
		var mano_n: Node3D = J.rig.P.RightHand if r.mano == "R" else J.rig.P.LeftHand
		var gt := nodo.global_transform
		nodo.get_parent().remove_child(nodo)
		mano_n.add_child(nodo)
		nodo.global_transform = gt
		suelo.erase(item)
		(item.etiqueta as Node3D).queue_free()
		Efectos.sonido(J, "Draw", J.global_position, 0.5, 0.8)
	# al final se guarda (o sustituye a la del mismo hueco, que se suelta al suelo)
	if p >= 1.0:
		recogiendo = null
		if is_instance_valid(item.nodo):
			(item.nodo as Node3D).queue_free()
		dar_arma(item.name, true, item.mag, item.reserve)
		J.notify("Has cogido: " + Armas.WEAPONS[item.name].Tip)


## ---------------------------------------------------------------- entrada
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		if e.pressed:
			var w := cfg()
			if w.is_empty():
				punetazo()
				return
			if w.Kind == "Gun":
				J.firing = true
				shoot()
			else:
				if J.stance == 2:
					J.notify("No puedes golpear tumbado")
				else:
					melee()
		else:
			J.firing = false
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_1: select_slot(0)
			KEY_2: select_slot(1)
			KEY_3: select_slot(2)
			KEY_4: select_slot(3)
			KEY_R: reload()
			KEY_X: set_rest(rest == null)
			KEY_G: patada()
			KEY_F:
				# junto a una moto (o en ella) F es subir/bajar (lo lleva el Jugador)
				if J.moto == null and J.moto_cercana() == null:
					_recoger()
			KEY_F5:
				if not OS.is_debug_build():
					return
				balas_infinitas = not balas_infinitas
				J.notify("Balas infinitas: " + ("SÍ" if balas_infinitas else "NO"))


## ---------------------------------------------------------------- recarga
func reload() -> void:
	var w := cfg()
	if w.is_empty() or w.Kind != "Gun" or recargando > 0.0:
		return
	if switching != null or ahora() < draw_until:
		return
	var d := datos_equipado()
	if d.mag >= w.Mag or (d.reserve <= 0 and not balas_infinitas):
		return
	if w.has("ShellTime"):
		# cartucho a cartucho: tantos como falten (y queden)
		var faltan: int = int(w.Mag) - int(d.mag)
		if not balas_infinitas:
			faltan = mini(faltan, int(d.reserve))
		var dur := 0.35 + faltan * float(w.ShellTime) + 0.25
		_cartuchos = {"total": faltan, "metidos": 0}
		recargando = ahora() + dur
		anim.on_reload(equipado, dur, faltan)
		Ruido.emitir(J, J.global_position, C.RUIDO.Recarga, Ruido.ARMA, J)
		return
	recargando = ahora() + w.Reload
	anim.on_reload(equipado, w.Reload)
	Ruido.emitir(J, J.global_position, C.RUIDO.Recarga, Ruido.ARMA, J)
	# grabaciones reales: la del rifle dura ~3 s y la de la pistola ~2 s (se aceleran un poco si la recarga es más rápida)
	var larga := str(w.get("Slot", "")) == "Larga"
	Efectos.sonido(J, "ReloadRifle" if larga else "ReloadPistol", J.global_position, 0.9, (3.0 if larga else 1.9) / float(w.Reload))


func _terminar_recarga() -> void:
	var w := cfg()
	var d := datos_equipado()
	recargando = 0.0
	if w.is_empty() or d.is_empty():
		return
	if w.has("ShellTime"):
		# los cartuchos que la animación no llegó a meter (fotogramas perdidos), se meten ahora
		while not _cartuchos.is_empty() and int(_cartuchos.metidos) < int(_cartuchos.total):
			cartucho_metido()
		_cartuchos = {}
		return
	var take: int = mini(int(w.Mag) - int(d.mag), int(d.reserve))
	if balas_infinitas:
		take = int(w.Mag) - int(d.mag)
		d.mag += take
		return
	d.mag += take
	d.reserve -= take


## casquillo por la ventana de expulsión (a la derecha del arma, algo por detrás de la boca)
func expulsar_casquillo(mz_t: Transform3D, escopeta: bool) -> void:
	var atras := 0.45 if not cfg().get("Slot", "") == "Larga" else 1.0
	var p := mz_t * Vector3(0.08, 0.05, atras)
	var d := mz_t.basis * Vector3(1.0, 0.7, 0.25)
	Efectos.casquillo(J, p, d, escopeta, J.vel_real * 0.8)


## escopeta: la animación avisa cada vez que mete un cartucho (uno a uno, como de verdad)
var _cartuchos := {}


func cartucho_metido() -> void:
	var w := cfg()
	var d := datos_equipado()
	if w.is_empty() or d.is_empty() or _cartuchos.is_empty():
		return
	if int(_cartuchos.metidos) >= int(_cartuchos.total) or int(d.mag) >= int(w.Mag):
		return
	_cartuchos.metidos = int(_cartuchos.metidos) + 1
	d.mag += 1
	Efectos.sonido(J, "Empty", J.global_position, 0.35, 0.8)
	if not balas_infinitas:
		d.reserve = maxi(0, int(d.reserve) - 1)


## ---------------------------------------------------------------- ¿se puede disparar ahí?
## El cuerpo debe poder girar hacia la mira y el cañón no puede estar metido en una pared.
func aim_check() -> Array:
	var w := cfg()
	if w.is_empty() or w.Kind != "Gun":
		return [true, ""]
	var look := Rbx.look(J.camara.global_transform)
	var flat_cam := Vector3(look.x, 0, look.z)
	var bl := Rbx.look(J.root_cf())
	var flat_body := Vector3(bl.x, 0, bl.z)
	if J.moto != null:
		# en la moto (2026-10-30) se dispara en cualquier dirección: hacia la izquierda y detrás por la izquierda
		# el arma pasa a la mano izquierda (Animador). Solo mientras se cambia de mano no se puede disparar
		if anim != null and anim.moto_cambiando():
			return [false, "cambio"]
		return [true, ""]
	if flat_cam.length() > 0.05 and flat_body.length() > 0.05:
		var rel := acos(clampf(flat_cam.normalized().dot(flat_body.normalized()), -1, 1))
		# boca arriba se apunta por encima de los pies (el cuerpo mira al lado contrario)
		if J.stance == 2 and J.supine:
			rel = minf(rel, PI - rel)
		var lim := deg_to_rad(40) if J.stance == 2 else deg_to_rad(75)
		if rel > lim:
			return [false, "body"]
	# pegado a una pared NO se bloquea: la bala sale hacia donde apunta el cañón (ver shoot)
	return [true, ""]


## punto al que apunta la mira (rayo de la cámara, sin dispersión); se calcula una vez por fotograma
var _mira_f := -1
var _mira_p := Vector3.ZERO
func punto_mira() -> Vector3:
	var f := Engine.get_process_frames()
	if f == _mira_f:
		return _mira_p
	_mira_f = f
	var cam := J.camara.global_transform
	var look := Rbx.look(cam)
	var head: Vector3 = (J.rig.P.Head as Node3D).global_position
	var origin := cam.origin + look * maxf(0.0, (head - cam.origin).dot(look))
	var rango := float(cfg().get("Range", 1000.0))
	var r := _rayo_bala(origin, look, rango)
	_mira_p = r.position if not r.is_empty() else origin + look * rango
	return _mira_p


## por dónde sale la bala: del cañón, en la dirección del cañón. Si el cañón está metido en una pared
## (pegado a ella), la bala da en la pared ahí mismo. Devuelve [origen, dirección, impacto_forzado]
func salida_bala() -> Array:
	var mz_t := (modelo_mano.get_node("Muzzle") as Node3D).global_transform
	var dir := (-mz_t.basis.z).normalized()
	# ¿la boca del cañón está metida en una pared? Se mira A LO LARGO DEL ARMA (de la empuñadura a la boca),
	# no desde el pecho: con el arma apoyada sobre un muro, la línea pecho-boca rozaba el propio muro y
	# la bala "salía del torso" contra él
	var empu: Vector3 = modelo_mano.global_position
	var dentro := J.raycast(empu, mz_t.origin - empu)
	# el rayo de la bala empieza en la línea del cañón a la altura de la empuñadura, no en la boca: con
	# un zombi pegado, la boca del cañón queda DENTRO de él (el rayo cuenta los blancos desde dentro)
	var atras := maxf(0.0, (mz_t.origin - empu).dot(dir))
	return [mz_t.origin, dir, dentro, mz_t.origin - dir * atras]


## ---------------------------------------------------------------- apoyar el arma (X)
const LADO_ALCANCE := 2.0 # studs: hasta dónde puede estar la pared para apoyar el arma de lado
## Busca delante una superficie a la altura adecuada (muro bajo, barrera, alféizar...). Tumbado: el suelo.
## (2026-11-03, KangooG) qué apoyos valen con X: encima de superficies horizontales (muros, barreras, alféizares) SÍ;
## de lado contra superficies verticales (paredes, esquinas) NO (desactivado: poner APOYO_LATERAL = true lo vuelve a
## activar tal cual). Tumbado, en el suelo, siempre. El apoyo horizontal de delante también se busca al apuntar
## (apoyo_delante) para que el cuerpo se incorpore y el arma no atraviese la barrera.
const APOYO_HORIZONTAL := true
const APOYO_LATERAL := false
var apoyo_delante = null        # barrera / muro bajo delante al apuntar (solo para no atravesarlo)
const REST_DELANTE_PIE := 0.5        # altura de la parte de delante del arma al apuntar, sobre el centro del cuerpo
const REST_DELANTE_AGACHADO := 0.15


func find_rest():
	var w := cfg()
	if w.is_empty() or w.Kind != "Gun" or J.vaulting != null or J.L.knocked:
		return null
	if J.prone_p > 0.001 and J.prone_p < 0.999:
		return null
	var look := Rbx.look(J.camara.global_transform)
	var fwd := Vector3(look.x, 0, look.z)
	if fwd.length() < 0.1:
		return null
	fwd = fwd.normalized()
	var rp := J.global_position
	if J.stance == 2:
		# boca arriba no hay dónde apoyarla (se apunta por encima de los pies, en el aire)
		if J.supine or J.L.get("supine", false):
			return null
		return {"top": rp.y, "point": rp + fwd * 1.5, "gap": 0.0, "ground": true}
	# el arma solo se apoya en algo que esté a la altura a la que se lleva al apuntar (de pie, un
	# alféizar o un muro alto; agachado, una barrera o un muro bajo). Si el apoyo queda más bajo,
	# hay que agacharse; si queda más alto, no se puede disparar por encima.
	var gun_y := rp.y + J.eye_cur - 0.3 # altura del arma al apuntar
	var feet_y := rp.y - J.center_cur
	rest_motivo = ""
	if APOYO_HORIZONTAL:
		var rh = _apoyo_horizontal(rp, fwd, gun_y, feet_y)
		if rh != null:
			return rh
	if not APOYO_LATERAL:
		return null
	return _apoyo_lateral(rp, fwd, gun_y)


## superficie horizontal delante a la altura del arma (muro, barrera, alféizar), o null
func buscar_apoyo_horizontal():
	var w := cfg()
	if w.is_empty() or w.Kind != "Gun" or J.vaulting != null or J.L.knocked or J.stance == 2:
		return null
	var look := Rbx.look(J.camara.global_transform)
	var fwd := Vector3(look.x, 0, look.z)
	if fwd.length() < 0.1:
		return null
	var rp := J.global_position
	return _apoyo_horizontal(rp, fwd.normalized(), rp.y + J.eye_cur - 0.3, rp.y - J.center_cur)


func _apoyo_horizontal(rp: Vector3, fwd: Vector3, gun_y: float, feet_y: float):
	for d in [1.0, 1.35, 1.7, 2.05]:
		var probe: Vector3 = rp + fwd * d
		var hit := J.raycast(Vector3(probe.x, gun_y + 1.2, probe.z), Vector3(0, -(gun_y + 1.2 - feet_y - 1.0), 0))
		if hit.is_empty() or hit.normal.y < 0.7:
			continue
		var top: float = hit.position.y
		if top <= feet_y + 1.2:
			continue
		# nada en medio entre el cuerpo y el borde
		var from := Vector3(rp.x, top + 0.3, rp.z)
		if not J.raycast(from, fwd * (d - 0.1)).is_empty():
			continue
		# (2026-11-03) el cuerpo se ajusta a la altura del apoyo (Animador._arma_sobre_apoyo): de pie puede bajar
		# doblando las rodillas y los brazos subir un poco el arma; agachado, además, incorporarse. "sube" = cuánto
		# tiene que subir la parte de delante del arma (medida en el juego al apuntar) para quedar encima del apoyo
		var sube := top + 0.02 - (rp.y + (REST_DELANTE_PIE if J.stance == 0 else REST_DELANTE_AGACHADO))
		var sube_max := 0.35 if J.stance == 0 else 1.2
		var baja_max := 1.1 if J.stance == 0 else 0.6
		if sube < -baja_max:
			rest_motivo = "bajo"
			continue
		if sube > sube_max:
			rest_motivo = "alto"
			continue
		return {"top": top, "point": hit.position, "gap": -sube, "ground": false}
	return null


func _apoyo_lateral(rp: Vector3, fwd: Vector3, gun_y: float):
	# APOYO LATERAL: de lado a una pared (o al borde de una esquina), el arma se apoya contra ella.
	# Hace falta una pared vertical justo al lado del arma, más o menos paralela a donde se apunta
	var der := Vector3(-fwd.z, 0, fwd.x)
	for d: float in [0.4, 0.9, 1.4]:
		var base: Vector3 = Vector3(rp.x, gun_y, rp.z) + fwd * d
		for lado: float in [-1.0, 1.0]:
			var hl := J.raycast(base, der * lado * LADO_ALCANCE)
			if hl.is_empty():
				continue
			var n: Vector3 = hl.normal
			if absf(n.y) > 0.3 or absf(n.dot(fwd)) > 0.6:
				continue
			return {"top": gun_y, "point": hl.position, "gap": 0.0, "ground": false, "lado": true, "normal": n}
	return null


func end_rest() -> void:
	if rest == null:
		return
	rest = null
	# se sigue apuntando solo si se mantiene el clic derecho
	J.aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func set_rest(on: bool) -> void:
	if not on:
		end_rest()
		return
	if J.moto != null:
		return
	if J.move_direction.length() > 0.1:
		J.notify("Quédate quieto para apoyar el arma")
		return
	var r = find_rest()
	if r == null:
		var w := cfg()
		if w.is_empty() or w.Kind != "Gun":
			J.notify("Necesitas un arma de fuego")
		elif J.stance == 2 and J.supine:
			J.notify("Boca arriba no puedes apoyar el arma")
		elif rest_motivo == "bajo":
			J.notify("El apoyo está muy bajo para el arma: agáchate")
		elif rest_motivo == "alto":
			J.notify("El apoyo está demasiado alto para el arma")
		else:
			J.notify("No hay dónde apoyar el arma aquí")
		return
	r.yaw0 = J.yaw
	r.stance = J.stance
	r.t0 = ahora()
	rest = r
	J.aiming = true


## ---------------------------------------------------------------- disparar
func shoot() -> void:
	if recogiendo != null:
		return
	var w := cfg()
	if w.is_empty() or w.Kind != "Gun" or J.health <= 0 or J.vaulting != null or J.L.gettingUp or J.ragdoll != null:
		return
	if switching != null or ahora() < draw_until:
		return
	if cc.bloqueo or cc.accion != null:
		return
	# No disparar desde la cámara si el arma visual todavía no está disponible.
	if modelo_mano == null or not modelo_mano.visible or not modelo_mano.has_node("Muzzle"):
		return
	var now := ahora()
	# humanamente imposible disparar ahí: se bloquea (y se reintenta un instante mientras el arma se alinea)
	if not aim_check()[0]:
		if pending_shot == null:
			pending_shot = now
		return
	pending_shot = null
	if now - last_shot < 60.0 / w.RPM:
		return
	if recargando > 0.0:
		# la escopeta deja de recargar para disparar (con los cartuchos que ya ha metido)
		if w.has("ShellTime") and int(datos_equipado().mag) > 0:
			recargando = 0.0
			_cartuchos = {}
			anim.cancelar_recarga()
		else:
			return
	var d := datos_equipado()
	if d.mag <= 0:
		last_shot = now
		Efectos.sonido(J, "Empty", J.global_position, 0.4, 0.6)
		Ruido.emitir(J, J.global_position, C.RUIDO.Vacio, Ruido.ARMA, J)
		J.firing = false
		reload()
		return
	last_shot = now
	if not balas_infinitas:
		d.mag -= 1
	# el disparo se oye muy lejos (radio "Alert" del arma)
	Ruido.emitir(J, J.global_position, float(w.Alert), Ruido.DISPARO, J)

	# dispersión: apuntar, movimiento, saltar y ráfaga
	var move_speed := Vector3(J.vel_real.x, 0, J.vel_real.z).length()
	if J.moto != null:
		# en la moto se mueve el vehículo, no los pies: dispara bastante mejor que corriendo
		move_speed = minf(move_speed, 30.0) * 0.45
	var spread: float = ((w.AimSpread if J.aiming else w.HipSpread) * (1.0 + move_speed / 18.0) + spread_bloom) * C.STANCE[J.stance].Spread
	if not J.en_suelo:
		spread *= 2.5
	# apoyada: mucho más precisa y la ráfaga se abre menos
	if rest != null:
		spread *= C.REST.ProneSpread if rest.ground else C.REST.Spread
	spread_bloom = minf(6.0, spread_bloom + (0.45 if w.Auto else 0.9) * (0.4 if rest != null else 1.0))

	# la bala sale del CAÑÓN y en la dirección del CAÑÓN (el animador orienta el arma hacia la mira al
	# apuntar o disparar). Si entre el arma y lo que se ve en la mira hay algo (esquina, muro bajo,
	# la pared contra la que está pegado), la bala da ahí; el círculo rojo del HUD lo avisa.
	var sb := salida_bala()
	var origin: Vector3 = sb[0]
	var eje: Vector3 = sb[1]
	var forzado: Dictionary = sb[2]
	var desde: Vector3 = sb[3]
	# perdigones (escopeta): varios rayos con su propia dispersión; un solo marcador de impacto
	var n_balas := int(w.get("Pellets", 1))
	var pell := float(w.get("PelletSpread", 0.0))
	var mz_t := Transform3D(Basis.IDENTITY, origin)
	if modelo_mano and modelo_mano.has_node("Muzzle"):
		mz_t = (modelo_mano.get_node("Muzzle") as Node3D).global_transform
	var mato := false
	var cabeza := false
	var acerto := false
	var impacto_superficie := Vector3.INF
	var r0 := deg_to_rad(spread) * sqrt(randf())
	var a0 := randf() * TAU
	var eje0 := Rbx.look(Rbx.look_at(Vector3.ZERO, eje) * Rbx.ang(cos(a0) * r0, sin(a0) * r0, 0))
	for nb in n_balas:
		var dir := eje0
		if n_balas > 1:
			var rp := deg_to_rad(pell) * sqrt(randf())
			var ap := randf() * TAU
			dir = Rbx.look(Rbx.look_at(Vector3.ZERO, eje0) * Rbx.ang(cos(ap) * rp, sin(ap) * rp, 0))
		var res := forzado if not forzado.is_empty() else _rayo_bala(desde, dir, float(w.Range) + desde.distance_to(origin))
		var punto_bala := origin + dir * float(w.Range)
		var tipo_superficie := "none"
		var intensidad := 1.0
		var normal := Vector3.UP
		if not res.is_empty():
			punto_bala = res.position
			normal = res.normal
			if normal.length() < 0.1: # el rayo empezó dentro (blanco pegado al arma)
				normal = -dir
			tipo_superficie = "surface"
			var col: Object = res.collider
			# zonas de impacto de un blanco (maniquí o zombi): ver "contrato de objetivo" en docs/RUIDO_Y_ZOMBIS.md
			if col and col.has_meta("objetivo"):
				tipo_superficie = "flesh"
				var obj = col.get_meta("objetivo")
				var pieza: String = res.pieza if res.has("pieza") else col.get_meta("pieza")
				var dmg: float = w.Damage * Maniqui.mult_pieza(pieza, w)
				# caída de daño con la distancia
				if punto_bala.distance_to(origin) > float(w.Range) * 0.5:
					dmg *= 0.75
				intensidad = clampf(sqrt(dmg / 30.0), 0.45, 1.65)
				if obj is Zombi and obj.rig.P.has(pieza):
					Efectos.herida(obj.rig.P[pieza], punto_bala, normal, 0.20 * intensidad, false)
				var estaba_vivo: bool = obj.vivo()
				var killed := false
				if obj.has_method("recibir_disparo"):
					var factor := 0.75 if punto_bala.distance_to(origin) > float(w.Range) * 0.5 else 1.0
					killed = obj.recibir_disparo(dmg, pieza, dir * ImpactoBalistico.impulso(equipado) * factor, punto_bala)
				elif estaba_vivo:
					killed = obj.recibir_danio(dmg, pieza, dir * (45.0 if n_balas == 1 else 12.0))
				if killed and equipado == "Francotirador" and obj is Zombi:
					obj.separar_extremidad(pieza, dir)
				if estaba_vivo:
					acerto = true
					mato = mato or killed
					cabeza = cabeza or pieza == "Head"
			elif impacto_superficie == Vector3.INF:
				impacto_superficie = punto_bala
		# trazadoras: todas las balas; de los perdigones, solo algunas
		if n_balas == 1 or nb % 3 == 0:
			Efectos.tracer(J, mz_t.origin, punto_bala)
		if tipo_superficie != "none":
			Efectos.impacto(J, punto_bala, normal, tipo_superficie, intensidad)
		if not forzado.is_empty():
			break
	if acerto:
		_confirmar(mato, cabeza)

	# efectos
	Efectos.sonido(J, w.Sound, J.global_position, 1.3, 0.95 + randf() * 0.1)
	var fuerza := {"Pistola": 0.8, "Revolver": 1.1, "Subfusil": 0.75, "Escopeta": 1.5, "Francotirador": 1.4}.get(equipado, 1.0) as float
	Efectos.muzzle_flash(J, mz_t, fuerza)
	# casquillo (las de corredera y cerrojo lo sueltan al accionarlas; el revólver no expulsa)
	if not w.get("Pump", false) and not w.get("Bolt", false) and equipado != "Revolver":
		expulsar_casquillo(mz_t, false)
	var tipo := "surface" if impacto_superficie != Vector3.INF else "none"
	var hit_pos := impacto_superficie
	# la bala que golpea una superficie también suena allí (sin "fuente": los zombis van a mirar ese
	# sitio, no saben que ha sido el jugador). Disparar a una pared lejana sirve para distraerlos.
	if tipo == "surface":
		Ruido.emitir(J, hit_pos, C.RUIDO.Impacto, Ruido.IMPACTO, null)
	anim.on_shot(equipado)

	# retroceso
	var k: float = (0.65 if J.aiming else 1.0) * C.STANCE[J.stance].Recoil * (C.REST.Recoil if rest != null else 1.0)
	J.pitch = clampf(J.pitch + deg_to_rad(w.Recoil * k * (0.8 + randf() * 0.4)), -1.35, 1.2)
	J.yaw += deg_to_rad((randf() - 0.5) * 2.0 * w.RecoilYaw * k)
	J.shake = minf(1.0, J.shake + (0.12 if w.Auto else 0.25) * (0.35 if rest != null else 1.0))


## rayo de una bala (escenario y zonas de impacto de los blancos). Un blanco con un único cuerpo de
## impacto (el zombi) dice qué pieza ha tocado la bala; si pasa sin tocar ninguna (entre los brazos),
## la bala sigue (ver "contrato de objetivo" en docs/RUIDO_Y_ZOMBIS.md)
func _rayo_bala(origin: Vector3, dir: Vector3, rango: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * rango, 1 | 2)
	q.hit_from_inside = true # un blanco pegado al arma también cuenta
	var excluir: Array[RID] = [J.get_rid()]
	if J.moto != null:
		excluir.append(J.moto.get_rid()) # la moto que conduce no para sus balas
	var res := {}
	for intento in 4:
		q.exclude = excluir
		res = J.get_world_3d().direct_space_state.intersect_ray(q)
		var c: Object = res.get("collider")
		if res.is_empty() or c == null or not c.has_meta("objetivo") or c.has_meta("pieza"):
			break
		var imp: Dictionary = c.get_meta("objetivo").impacto_bala(origin, dir)
		if not imp.is_empty():
			res.position = imp.punto
			res.pieza = imp.pieza
			break
		excluir.append(res.rid)
		res = {}
	return res


func _confirmar(killed: bool, headshot: bool) -> void:
	hit_t = ahora()
	hit_color = Color8(230, 40, 40) if killed else (Color8(255, 210, 80) if headshot else Color.WHITE)
	Efectos.sonido(J, "Hit", null, 0.5, 1.6 if headshot else 1.2)
	if killed:
		J.notify("DISPARO A LA CABEZA" if headshot else "BAJA")


## ---------------------------------------------------------------- cuerpo a cuerpo
var _golpe_tras_frenar := ""
var _golpe_caduca := -9.0

func _esperar_frenada(tipo: String) -> bool:
	if J.moto != null:
		return false
	if J.L.sprinting or (Rbx.flat(J.vel_real).length() > C.PLAYER.WalkSpeed * 1.1):
		_golpe_tras_frenar = tipo
		_golpe_caduca = ahora() + 0.7
		J._frenar_combate_hasta = ahora() + 0.25
		return true
	return false


func melee() -> void:
	if _esperar_frenada("arma"):
		return
	if recogiendo != null:
		return
	var w := cfg()
	if w.is_empty() or w.Kind != "Melee" or J.health <= 0 or J.vaulting != null or J.ragdoll != null or J.L.gettingUp:
		return
	if switching != null or ahora() < draw_until or cc.accion != null:
		return
	var now := ahora()
	if now - last_melee < w.Cooldown:
		return
	if J.stamina < w.Stamina * 0.5 and not J.estamina_infinita:
		J.notify("Estás agotado")
		return
	last_melee = now
	J.stamina = maxf(0.0, J.stamina - w.Stamina)
	Ruido.emitir(J, J.global_position, C.RUIDO.GolpeAire, Ruido.GOLPE, J)
	var base_g := Armas.base(equipado)
	var nuevos: Array = CombateCC.GOLPES.get(base_g, [])
	if J.moto == null and not nuevos.is_empty() and cc_puede():
		var vg := _cc_variante("golpe_" + equipado, nuevos.size())
		var ag: Dictionary = nuevos[vg]
		var bajo := _blanco_caido()
		if bajo:
			ag = CombateCC.SUELO
		var dur_g: float = float(ag.dur)
		cc.accion = {"tipo": "golpe", "clase": cc_clase(), "base": base_g, "bajo": bajo, "var": vg, "t0": now, "dur": dur_g,
			"avance_prev": 0.0, "extra": _cc_extra(float(w.Range) * 0.55) * 0.5}
		cc_golpes.append([now + dur_g * float(ag.golpe), "golpe", {"arma": equipado}])
		J.shake = minf(1.0, J.shake + 0.15)
		impacto.preparar(cc.accion, ag)
		return
	anim.on_melee(equipado)
	# el impacto llega en el punto de golpe de la animación
	# (en la moto el golpe llega antes: a esa velocidad el blanco se queda atrás enseguida)
	golpes_pendientes.append([now + float(w.get("HitTime", 0.26)) * (0.6 if J.moto != null else 1.0), equipado, false])
	J.shake = minf(1.0, J.shake + 0.15)


# Segmentos locales del filo o cuerpo contundente, medidos sobre ModelosArmas (studs).
const CONTACTO_ARMA := {
	"Cuchillo": [Vector3(0, 0, -0.25), Vector3(0, 0, -0.93), 0.08],
	"Machete": [Vector3(0, 0, -0.30), Vector3(0, 0, -1.67), 0.13],
	"Bate": [Vector3(0, 0, -0.39), Vector3(0, 0, -2.28), 0.17],
	"Hacha": [Vector3(0, 0.42, -1.68), Vector3(0, -0.52, -1.68), 0.13],
	"Palanca": [Vector3(0, 0, -0.18), Vector3(0, 0, -1.65), 0.06],
}


func _resolver_golpe(arma: String) -> bool:
	if modelo_mano == null or not modelo_mano.visible or not CONTACTO_ARMA.has(arma):
		return false
	var perfil: Array = CONTACTO_ARMA[arma]
	var inicio := modelo_mano.to_global(perfil[0])
	var fin := modelo_mano.to_global(perfil[1])
	var w: Dictionary = Armas.WEAPONS[arma]
	for blanco in _cc_blancos(float(w.Range) + 1.5):
		var man = blanco[1]
		for pn in man.rig.P:
			if pn == "HumanoidRootPart":
				continue
			var parte: Node3D = man.rig.P[pn]
			var tam: Vector3 = parte.get_meta("size")
			var caja := AABB(-tam * 0.5, tam).grow(perfil[2])
			var local := parte.to_local(inicio)
			var contacto = local if caja.has_point(local) else caja.intersects_segment(local, parte.to_local(fin))
			if contacto == null:
				continue
			var punto := parte.to_global(contacto)
			if not J.raycast(J.root_cf().origin, punto - J.root_cf().origin).is_empty():
				continue
			_aplicar_contacto_arma(man, pn, punto, w)
			return true
	return false


func _aplicar_contacto_arma(man, pieza: String, ppos: Vector3, w: Dictionary) -> void:
	var look := Rbx.look(J.root_cf())
	var crit := pieza == "Head"
	var bonus := 1.0
	if J.moto != null:
		bonus += clampf(absf(J.moto.velocidad()) / 60.0, 0.0, 0.7)
	var dmg: float = w.Damage * (w.HeadMult if crit else 1.0) * bonus
	# (al que está en el suelo, el golpe va hacia abajo y sacude su ragdoll)
	var imp_v: Vector3 = look * float(w.Knockback) if man.en_pie() else (look * 0.4 + Vector3.DOWN).normalized() * float(w.Knockback) * 2.5
	var contundente: bool = str(w.get("Sound", "Flesh")) == "Blunt"
	var fuerza := clampf(dmg / 45.0, 0.5, 1.5)
	if man is Zombi and (not contundente or crit):
		Efectos.herida(man.rig.P[pieza], ppos, -look, 0.35 * fuerza, not contundente)
	var killed: bool = man.recibir_danio(dmg, pieza, imp_v)
	if killed and man is Zombi and equipado in ["Machete", "Hacha"]:
		man.separar_extremidad(pieza, look)
	Ruido.emitir(J, ppos, C.RUIDO.GolpeContundente if contundente else C.RUIDO.GolpeCarne, Ruido.GOLPE, J)
	_confirmar(killed, crit)
	if not killed and man.en_pie():
		var p_derribo := float(w.get("Derriba", 0.0))
		if p_derribo > 0.0 and (crit or randf() < p_derribo):
			# batazo: lo derriba y luego se levanta
			man.derribar(look * 38 + Vector3(0, 12, 0), 2.2)
		else:
			man.empujar(look * float(w.Knockback) * 0.8, float(w.get("Stagger", 0.45)))
	Efectos.blood_at(J, ppos, -look, fuerza * (0.55 if contundente else 1.0))
	Efectos.sonido(J, "BatHit" if contundente else "Blade", ppos, 0.85)
	impacto.golpe("golpe", man, pieza, ppos, clampf(dmg / 3.0, 5.0, 18.0), look)


## ---------------------------------------------------------------- combate cuerpo a cuerpo (2026-11-08, KangooG)
## Clic derecho mantenido: con arma blanca o sin arma, GUARDIA (con arma de fuego sigue siendo apuntar).
## Con el clic derecho mantenido: Espacio mantenido = BLOQUEO (si se pone justo antes del golpe, PARADA: no hace daño
## y el zombi se tambalea) y doble Espacio = EMPUJÓN (con las manos si el arma es corta; con el arma si es larga).
## G = PATADA frontal (con cualquier arma, de pie): hace daño, empuja y puede tirarlo; gasta estamina.
## Las animaciones salen de Blender (CombateCC, animaciones/blender/combate/); el Animador las pone (_paso_cc).
const CC_DOBLE := 0.32            # s entre las dos pulsaciones de Espacio para el empujón
const CC_PARADA := 0.28           # s: bloqueo puesto como mucho tanto antes del golpe = parada
const CC_BLOQUEO_DANIO := 0.25    # parte del daño que pasa bloqueando
const CC_BLOQUEO_GASTO := 0.9     # estamina por punto de daño parado
const CC_EMPUJON := {"estamina": 8.0, "espera": 0.7, "alcance": 3.3, "empuje": 46.0, "tambaleo": 1.2, "danio": 0.0}
const CC_EMPUJON_ARMA := {"estamina": 10.0, "espera": 0.8, "alcance": 3.5, "empuje": 50.0, "tambaleo": 1.2, "danio": 4.0}
const CC_PATADA := {"estamina": 14.0, "espera": 0.9, "alcance": 3.6}
const CC_PISOTON := {"estamina": 12.0, "espera": 0.85, "alcance": 4.2, "cabeza": 1.8}
const CC_PUNO := {"estamina": 4.0, "espera": 0.08, "alcance": 3.4, "seguido": 1.0}
const CC_ACERCA := 0.7            # studs: si el blanco está algo más lejos, el cuerpo avanza algo más para llegar
const CC_CONO := 0.45             # coseno: lo que está delante (unos 63° a cada lado)
var cc := {"guardia": false, "bloqueo": false, "bloqueo_t0": -9.0, "accion": null}
var _cc_espacio := false          # Espacio mantenido (con el clic derecho)
var _cc_espacio_t := -9.0         # última pulsación de Espacio
var _cc_listo_t := -9.0           # hasta cuándo no se puede empezar otra acción
var _cc_roto_t := -9.0            # guardia rota (sin estamina): hasta cuándo no se puede bloquear
var _cc_ultima := {}              # tipo -> última variante (para no repetir)
var cc_golpes := []               # impactos pendientes [hora, tipo, datos]
var _puno_n := 0                  # puñetazos seguidos (directo, cruzado, gancho, gancho de abajo)
var _puno_t := -9.0
var _puno_ult := 0                 # último puñetazo (y el de antes): Arsenal.punetazo no los repite
var _puno_ult2 := -1
var _puno_pedido := -9.0          # clic durante un puñetazo: el siguiente sale en cuanto termine (si fue hace poco)


## animación (CombateCC) de una acción en curso
func cc_anim(ac: Dictionary) -> Dictionary:
	if ac.get("bajo", false):
		return CombateCC.SUELO
	match str(ac.tipo):
		"empujon":
			return CombateCC.EMPUJON[ac.clase][ac["var"]]
		"golpe":
			return CombateCC.GOLPES[ac.base][ac["var"]]
		"puno":
			return CombateCC.PUNOS[ac["var"]]
		"pisoton":
			return CombateCC.PISOTON[ac["var"]]
	return CombateCC.PATADA[ac["var"]]


## clase de combate del arma en la mano (CombateCC): manos, corta, larga, fuego_corta, fuego_larga
func cc_clase() -> String:
	var w := cfg()
	if w.is_empty():
		return "manos"
	if w.Kind == "Gun":
		return "fuego_corta" if w.Slot == "Corta" else "fuego_larga"
	return "corta" if w.Slot == "BlancaCorta" else "larga"


## ¿puede pelear ahora? (de pie o agachado, en el suelo, sin estar ocupado)
func cc_puede(de_pie := false) -> bool:
	if J.health <= 0 or J.moto != null or J.vaulting != null or J.colgado != null or J.ragdoll != null:
		return false
	if J.L.get("knocked", false) or J.L.get("gettingUp", false) or J.levantando_moto != null:
		return false
	if J.stance == 2 or J.prone_p > 0.01 or (de_pie and J.stance != 0) or not J.en_suelo:
		return false
	if switching != null or ahora() < draw_until or recogiendo != null or rest != null:
		return false
	return true


## Espacio con el clic derecho mantenido: el Jugador pregunta antes de saltar
func cc_quiere_espacio() -> bool:
	return J.aiming and cc_puede()


func cc_espacio(pulsado: bool) -> void:
	var now := ahora()
	if not pulsado:
		_cc_espacio = false
		return
	_cc_espacio = true
	if now - _cc_espacio_t < CC_DOBLE:
		_cc_espacio_t = -9.0
		empujon()
		return
	_cc_espacio_t = now
	if now >= _cc_roto_t:
		cc.bloqueo_t0 = now


func _cc_variante(tipo: String, n: int) -> int:
	# "bolsa": salen todas las variantes en orden al azar antes de repetir ninguna (y nunca la misma dos veces seguidas)
	if n <= 1:
		return 0
	var bolsa: Array = _cc_ultima.get(tipo + "_bolsa", [])
	if bolsa.is_empty():
		for i in n:
			bolsa.append(i)
		bolsa.shuffle()
		if int(bolsa[0]) == int(_cc_ultima.get(tipo, -1)):
			bolsa.push_back(bolsa.pop_front())
	var v: int = bolsa.pop_front()
	_cc_ultima[tipo + "_bolsa"] = bolsa
	_cc_ultima[tipo] = v
	return v


func _cc_empezar(_tipo: String, coste: float, espera: float) -> bool:
	var now := ahora()
	if now < _cc_listo_t or cc.accion != null or now - last_melee < 0.35:
		return false
	if J.stamina < coste * 0.5 and not J.estamina_infinita:
		J.notify("Estás agotado")
		return false
	if not J.estamina_infinita:
		J.stamina = maxf(0.0, J.stamina - coste)
	_cc_listo_t = now + espera
	if recargando > 0.0:
		recargando = 0.0
		anim.cancelar_recarga()
	return true


func empujon() -> void:
	if not cc_puede():
		return
	var clase := cc_clase()
	var lista: Array = CombateCC.EMPUJON[clase]
	var con_arma := clase in ["larga", "fuego_larga"]
	var p: Dictionary = CC_EMPUJON_ARMA if con_arma else CC_EMPUJON
	if not _cc_empezar("empujon", p.estamina, p.espera):
		return
	var v := _cc_variante("empujon_" + clase, lista.size())
	var a: Dictionary = lista[v]
	var now := ahora()
	cc.accion = {"tipo": "empujon", "clase": clase, "var": v, "t0": now, "dur": float(a.dur), "avance_prev": 0.0,
		"extra": _cc_extra(float(p.alcance))}
	cc_golpes.append([now + float(a.dur) * float(a.golpe), "empujon", p])
	impacto.preparar(cc.accion, a)
	Efectos.sonido(J, "Swing", J.global_position, 0.6, 0.75 + randf() * 0.15)


func _blanco_caido() -> bool:
	var bl := cc_blanco(CC_PISOTON.alcance)
	return not bl.is_empty() and not bl[1].en_pie()


func patada() -> void:
	# Comprobar también la entrada actual: G puede llegar antes de actualizar L.sprinting.
	if J.L.sprinting or (Input.is_physical_key_pressed(KEY_SHIFT) and J._leer_movimiento().length() > 0.1 and not J.aiming and not J.firing and not J.exhausted):
		return
	if not cc_puede(true):
		return
	# con el blanco en el suelo delante, pisotón
	if _blanco_caido():
		pisoton()
		return
	if not _cc_empezar("patada", CC_PATADA.estamina, CC_PATADA.espera):
		return
	var v := _cc_variante("patada", CombateCC.PATADA.size())
	var a: Dictionary = CombateCC.PATADA[v]
	var now := ahora()
	cc.accion = {"tipo": "patada", "clase": cc_clase(), "var": v, "t0": now, "dur": float(a.dur), "avance_prev": 0.0,
		"extra": _cc_extra(float(CC_PATADA.alcance))}
	cc_golpes.append([now + float(a.dur) * float(a.golpe), "patada", a])
	impacto.preparar(cc.accion, a)
	Efectos.sonido(J, "Swing", J.global_position, 0.7, 0.65 + randf() * 0.15)


## G con un zombi (o muñeco) en el suelo delante: PISOTÓN (sube la rodilla y baja el pie con todo el peso)
func pisoton() -> void:
	if not _cc_empezar("pisoton", CC_PISOTON.estamina, CC_PISOTON.espera):
		return
	var v := _cc_variante("pisoton", CombateCC.PISOTON.size())
	var a: Dictionary = CombateCC.PISOTON[v]
	var now := ahora()
	cc.accion = {"tipo": "pisoton", "clase": cc_clase(), "var": v, "t0": now, "dur": float(a.dur), "avance_prev": 0.0,
		"extra": _cc_extra(CC_PISOTON.alcance - 1.2)}
	cc_golpes.append([now + float(a.dur) * float(a.golpe), "pisoton", a])
	impacto.preparar(cc.accion, a)
	Efectos.sonido(J, "Swing", J.global_position, 0.6, 0.6 + randf() * 0.1)


## SIN ARMA, clic izquierdo: puñetazos encadenados (directo, cruzado, gancho, gancho de abajo; si pasa un rato, vuelve
## a empezar por el directo)
func punetazo() -> void:
	if _esperar_frenada("puno"):
		return
	if equipado != "" or not cc_puede():
		return
	var now := ahora()
	if cc.accion != null:
		if cc.accion.tipo == "puno":
			_puno_pedido = now
		return
	if not _cc_empezar("puno", CC_PUNO.estamina, CC_PUNO.espera):
		return
	if now - _puno_t > float(CC_PUNO.seguido):
		_puno_n = 0
	# (2026-11-08, 10: 6 puñetazos) tras una pausa, el directo; luego alternando manos, al azar entre los de la otra
	# mano (sin repetir los dos últimos)
	var v := 0
	if _puno_n > 0:
		var lado_prev := str(CombateCC.PUNOS[_puno_ult].get("lado", "L"))
		var cand := []
		for i in CombateCC.PUNOS.size():
			if i != _puno_ult and i != _puno_ult2 and str(CombateCC.PUNOS[i].get("lado", "L")) != lado_prev:
				cand.append(i)
		if cand.is_empty():
			cand = [(_puno_ult + 1) % CombateCC.PUNOS.size()]
		v = int(cand[randi() % cand.size()])
	_puno_ult2 = _puno_ult
	_puno_ult = v
	_puno_n += 1
	_puno_t = now
	var bajo := _blanco_caido()
	var a: Dictionary = CombateCC.SUELO if bajo else CombateCC.PUNOS[v]
	cc.accion = {"tipo": "puno", "clase": "manos", "bajo": bajo, "var": v, "t0": now, "dur": float(a.dur), "avance_prev": 0.0,
		"extra": _cc_extra(float(CC_PUNO.alcance)) * 0.5}
	var d := a.duplicate()
	d["alcance"] = CC_PUNO.alcance
	cc_golpes.append([now + float(a.dur) * float(a.golpe), "puno", d])
	impacto.preparar(cc.accion, a)
	last_melee = now
	Efectos.sonido(J, "Swing", J.global_position, 0.5, 1.1 + randf() * 0.2)
	Ruido.emitir(J, J.global_position, C.RUIDO.GolpeAire, Ruido.GOLPE, J)


## si hay un blanco delante un poco más lejos de lo que llega la animación, el cuerpo avanzará lo que falte
func _cc_extra(alcance: float) -> float:
	var b := cc_blanco(alcance + CC_ACERCA)
	if b.is_empty():
		return 0.0
	return clampf(float(b[0]) - alcance + 0.4, 0.0, CC_ACERCA)


## la animación de la acción en curso (Animador): avance del cuerpo y fin
func _cc_paso(dt: float) -> void:
	var now := ahora()
	_cc_seguir_miembros(dt)
	# (sin arma, después de un puñetazo se queda un momento en guardia: los puños no bajan entre golpe y golpe)
	cc.guardia = (J.aiming or (equipado == "" and now - _puno_t < 1.3)) and cc_clase() in ["manos", "corta", "larga"] and cc_puede()
	cc.bloqueo = J.aiming and _cc_espacio and cc_puede() and now >= _cc_roto_t and cc.accion == null \
		and now - last_melee > 0.3 and (J.stamina > 0.5 or J.estamina_infinita)
	if not cc.bloqueo and not _cc_espacio:
		cc.bloqueo_t0 = -9.0
	var ac = cc.accion
	if ac != null:
		var u := (now - float(ac.t0)) / float(ac.dur)
		if u >= 1.0 or not cc_puede(ac.tipo == "patada" or ac.tipo == "pisoton"):
			cc.accion = null
			# puñetazo pedido mientras daba el anterior: sale ya (combinación)
			if ac.tipo == "puno" and now - _puno_pedido < 0.4:
				_puno_pedido = -9.0
				last_melee = -9.0
				punetazo()
		else:
			# el cuerpo avanza lo que diga la animación (medio paso al empujar, la cadera al patear)
			var a: Dictionary = cc_anim(ac)
			var c: Dictionary = a.canales
			if c.has("avance"):
				# (más avance si el blanco está algo más lejos: el extra se reparte hasta el impacto)
				var av := CombateCC._abierta(c.avance, u) + float(ac.extra) * Rbx.smooth(u / maxf(0.05, float(a.golpe)))
				var dv := av - float(ac.avance_prev)
				ac.avance_prev = av
				if dv > 0.0:
					# (se fija la velocidad hacia delante, no se acumula: J.empuje se gasta y se apaga cada fotograma)
					var lk := Rbx.flat(Rbx.look(J.root_cf())).normalized()
					J.empuje += lk * (dv / maxf(dt, 1e-3) - J.empuje.dot(lk))
	impacto.paso(now)
	# impactos: desde un poco antes del momento del golpe hasta un poco después, en cuanto el pie / la mano toca
	for g in cc_golpes.duplicate():
		var ventana := 0.16
		if now >= float(g[0]) - 0.05:
			var sigue: bool = cc.accion != null and cc.accion.tipo == g[1]
			if not sigue:
				cc_golpes.erase(g)
			elif _cc_resolver(g[1], g[2]) or now >= float(g[0]) + ventana:
				cc_golpes.erase(g)


## blancos delante (zombis y muñecos): [distancia, nodo], el más cercano primero; nunca a través de paredes
## (2026-11-08, 8) también los que están en el suelo, vivos o MUERTOS (cadáveres: se les puede pegar y pisar, el
## ragdoll se sacude). Con uno tumbado la distancia es a la pieza suya más cercana (no al pecho: tumbado, el cuerpo
## mide ~5 studs y muchas veces se tiene delante las piernas).
func _cc_blancos(alcance: float) -> Array:
	var root := J.root_cf()
	var look := Rbx.flat(Rbx.look(root)).normalized()
	var pecho := root.origin + Vector3(0, 1.0, 0)
	var res := []
	for man in J.get_tree().get_nodes_in_group("objetivos"):
		if not is_instance_valid(man) or man.is_queued_for_deletion():
			continue
		var de_pie: bool = man.vivo() and man.en_pie()
		var punto: Vector3 = man.centro()
		if not de_pie:
			var md := INF
			for pn in ["Head", "UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]:
				var nd: Node3D = man.rig.P.get(pn)
				if nd:
					var dd := Rbx.flat(nd.global_position - root.origin).length()
					if dd < md:
						md = dd
						punto = nd.global_position
		var off: Vector3 = punto - root.origin
		var flat := Rbx.flat(off)
		if flat.length() < alcance and absf(off.y) < 5.0 and (flat.length() < 1.6 or flat.normalized().dot(look) > CC_CONO):
			if not J.raycast(pecho, punto + Vector3(0, 0.6, 0) - pecho).is_empty():
				continue
			res.append([flat.length(), man])
	res.sort_custom(func(a, b): return a[0] < b[0])
	return res


## (2026-11-08, 9: "si vienen en grupo el personaje se confunde y pega al suelo") EL blanco de una acción: primero los
## que están DE PIE (son los que atacan); uno del suelo solo si no hay nadie de pie a tiro, o si se mira claramente
## hacia abajo (la cámara apunta al suelo: así se puede rematar a uno caído aunque haya otros cerca).
## [distancia, nodo] o [] si no hay nadie.
const CC_MIRA_SUELO := -0.45      # componente vertical de la mirada de la cámara a partir de la cual se busca el suelo
func cc_blanco(alcance: float) -> Array:
	var todos := _cc_blancos(alcance)
	if todos.is_empty():
		return []
	var de_pie := todos.filter(func(b): return b[1].vivo() and b[1].en_pie())
	var caidos := todos.filter(func(b): return not (b[1].vivo() and b[1].en_pie()))
	var mira_abajo := J.camara != null and Rbx.look(J.camara.global_transform).y < CC_MIRA_SUELO
	if mira_abajo and not caidos.is_empty():
		return caidos[0]
	if not de_pie.is_empty():
		return de_pie[0]
	return caidos[0]


func _cc_resolver(tipo: String, d: Dictionary) -> bool:
	if tipo == "golpe":
		# golpe con arma blanca de los nuevos (CombateCC.GOLPES): el daño, como el de siempre
		if equipado == d.arma:
			return _resolver_golpe(d.arma)
		return true
	return _cc_impacto(tipo, d)


## ---- IMPACTO CON FÍSICA (2026-11-08, 3: "que la patada y el empujón tengan física real al impactar")
## Solo hay impacto si el pie / la mano que golpea LLEGA al cuerpo del otro (a una de sus piezas). Lo que le pasa sale
## de la cantidad de movimiento: Δv = parte de la masa del jugador que va en el golpe · (velocidad del pie o la mano +
## lo que el otro venía hacia él) / masa del otro. Con eso se echa hacia atrás y retrocede (empujar: frena solo), y
## puede perder el equilibrio y caer (más cuanto más fuerte, más abajo le den y si ya iba tambaleándose); al caer, el
## ragdoll sale con ese mismo impulso desde la pieza golpeada. El jugador nota un poco el retroceso.
const CC_MASA_JUGADOR := 80.0
const CC_MASA_BLANCO := 70.0
# parte de la masa del jugador que va en el golpe (el empujón lleva el peso del cuerpo; la patada, la pierna y la
# cadera; el puñetazo, el brazo y algo de hombro) y velocidad máxima real de la mano / el pie (studs/s: empujón ~4 m/s,
# patada ~10 m/s, puñetazo ~9 m/s; la animación es más rápida que eso en el último instante)
const CC_MASA_GOLPE := {"empujon": 0.55, "empujon_arma": 0.6, "patada": 0.34, "puno": 0.1, "pisoton": 0.8}
const CC_VEL_MAX := {"empujon": 14.0, "empujon_arma": 15.0, "patada": 32.0, "puno": 28.0, "pisoton": 24.0}
# cuánto tiempo va tambaleándose hacia atrás a esa velocidad antes de recuperar los pies (distancia = Δv · esto)
const CC_TROPIEZO := {"empujon": 0.3, "empujon_arma": 0.32, "patada": 0.42, "puno": 0.22}
const CC_FRENADO := 6.0           # lo que frenan solos los zombis y los muñecos al ser empujados (1/s)
const CC_CAIDA_UMBRAL := 5.0      # studs/s de Δv por debajo de los cuales no se cae nunca
const CC_CAIDA_RANGO := 15.0      # cuánto más hace falta para la probabilidad máxima
const CC_CAIDA_MAX := 0.8
const CC_ALTURA_CAIDA := {"Head": 0.7, "UpperTorso": 0.9, "LowerTorso": 1.0, "LeftUpperLeg": 1.3, "RightUpperLeg": 1.3,
	"LeftLowerLeg": 1.4, "RightLowerLeg": 1.4}
const CC_MIEMBROS := ["RightHand", "LeftHand", "RightFoot", "LeftFoot"]
var _cc_miembro := {}             # pieza -> {pos, vels: [[hora, v]]}
var _cc_desequilibrio := {}       # id del blanco -> hasta cuándo va tambaleándose (un segundo empujón lo tira antes)
var cc_ultimo_impacto := {}       # (para las pruebas)


func _cc_seguir_miembros(dt: float) -> void:
	var now := ahora()
	for n in CC_MIEMBROS:
		var nd: Node3D = J.rig.P.get(n)
		if nd == null:
			continue
		var p := nd.global_position
		var m: Dictionary = _cc_miembro.get(n, {"pos": p, "vels": []})
		var v: Vector3 = (p - (m.pos as Vector3)) / maxf(dt, 1e-3)
		m.pos = p
		var vs: Array = m.vels
		vs.append([now, v])
		while vs.size() > 0 and now - float(vs[0][0]) > 0.14:
			vs.pop_front()
		_cc_miembro[n] = m


## velocidad del miembro hacia delante (lo más rápido de lo que lleva recorrido en el último instante)
func _cc_vel_miembro(n: String, dir: Vector3) -> float:
	var mx := 0.0
	for e in (_cc_miembro.get(n, {}).get("vels", []) as Array):
		mx = maxf(mx, (e[1] as Vector3).dot(dir))
	return mx


func _cc_impacto(tipo: String, d: Dictionary) -> bool:
	var look := Rbx.flat(Rbx.look(J.root_cf())).normalized()
	# qué golpea: el pie de la patada; si no, la mano (o el arma) más adelantada
	var miembros: Array = []
	if tipo == "patada" or tipo == "pisoton":
		miembros = ["LeftFoot" if str(d.get("lado", "R")) == "L" else "RightFoot"]
	elif tipo == "puno":
		miembros = ["LeftHand" if d.get("lado") == "L" else "RightHand"]
	else:
		miembros = ["RightHand", "LeftHand"]
	var origen := J.root_cf().origin
	var mejor := ""
	var mejor_d := -INF
	for n in miembros:
		var nd: Node3D = J.rig.P.get(n)
		if nd and (nd.global_position - origen).dot(look) > mejor_d:
			mejor_d = (nd.global_position - origen).dot(look)
			mejor = n
	if mejor == "":
		return false
	var punto: Vector3 = (J.rig.P[mejor] as Node3D).global_position
	if modelo_mano and tipo == "empujon" and cc_clase() in ["larga", "fuego_larga"]:
		punto = modelo_mano.global_position.lerp(punto, 0.5)
	# ¿llega al cuerpo de alguien? (la pieza más cercana al punto de contacto)
	var man = null
	var pieza := ""
	# contacto de verdad: la distancia del pie / la mano a la caja de cada pieza (radio del pie o del puño + margen)
	var dist := 0.6 if tipo == "pisoton" else (0.55 if tipo == "patada" else (0.24 if tipo == "puno" else 0.45))
	var al_suelo: bool = tipo == "pisoton" or impacto.va_al_suelo()
	for b in _cc_blancos(float(d.get("alcance", CC_PATADA.alcance)) + 1.5):
		var o = b[1]
		if not al_suelo and not (o.vivo() and o.en_pie()):
			continue # (con zombis de pie delante, los cuerpos del suelo no "paran" el golpe)
		for pn in o.rig.P:
			# (los brazos del otro no cuentan: se le da en el cuerpo, las piernas o la cabeza)
			if pn == "HumanoidRootPart" or "Arm" in pn or "Hand" in pn:
				continue
			var nd: Node3D = o.rig.P[pn]
			var sz: Vector3 = nd.get_meta("size", Vector3.ONE)
			var lp: Vector3 = nd.global_transform.affine_inverse() * punto
			var fuera := Vector3(maxf(absf(lp.x) - sz.x * 0.5, 0.0), maxf(absf(lp.y) - sz.y * 0.5, 0.0), maxf(absf(lp.z) - sz.z * 0.5, 0.0))
			var dd := fuera.length()
			if dd < dist:
				dist = dd
				man = o
				pieza = pn
	if man == null:
		return false
	# Δv por la cantidad de movimiento
	# (el pisotón va hacia abajo; lo demás, hacia delante)
	var dir_g := Vector3.DOWN if tipo == "pisoton" else look
	var v_golpe := maxf(_cc_vel_miembro(mejor, dir_g), 0.0) + maxf(Rbx.flat(J.vel_real).dot(look), 0.0) * 0.5
	var v_suya := 0.0
	var vb = man.get("velocity")
	if vb == null:
		vb = man.get("_vel")
	if vb is Vector3:
		v_suya = maxf(-(vb as Vector3).dot(look), 0.0)
	var clave := "empujon_arma" if (tipo == "empujon" and float(d.get("danio", 0.0)) > 0.0) else tipo
	v_golpe = minf(v_golpe, float(CC_VEL_MAX.get(clave, 20.0)))
	var dv := clampf(float(CC_MASA_GOLPE.get(clave, 0.3)) * CC_MASA_JUGADOR * (v_golpe + v_suya) / CC_MASA_BLANCO, 0.0, 20.0)
	var ppos: Vector3 = (man.rig.P[pieza] as Node3D).global_position
	# la sensación del golpe: parón, el miembro se detiene y rebota, la pieza se hunde, cámara (ImpactoCC)
	var dir_imp := (look * 0.35 + Vector3.DOWN).normalized() if tipo == "pisoton" else look
	impacto.golpe(tipo, man, pieza, punto, dv, dir_imp)
	Ruido.emitir(J, ppos, C.RUIDO.GolpeContundente, Ruido.GOLPE, J)
	var sonido_contacto: String = {"puno": "Punch", "patada": "Kick", "pisoton": "Stomp"}.get(tipo, "BatHit" if clave == "empujon_arma" else "Punch")
	Efectos.sonido(J, sonido_contacto, punto, clampf(0.45 + dv * 0.035, 0.5, 1.15))
	# retroceso para el jugador (empujar a alguien también te echa un poco atrás)
	J.empuje -= look * minf(dv * CC_MASA_BLANCO / CC_MASA_JUGADOR * 0.12, 2.5)
	# daño (patadas, puñetazos, empujón con el arma)
	var danio := float(d.get("danio", 0.0))
	if tipo == "pisoton" and pieza == "Head":
		danio *= float(CC_PISOTON.cabeza)
	if danio > 0.0:
		# (al que está en el suelo, el golpe sacude su cuerpo desde la pieza: hacia abajo si es un pisotón)
		var killed: bool = man.recibir_danio(danio, pieza, dir_imp * dv * (4.0 if not man.en_pie() else 1.0))
		_confirmar(killed, false)
		if killed:
			cc_ultimo_impacto = {"tipo": tipo, "dv": dv, "pieza": pieza, "cae": false, "muere": true, "danio": danio, "t": ahora()}
			return true
	if not man.en_pie():
		cc_ultimo_impacto = {"tipo": tipo, "dv": dv, "pieza": pieza, "cae": false, "suelo": true, "danio": danio, "t": ahora()}
		return true
	# ¿pierde el equilibrio?
	var id: int = man.get_instance_id()
	var now := ahora()
	var tambaleando: bool = now < float(_cc_desequilibrio.get(id, -9.0))
	var p_caer := clampf((dv - CC_CAIDA_UMBRAL) / CC_CAIDA_RANGO, 0.0, 1.0) * CC_CAIDA_MAX * float(CC_ALTURA_CAIDA.get(pieza, 1.0))
	if tipo == "patada":
		p_caer *= float(d.get("derribo", 0.3)) / 0.3
	if tambaleando:
		p_caer += 0.3
	p_caer = clampf(p_caer, 0.0, 0.9)
	var cae := randf() < p_caer
	if cae:
		# cae con el impulso del golpe (el ragdoll sale desde la pieza golpeada)
		man.derribar((look * dv + Vector3(0, 1.5 + dv * 0.08, 0)) / 0.3, 1.6 + dv * 0.03)
		_cc_desequilibrio.erase(id)
	else:
		# se echa hacia atrás y retrocede tambaleándose (lo que dure depende de lo fuerte que haya sido)
		var tambaleo := 0.35 + dv * 0.06
		man.empujar(look * dv * float(CC_TROPIEZO.get(clave, 0.3)) * CC_FRENADO, tambaleo)
		_cc_desequilibrio[id] = now + tambaleo + 0.6
	cc_ultimo_impacto = {"tipo": tipo, "dv": dv, "pieza": pieza, "cae": cae, "p": p_caer, "v_golpe": v_golpe, "t": now}
	return true


## lo llama Jugador.recibir_danio: ¿para el golpe? Devuelve la parte del daño que pasa (1 = no bloquea)
func cc_bloquear(cantidad: float, desde: Vector3) -> float:
	if not cc.bloqueo or desde == Vector3.ZERO:
		return 1.0
	var a_mi := Rbx.flat(desde - J.global_position)
	if a_mi.length() > 0.01 and a_mi.normalized().dot(Rbx.flat(Rbx.look(J.root_cf())).normalized()) < 0.2:
		return 1.0 # por detrás o de lado no se para
	var now := ahora()
	var atacante = _cc_atacante(desde)
	if now - float(cc.bloqueo_t0) <= CC_PARADA:
		# PARADA: a tiempo, no pasa nada y el zombi se queda vendido
		J.notify("¡Parada!")
		Efectos.sonido(J, "Block", J.global_position + Vector3(0, 1.5, 0), 0.9, 1.25)
		if atacante != null:
			atacante.empujar(-a_mi.normalized() * 26.0, 1.4)
		cc.bloqueo_t0 = -9.0
		return 0.0
	var gasto := cantidad * CC_BLOQUEO_GASTO
	if J.stamina < gasto and not J.estamina_infinita:
		# sin fuerza para aguantarlo: la guardia se rompe
		J.stamina = 0.0
		_cc_roto_t = now + 1.2
		J.notify("Guardia rota")
		return 0.75
	if not J.estamina_infinita:
		J.stamina -= gasto
	Efectos.sonido(J, "Block", J.global_position + Vector3(0, 1.5, 0), 0.7, 0.9)
	return CC_BLOQUEO_DANIO


func _cc_atacante(desde: Vector3):
	var mejor = null
	var md := 1.5
	for man in J.get_tree().get_nodes_in_group("objetivos"):
		var dd: float = Rbx.flat((man as Node3D).global_position - desde).length()
		if dd < md:
			md = dd
			mejor = man
	return mejor


## ---------------------------------------------------------------- cada fotograma
func actualizar(dt: float) -> void:
	var now := ahora()
	if _golpe_tras_frenar != "":
		if now > _golpe_caduca or J.health <= 0 or J.ragdoll != null or J.moto != null:
			_golpe_tras_frenar = ""
		else:
			J._frenar_combate_hasta = now + 0.25
			if not J.L.sprinting and Rbx.flat(J.vel_real).length() <= C.PLAYER.WalkSpeed * 1.1:
				var pedido := _golpe_tras_frenar
				_golpe_tras_frenar = ""
				if pedido == "arma": melee()
				else: punetazo()
	_cc_paso(dt)
	if recogiendo != null:
		_paso_recoger()
	# terminar de guardar el arma y sacar la siguiente
	if switching != null and now - float(switching.t0) >= Armas.HOLSTER_TIME:
		var nt: String = switching.next
		switching = null
		J.L.holster = null
		recargando = 0.0
		_equipar("")
		if nt != "" and J.health > 0 and arma_en_hueco(_hueco_de(nt)) == nt and not (J.stance == 2 and Armas.es_larga_blanca(nt)):
			_equipar(nt)
	if recargando > 0.0 and now >= recargando:
		_terminar_recarga()
	# golpes que llegan
	for g in golpes_pendientes.duplicate():
		# acometida: el cuerpo da un paso hacia delante justo antes del impacto
		if not g[2] and now >= g[0] - 0.09:
			g[2] = true
			# (en la moto no hay paso adelante)
			# (2026-11-08, 2: la mitad, "que el dash no sea tan agresivo")
			var fuerza := {"Cuchillo": 4.5, "Machete": 4.0, "Bate": 3.0, "Hacha": 3.5, "Palanca": 3.8}.get(g[1], 3.0) as float
			if J.moto == null:
				J.empuje += Rbx.look(J.root_cf()) * fuerza
		if now >= g[0]:
			golpes_pendientes.erase(g)
			if equipado == g[1]:
				_resolver_golpe(g[1])
	var w := cfg()
	var moving := J.move_direction.length() > 0.1
	# arma apoyada: se suelta al moverse, cambiar de postura o de arma, caer...
	if rest != null:
		if w.is_empty() or w.Kind != "Gun" or moving or J.moto != null or J.stance != rest.stance or J.vaulting != null or (J.stance == 2 and J.supine) \
				or J.L.knocked or switching != null or not J.en_suelo:
			end_rest()
		else:
			J.aiming = true
			# el apoyo sigue ahí
			if not rest.ground and now - float(rest.get("checkT", 0.0)) > 0.4:
				rest.checkT = now
				var r2 = find_rest()
				if r2 != null:
					rest.top = r2.top
					rest.point = r2.point
					rest.gap += (r2.gap - rest.gap) * 0.5
				elif now - float(rest.t0) > 0.5:
					end_rest()
	# (la cámara baja con el cuerpo: el Animador lo agacha lo justo para que el arma quede encima del apoyo)
	# (también apuntando junto a una barrera: el cuerpo se incorpora para pasar el arma por encima)
	var baja_c: float = anim.rest_baja if anim != null else 0.0
	J.rest_lower_cur += (baja_c - J.rest_lower_cur) * minf(1.0, dt * 6.0)
	# ¿hay dónde apoyar el arma? (solo al apuntar con un arma de fuego, para el aviso)
	if rest == null and J.aiming and now - rest_scan_t > 0.2:
		rest_scan_t = now
		rest_avail = find_rest() if not moving else null
		apoyo_delante = buscar_apoyo_horizontal() if not moving else null
	elif not J.aiming:
		rest_avail = null
		apoyo_delante = null
	J.L.rested = rest != null
	J.L.restGap = rest.gap if (rest != null and not rest.ground) else null

	# disparo automático
	if J.firing and not w.is_empty() and w.Kind == "Gun" and w.Auto:
		shoot()
	# disparo pendiente: el arma se está alineando con la mira (si tarda demasiado, se cancela)
	if pending_shot != null:
		if now - float(pending_shot) > (0.75 if J.moto != null else 0.35) or w.is_empty() or w.Kind != "Gun":
			pending_shot = null
		elif not (J.firing and w.Auto):
			shoot()
	aim_blocked = false
	if not w.is_empty() and w.Kind == "Gun" and (J.aiming or J.firing or pending_shot != null):
		var ac := aim_check()
		aim_blocked = not ac[0] and ac[1] != "cambio" # (pasar el arma de mano es un instante: sin mira roja)
		aim_block_reason = ac[1]
	spread_bloom = maxf(0.0, spread_bloom - dt * (2.0 if J.firing else 7.0))
	# armas en el suelo: aviso al acercarse
	var pies := J.global_position - Vector3(0, J.center_cur, 0)
	for s in suelo:
		(s.etiqueta as Label3D).visible = ((s.nodo as Node3D).global_position - pies).length() < 9.0
	_actualizar_hud()


## ---------------------------------------------------------------- HUD de armas
const MIRA_TELE_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 px = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (SCREEN_UV - 0.5) * px / px.y; // coordenadas con el alto = 1
	float r = length(p);
	float borde = smoothstep(0.43, 0.445, r);
	vec4 c = vec4(0.0, 0.0, 0.0, borde);
	// retícula: líneas finas, gruesas lejos del centro, y puntos cada 0.04
	float fino = 0.0012;
	float grueso = 0.004;
	float lx = abs(p.y) < (abs(p.x) > 0.12 ? grueso : fino) ? 1.0 : 0.0;
	float ly = abs(p.x) < (abs(p.y) > 0.12 ? grueso : fino) ? 1.0 : 0.0;
	float puntos = 0.0;
	if (abs(p.y) < 0.004 && abs(fract(p.x / 0.04 + 0.5) - 0.5) < 0.08 && abs(p.x) > 0.01 && abs(p.x) < 0.12) puntos = 1.0;
	if (abs(p.x) < 0.004 && abs(fract(p.y / 0.04 + 0.5) - 0.5) < 0.08 && abs(p.y) > 0.01 && abs(p.y) < 0.12) puntos = 1.0;
	float ret = max(max(lx, ly), puntos) * (1.0 - borde);
	// viñeta suave dentro del círculo
	float vig = smoothstep(0.28, 0.43, r) * 0.45;
	c = mix(vec4(0.0, 0.0, 0.0, vig), vec4(0.0, 0.0, 0.0, 1.0), max(borde, ret));
	COLOR = c;
}
"""


## círculo rojo del HUD: pegado a una estructura (pared, esquina, muro) el cañón no da donde marca la
## mira: marca el punto donde daría la bala. Solo si lo que tapa el cañón está a menos de CIRCULO_CERCA
const CIRCULO_CERCA := 3.0   # studs
const CIRCULO_PX := 12.0     # tamaño del círculo
const CIRCULO_MIN_PX := 28.0 # solo si en pantalla se separa al menos esto de la mira
func _actualizar_circulo(gun: bool) -> void:
	var circ: Panel = _hud.impacto
	circ.visible = false
	if not gun or modelo_mano == null or not modelo_mano.has_node("Muzzle") or not modelo_mano.visible:
		return
	if recargando > 0.0 or switching != null or ahora() < draw_until or J.colgado != null or rest != null or J.mira_tele:
		return
	var sb := salida_bala()
	var imp: Dictionary = sb[2]
	if imp.is_empty():
		# solo pegado a una estructura: lo que tapa el cañón tiene que estar muy cerca
		imp = _rayo_bala(sb[0], sb[1], CIRCULO_CERCA)
	if imp.is_empty():
		return
	# un muñeco o un zombi no es una estructura
	var col: Object = imp.get("collider")
	if col != null and col.has_meta("objetivo"):
		return
	var p: Vector3 = imp.position
	if J.camara.is_position_behind(p):
		return
	# solo si en pantalla no coincide con la mira (al centro)
	var sp := J.camara.unproject_position(p)
	var centro := J.camara.get_viewport().get_visible_rect().size * 0.5
	if sp.distance_to(centro) < CIRCULO_MIN_PX:
		return
	circ.visible = true
	circ.position = sp - circ.size * 0.5


## la interfaz nunca recibe el ratón (no debe bloquear la cámara ni los clics)
static func _ignorar_raton(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignorar_raton(c)


func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	# mira: 4 trazos que se abren con la dispersión
	var mira := Control.new()
	mira.anchor_left = 0.5
	mira.anchor_top = 0.5
	mira.anchor_right = 0.5
	mira.anchor_bottom = 0.5
	capa.add_child(mira)
	_hud.mira = mira
	var punto := ColorRect.new()
	punto.size = Vector2(3, 3)
	punto.position = Vector2(-1.5, -1.5)
	punto.color = Color(1, 1, 1, 0.85)
	mira.add_child(punto)
	_hud.lineas = []
	for i in 4:
		var l := ColorRect.new()
		l.size = Vector2(2, 9) if i < 2 else Vector2(9, 2)
		mira.add_child(l)
		_hud.lineas.append(l)
	_hud.hit = []
	for i in 4:
		var h := ColorRect.new()
		h.size = Vector2(9, 2)
		h.pivot_offset = Vector2(4.5, 1)
		h.rotation = deg_to_rad(45 + 90 * i)
		var ang := deg_to_rad(45 + 90 * i)
		h.position = Vector2(cos(ang), sin(ang)) * 11 - Vector2(4.5, 1)
		mira.add_child(h)
		_hud.hit.append(h)
	var bx := Label.new()
	bx.text = "✕"
	bx.add_theme_font_size_override("font_size", 26)
	bx.add_theme_color_override("font_color", Color8(230, 60, 50))
	bx.position = Vector2(-9, -19)
	mira.add_child(bx)
	_hud.bloqueo = bx
	# círculo rojo: dónde va a dar de verdad la bala cuando no es donde marca la mira (pared, esquina)
	var circ := Panel.new()
	var sbx := StyleBoxFlat.new()
	sbx.bg_color = Color(0, 0, 0, 0)
	sbx.border_color = Color8(235, 50, 40)
	sbx.set_border_width_all(2)
	sbx.set_corner_radius_all(int(CIRCULO_PX * 0.5))
	circ.add_theme_stylebox_override("panel", sbx)
	circ.size = Vector2(CIRCULO_PX, CIRCULO_PX)
	circ.visible = false
	capa.add_child(circ)
	_hud.impacto = circ
	# mira telescópica: círculo negro alrededor, retícula con puntos (shader, sin texturas)
	var tele := ColorRect.new()
	tele.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MIRA_TELE_SHADER
	sm.shader = sh
	tele.material = sm
	tele.visible = false
	capa.add_child(tele)
	capa.move_child(tele, 0)
	_hud.tele = tele
	# panel del arma (abajo a la derecha)
	var panel := VBoxContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -300
	panel.offset_top = -150
	panel.offset_right = -28
	panel.offset_bottom = -44
	panel.alignment = BoxContainer.ALIGNMENT_END
	capa.add_child(panel)
	var nom := Label.new()
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nom.add_theme_font_size_override("font_size", 16)
	nom.modulate = Color(1, 1, 1, 0.9)
	Jugador._contorno(nom, 5)
	panel.add_child(nom)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(fila)
	var mag := Label.new()
	mag.add_theme_font_size_override("font_size", 40)
	Jugador._contorno(mag, 8)
	fila.add_child(mag)
	var res := Label.new()
	res.add_theme_font_size_override("font_size", 22)
	res.modulate = Color(1, 1, 1, 0.9)
	Jugador._contorno(res, 6)
	fila.add_child(res)
	var rec := Label.new()
	rec.text = "RECARGANDO…"
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rec.add_theme_color_override("font_color", Color8(240, 200, 90))
	Jugador._contorno(rec, 5)
	panel.add_child(rec)
	_hud.panel = panel
	_hud.nombre = nom
	_hud.mag = mag
	_hud.res = res
	_hud.rec = rec
	# aviso de apoyar el arma
	var rh := Label.new()
	rh.anchor_left = 0.5
	rh.anchor_right = 0.5
	rh.anchor_top = 0.5
	rh.offset_left = -200
	rh.offset_right = 200
	rh.offset_top = 40
	rh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rh.add_theme_font_size_override("font_size", 15)
	Jugador._contorno(rh, 5)
	capa.add_child(rh)
	_hud.rest = rh
	# huecos de arma (abajo a la derecha, encima del panel del arma). Solo se ven un momento al cambiar o coger
	# un arma (antes estaban siempre en el centro, tapando los pies del personaje)
	var barra := HBoxContainer.new()
	barra.anchor_left = 1.0
	barra.anchor_right = 1.0
	barra.anchor_top = 1.0
	barra.anchor_bottom = 1.0
	barra.offset_left = -560
	barra.offset_right = -28
	barra.offset_top = -190
	barra.offset_bottom = -160
	barra.alignment = BoxContainer.ALIGNMENT_END
	barra.add_theme_constant_override("separation", 6)
	capa.add_child(barra)
	_hud.barra = barra
	_hud.huecos = []
	for i in Armas.SLOTS.size():
		var caja := PanelContainer.new()
		caja.custom_minimum_size = Vector2(124, 30)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.45)
		sb.set_corner_radius_all(4)
		sb.border_color = Color8(230, 200, 120)
		caja.add_theme_stylebox_override("panel", sb)
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 12)
		Jugador._contorno(lab, 3)
		caja.add_child(lab)
		barra.add_child(caja)
		_hud.huecos.append({"caja": caja, "sb": sb, "lab": lab})
	_ignorar_raton(capa)


var _barra_t := -99.0      # última vez que cambió el arma o el inventario (la barra de huecos se ve un rato)
var _barra_firma := ""


func _actualizar_hud() -> void:
	var w := cfg()
	var vivo := J.health > 0
	# barra de huecos: visible 3 s después de cualquier cambio (o mientras se cambia de arma), luego se desvanece
	var firma := equipado + str(inventario.keys()) + str(switching != null)
	for k in inventario:
		firma += str(inventario[k].name)
	if firma != _barra_firma:
		_barra_firma = firma
		_barra_t = ahora()
	var vis_b := clampf(1.0 - (ahora() - _barra_t - 3.0) / 0.6, 0.0, 1.0)
	(_hud.barra as Control).modulate.a = vis_b
	(_hud.barra as Control).visible = vis_b > 0.01
	_hud.panel.visible = not w.is_empty()
	_hud.rec.visible = recargando > 0.0
	if not w.is_empty():
		_hud.nombre.text = String(w.Tip).to_upper()
		if w.Kind == "Gun":
			var d := datos_equipado()
			_hud.mag.text = str(d.mag)
			_hud.mag.add_theme_color_override("font_color", Color8(220, 80, 60) if d.mag <= int(floor(w.Mag * 0.25)) else Color8(230, 225, 215))
			_hud.res.text = " / ∞" if balas_infinitas else " / " + str(d.reserve)
		else:
			_hud.mag.text = "—"
			_hud.res.text = ""
			_hud.mag.add_theme_color_override("font_color", Color8(230, 225, 215))
	# mira
	var gun: bool = not w.is_empty() and w.Kind == "Gun"
	_hud.mira.visible = vivo
	var gap := 0.0
	if gun:
		var rmul := 1.0
		if rest != null:
			rmul = C.REST.ProneSpread if rest.ground else C.REST.Spread
		gap = 6.0 + ((w.AimSpread if J.aiming else w.HipSpread) + spread_bloom) * 3.2 * rmul
	# arma apoyada: la mira se hace más pequeña (rayitas más cortas y más juntas), poco a poco
	mira_esc = lerpf(mira_esc, 0.55 if (gun and rest != null) else 1.0, 1.0 - exp(-8.0 * get_process_delta_time()))
	gap *= lerpf(1.0, 0.6, (1.0 - mira_esc) / 0.45)
	var lr := 9.0 * mira_esc
	var lin: Array = _hud.lineas
	(lin[0] as ColorRect).size = Vector2(2, lr)
	(lin[1] as ColorRect).size = Vector2(2, lr)
	(lin[2] as ColorRect).size = Vector2(lr, 2)
	(lin[3] as ColorRect).size = Vector2(lr, 2)
	(lin[0] as ColorRect).position = Vector2(-1, -gap - 4 * mira_esc - lr)
	(lin[1] as ColorRect).position = Vector2(-1, gap + 4 * mira_esc)
	(lin[2] as ColorRect).position = Vector2(-gap - 4 * mira_esc - lr, -1)
	(lin[3] as ColorRect).position = Vector2(gap + 4 * mira_esc, -1)
	for l in lin:
		(l as ColorRect).visible = gun
		(l as ColorRect).color = Color(0.9, 0.24, 0.2, 0.4) if aim_blocked else Color(0.94, 0.94, 0.94, 1)
	_hud.bloqueo.visible = gun and aim_blocked
	var tele_on: bool = J.mira_tele and J.cam_fov < 30.0
	(_hud.tele as ColorRect).visible = tele_on
	if tele_on:
		_hud.mira.visible = false
	_actualizar_circulo(gun and vivo)
	var ht := clampf(1.0 - (ahora() - hit_t) / 0.25, 0, 1)
	for h in _hud.hit:
		(h as ColorRect).color = Color(hit_color, ht)
	# apoyar el arma
	if gun and vivo and rest != null:
		_hud.rest.text = "ARMA APOYADA · [X] soltar"
		_hud.rest.add_theme_color_override("font_color", Color8(150, 230, 140))
	elif gun and vivo and rest_avail != null:
		_hud.rest.text = "[X] apoyar el arma"
		_hud.rest.add_theme_color_override("font_color", Color8(235, 235, 235))
	else:
		_hud.rest.text = ""
	# huecos
	for i in Armas.SLOTS.size():
		var ui: Dictionary = _hud.huecos[i]
		var n := arma_en_hueco(Armas.SLOTS[i].Id)
		(ui.lab as Label).text = "%d  %s" % [i + 1, Armas.WEAPONS[n].Tip if n != "" else "—"]
		var activa := n != "" and n == equipado
		(ui.sb as StyleBoxFlat).set_border_width_all(2 if activa else 0)
		(ui.sb as StyleBoxFlat).bg_color = Color(0, 0, 0, 0.7 if activa else 0.4)
		(ui.lab as Label).modulate = Color8(230, 225, 215) if n != "" else Color8(110, 105, 100)
