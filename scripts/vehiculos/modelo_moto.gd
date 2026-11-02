class_name ModeloMoto
## Modelo de la moto, hecho pieza a pieza por código (estilo del resto del juego). Todo en studs.
## Origen = suelo, en el centro entre las dos ruedas; la moto mira hacia -Z; +Y arriba.
##  Cuerpo (se inclina con la moto)
##    ├─ chasis, depósito, asiento, motor, escape, basculante, amortiguadores, guardabarros, piloto...
##    ├─ RuedaTras (gira)
##    └─ Horquilla (en la pipa de dirección, inclinada) → Giro (gira con el manillar)
##          ├─ barras, tijas, manillar, puños, retrovisores, faro (con luz), guardabarros
##          └─ RuedaDel (gira)

const R_RUEDA := 1.0           # radio de las ruedas
const EJE_TRAS := Vector3(0, 1.0, 2.3)
const EJE_DEL := Vector3(0, 1.0, -2.3)
const PIPA := Vector3(0, 3.0, -1.75)  # pipa de dirección (arriba de la horquilla)
const ASIENTO := Vector3(0, 2.4, 0.5)
const PIVOTE_BASC := Vector3(0, 1.2, 0.7)  # eje del basculante
const ESTRIBO := Vector3(0.62, 1.25, 0.45)  # (x = a cada lado)

const PINTURA := Color8(150, 24, 22)
const PINTURA_OSC := Color8(95, 14, 14)
const NEGRO := Color8(22, 22, 24)
const CAUCHO := Color8(26, 26, 27)
const CROMO := Color8(200, 202, 206)
const ALUMINIO := Color8(150, 152, 156)
const ACERO := Color8(70, 72, 76)
const CUERO := Color8(32, 26, 22)
const AMARILLO := Color8(220, 170, 30)


