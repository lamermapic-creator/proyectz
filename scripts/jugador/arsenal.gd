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
	Efectos.sonido(J, "Reload", J.global_position, 0.9, 1.5 / w.Reload * 1.1)


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
		# en la moto se dispara libre hacia cualquier lado: el torso gira y la bala va a la mira
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
	var pecho: Vector3 = (J.rig.P.UpperTorso as Node3D).global_position
	# ¿la boca del cañón está metida en una pared? Se mira A LO LARGO DEL ARMA (de la empuñadura a la boca),
	# no desde el pecho: con el arma apoyada sobre un muro, la línea pecho-boca rozaba el propio muro y
	# la bala "salía del torso" contra él
	var empu: Vector3 = modelo_mano.global_position
	var dentro := J.raycast(empu, mz_t.origin - empu)
	# el arma aún está subiendo hacia la mira (primer disparo desde la pose baja): la bala va al punto
	# de la mira desde el cañón, en vez de al suelo. Pegado a una pared (arma levantada), donde apunte
	if anim == null or anim.arma_alzada < 0.1:
		var pm := punto_mira()
		var al := pm - mz_t.origin
		if al.length() < 3.0 or al.dot(pm - pecho) < 0.0:
			# blanco PEGADO (un zombi encima): el cañón puede quedar a su lado o dentro de él; la bala va
			# desde el pecho hacia lo que marca la mira
			if (pm - pecho).length() > 0.3:
				return [mz_t.origin, (pm - pecho).normalized(), {}, pecho]
		elif dir.angle_to(al) > deg_to_rad(8):
			dir = al.normalized()
	# el rayo de la bala empieza en la línea del cañón a la altura de la empuñadura, no en la boca: con
	# un zombi pegado, la boca del cañón queda DENTRO de él (el rayo cuenta los blancos desde dentro)
	var atras := maxf(0.0, (mz_t.origin - empu).dot(dir))
	return [mz_t.origin, dir, dentro, mz_t.origin - dir * atras]


## ---------------------------------------------------------------- apoyar el arma (X)
const LADO_ALCANCE := 2.0 # studs: hasta dónde puede estar la pared para apoyar el arma de lado
## Busca delante una superficie a la altura adecuada (muro bajo, barrera, alféizar...). Tumbado: el suelo.
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
	var max_gap: float = C.REST.MaxGapCrouch if J.stance == 1 else C.REST.MaxGapStand
	rest_motivo = ""
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
		var gap := gun_y - (top + 0.26)
		if gap > max_gap:
			rest_motivo = "bajo"
			continue
		if gap < -0.25:
			rest_motivo = "alto"
			continue
		return {"top": top, "point": hit.position, "gap": maxf(0.0, gap), "ground": false}
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
	var cam := J.camara.global_transform
	var look := Rbx.look(cam)
	var origin := cam.origin
	var eje := look
	var forzado := {}
	var desde := origin
	if modelo_mano and modelo_mano.has_node("Muzzle"):
		var sb := salida_bala()
		origin = sb[0]
		eje = sb[1]
		forzado = sb[2]
		desde = sb[3]
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
		var hit_pos := origin + dir * float(w.Range)
		var tipo := "none"
		var normal := Vector3.UP
		if not res.is_empty():
			hit_pos = res.position
			normal = res.normal
			if normal.length() < 0.1: # el rayo empezó dentro (blanco pegado al arma)
				normal = -dir
			tipo = "surface"
			var col: Object = res.collider
			# zonas de impacto de un blanco (maniquí o zombi): ver "contrato de objetivo" en docs/RUIDO_Y_ZOMBIS.md
			if col and col.has_meta("objetivo"):
				tipo = "flesh"
				var obj = col.get_meta("objetivo")
				var pieza: String = res.pieza if res.has("pieza") else col.get_meta("pieza")
				var dmg: float = w.Damage * Maniqui.mult_pieza(pieza, w)
				# caída de daño con la distancia
				if hit_pos.distance_to(origin) > float(w.Range) * 0.5:
					dmg *= 0.75
				if obj.vivo():
					var killed: bool = obj.recibir_danio(dmg, pieza, dir * (45.0 if n_balas == 1 else 12.0))
					acerto = true
					mato = mato or killed
					cabeza = cabeza or pieza == "Head"
			elif impacto_superficie == Vector3.INF:
				impacto_superficie = hit_pos
		# trazadoras: todas las balas; de los perdigones, solo algunas
		if n_balas == 1 or nb % 3 == 0:
			Efectos.tracer(J, mz_t.origin, hit_pos)
		if tipo != "none":
			Efectos.impacto(J, hit_pos, normal, tipo)
		if not forzado.is_empty():
			break
	if acerto:
		_confirmar(mato, cabeza)

	# efectos
	Efectos.sonido(J, w.Sound, J.global_position, 1.3, 0.95 + randf() * 0.1)
	Efectos.muzzle_flash(J, mz_t)
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
func melee() -> void:
	if recogiendo != null:
		return
	var w := cfg()
	if w.is_empty() or w.Kind != "Melee" or J.health <= 0 or J.vaulting != null or J.ragdoll != null or J.L.gettingUp:
		return
	if switching != null or ahora() < draw_until:
		return
	var now := ahora()
	if now - last_melee < w.Cooldown:
		return
	if J.stamina < w.Stamina * 0.5 and not J.estamina_infinita:
		J.notify("Estás agotado")
		return
	last_melee = now
	J.stamina = maxf(0.0, J.stamina - w.Stamina)
	Efectos.sonido(J, "Swing", J.global_position, 0.8, 0.9 + randf() * 0.2)
	Ruido.emitir(J, J.global_position, C.RUIDO.GolpeAire, Ruido.GOLPE, J)
	anim.on_melee(equipado)
	# el impacto llega en el punto de golpe de la animación
	# (en la moto el golpe llega antes: a esa velocidad el blanco se queda atrás enseguida)
	golpes_pendientes.append([now + float(w.get("HitTime", 0.26)) * (0.6 if J.moto != null else 1.0), equipado, false])
	J.shake = minf(1.0, J.shake + 0.15)


