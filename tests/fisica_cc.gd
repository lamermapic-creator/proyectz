extends Node
## Física de los golpes del combate cuerpo a cuerpo (2026-11-08): empujones o patadas a un zombi quieto (o a un
## muñeco con --muneco). --golpe=empujon|patada|puno, --veces=N. Para cada impacto imprime Δv, si cae y cuánto
## retrocede, y al final "FISICA golpe=... caidas=x/N retroceso_medio=... inclina_max=..." y OK/MAL.
var j: Jugador
var obj
var t := 0.0
var golpe := "empujon"
var veces := 8
var hechos := 0
var proximo := 1.2
var pos0 := Vector3.ZERO
var medir_t := -1.0
var caidas := 0
var retrocesos := []
var inclina_max := 0.0
var ult_imp_t := -1.0
var inclina0 := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--golpe="):
			golpe = a.split("=")[1]
		if a.begins_with("--veces="):
			veces = int(a.split("=")[1])
	seed(11)
	j = get_parent().get_node("Jugador")
	j.global_position = Vector3(-100, 3.2, 100)
	j.yaw = 0.0
	j.estamina_infinita = true
	j.invencible = true # (al levantarse, el zombi va a por él)
	Zombi.sordos = true
	Zombi.ciegos = true

func _colocar() -> void:
	# el blanco, quieto delante del jugador a 3,6 studs (se recoloca antes de cada golpe)
	var pies := j.global_position + Vector3(0, -3.1, -(2.7 if golpe == "puno" else 3.4))
	if obj == null:
		if OS.get_cmdline_user_args().has("--muneco"):
			obj = Maniqui.new()
			obj.position = pies
			get_parent().add_child(obj)
		else:
			obj = get_parent().get_node("Zombis").crear_zombi(pies, 0.0, false)
	elif obj is Node3D:
		if obj.has_method("en_pie") and obj.en_pie():
			if obj is Maniqui:
				obj._base = pies
			else:
				obj.global_position = pies + Vector3(0, 3.1, 0)

func _process(dt: float) -> void:
	t += dt
	var a := j.arsenal
	if t > 0.3 and obj == null:
		_colocar()
	if obj == null:
		return
	# inclinación del tronco del blanco hacia atrás (lo que se echa para atrás)
	var ut: Node3D = obj.rig.P.UpperTorso
	var up := ut.global_transform.basis.y
	# cuánto se echa hacia atrás (alejándose del jugador) respecto a como estaba antes del golpe
	var atras := rad_to_deg(asin(clampf(up.dot(Rbx.flat(Rbx.look(j.root_cf())).normalized()), -1, 1)))
	if medir_t > 0.0 and obj.en_pie():
		inclina_max = maxf(inclina_max, atras - inclina0)
	if hechos < veces and t > proximo and obj.en_pie():
		_colocar()
		pos0 = (obj as Node3D).global_position
		inclina0 = rad_to_deg(asin(clampf((obj.rig.P.UpperTorso as Node3D).global_transform.basis.y.dot(Rbx.flat(Rbx.look(j.root_cf())).normalized()), -1, 1)))
		hechos += 1
		proximo = t + 2.6
		print("FISICA intento %d t=%.1f" % [hechos, t])
		if golpe == "empujon":
			j.aiming = true
			a.cc_espacio(true)
			a.cc_espacio(false)
			a.cc_espacio(true)
			a.cc_espacio(false)
		elif golpe == "patada":
			a.patada()
		else:
			a.punetazo()
	if golpe == "empujon" and a.cc.accion == null and t > proximo - 2.0:
		j.aiming = false
	var imp: Dictionary = a.cc_ultimo_impacto
	if not imp.is_empty() and float(imp.get("t", -1.0)) != ult_imp_t:
		ult_imp_t = float(imp.get("t", -1.0))
		medir_t = t + 0.9
		if imp.get("cae", false):
			caidas += 1
		print("FISICA impacto %s dv=%.1f pieza=%s cae=%s p=%.2f" % [imp.tipo, float(imp.dv), imp.pieza, str(imp.cae), float(imp.get("p", 0.0))])
	if medir_t > 0.0 and t > medir_t:
		medir_t = -1.0
		var r := Rbx.flat((obj as Node3D).global_position - pos0).length()
		retrocesos.append(r)
		print("FISICA retrocede=%.2f studs (de pie=%s)" % [r, str(obj.en_pie())])
	if hechos >= veces and t > proximo + 1.0 or t > 60.0:
		var media := 0.0
		for r in retrocesos:
			media += r
		media /= maxf(1.0, retrocesos.size())
		print("FISICA golpe=%s impactos=%d caidas=%d/%d retroceso_medio=%.2f inclina_max=%.0f" % [golpe, retrocesos.size(), caidas, hechos, media, inclina_max])
		# (el zombi deambula un poco entre golpe y golpe: alguno puede fallar)
		var ok := retrocesos.size() >= int(hechos * 0.6) and media > 0.6 and media < 6.0 and inclina_max > 4.0
		print("OK fisica_" + golpe if ok else "MAL fisica_%s" % golpe)
		get_tree().quit()