static func _mi(padre: Node3D, nombre: String, malla: Mesh, t: Transform3D, col: Color, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = malla
	mi.transform = t
	mi.material_override = Armas.material(col, mat)
	padre.add_child(mi)
	return mi


static func caja(padre: Node3D, nombre: String, tam: Vector3, pos: Vector3, rot_grados: Vector3, col: Color, mat: String) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = tam
	var rot := rot_grados * (PI / 180.0)
	return _mi(padre, nombre, bm, Transform3D(Rbx.angb(rot.x, rot.y, rot.z), pos), col, mat)


## cilindro a lo largo de X (ruedas, ejes), de Z (escape) o de Y
static func cil(padre: Node3D, nombre: String, d: float, largo: float, pos: Vector3, eje: String, col: Color, mat: String, d2 := -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = d * 0.5
	cm.bottom_radius = (d2 if d2 > 0 else d) * 0.5
	cm.height = largo
	cm.radial_segments = 20 if d > 1.0 else 12
	cm.rings = 1
	var b := Basis.IDENTITY
	match eje:
		"x": b = Basis(Vector3(0, 0, 1), PI / 2)
		"z": b = Basis(Vector3(1, 0, 0), -PI / 2)
	return _mi(padre, nombre, cm, Transform3D(b, pos), col, mat)


## tubo recto de a a b (sección cuadrada o redonda)
static func tubo(padre: Node3D, nombre: String, a: Vector3, b: Vector3, grosor: float, col: Color, mat: String, redondo := true) -> MeshInstance3D:
	var d := b - a
	var largo := d.length()
	var y := d / largo
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	var basis := Basis(x, y, z)
	var malla: Mesh
	if redondo:
		var cm := CylinderMesh.new()
		cm.top_radius = grosor * 0.5
		cm.bottom_radius = grosor * 0.5
		cm.height = largo
		cm.radial_segments = 10
		cm.rings = 1
		malla = cm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(grosor, largo, grosor)
		malla = bm
	return _mi(padre, nombre, malla, Transform3D(basis, (a + b) * 0.5), col, mat)


## rueda: neumático de goma "inflado" (perfil redondeado, se aplasta contra el suelo: ver NEUMATICO_SHADER),
## llanta de aluminio con perfil, radios dobles, buje y discos de freno.
## El neumático NO gira (es redondo: no hace falta); su dibujo sí se mueve (parámetro "giro" del shader), así
## la deformación del apoyo se queda abajo. Devuelve el nodo que gira (eje X); el neumático queda en
## soporte.get_meta("neumatico").
static func rueda(padre: Node3D, nombre: String, pos: Vector3, delantera: bool) -> Node3D:
	var soporte := Node3D.new()
	soporte.name = nombre
	soporte.position = pos
	padre.add_child(soporte)
	var neu := MeshInstance3D.new()
	neu.name = "Neumatico"
	neu.mesh = malla_neumatico()
	var mat := ShaderMaterial.new()
	mat.shader = _shader_neumatico()
	mat.set_shader_parameter("r_ext", R_RUEDA)
	neu.material_override = mat
	# el aplastamiento cambia la forma: que no la recorten por la caja de la malla
	neu.extra_cull_margin = 0.5
	soporte.add_child(neu)
	soporte.set_meta("neumatico", neu)
	var giro := Node3D.new()
	giro.name = "Gira"
	soporte.add_child(giro)
	# llanta: aro con perfil (pestañas) y cara interior
	var llanta := MeshInstance3D.new()
	llanta.name = "Llanta"
	llanta.mesh = malla_llanta()
	var mat_ll := (Armas.material(ALUMINIO, "Steel") as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat_ll.cull_mode = BaseMaterial3D.CULL_DISABLED
	llanta.material_override = mat_ll
	giro.add_child(llanta)
	# 5 radios dobles (llanta de aleación), del buje al aro
	for i in 5:
		var a := TAU * i / 5.0
		for k in [-1.0, 1.0]:
			var a2: float = a + k * 0.09
			var dentro := Vector3(k * 0.05, sin(a) * 0.17, cos(a) * 0.17)
			var fuera := Vector3(k * 0.07, sin(a2) * 0.62, cos(a2) * 0.62)
			tubo(giro, "Radio%d_%d" % [i, int(k)], dentro, fuera, 0.075, NEGRO, "Metal", false)
	cil(giro, "Buje", 0.36, 0.5, Vector3.ZERO, "x", ALUMINIO, "Steel")
	cil(giro, "TapaBuje", 0.2, 0.54, Vector3.ZERO, "x", CROMO, "Steel")
	cil(giro, "Disco", 0.95 if delantera else 0.75, 0.04, Vector3(-0.2, 0, 0), "x", CROMO, "Steel")
	cil(giro, "DiscoCentro", 0.5, 0.05, Vector3(-0.2, 0, 0), "x", ACERO, "Metal")
	if delantera:
		cil(giro, "Disco2", 0.95, 0.04, Vector3(0.2, 0, 0), "x", CROMO, "Steel")
		cil(giro, "Disco2Centro", 0.5, 0.05, Vector3(0.2, 0, 0), "x", ACERO, "Metal")
	# pinza de freno (no gira)
	var pinza := caja(soporte, "Pinza", Vector3(0.16, 0.42, 0.3), Vector3(-0.22, 0.32, 0.18 if delantera else -0.18), Vector3(0, 0, 0), ROJO_PINZA, "Metal")
	pinza.rotation.x = deg_to_rad(-35.0 if delantera else 35.0)
	return giro


const ROJO_PINZA := Color8(180, 30, 25)
static var _malla_neu: ArrayMesh
static var _malla_ll: ArrayMesh
static var _sh_neu: Shader


## perfil del neumático (x = ancho, r = radio): superelipse (flancos abombados y banda de rodadura casi plana)
static func malla_neumatico() -> ArrayMesh:
	if _malla_neu == null:
		var perfil := PackedVector2Array()
		var n_p := 32
		for j in n_p:
			var t := TAU * j / n_p
			var c := cos(t)
			var sn := sin(t)
			var ex := 2.0 / 3.2
			perfil.append(Vector2(0.23 * signf(c) * pow(absf(c), ex), 0.82 + 0.18 * signf(sn) * pow(absf(sn), ex)))
		_malla_neu = _torno(perfil, 56, Vector2(0.0, 0.82))
	return _malla_neu


static func malla_llanta() -> ArrayMesh:
	if _malla_ll == null:
		# sección del aro: canal con dos pestañas
		var perfil := PackedVector2Array([
			Vector2(-0.19, 0.70), Vector2(-0.19, 0.64), Vector2(-0.15, 0.62), Vector2(0.15, 0.62),
			Vector2(0.19, 0.64), Vector2(0.19, 0.70), Vector2(0.16, 0.71), Vector2(0.15, 0.66),
			Vector2(-0.15, 0.66), Vector2(-0.16, 0.71)])
		_malla_ll = _torno(perfil, 48, Vector2(0.0, 0.665))
	return _malla_ll


## malla de revolución alrededor del eje X a partir de un perfil cerrado (x, radio). Normales hacia fuera del
## centro del perfil (vale para perfiles casi convexos).
static func _torno(perfil: PackedVector2Array, segs: int, centro: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_p := perfil.size()
	for i in segs + 1:
		var a := TAU * i / segs
		for j in n_p:
			var p := perfil[j]
			# normal: perpendicular a la tangente del perfil, hacia fuera del centro
			var tg := perfil[(j + 1) % n_p] - perfil[(j - 1 + n_p) % n_p]
			var nn := Vector2(-tg.y, tg.x).normalized()
			if nn.dot(p - centro) < 0.0:
				nn = -nn
			st.set_normal(Vector3(nn.x, nn.y * sin(a), nn.y * cos(a)))
			st.set_uv(Vector2(float(i) / segs, float(j) / n_p))
			st.add_vertex(Vector3(p.x, p.y * sin(a), p.y * cos(a)))
	for i in segs:
		for j in n_p:
			var a0 := i * n_p + j
			var a1 := i * n_p + (j + 1) % n_p
			var b0 := (i + 1) * n_p + j
			var b1 := (i + 1) * n_p + (j + 1) % n_p
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a1)
			st.add_index(a1)
			st.add_index(b0)
			st.add_index(b1)
	return st.commit()


## goma: aplastamiento en el apoyo (los vértices bajo el suelo se quedan en el suelo y el flanco se abomba
## hacia fuera, como un neumático con aire), dibujo de la banda que se mueve con la rueda y flanco con letras
const NEUMATICO_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 plano = vec4(0.0, 1.0, 0.0, -100000.0); // suelo bajo la rueda: normal (xyz) y distancia (w)
uniform float giro = 0.0;                           // ángulo de la rueda (rad)
uniform float r_ext = 1.0;
uniform vec3 goma : source_color = vec3(0.075, 0.075, 0.08);
varying vec3 v_loc;

void vertex() {
	v_loc = VERTEX;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 eje = normalize(MODEL_MATRIX[0].xyz);
	vec3 n = plano.xyz;
	float h = dot(n, w) - plano.w;
	float hc = dot(n, c) - plano.w;
	float aplasta = clamp(r_ext - hc, 0.0, 0.35);
	if (h < 0.0) {
		w -= n * h;
		NORMAL = mix(NORMAL, (inverse(MODEL_MATRIX) * vec4(-n, 0.0)).xyz, 0.6);
	}
	// el flanco se abomba cerca del apoyo (más cuanto más aplastada)
	float cerca = clamp(1.0 - max(h, 0.0) / (0.25 + aplasta * 2.0), 0.0, 1.0);
	float lado = dot(w - c, eje);
	w += eje * sign(lado) * aplasta * 0.55 * cerca * cerca;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	float ang = atan(v_loc.y, v_loc.z) - giro;
	float rr = length(v_loc.yz);
	float lat = v_loc.x;
	vec3 col = goma;
	float rough = 0.88;
	if (rr > r_ext - 0.075) {
		// banda de rodadura: surcos en V y uno central
		float ch = fract(ang * 22.0 / 6.2831853 + abs(lat) * 2.6);
		float surco = smoothstep(0.66, 0.7, ch) * (1.0 - smoothstep(0.9, 0.94, ch)) * step(abs(lat), 0.19);
		surco = max(surco, 1.0 - smoothstep(0.012, 0.02, abs(lat)));
		col *= mix(1.0, 0.35, surco);
		rough = mix(0.82, 1.0, surco);
	} else {
		// flanco: un anillo en relieve y "letras" (rayas) algo más claras
		float anillo = smoothstep(0.865, 0.875, rr) * (1.0 - smoothstep(0.89, 0.9, rr));
		float banda = smoothstep(0.75, 0.76, rr) * (1.0 - smoothstep(0.82, 0.83, rr));
		float letras = step(0.45, fract(ang * 46.0 / 6.2831853)) * step(0.35, fract(ang * 5.0 / 6.2831853));
		col = mix(col, vec3(0.16), max(anillo * 0.7, banda * letras * 0.75));
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
"""


static func _shader_neumatico() -> Shader:
	if _sh_neu == null:
		_sh_neu = Shader.new()
		_sh_neu.code = NEUMATICO_SHADER
	return _sh_neu


## construye la moto dentro de "raiz"; devuelve los nodos que se mueven
static func construir(raiz: Node3D) -> Dictionary:
	var cuerpo := Node3D.new()
	cuerpo.name = "Cuerpo"
	raiz.add_child(cuerpo)
	# --- chasis (tubos)
	tubo(cuerpo, "ChasisSup", PIPA, Vector3(0, 2.35, 0.9), 0.2, NEGRO, "Metal")
	tubo(cuerpo, "ChasisBajL", PIPA, Vector3(-0.22, 1.05, -0.75), 0.16, NEGRO, "Metal")
	tubo(cuerpo, "ChasisBajR", PIPA, Vector3(0.22, 1.05, -0.75), 0.16, NEGRO, "Metal")
	tubo(cuerpo, "CunaL", Vector3(-0.22, 1.05, -0.75), Vector3(-0.25, 1.1, 0.7), 0.15, NEGRO, "Metal")
	tubo(cuerpo, "CunaR", Vector3(0.22, 1.05, -0.75), Vector3(0.25, 1.1, 0.7), 0.15, NEGRO, "Metal")
	tubo(cuerpo, "SubchasisL", Vector3(-0.25, 1.1, 0.7), Vector3(-0.3, 2.4, 1.7), 0.12, NEGRO, "Metal")
	tubo(cuerpo, "SubchasisR", Vector3(0.25, 1.1, 0.7), Vector3(0.3, 2.4, 1.7), 0.12, NEGRO, "Metal")
	cil(cuerpo, "Pipa", 0.3, 0.5, PIPA + Vector3(0, -0.1, 0), "y", NEGRO, "Metal")
	# --- depósito y tapa
	caja(cuerpo, "Deposito", Vector3(0.95, 0.62, 1.35), Vector3(0, 2.95, -0.85), Vector3(-6, 0, 0), PINTURA, "Metal")
	caja(cuerpo, "DepositoTop", Vector3(0.78, 0.16, 1.15), Vector3(0, 3.3, -0.88), Vector3(-6, 0, 0), PINTURA, "Metal")
	caja(cuerpo, "FranjaL", Vector3(0.02, 0.14, 1.2), Vector3(-0.48, 3.0, -0.85), Vector3(-6, 0, 0), Color8(230, 230, 230), "Metal")
	caja(cuerpo, "FranjaR", Vector3(0.02, 0.14, 1.2), Vector3(0.48, 3.0, -0.85), Vector3(-6, 0, 0), Color8(230, 230, 230), "Metal")
	cil(cuerpo, "Tapon", 0.22, 0.06, Vector3(0, 3.4, -1.05), "y", CROMO, "Steel")
	caja(cuerpo, "Rodillera", Vector3(0.97, 0.3, 0.5), Vector3(0, 2.75, -0.25), Z(), CAUCHO, "Rubber")
	# --- asiento
	caja(cuerpo, "Asiento", Vector3(0.82, 0.24, 1.7), ASIENTO + Vector3(0, -0.05, 0.1), Z(), CUERO, "Leather")
	caja(cuerpo, "AsientoCostura", Vector3(0.84, 0.03, 1.72), ASIENTO + Vector3(0, -0.15, 0.1), Z(), NEGRO, "Leather")
	caja(cuerpo, "AsientoPasajero", Vector3(0.7, 0.18, 0.6), ASIENTO + Vector3(0, 0.1, 1.05), Z(), CUERO, "Leather")
	caja(cuerpo, "TapaL", Vector3(0.08, 0.5, 0.85), Vector3(-0.44, 2.2, 0.45), Z(), PINTURA_OSC, "Metal")
	caja(cuerpo, "TapaR", Vector3(0.08, 0.5, 0.85), Vector3(0.44, 2.2, 0.45), Z(), PINTURA_OSC, "Metal")
	# --- motor (bloque, aletas de los cilindros, tapas)
	caja(cuerpo, "Carter", Vector3(0.82, 0.7, 1.05), Vector3(0, 1.45, -0.3), Z(), ALUMINIO, "Metal")
	for i in 5:
		caja(cuerpo, "Aleta%d" % i, Vector3(0.95, 0.05, 0.55), Vector3(0, 1.88 + i * 0.09, -0.65 - i * 0.03), Vector3(-18, 0, 0), ACERO, "Metal")
	caja(cuerpo, "Culata", Vector3(0.8, 0.22, 0.45), Vector3(0, 2.35, -0.78), Vector3(-18, 0, 0), ALUMINIO, "Metal")
	cil(cuerpo, "TapaEmbrague", 0.62, 0.1, Vector3(-0.46, 1.45, -0.25), "x", CROMO, "Steel")
	cil(cuerpo, "TapaAlternador", 0.5, 0.1, Vector3(0.46, 1.4, -0.35), "x", CROMO, "Steel")
	caja(cuerpo, "Carburador", Vector3(0.25, 0.25, 0.3), Vector3(0.2, 2.0, -0.15), Z(), ALUMINIO, "Metal")
	cil(cuerpo, "Filtro", 0.32, 0.2, Vector3(0.38, 2.0, 0.08), "x", NEGRO, "Metal")
	caja(cuerpo, "Bateria", Vector3(0.4, 0.35, 0.3), Vector3(0, 1.95, 0.55), Z(), NEGRO, "Plastic")
	# --- escape (lado derecho)
	tubo(cuerpo, "Colector1", Vector3(0.2, 2.15, -1.0), Vector3(0.32, 1.0, -0.65), 0.14, CROMO, "Steel")
	tubo(cuerpo, "Colector2", Vector3(0.32, 1.0, -0.65), Vector3(0.45, 1.05, 0.9), 0.14, CROMO, "Steel")
	tubo(cuerpo, "Colector3", Vector3(0.45, 1.05, 0.9), Vector3(0.5, 1.3, 1.4), 0.14, CROMO, "Steel")
	var silen := cil(cuerpo, "Silenciador", 0.34, 1.35, Vector3(0.52, 1.45, 2.0), "z", CROMO, "Steel", 0.28)
	silen.rotation.x = -PI / 2 + deg_to_rad(8)
	cil(cuerpo, "Punta", 0.2, 0.08, Vector3(0.52, 1.55, 2.68), "z", NEGRO, "Metal")
	caja(cuerpo, "Protector", Vector3(0.06, 0.22, 0.6), Vector3(0.68, 1.5, 1.9), Vector3(-8, 0, 0), NEGRO, "Metal")
	# --- basculante (gira en su eje: la rueda de atrás sube y baja con la suspensión), amortiguadores y estribos
	var basc := Node3D.new()
	basc.name = "Basculante"
	basc.position = PIVOTE_BASC
	cuerpo.add_child(basc)
	tubo(basc, "BasculanteL", Vector3(-0.3, 0, 0), EJE_TRAS - PIVOTE_BASC + Vector3(-0.3, 0, 0), 0.14, NEGRO, "Metal", false)
	tubo(basc, "BasculanteR", Vector3(0.3, 0, 0), EJE_TRAS - PIVOTE_BASC + Vector3(0.3, 0, 0), 0.14, NEGRO, "Metal", false)
	cil(basc, "EjeBasculante", 0.16, 0.72, Vector3.ZERO, "x", ALUMINIO, "Steel")
	var amorts := []
	for lado in [-1.0, 1.0]:
		var nombre := "L" if lado < 0 else "R"
		# el amortiguador va del chasis (arriba) al basculante (abajo): se rehace cada fotograma (ver amortiguador())
		var am := Node3D.new()
		am.name = "Amortiguador" + nombre
		cuerpo.add_child(am)
		cil(am, "Cuerpo", 0.16, 1.0, Vector3.ZERO, "y", ALUMINIO, "Steel")
		cil(am, "Vastago", 0.07, 1.0, Vector3.ZERO, "y", CROMO, "Steel")
		cil(am, "Muelle", 0.2, 1.0, Vector3.ZERO, "y", AMARILLO, "Metal")
		am.set_meta("arriba", Vector3(0.36 * lado, 2.35, 1.2))
		am.set_meta("abajo_basc", Vector3(0.36 * lado, 1.15, 1.95) - PIVOTE_BASC)
		amorts.append(am)
		caja(cuerpo, "Estribo" + nombre, Vector3(0.36, 0.08, 0.14), Vector3(ESTRIBO.x * lado, ESTRIBO.y, ESTRIBO.z), Z(), NEGRO, "Rubber")
		tubo(cuerpo, "SoporteEstribo" + nombre, Vector3(0.28 * lado, 1.15, 0.45), Vector3(0.48 * lado, 1.25, 0.45), 0.08, ALUMINIO, "Steel")
	caja(cuerpo, "PedalFreno", Vector3(0.06, 0.06, 0.45), Vector3(0.55, 1.2, 0.15), Vector3(10, 0, 0), ALUMINIO, "Steel")
	caja(cuerpo, "PedalCambio", Vector3(0.06, 0.06, 0.4), Vector3(-0.55, 1.25, 0.1), Vector3(-8, 0, 0), ALUMINIO, "Steel")
	# --- guardabarros trasero, piloto y matrícula
	caja(cuerpo, "GuardabarrosTras", Vector3(0.52, 0.06, 1.3), Vector3(0, 2.25, 2.55), Vector3(-18, 0, 0), PINTURA, "Metal")
	caja(cuerpo, "Colin", Vector3(0.7, 0.25, 0.6), Vector3(0, 2.6, 1.85), Vector3(-6, 0, 0), PINTURA, "Metal")
	caja(cuerpo, "Piloto", Vector3(0.32, 0.12, 0.08), Vector3(0, 2.48, 3.1), Z(), Color8(255, 30, 20), "Glow")
	caja(cuerpo, "Matricula", Vector3(0.5, 0.34, 0.03), Vector3(0, 1.95, 3.2), Vector3(-10, 0, 0), Color8(235, 230, 200), "Plastic")
	caja(cuerpo, "MatriculaNum", Vector3(0.4, 0.1, 0.035), Vector3(0, 1.95, 3.2), Vector3(-10, 0, 0), NEGRO, "Plastic")
	for lado2 in [-1.0, 1.0]:
		caja(cuerpo, "Intermitente%s" % ("L" if lado2 < 0 else "R"), Vector3(0.16, 0.08, 0.08), Vector3(0.36 * lado2, 2.3, 2.95), Z(), Color8(255, 150, 20), "Glow")
	# --- pata de cabra (lado izquierdo; se ve cuando está aparcada)
	var pata := tubo(cuerpo, "PataCabra", Vector3(-0.35, 1.15, 0.2), Vector3(-0.85, 0.05, 0.45), 0.08, NEGRO, "Metal")
	# --- rueda trasera
	var rueda_tras := rueda(basc, "RuedaTras", EJE_TRAS - PIVOTE_BASC, false)
	# --- dirección: horquilla inclinada en la pipa, y el giro del manillar
	var horq := Node3D.new()
	horq.name = "Horquilla"
	horq.position = PIPA
	var eje_h := (EJE_DEL - PIPA)
	horq.rotation.x = atan2(-eje_h.z, -eje_h.y)
	cuerpo.add_child(horq)
	var giro := Node3D.new()
	giro.name = "Giro"
	horq.add_child(giro)
	var largo_h := eje_h.length()
	# la parte de abajo de la horquilla (botellas, guardabarros y rueda) se desliza por las barras cromadas
	var desl := Node3D.new()
	desl.name = "Deslizante"
	giro.add_child(desl)
	for lado3 in [-1.0, 1.0]:
		var n3 := "L" if lado3 < 0 else "R"
		cil(giro, "Barra" + n3, 0.16, largo_h * 0.62, Vector3(0.32 * lado3, -largo_h * 0.33, 0), "y", CROMO, "Steel")
		cil(desl, "Botella" + n3, 0.22, largo_h * 0.5, Vector3(0.32 * lado3, -largo_h * 0.74, 0), "y", NEGRO, "Metal")
		cil(desl, "Reten" + n3, 0.25, 0.06, Vector3(0.32 * lado3, -largo_h * 0.49, 0), "y", CAUCHO, "Rubber")
	caja(giro, "TijaSup", Vector3(0.9, 0.08, 0.3), Vector3(0, 0.12, 0), Z(), ALUMINIO, "Steel")
	caja(giro, "TijaInf", Vector3(0.9, 0.1, 0.32), Vector3(0, -0.35, 0), Z(), ALUMINIO, "Steel")
	# manillar y puños (posiciones para las manos del piloto)
	cil(giro, "Manillar", 0.1, 1.95, Vector3(0, 0.42, 0.2), "x", NEGRO, "Metal")
	tubo(giro, "TorreL", Vector3(-0.15, 0.12, 0.0), Vector3(-0.15, 0.42, 0.18), 0.08, NEGRO, "Metal")
	tubo(giro, "TorreR", Vector3(0.15, 0.12, 0.0), Vector3(0.15, 0.42, 0.18), 0.08, NEGRO, "Metal")
	cil(giro, "PunoL", 0.14, 0.32, Vector3(-0.85, 0.42, 0.2), "x", CAUCHO, "Rubber")
	cil(giro, "PunoR", 0.14, 0.32, Vector3(0.85, 0.42, 0.2), "x", CAUCHO, "Rubber")
	caja(giro, "LevaFreno", Vector3(0.45, 0.04, 0.06), Vector3(0.78, 0.45, 0.02), Vector3(0, 15, 0), ALUMINIO, "Steel")
	caja(giro, "LevaEmbrague", Vector3(0.45, 0.04, 0.06), Vector3(-0.78, 0.45, 0.02), Vector3(0, -15, 0), ALUMINIO, "Steel")
	cil(giro, "BombaFreno", 0.12, 0.18, Vector3(0.5, 0.48, 0.2), "x", NEGRO, "Metal")
	for lado4 in [-1.0, 1.0]:
		var n4 := "L" if lado4 < 0 else "R"
		tubo(giro, "Varilla" + n4, Vector3(0.55 * lado4, 0.45, 0.2), Vector3(0.72 * lado4, 0.85, 0.08), 0.04, CROMO, "Steel")
		cil(giro, "Espejo" + n4, 0.24, 0.05, Vector3(0.74 * lado4, 0.9, 0.07), "z", NEGRO, "Metal")
		cil(giro, "Cristal" + n4, 0.2, 0.01, Vector3(0.74 * lado4, 0.9, 0.1), "z", Color8(150, 170, 190), "Glass")
	# relojes
	cil(giro, "Reloj", 0.36, 0.14, Vector3(0, 0.62, 0.05), "y", NEGRO, "Metal")
	cil(giro, "RelojCara", 0.3, 0.02, Vector3(0, 0.7, 0.05), "y", Color8(230, 230, 220), "Glow")
	# faro (con luz) y guardabarros delantero
	var faro := cil(giro, "Faro", 0.55, 0.35, Vector3(0, -0.12, -0.4), "z", NEGRO, "Metal", 0.4)
	cil(giro, "FaroCristal", 0.48, 0.02, Vector3(0, -0.12, -0.58), "z", Color8(255, 245, 210), "Glow")
	cil(giro, "FaroAro", 0.56, 0.05, Vector3(0, -0.12, -0.57), "z", CROMO, "Steel")
	var luz := SpotLight3D.new()
	luz.name = "Luz"
	luz.position = Vector3(0, -0.12, -0.65)
	luz.spot_range = 90.0
	luz.spot_angle = 26.0
	luz.light_energy = 2.5
	luz.light_color = Color(1.0, 0.95, 0.85)
	luz.shadow_enabled = false
	luz.visible = false
	giro.add_child(luz)
	# guardabarros delantero (sobre la rueda) y la rueda, en el eje de la horquilla
	var eje_local := Vector3(0, -largo_h, 0)
	caja(desl, "GuardabarrosDel", Vector3(0.5, 0.06, 1.3), eje_local + Vector3(0, R_RUEDA + 0.15, -0.1), Vector3(-15.4, 0, 0), PINTURA, "Metal")
	var rueda_del := rueda(desl, "RuedaDel", eje_local, true)
	# el eje de la rueda delantera tiene que quedar horizontal aunque la horquilla esté inclinada
	(rueda_del.get_parent() as Node3D).rotation.x = -horq.rotation.x
	# cartel para subirse
	var cartel := Label3D.new()
	cartel.name = "Cartel"
	cartel.text = "[F] Subir a la moto"
	cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cartel.font_size = 40
	cartel.pixel_size = 0.008
	cartel.outline_size = 8
	cartel.position = Vector3(0, 4.6, 0)
	cartel.visible = false
	raiz.add_child(cartel)
	for am in amorts:
		amortiguador(am, basc)
	return {"cuerpo": cuerpo, "giro": giro, "horquilla": horq, "rueda_tras": rueda_tras, "rueda_del": rueda_del,
		"basculante": basc, "deslizante": desl, "amortiguadores": amorts,
		"neu_tras": rueda_tras.get_parent().get_meta("neumatico"), "neu_del": rueda_del.get_parent().get_meta("neumatico"),
		"luz": luz, "faro": faro, "pata": pata, "cartel": cartel}


## coloca un amortiguador entre su anclaje en el chasis y el del basculante (que gira): el cuerpo arriba, el vástago
## que entra y sale y el muelle, que se acorta al comprimirse
static func amortiguador(am: Node3D, basc: Node3D) -> void:
	var a: Vector3 = am.get_meta("arriba")
	var b: Vector3 = basc.transform * (am.get_meta("abajo_basc") as Vector3)
	var d := a - b
	var largo := d.length()
	var y := d / largo
	var x := Vector3.RIGHT
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	am.transform = Transform3D(Basis(x, y, z), b)
	# (de abajo, el ojo del basculante, hacia arriba)
	var cu := am.get_node("Cuerpo") as MeshInstance3D
	cu.scale = Vector3(1, 0.5, 1)
	cu.position = Vector3(0, largo - 0.25, 0)
	var va := am.get_node("Vastago") as MeshInstance3D
	va.scale = Vector3(1, largo * 0.75, 1)
	va.position = Vector3(0, largo * 0.375, 0)
	var mu := am.get_node("Muelle") as MeshInstance3D
	mu.scale = Vector3(1, maxf(0.2, largo - 0.42), 1)
	mu.position = Vector3(0, 0.14 + (largo - 0.42) * 0.5, 0)


static func Z() -> Vector3:
	return Vector3.ZERO