func _resolver_golpe(arma: String) -> void:
	var w: Dictionary = Armas.WEAPONS[arma]
	var root := J.root_cf()
	var look := Rbx.look(root)
	var hits := []
	var pecho := root.origin + Vector3(0, 1.2, 0)
	var alcance := float(w.Range)
	var bonus := 1.0
	if J.moto != null:
		# en la moto: se golpea hacia donde mira la cámara, con un poco más de alcance, y la velocidad
		# de la moto se suma al golpe
		var lc := Rbx.flat(Rbx.look(J.camara.global_transform))
		if lc.length() > 0.1:
			look = lc.normalized()
		alcance += 1.6
		bonus = 1.0 + clampf(absf(J.moto.velocidad()) / 60.0, 0.0, 0.7)
		root = Transform3D(root.basis, root.origin - Vector3(0, 1.0, 0))
	# blancos: maniquíes y zombis (grupo "objetivos", ver "contrato de objetivo" en docs/RUIDO_Y_ZOMBIS.md)
	for man in J.get_tree().get_nodes_in_group("objetivos"):
		if not man.vivo():
			continue
		var off: Vector3 = man.centro() - root.origin
		var flat := Vector3(off.x, 0, off.z)
		var cono := 0.0 if J.moto != null else 0.35 # (en la moto, también lo que ya está a tu lado)
		if flat.length() < alcance and absf(off.y) < 5 and (flat.length() < 2 or flat.normalized().dot(look) > cono):
			# nada de golpear a través de paredes (AUDITORIA.md §7.1)
			if not J.raycast(pecho, man.centro() - pecho).is_empty():
				continue
			hits.append([flat.length(), man])
	hits.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(2, hits.size()):
		var man = hits[i][1]
		var crit := randf() < 0.25
		var dmg: float = w.Damage * (w.HeadMult if crit else 1.0) * (0.5 if i == 1 else 1.0) * bonus
		var pieza := "Head" if crit else "UpperTorso"
		var ppos: Vector3 = (man.rig.P[pieza] as Node3D).global_position
		var killed: bool = man.recibir_danio(dmg, pieza, look * float(w.Knockback))
		var contundente: bool = str(w.get("Sound", "Flesh")) == "Blunt"
		Ruido.emitir(J, ppos, C.RUIDO.GolpeContundente if contundente else C.RUIDO.GolpeCarne, Ruido.GOLPE, J)
		_confirmar(killed, crit)
		if not killed and man.en_pie():
			var p_derribo := float(w.get("Derriba", 0.0))
			if p_derribo > 0.0 and (crit or randf() < p_derribo):
				# batazo: lo derriba y luego se levanta
				man.derribar(look * 38 + Vector3(0, 12, 0), 2.2)
			else:
				man.empujar(look * float(w.Knockback) * 0.8, float(w.get("Stagger", 0.45)))
		Efectos.blood_at(J, ppos, -look)
		Efectos.sonido(J, "Blunt" if contundente else "Flesh", ppos, 1.1, 0.9 + randf() * 0.2)


## ---------------------------------------------------------------- cada fotograma
func actualizar(dt: float) -> void:
	var now := ahora()
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
			var fuerza := {"Cuchillo": 9.0, "Machete": 8.0, "Bate": 6.0, "Hacha": 7.0, "Palanca": 7.5}.get(g[1], 6.0) as float
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
	J.rest_lower_cur += ((rest.gap if rest != null else 0.0) - J.rest_lower_cur) * minf(1.0, dt * 6.0)
	# ¿hay dónde apoyar el arma? (solo al apuntar con un arma de fuego, para el aviso)
	if rest == null and J.aiming and now - rest_scan_t > 0.2:
		rest_scan_t = now
		rest_avail = find_rest() if not moving else null
	elif not J.aiming:
		rest_avail = null
	J.L.rested = rest != null
	J.L.restGap = rest.gap if (rest != null and not rest.ground) else null

	# disparo automático
	if J.firing and not w.is_empty() and w.Kind == "Gun" and w.Auto:
		shoot()
	# disparo pendiente: el arma se está alineando con la mira (si tarda demasiado, se cancela)
	if pending_shot != null:
		if now - float(pending_shot) > 0.35 or w.is_empty() or w.Kind != "Gun":
			pending_shot = null
		elif not (J.firing and w.Auto):
			shoot()
	aim_blocked = false
	if not w.is_empty() and w.Kind == "Gun" and (J.aiming or J.firing or pending_shot != null):
		var ac := aim_check()
		aim_blocked = not ac[0]
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
	nom.modulate = Color(1, 1, 1, 0.8)
	panel.add_child(nom)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(fila)
	var mag := Label.new()
	mag.add_theme_font_size_override("font_size", 40)
	fila.add_child(mag)
	var res := Label.new()
	res.add_theme_font_size_override("font_size", 22)
	res.modulate = Color(1, 1, 1, 0.75)
	fila.add_child(res)
	var rec := Label.new()
	rec.text = "RECARGANDO…"
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rec.add_theme_color_override("font_color", Color8(240, 200, 90))
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
	capa.add_child(rh)
	_hud.rest = rh
	# huecos de arma (abajo, centrados)
	var barra := HBoxContainer.new()
	barra.anchor_left = 0.5
	barra.anchor_right = 0.5
	barra.anchor_top = 1.0
	barra.anchor_bottom = 1.0
	barra.offset_left = -330
	barra.offset_right = 330
	barra.offset_top = -92
	barra.offset_bottom = -50
	barra.alignment = BoxContainer.ALIGNMENT_CENTER
	barra.add_theme_constant_override("separation", 8)
	capa.add_child(barra)
	_hud.huecos = []
	for i in Armas.SLOTS.size():
		var caja := PanelContainer.new()
		caja.custom_minimum_size = Vector2(150, 40)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.45)
		sb.set_corner_radius_all(4)
		sb.border_color = Color8(230, 200, 120)
		caja.add_theme_stylebox_override("panel", sb)
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 13)
		caja.add_child(lab)
		barra.add_child(caja)
		_hud.huecos.append({"caja": caja, "sb": sb, "lab": lab})
	_ignorar_raton(capa)


func _actualizar_hud() -> void:
	var w := cfg()
	var vivo := J.health > 0
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
	var lin: Array = _hud.lineas
	(lin[0] as ColorRect).position = Vector2(-1, -gap - 4 - 9)
	(lin[1] as ColorRect).position = Vector2(-1, gap + 4)
	(lin[2] as ColorRect).position = Vector2(-gap - 4 - 9, -1)
	(lin[3] as ColorRect).position = Vector2(gap + 4, -1)
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
