class_name ModelosArmas
## Modelos de las armas, hechos pieza a pieza por código (v0.4: unas 3 veces más piezas que los de
## Roblox: cañones redondos, guardamanos, miras, carriles, gatillos, tornillos, cargadores curvos...).
## Origen = el Handle (donde la mano derecha empuña); el cañón o la hoja apuntan hacia -Z; +Y arriba.
## Todo en studs. Cada pieza: [nombre, forma, tamaño, posición, giro XYZ (grados), color, material, grupo]
## (formas y grupos: ver Armas.construir_modelo). Los puntos de referencia (Muzzle, LeftGrip, Mag...)
## son los que usan el animador y el arsenal: si se cambia un modelo, mantenerlos donde corresponde.

## ---------------------------------------------------------------- colores
const NEGRO := Color8(24, 24, 26)
const NEGRO2 := Color8(14, 14, 15)
const CAUCHO := Color8(30, 30, 31)
const ANODIZADO := Color8(38, 39, 42)
const ACERO := Color8(58, 60, 64)
const ACERO_OSC := Color8(36, 37, 40)
const PAVONADO := Color8(30, 33, 40)
const ACERO_CLARO := Color8(170, 173, 178)
const CROMO := Color8(205, 208, 212)
const MADERA := Color8(118, 72, 38)
const MADERA_OSC := Color8(74, 46, 26)
const LATON := Color8(190, 150, 70)
const OLIVA := Color8(84, 86, 60)
const ROJO := Color8(150, 26, 22)
const ROJO_OSC := Color8(105, 22, 20)
const OXIDO := Color8(110, 58, 32)
const VERDE_GLOW := Color8(90, 255, 130)
const ROJO_GLOW := Color8(255, 40, 30)
const LENTE := Color8(40, 70, 110)
const SANGRE := Color8(70, 8, 8)

const Z := Vector3.ZERO


static var _cache := {}


static func piezas(nombre: String) -> Array:
	if _cache.has(nombre):
		return _cache[nombre]
	var a := []
	match nombre:
		"Pistola": _pistola(a)
		"Revolver": _revolver(a)
		"Subfusil": _subfusil(a)
		"Rifle": _rifle(a)
		"Escopeta": _escopeta(a)
		"Francotirador": _francotirador(a)
		"Cuchillo": _cuchillo(a)
		"Machete": _machete(a)
		"Bate": _bate(a)
		"Hacha": _hacha(a)
		"Palanca": _palanca(a)
	_cache[nombre] = a
	return a


## puntos de referencia (Attachments), relativos al Handle. "Grupo/Nombre" = dentro de un grupo móvil
static func puntos(nombre: String) -> Dictionary:
	match nombre:
		"Pistola":
			return {"SupportGrip": Vector3(-0.132, -0.033, 0.033), "Muzzle": Vector3(0, 0.37, -0.805),
				"SlideRear": Vector3(0, 0.43, 0.09), "MagBottom": Vector3(0, -0.38, 0.06)}
		"Revolver":
			return {"SupportGrip": Vector3(-0.14, -0.06, 0.05), "Muzzle": Vector3(0, 0.4, -1.17),
				"SlideRear": Vector3(0, 0.5, 0.1), "MagBottom": Vector3(0, 0.3, -0.41)}
		"Subfusil":
			return {"LeftGrip": Vector3(0, 0.14, -0.96), "Muzzle": Vector3(0, 0.32, -1.43),
				"ChargingHandle": Vector3(-0.09, 0.37, -0.95), "MagBottom": Vector3(0, -0.47, -0.63)}
		"Rifle":
			return {"ChargingHandle": Vector3(-0.05, 0.47, 0.1), "LeftGrip": Vector3(0, 0.06, -0.84),
				"Muzzle": Vector3(0, 0.3, -2.15), "MagBottom": Vector3(0, -0.47, -0.6)}
		"Escopeta":
			return {"Pump/LeftGrip": Vector3(0, 0.13, -1.0), "Muzzle": Vector3(0, 0.38, -2.2),
				"ChargingHandle": Vector3(0, 0.13, -1.0), "MagBottom": Vector3(0, 0.13, -0.45)}
		"Francotirador":
			return {"LeftGrip": Vector3(0, 0.13, -1.0), "Muzzle": Vector3(0, 0.36, -2.52),
				"Bolt/ChargingHandle": Vector3(0.23, 0.3, 0.1), "MagBottom": Vector3(0, -0.19, -0.45)}
		"Bate":
			return {"LeftGrip": Vector3(0, 0, 0.18)}
		"Hacha":
			return {"LeftGrip": Vector3(0, 0, -0.5)}
	return {}


## ---------------------------------------------------------------- ayudas
static func _b(a: Array, n: String, tam: Vector3, pos: Vector3, rot: Vector3, col: Color, mat: String, g := "") -> void:
	a.append([n, "box", tam, pos, rot, col, mat, g])


## cilindro (diámetro, largo); forma: cylz (a lo largo de Z), cylx, cyly, hexz (barra hexagonal)
static func _c(a: Array, n: String, d: float, largo: float, pos: Vector3, col: Color, mat: String, g := "", forma := "cylz", rot := Vector3.ZERO) -> void:
	a.append([n, forma, Vector3(d, d, largo), pos, rot, col, mat, g])


## cono a lo largo de Z: d_del = diámetro delante (-Z), d_atr = detrás
static func _cono(a: Array, n: String, d_del: float, d_atr: float, largo: float, pos: Vector3, col: Color, mat: String, g := "") -> void:
	a.append([n, "conoz", Vector3(d_del, d_atr, largo), pos, Z, col, mat, g])


static func _e(a: Array, n: String, d: float, pos: Vector3, col: Color, mat: String, g := "") -> void:
	a.append([n, "esf", Vector3(d, d, d), pos, Z, col, mat, g])


## mira de puntos luminosos (alza o punto de mira)
static func _punto(a: Array, n: String, pos: Vector3, col := VERDE_GLOW, g := "") -> void:
	_b(a, n, Vector3(0.018, 0.018, 0.01), pos, Z, col, "Glow", g)


## ---------------------------------------------------------------- PISTOLA 9 mm (polímero)
static func _pistola(a: Array) -> void:
	_b(a, "Handle", Vector3(0.2, 0.54, 0.29), Vector3(0, -0.02, 0.02), Vector3(-10, 0, 0), NEGRO, "Polymer")
	_b(a, "GripL", Vector3(0.012, 0.36, 0.22), Vector3(-0.103, -0.06, 0.03), Vector3(-10, 0, 0), CAUCHO, "Rubber")
	_b(a, "GripR", Vector3(0.012, 0.36, 0.22), Vector3(0.103, -0.06, 0.03), Vector3(-10, 0, 0), CAUCHO, "Rubber")
	_b(a, "Backstrap", Vector3(0.15, 0.4, 0.04), Vector3(0, -0.04, 0.17), Vector3(-10, 0, 0), CAUCHO, "Rubber")
	_b(a, "Beavertail", Vector3(0.17, 0.05, 0.13), Vector3(0, 0.235, 0.19), Z, NEGRO, "Polymer")
	_b(a, "Frame", Vector3(0.2, 0.13, 0.8), Vector3(0, 0.215, -0.32), Z, NEGRO, "Polymer")
	for i in 3:
		_b(a, "RailSlot%d" % i, Vector3(0.21, 0.025, 0.03), Vector3(0, 0.15, -0.52 - i * 0.07), Z, NEGRO2, "Polymer")
	_b(a, "GuardBottom", Vector3(0.07, 0.035, 0.27), Vector3(0, 0.045, -0.3), Z, NEGRO, "Polymer")
	_b(a, "GuardFront", Vector3(0.07, 0.15, 0.035), Vector3(0, 0.11, -0.43), Vector3(8, 0, 0), NEGRO, "Polymer")
	_b(a, "Trigger", Vector3(0.035, 0.11, 0.03), Vector3(0, 0.12, -0.27), Vector3(-15, 0, 0), ACERO_OSC, "Metal")
	_b(a, "Slide", Vector3(0.23, 0.24, 0.99), Vector3(0, 0.363, -0.277), Z, ACERO, "Metal")
	_b(a, "SlideTop", Vector3(0.16, 0.03, 0.97), Vector3(0, 0.49, -0.277), Z, ACERO, "Metal")
	for i in 5:
		_b(a, "Serr%d" % i, Vector3(0.236, 0.17, 0.012), Vector3(0, 0.36, 0.05 + i * 0.033), Z, NEGRO2, "Metal")
	for i in 3:
		_b(a, "SerrF%d" % i, Vector3(0.236, 0.15, 0.012), Vector3(0, 0.36, -0.6 - i * 0.035), Z, NEGRO2, "Metal")
	_b(a, "Port", Vector3(0.012, 0.09, 0.24), Vector3(0.115, 0.4, -0.24), Z, NEGRO2, "Metal")
	_b(a, "BarrelHood", Vector3(0.05, 0.075, 0.2), Vector3(0.09, 0.4, -0.24), Z, ACERO_CLARO, "Steel")
	_c(a, "MuzzleRing", 0.1, 0.03, Vector3(0, 0.37, -0.78), ACERO_OSC, "Metal")
	_c(a, "Bore", 0.055, 0.02, Vector3(0, 0.37, -0.795), NEGRO2, "Metal")
	_b(a, "FrontSight", Vector3(0.04, 0.05, 0.05), Vector3(0, 0.51, -0.72), Z, NEGRO, "Metal")
	_punto(a, "FrontDot", Vector3(0, 0.52, -0.694))
	_b(a, "RearSight", Vector3(0.17, 0.055, 0.06), Vector3(0, 0.51, 0.14), Z, NEGRO, "Metal")
	_punto(a, "RearDotL", Vector3(-0.05, 0.52, 0.108))
	_punto(a, "RearDotR", Vector3(0.05, 0.52, 0.108))
	_b(a, "SlideStop", Vector3(0.016, 0.03, 0.13), Vector3(-0.118, 0.255, -0.12), Z, NEGRO2, "Metal")
	_b(a, "MagCatch", Vector3(0.02, 0.05, 0.05), Vector3(-0.104, 0.12, -0.13), Z, NEGRO2, "Polymer")
	_b(a, "TakedownL", Vector3(0.016, 0.02, 0.07), Vector3(-0.104, 0.22, -0.38), Z, ACERO, "Metal")
	_b(a, "TakedownR", Vector3(0.016, 0.02, 0.07), Vector3(0.104, 0.22, -0.38), Z, ACERO, "Metal")
	_b(a, "MagBody", Vector3(0.15, 0.33, 0.24), Vector3(0, -0.198, 0.013), Vector3(-10, 0, 0), NEGRO, "Metal", "Mag")
	_b(a, "MagBase", Vector3(0.18, 0.05, 0.28), Vector3(0, -0.385, 0.05), Vector3(-10, 0, 0), NEGRO, "Polymer", "Mag")


## ---------------------------------------------------------------- REVÓLVER .357 (acero y madera)
static func _revolver(a: Array) -> void:
	_b(a, "Handle", Vector3(0.17, 0.48, 0.27), Vector3(0, -0.04, 0.06), Vector3(-18, 0, 0), MADERA, "Wood")
	_b(a, "GripCap", Vector3(0.15, 0.04, 0.24), Vector3(0, -0.27, 0.13), Vector3(-18, 0, 0), ACERO, "Steel")
	_b(a, "Backstrap", Vector3(0.06, 0.4, 0.03), Vector3(0, -0.01, 0.2), Vector3(-18, 0, 0), ACERO, "Steel")
	_c(a, "MedallionL", 0.06, 0.012, Vector3(-0.087, 0.0, 0.06), LATON, "Brass", "", "cylx")
	_c(a, "MedallionR", 0.06, 0.012, Vector3(0.087, 0.0, 0.06), LATON, "Brass", "", "cylx")
	_b(a, "Frame", Vector3(0.18, 0.3, 0.42), Vector3(0, 0.27, -0.18), Z, ACERO, "Steel")
	_b(a, "TopStrap", Vector3(0.12, 0.05, 0.5), Vector3(0, 0.45, -0.25), Z, ACERO, "Steel")
	_b(a, "SideplateL", Vector3(0.01, 0.16, 0.2), Vector3(-0.092, 0.22, -0.1), Z, ACERO_OSC, "Steel")
	_c(a, "Screw1", 0.03, 0.01, Vector3(0.091, 0.2, -0.05), ACERO_CLARO, "Steel", "", "cylx")
	_c(a, "Screw2", 0.03, 0.01, Vector3(0.091, 0.28, -0.2), ACERO_CLARO, "Steel", "", "cylx")
	# tambor (grupo "Mag": se abre al recargar y el cargador rápido es una copia)
	_c(a, "Cylinder", 0.32, 0.36, Vector3(0, 0.3, -0.22), ACERO, "Steel", "Mag")
	for i in 6:
		var ang := TAU * i / 6.0 + PI / 6.0
		_b(a, "Flute%d" % i, Vector3(0.05, 0.03, 0.26), Vector3(cos(ang) * 0.155, 0.3 + sin(ang) * 0.155, -0.22), Vector3(0, 0, rad_to_deg(ang) + 90), ACERO_OSC, "Steel", "Mag")
		var ang2 := TAU * i / 6.0
		_c(a, "Chamber%d" % i, 0.07, 0.012, Vector3(cos(ang2) * 0.095, 0.3 + sin(ang2) * 0.095, -0.402), NEGRO2, "Metal", "Mag")
		_c(a, "Rim%d" % i, 0.068, 0.01, Vector3(cos(ang2) * 0.095, 0.3 + sin(ang2) * 0.095, -0.038), LATON, "Brass", "Mag")
	_c(a, "Ejector", 0.08, 0.04, Vector3(0, 0.3, -0.42), ACERO_CLARO, "Steel", "Mag")
	_c(a, "Barrel", 0.13, 0.75, Vector3(0, 0.4, -0.78), ACERO, "Steel")
	_b(a, "Rib", Vector3(0.06, 0.03, 0.7), Vector3(0, 0.475, -0.78), Z, ACERO, "Steel")
	_b(a, "Underlug", Vector3(0.09, 0.13, 0.66), Vector3(0, 0.28, -0.8), Z, ACERO, "Steel")
	_c(a, "EjectorRod", 0.04, 0.04, Vector3(0, 0.28, -1.13), ACERO_CLARO, "Steel")
	_c(a, "Bore", 0.06, 0.02, Vector3(0, 0.4, -1.16), NEGRO2, "Metal")
	_b(a, "FrontSight", Vector3(0.03, 0.08, 0.12), Vector3(0, 0.5, -1.08), Vector3(15, 0, 0), ACERO, "Steel")
	_b(a, "FrontInsert", Vector3(0.032, 0.03, 0.04), Vector3(0, 0.525, -1.06), Z, ROJO, "Polymer")
	_b(a, "RearSight", Vector3(0.08, 0.04, 0.05), Vector3(0, 0.49, 0.0), Z, NEGRO, "Metal")
	_b(a, "Hammer", Vector3(0.05, 0.12, 0.08), Vector3(0, 0.44, 0.07), Vector3(25, 0, 0), ACERO_OSC, "Steel")
	_b(a, "HammerSpur", Vector3(0.05, 0.03, 0.09), Vector3(0, 0.5, 0.12), Z, ACERO_OSC, "Steel")
	_b(a, "GuardBottom", Vector3(0.06, 0.03, 0.22), Vector3(0, 0.04, -0.18), Z, ACERO, "Steel")
	_b(a, "GuardFront", Vector3(0.06, 0.14, 0.03), Vector3(0, 0.1, -0.3), Vector3(10, 0, 0), ACERO, "Steel")
	_b(a, "Trigger", Vector3(0.035, 0.12, 0.04), Vector3(0, 0.12, -0.15), Vector3(-15, 0, 0), ACERO_OSC, "Steel")
	_b(a, "Latch", Vector3(0.015, 0.05, 0.07), Vector3(-0.095, 0.33, 0.0), Z, ACERO_CLARO, "Steel")


## ---------------------------------------------------------------- SUBFUSIL (tipo MP5, culata recogida)
static func _subfusil(a: Array) -> void:
	_b(a, "Handle", Vector3(0.14, 0.38, 0.2), Vector3(0, 0, 0.01), Vector3(-15, 0, 0), NEGRO, "Polymer")
	_b(a, "GripTex", Vector3(0.145, 0.22, 0.12), Vector3(0, -0.04, 0.04), Vector3(-15, 0, 0), CAUCHO, "Rubber")
	_b(a, "Lower", Vector3(0.16, 0.16, 0.5), Vector3(0, 0.16, -0.18), Z, NEGRO, "Polymer")
	_c(a, "Receiver", 0.2, 0.95, Vector3(0, 0.33, -0.35), ACERO_OSC, "Metal")
	_b(a, "RecSeam", Vector3(0.205, 0.02, 0.9), Vector3(0, 0.28, -0.35), Z, NEGRO2, "Metal")
	_b(a, "Rail", Vector3(0.08, 0.03, 0.4), Vector3(0, 0.445, -0.25), Z, NEGRO, "Metal")
	for i in 4:
		_b(a, "RailSlot%d" % i, Vector3(0.085, 0.015, 0.02), Vector3(0, 0.46, -0.1 - i * 0.1), Z, NEGRO2, "Metal")
	_c(a, "CockTube", 0.1, 0.55, Vector3(0, 0.32, -1.0), ACERO_OSC, "Metal")
	_b(a, "CockSlot", Vector3(0.012, 0.03, 0.3), Vector3(-0.1, 0.36, -0.75), Z, NEGRO2, "Metal")
	_b(a, "CockHandle", Vector3(0.06, 0.04, 0.06), Vector3(-0.1, 0.37, -0.95), Vector3(0, 0, -30), NEGRO, "Polymer")
	_b(a, "Handguard", Vector3(0.2, 0.2, 0.42), Vector3(0, 0.25, -0.98), Z, NEGRO, "Polymer")
	for i in 4:
		_b(a, "Rib%d" % i, Vector3(0.205, 0.015, 0.025), Vector3(0, 0.2, -0.82 - i * 0.1), Z, NEGRO2, "Polymer")
	_c(a, "Barrel", 0.07, 0.18, Vector3(0, 0.32, -1.27), ACERO_OSC, "Steel")
	_c(a, "Hider", 0.09, 0.08, Vector3(0, 0.32, -1.38), NEGRO, "Metal")
	_c(a, "Bore", 0.045, 0.02, Vector3(0, 0.32, -1.425), NEGRO2, "Metal")
	_b(a, "FSHood", Vector3(0.11, 0.13, 0.06), Vector3(0, 0.46, -1.18), Z, NEGRO, "Metal")
	_b(a, "FSPost", Vector3(0.02, 0.06, 0.02), Vector3(0, 0.46, -1.18), Z, ACERO, "Metal")
	_punto(a, "FSDot", Vector3(0, 0.49, -1.15))
	_b(a, "RearBase", Vector3(0.1, 0.06, 0.1), Vector3(0, 0.45, -0.05), Z, NEGRO, "Metal")
	_c(a, "RearDrum", 0.1, 0.08, Vector3(0, 0.52, -0.05), ACERO_OSC, "Metal", "", "cylx")
	_b(a, "GuardBottom", Vector3(0.06, 0.03, 0.22), Vector3(0, 0.06, -0.14), Z, NEGRO, "Polymer")
	_b(a, "GuardFront", Vector3(0.06, 0.12, 0.03), Vector3(0, 0.11, -0.25), Z, NEGRO, "Polymer")
	_b(a, "Trigger", Vector3(0.03, 0.1, 0.03), Vector3(0, 0.12, -0.13), Vector3(-10, 0, 0), ACERO_OSC, "Metal")
	_b(a, "Selector", Vector3(0.015, 0.04, 0.08), Vector3(-0.085, 0.22, -0.02), Z, ACERO_CLARO, "Metal")
	_b(a, "Magwell", Vector3(0.14, 0.12, 0.22), Vector3(0, 0.13, -0.5), Z, ACERO_OSC, "Metal")
	_b(a, "MagUpper", Vector3(0.11, 0.28, 0.17), Vector3(0, -0.08, -0.5), Vector3(10, 0, 0), ACERO_OSC, "Metal", "Mag")
	_b(a, "MagLower", Vector3(0.11, 0.26, 0.17), Vector3(0, -0.33, -0.57), Vector3(24, 0, 0), ACERO_OSC, "Metal", "Mag")
	_b(a, "MagRibL", Vector3(0.115, 0.02, 0.12), Vector3(0, -0.22, -0.53), Vector3(16, 0, 0), NEGRO2, "Metal", "Mag")
	_b(a, "MagBase", Vector3(0.13, 0.04, 0.19), Vector3(0, -0.46, -0.63), Vector3(24, 0, 0), NEGRO, "Polymer", "Mag")
	_c(a, "StockRodL", 0.04, 0.55, Vector3(-0.07, 0.3, 0.25), ACERO, "Steel")
	_c(a, "StockRodR", 0.04, 0.55, Vector3(0.07, 0.3, 0.25), ACERO, "Steel")
	_b(a, "Butt", Vector3(0.18, 0.3, 0.05), Vector3(0, 0.27, 0.52), Z, CAUCHO, "Rubber")
	_b(a, "Sling", Vector3(0.02, 0.05, 0.05), Vector3(0.11, 0.33, -0.9), Z, ACERO, "Metal")


## ---------------------------------------------------------------- RIFLE DE ASALTO (tipo AR-15)
static func _rifle(a: Array) -> void:
	_b(a, "Handle", Vector3(0.15, 0.4, 0.22), Vector3(0, 0, 0.01), Vector3(-18, 0, 0), NEGRO, "Polymer")
	_b(a, "GripTexL", Vector3(0.01, 0.26, 0.16), Vector3(-0.076, -0.03, 0.02), Vector3(-18, 0, 0), CAUCHO, "Rubber")
	_b(a, "GripTexR", Vector3(0.01, 0.26, 0.16), Vector3(0.076, -0.03, 0.02), Vector3(-18, 0, 0), CAUCHO, "Rubber")
	_b(a, "Lower", Vector3(0.19, 0.2, 0.62), Vector3(0, 0.17, -0.27), Z, ANODIZADO, "Metal")
	_b(a, "Magwell", Vector3(0.17, 0.16, 0.27), Vector3(0, 0.05, -0.5), Vector3(-6, 0, 0), ANODIZADO, "Metal")
	_b(a, "MagRelease", Vector3(0.02, 0.04, 0.04), Vector3(0.1, 0.13, -0.38), Z, ACERO_OSC, "Metal")
	_b(a, "BoltRelease", Vector3(0.015, 0.08, 0.03), Vector3(-0.1, 0.24, -0.4), Z, ACERO_OSC, "Metal")
	_b(a, "Selector", Vector3(0.015, 0.04, 0.09), Vector3(-0.1, 0.24, -0.04), Z, ACERO_OSC, "Metal")
	_b(a, "Upper", Vector3(0.18, 0.18, 0.84), Vector3(0, 0.355, -0.34), Z, ANODIZADO, "Metal")
	_b(a, "RailTop", Vector3(0.12, 0.035, 0.84), Vector3(0, 0.46, -0.34), Z, ANODIZADO, "Metal")
	for i in 7:
		_b(a, "RailSlot%d" % i, Vector3(0.125, 0.02, 0.022), Vector3(0, 0.475, -0.02 - i * 0.11), Z, NEGRO2, "Metal")
	_b(a, "Port", Vector3(0.01, 0.09, 0.25), Vector3(0.092, 0.35, -0.25), Z, NEGRO2, "Metal")
	_c(a, "FwdAssist", 0.06, 0.12, Vector3(0.1, 0.4, -0.02), ANODIZADO, "Metal")
	_b(a, "ChargeH", Vector3(0.17, 0.04, 0.12), Vector3(0, 0.45, 0.1), Z, ANODIZADO, "Metal")
	_b(a, "ChargeLatch", Vector3(0.05, 0.03, 0.05), Vector3(-0.1, 0.45, 0.12), Z, ANODIZADO, "Metal")
	_b(a, "GuardBottom", Vector3(0.06, 0.03, 0.24), Vector3(0, 0.06, -0.15), Z, ANODIZADO, "Metal")
	_b(a, "GuardFront", Vector3(0.06, 0.12, 0.03), Vector3(0, 0.11, -0.27), Z, ANODIZADO, "Metal")
	_b(a, "Trigger", Vector3(0.03, 0.1, 0.03), Vector3(0, 0.12, -0.14), Vector3(-10, 0, 0), ACERO_CLARO, "Steel")
	# cargador curvo (grupo "Mag": cae al recargar)
	_b(a, "MagUpper", Vector3(0.135, 0.3, 0.21), Vector3(0, -0.06, -0.5), Vector3(-10, 0, 0), NEGRO, "Metal", "Mag")
	_b(a, "MagLower", Vector3(0.135, 0.28, 0.21), Vector3(0, -0.33, -0.56), Vector3(-22, 0, 0), NEGRO, "Metal", "Mag")
	_b(a, "MagRib", Vector3(0.14, 0.02, 0.15), Vector3(0, -0.2, -0.53), Vector3(-16, 0, 0), NEGRO2, "Metal", "Mag")
	_b(a, "MagBase", Vector3(0.15, 0.05, 0.24), Vector3(0, -0.47, -0.6), Vector3(-22, 0, 0), NEGRO, "Polymer", "Mag")
	# culata
	_c(a, "Buffer", 0.13, 0.6, Vector3(0, 0.33, 0.32), ANODIZADO, "Metal")
	_b(a, "Stock", Vector3(0.15, 0.28, 0.48), Vector3(0, 0.26, 0.72), Z, NEGRO, "Polymer")
	_b(a, "StockTop", Vector3(0.13, 0.06, 0.42), Vector3(0, 0.42, 0.72), Z, NEGRO, "Polymer")
	_b(a, "StockBottom", Vector3(0.12, 0.1, 0.3), Vector3(0, 0.08, 0.78), Vector3(10, 0, 0), NEGRO, "Polymer")
	_b(a, "ButtPad", Vector3(0.16, 0.36, 0.05), Vector3(0, 0.24, 0.98), Z, CAUCHO, "Rubber")
	_b(a, "StockLatch", Vector3(0.05, 0.03, 0.12), Vector3(0, 0.13, 0.6), Z, NEGRO2, "Polymer")
	# guardamanos con carriles y ventilación
	_c(a, "Handguard", 0.24, 0.72, Vector3(0, 0.3, -1.15), ANODIZADO, "Metal")
	_b(a, "HGRailTop", Vector3(0.1, 0.03, 0.7), Vector3(0, 0.43, -1.15), Z, ANODIZADO, "Metal")
	_b(a, "HGRailL", Vector3(0.03, 0.1, 0.62), Vector3(-0.13, 0.3, -1.15), Z, ANODIZADO, "Metal")
	_b(a, "HGRailR", Vector3(0.03, 0.1, 0.62), Vector3(0.13, 0.3, -1.15), Z, ANODIZADO, "Metal")
	for i in 4:
		_b(a, "VentL%d" % i, Vector3(0.012, 0.05, 0.09), Vector3(-0.121, 0.22, -0.92 - i * 0.15), Z, NEGRO2, "Metal")
		_b(a, "VentR%d" % i, Vector3(0.012, 0.05, 0.09), Vector3(0.121, 0.22, -0.92 - i * 0.15), Z, NEGRO2, "Metal")
	_c(a, "Foregrip", 0.1, 0.3, Vector3(0, 0.07, -0.84), NEGRO, "Polymer", "", "cyly")
	# cañón, punto de mira y freno de boca
	_c(a, "Barrel", 0.075, 0.72, Vector3(0, 0.3, -1.79), ACERO_OSC, "Steel")
	_b(a, "GasBlock", Vector3(0.1, 0.1, 0.06), Vector3(0, 0.32, -1.55), Z, NEGRO, "Metal")
	_b(a, "FSBase", Vector3(0.06, 0.06, 0.06), Vector3(0, 0.39, -1.55), Z, NEGRO, "Metal")
	_b(a, "FSPost", Vector3(0.025, 0.12, 0.025), Vector3(0, 0.47, -1.55), Z, NEGRO, "Metal")
	_b(a, "FSEarL", Vector3(0.012, 0.1, 0.03), Vector3(-0.05, 0.46, -1.55), Z, NEGRO, "Metal")
	_b(a, "FSEarR", Vector3(0.012, 0.1, 0.03), Vector3(0.05, 0.46, -1.55), Z, NEGRO, "Metal")
	_c(a, "Brake", 0.11, 0.16, Vector3(0, 0.3, -2.06), NEGRO, "Metal")
	_b(a, "BrakePort", Vector3(0.115, 0.03, 0.04), Vector3(0, 0.33, -2.06), Z, NEGRO2, "Metal")
	_c(a, "Bore", 0.045, 0.02, Vector3(0, 0.3, -2.145), NEGRO2, "Metal")
	# mira de punto rojo
	_b(a, "OpticBase", Vector3(0.11, 0.05, 0.2), Vector3(0, 0.5, -0.3), Z, NEGRO, "Metal")
	_c(a, "OpticTube", 0.13, 0.22, Vector3(0, 0.6, -0.3), NEGRO, "Metal")
	_c(a, "OpticLens", 0.11, 0.01, Vector3(0, 0.6, -0.415), LENTE, "Glass")
	_c(a, "OpticEye", 0.11, 0.01, Vector3(0, 0.6, -0.185), LENTE, "Glass")
	_b(a, "OpticTurret", Vector3(0.05, 0.05, 0.05), Vector3(0.08, 0.6, -0.3), Z, NEGRO, "Metal")
	_punto(a, "OpticDot", Vector3(0, 0.6, -0.3), ROJO_GLOW)
	_b(a, "SlingLoop", Vector3(0.02, 0.06, 0.06), Vector3(0, 0.1, 0.92), Z, ACERO, "Metal")


## ---------------------------------------------------------------- ESCOPETA DE CORREDERA (madera)
static func _escopeta(a: Array) -> void:
	_b(a, "Handle", Vector3(0.15, 0.36, 0.22), Vector3(0, 0.0, 0.03), Vector3(-25, 0, 0), MADERA, "Wood")
	_b(a, "Checker", Vector3(0.155, 0.18, 0.12), Vector3(0, 0.02, 0.03), Vector3(-25, 0, 0), MADERA_OSC, "Wood")
	_b(a, "Receiver", Vector3(0.2, 0.3, 0.8), Vector3(0, 0.3, -0.35), Z, PAVONADO, "Metal")
	_b(a, "RecTop", Vector3(0.16, 0.04, 0.78), Vector3(0, 0.465, -0.35), Z, PAVONADO, "Metal")
	_b(a, "Port", Vector3(0.012, 0.12, 0.3), Vector3(0.101, 0.33, -0.3), Z, NEGRO2, "Metal")
	_b(a, "LoadPort", Vector3(0.12, 0.012, 0.35), Vector3(0, 0.148, -0.45), Z, NEGRO2, "Metal")
	_b(a, "Safety", Vector3(0.05, 0.025, 0.06), Vector3(0, 0.48, 0.02), Z, ACERO_CLARO, "Steel")
	_b(a, "GuardBottom", Vector3(0.06, 0.03, 0.24), Vector3(0, 0.07, -0.15), Z, PAVONADO, "Metal")
	_b(a, "GuardFront", Vector3(0.06, 0.12, 0.03), Vector3(0, 0.12, -0.27), Z, PAVONADO, "Metal")
	_b(a, "Trigger", Vector3(0.03, 0.1, 0.03), Vector3(0, 0.13, -0.14), Vector3(-10, 0, 0), LATON, "Brass")
	_c(a, "Barrel", 0.11, 1.45, Vector3(0, 0.38, -1.47), PAVONADO, "Steel")
	_b(a, "Rib", Vector3(0.04, 0.02, 1.38), Vector3(0, 0.445, -1.45), Z, PAVONADO, "Steel")
	_e(a, "Bead", 0.035, Vector3(0, 0.465, -2.13), LATON, "Brass")
	_c(a, "Bore", 0.08, 0.02, Vector3(0, 0.38, -2.19), NEGRO2, "Metal")
	_c(a, "MagTube", 0.1, 1.15, Vector3(0, 0.24, -1.3), PAVONADO, "Steel")
	_c(a, "TubeCap", 0.115, 0.07, Vector3(0, 0.24, -1.9), ACERO, "Steel")
	_b(a, "Clamp", Vector3(0.12, 0.24, 0.06), Vector3(0, 0.31, -1.8), Z, PAVONADO, "Metal")
	# corredera (grupo "Pump": va y vuelve tras cada disparo; la mano izquierda va con ella)
	_c(a, "Forend", 0.2, 0.55, Vector3(0, 0.24, -1.0), MADERA, "Wood", "Pump")
	for i in 5:
		_c(a, "Groove%d" % i, 0.206, 0.02, Vector3(0, 0.24, -0.82 - i * 0.09), MADERA_OSC, "Wood", "Pump")
	_b(a, "ActionBarL", Vector3(0.02, 0.03, 0.45), Vector3(-0.08, 0.3, -0.62), Z, ACERO, "Steel", "Pump")
	# culata
	_b(a, "StockWrist", Vector3(0.14, 0.25, 0.35), Vector3(0, 0.15, 0.24), Vector3(-12, 0, 0), MADERA, "Wood")
	_b(a, "Stock", Vector3(0.15, 0.36, 0.6), Vector3(0, 0.13, 0.63), Vector3(-6, 0, 0), MADERA, "Wood")
	_b(a, "Comb", Vector3(0.13, 0.06, 0.5), Vector3(0, 0.33, 0.6), Vector3(-4, 0, 0), MADERA, "Wood")
	_b(a, "ButtPad", Vector3(0.16, 0.42, 0.06), Vector3(0, 0.12, 0.95), Vector3(-6, 0, 0), CAUCHO, "Rubber")
	_b(a, "SwivelRear", Vector3(0.02, 0.05, 0.05), Vector3(0, -0.07, 0.8), Z, ACERO, "Metal")
	# cartuchera lateral con 4 cartuchos
	_b(a, "Saddle", Vector3(0.015, 0.17, 0.38), Vector3(-0.108, 0.31, -0.33), Z, NEGRO, "Polymer")
	for i in 4:
		var z := -0.47 + i * 0.09
		_c(a, "Shell%d" % i, 0.065, 0.19, Vector3(-0.145, 0.33, z), ROJO, "Polymer", "", "cyly")
		_c(a, "ShellBase%d" % i, 0.068, 0.045, Vector3(-0.145, 0.215, z), LATON, "Brass", "", "cyly")


## ---------------------------------------------------------------- FUSIL DE FRANCOTIRADOR (cerrojo)
static func _francotirador(a: Array) -> void:
	_b(a, "Handle", Vector3(0.15, 0.38, 0.22), Vector3(0, 0, 0.01), Vector3(-15, 0, 0), NEGRO, "Polymer")
	_b(a, "Chassis", Vector3(0.18, 0.2, 0.85), Vector3(0, 0.2, -0.35), Z, OLIVA, "Polymer")
	_c(a, "Receiver", 0.2, 0.8, Vector3(0, 0.36, -0.32), PAVONADO, "Metal")
	_b(a, "Port", Vector3(0.012, 0.09, 0.28), Vector3(0.1, 0.38, -0.2), Z, NEGRO2, "Metal")
	# cerrojo (grupo "Bolt": se acciona tras cada disparo)
	_c(a, "BoltBody", 0.13, 0.3, Vector3(0, 0.36, 0.12), ACERO_CLARO, "Steel", "Bolt")
	_c(a, "BoltArm", 0.035, 0.22, Vector3(0.11, 0.33, 0.1), ACERO_CLARO, "Steel", "Bolt", "cylx")
	_e(a, "BoltKnob", 0.085, Vector3(0.23, 0.3, 0.1), NEGRO, "Polymer", "Bolt")
	_b(a, "GuardBottom", Vector3(0.06, 0.03, 0.24), Vector3(0, 0.07, -0.15), Z, NEGRO, "Metal")
	_b(a, "GuardFront", Vector3(0.06, 0.12, 0.03), Vector3(0, 0.12, -0.27), Z, NEGRO, "Metal")
	_b(a, "Trigger", Vector3(0.03, 0.1, 0.03), Vector3(0, 0.13, -0.14), Vector3(-10, 0, 0), ACERO_CLARO, "Steel")
	_b(a, "Safety", Vector3(0.015, 0.04, 0.08), Vector3(0.1, 0.27, 0.05), Z, ACERO_CLARO, "Steel")
	# cañón estriado y freno de boca
	_c(a, "Barrel", 0.11, 1.6, Vector3(0, 0.36, -1.52), PAVONADO, "Steel")
	_b(a, "FluteT", Vector3(0.012, 0.012, 1.1), Vector3(0, 0.416, -1.6), Z, NEGRO2, "Steel")
	_b(a, "FluteL", Vector3(0.012, 0.012, 1.1), Vector3(-0.056, 0.36, -1.6), Z, NEGRO2, "Steel")
	_b(a, "FluteR", Vector3(0.012, 0.012, 1.1), Vector3(0.056, 0.36, -1.6), Z, NEGRO2, "Steel")
	_b(a, "Brake", Vector3(0.14, 0.11, 0.22), Vector3(0, 0.36, -2.4), Z, NEGRO, "Metal")
	for i in 3:
		_b(a, "BrakePort%d" % i, Vector3(0.145, 0.06, 0.025), Vector3(0, 0.36, -2.33 - i * 0.06), Z, NEGRO2, "Metal")
	_c(a, "Bore", 0.05, 0.02, Vector3(0, 0.36, -2.515), NEGRO2, "Metal")
	# guardamanos y bípode plegado
	_b(a, "Forend", Vector3(0.2, 0.2, 0.75), Vector3(0, 0.26, -1.05), Z, OLIVA, "Polymer")
	for i in 3:
		_b(a, "SlotL%d" % i, Vector3(0.01, 0.04, 0.1), Vector3(-0.101, 0.26, -0.82 - i * 0.18), Z, NEGRO2, "Polymer")
		_b(a, "SlotR%d" % i, Vector3(0.01, 0.04, 0.1), Vector3(0.101, 0.26, -0.82 - i * 0.18), Z, NEGRO2, "Polymer")
	_b(a, "BipodBase", Vector3(0.12, 0.06, 0.08), Vector3(0, 0.14, -1.38), Z, NEGRO, "Metal")
	_c(a, "BipodL", 0.04, 0.55, Vector3(-0.05, 0.12, -1.1), NEGRO, "Metal")
	_c(a, "BipodR", 0.04, 0.55, Vector3(0.05, 0.12, -1.1), NEGRO, "Metal")
	_e(a, "BipodFootL", 0.06, Vector3(-0.05, 0.12, -0.83), CAUCHO, "Rubber")
	_e(a, "BipodFootR", 0.06, Vector3(0.05, 0.12, -0.83), CAUCHO, "Rubber")
	# mira telescópica
	_b(a, "Ring1", Vector3(0.17, 0.12, 0.06), Vector3(0, 0.55, -0.1), Z, NEGRO, "Metal")
	_b(a, "Ring2", Vector3(0.17, 0.12, 0.06), Vector3(0, 0.55, -0.6), Z, NEGRO, "Metal")
	_c(a, "ScopeTube", 0.13, 0.75, Vector3(0, 0.64, -0.35), NEGRO, "Metal")
	_cono(a, "Objective", 0.22, 0.13, 0.25, Vector3(0, 0.64, -0.84), NEGRO, "Metal")
	_c(a, "ObjLens", 0.2, 0.01, Vector3(0, 0.64, -0.97), LENTE, "Glass")
	_c(a, "ZoomRing", 0.16, 0.06, Vector3(0, 0.64, 0.0), NEGRO2, "Rubber")
	_cono(a, "Ocular", 0.13, 0.17, 0.2, Vector3(0, 0.64, 0.12), NEGRO, "Metal")
	_c(a, "EyeLens", 0.15, 0.01, Vector3(0, 0.64, 0.225), LENTE, "Glass")
	_c(a, "TurretUp", 0.09, 0.08, Vector3(0, 0.74, -0.35), NEGRO, "Metal", "", "cyly")
	_c(a, "TurretSide", 0.09, 0.08, Vector3(0.1, 0.64, -0.35), NEGRO, "Metal", "", "cylx")
	# culata con carrillera
	_b(a, "Stock", Vector3(0.15, 0.32, 0.62), Vector3(0, 0.22, 0.55), Z, OLIVA, "Polymer")
	_b(a, "Thumbhole", Vector3(0.155, 0.12, 0.14), Vector3(0, 0.15, 0.3), Z, NEGRO2, "Polymer")
	_b(a, "Cheek", Vector3(0.12, 0.08, 0.4), Vector3(0, 0.42, 0.52), Z, NEGRO, "Polymer")
	_b(a, "ButtPad", Vector3(0.16, 0.38, 0.05), Vector3(0, 0.2, 0.88), Z, CAUCHO, "Rubber")
	# cargador (grupo "Mag")
	_b(a, "MagBody", Vector3(0.12, 0.24, 0.28), Vector3(0, -0.04, -0.45), Z, NEGRO, "Metal", "Mag")
	_b(a, "MagBase", Vector3(0.13, 0.04, 0.3), Vector3(0, -0.17, -0.45), Z, NEGRO, "Polymer", "Mag")


## ---------------------------------------------------------------- CUCHILLO DE COMBATE
static func _cuchillo(a: Array) -> void:
	_b(a, "Handle", Vector3(0.13, 0.17, 0.42), Z, Z, CAUCHO, "Rubber")
	for i in 4:
		_b(a, "Ring%d" % i, Vector3(0.136, 0.176, 0.02), Vector3(0, 0, -0.15 + i * 0.1), Z, NEGRO2, "Rubber")
	_b(a, "Pommel", Vector3(0.15, 0.18, 0.06), Vector3(0, 0, 0.23), Z, ACERO_OSC, "Steel")
	_b(a, "Lanyard", Vector3(0.155, 0.04, 0.03), Vector3(0, 0, 0.24), Z, NEGRO2, "Steel")
	_b(a, "Guard", Vector3(0.16, 0.3, 0.05), Vector3(0, 0.01, -0.235), Z, ACERO_OSC, "Steel")
	_b(a, "Blade", Vector3(0.03, 0.17, 0.58), Vector3(0, 0.01, -0.55), Z, ACERO_CLARO, "Steel")
	_b(a, "Edge", Vector3(0.018, 0.05, 0.58), Vector3(0, -0.075, -0.55), Z, CROMO, "Steel")
	_b(a, "Fuller", Vector3(0.032, 0.025, 0.4), Vector3(0, 0.05, -0.5), Z, ACERO, "Steel")
	_b(a, "Spine", Vector3(0.035, 0.03, 0.5), Vector3(0, 0.1, -0.5), Z, ACERO, "Steel")
	for i in 6:
		_b(a, "Serr%d" % i, Vector3(0.036, 0.025, 0.025), Vector3(0, 0.118, -0.3 - i * 0.045), Vector3(45, 0, 0), ACERO, "Steel")
	# punta: un rombo al final de la hoja (el filo sube y el lomo baja hasta la punta)
	_b(a, "Tip", Vector3(0.03, 0.12, 0.12), Vector3(0, 0.0, -0.84), Vector3(45, 0, 0), ACERO_CLARO, "Steel")
	_b(a, "TipEdge", Vector3(0.018, 0.03, 0.12), Vector3(0, -0.05, -0.86), Vector3(30, 0, 0), CROMO, "Steel")


## ---------------------------------------------------------------- MACHETE
static func _machete(a: Array) -> void:
	_b(a, "Handle", Vector3(0.15, 0.19, 0.55), Z, Z, MADERA_OSC, "Wood")
	_b(a, "Tang", Vector3(0.04, 0.2, 0.56), Z, Z, ACERO_OSC, "Steel")
	for i in 3:
		_c(a, "Rivet%d" % i, 0.05, 0.16, Vector3(0, 0, -0.18 + i * 0.18), LATON, "Brass", "", "cylx")
	_b(a, "Pommel", Vector3(0.15, 0.22, 0.08), Vector3(0, -0.02, 0.29), Vector3(-15, 0, 0), ACERO_OSC, "Steel")
	_b(a, "Guard", Vector3(0.17, 0.25, 0.06), Vector3(0, 0.025, -0.29), Z, ACERO_OSC, "Steel")
	_b(a, "Blade", Vector3(0.035, 0.27, 1.2), Vector3(0, 0.04, -0.88), Z, Color8(150, 152, 150), "Steel")
	_b(a, "Belly", Vector3(0.035, 0.3, 0.35), Vector3(0, 0.01, -1.38), Z, Color8(150, 152, 150), "Steel")
	_b(a, "Tip", Vector3(0.035, 0.21, 0.21), Vector3(0, 0.02, -1.55), Vector3(45, 0, 0), Color8(150, 152, 150), "Steel")
	_b(a, "Edge", Vector3(0.02, 0.04, 1.3), Vector3(0, -0.105, -0.95), Z, CROMO, "Steel")
	_b(a, "EdgeTip", Vector3(0.02, 0.035, 0.16), Vector3(0, -0.09, -1.6), Vector3(40, 0, 0), CROMO, "Steel")
	_b(a, "Spine", Vector3(0.037, 0.02, 1.15), Vector3(0, 0.18, -0.85), Z, ACERO_OSC, "Steel")
	_b(a, "Mark", Vector3(0.037, 0.05, 0.12), Vector3(0, 0.07, -0.5), Z, ACERO_OSC, "Steel")
	_b(a, "Rust1", Vector3(0.037, 0.08, 0.1), Vector3(0, 0.1, -1.2), Z, OXIDO, "Metal")
	_b(a, "Rust2", Vector3(0.037, 0.05, 0.14), Vector3(0, -0.02, -0.75), Z, OXIDO, "Metal")


## ---------------------------------------------------------------- BATE CON CLAVOS
static func _bate(a: Array) -> void:
	_b(a, "Handle", Vector3(0.18, 0.18, 0.78), Z, Z, Color8(35, 30, 28), "Fabric")
	for i in 3:
		_c(a, "Wrap%d" % i, 0.19, 0.03, Vector3(0, 0, -0.25 + i * 0.25), NEGRO2, "Fabric")
	_c(a, "Knob", 0.27, 0.09, Vector3(0, 0, 0.42), Color8(150, 110, 70), "Wood")
	_cono(a, "Body", 0.34, 0.2, 1.92, Vector3(0, 0, -1.32), Color8(150, 110, 70), "Wood")
	_c(a, "EndCap", 0.32, 0.03, Vector3(0, 0, -2.28), Color8(130, 95, 60), "Wood")
	_c(a, "Tape", 0.29, 0.14, Vector3(0, 0, -0.95), Color8(150, 150, 150), "Fabric")
	_b(a, "Label", Vector3(0.02, 0.08, 0.3), Vector3(0.135, 0, -1.4), Z, Color8(30, 30, 30), "Plastic")
	for i in 8:
		var z := -1.15 - i * 0.13
		var ang := 35.0 + i * 47.0
		_b(a, "Nail%d" % i, Vector3(0.03, 0.52, 0.03), Vector3(0, 0, z), Vector3(0, 0, ang), Color8(120, 120, 120), "Metal")
		var r := 0.26
		_e(a, "NailHead%d" % i, 0.05, Vector3(-sin(deg_to_rad(ang)) * r, cos(deg_to_rad(ang)) * r, z), Color8(95, 95, 95), "Metal")
	_b(a, "Blood1", Vector3(0.2, 0.06, 0.25), Vector3(0, 0.15, -1.9), Vector3(0, 0, 20), SANGRE, "Plastic")
	_b(a, "Blood2", Vector3(0.06, 0.18, 0.2), Vector3(-0.15, 0, -1.6), Z, SANGRE, "Plastic")


## ---------------------------------------------------------------- HACHA DE BOMBERO (a dos manos)
static func _hacha(a: Array) -> void:
	_b(a, "Shaft", Vector3(0.13, 0.16, 2.0), Vector3(0, 0, -0.75), Z, MADERA, "Wood")
	_b(a, "Grip", Vector3(0.15, 0.18, 0.5), Vector3(0, 0, 0.05), Z, CAUCHO, "Rubber")
	_b(a, "Knob", Vector3(0.16, 0.21, 0.08), Vector3(0, 0, 0.3), Z, CAUCHO, "Rubber")
	_b(a, "Stripe", Vector3(0.135, 0.165, 0.12), Vector3(0, 0, -1.2), Z, Color8(210, 170, 30), "Plastic")
	_b(a, "Eye", Vector3(0.2, 0.26, 0.24), Vector3(0, 0, -1.68), Z, ROJO, "Metal")
	_b(a, "Blade", Vector3(0.06, 0.26, 0.26), Vector3(0, -0.24, -1.68), Z, ROJO, "Metal")
	_b(a, "BladeFlare", Vector3(0.045, 0.16, 0.4), Vector3(0, -0.42, -1.68), Z, ROJO, "Metal")
	_b(a, "FlareF", Vector3(0.045, 0.12, 0.1), Vector3(0, -0.4, -1.85), Vector3(-35, 0, 0), ROJO, "Metal")
	_b(a, "FlareB", Vector3(0.045, 0.12, 0.1), Vector3(0, -0.4, -1.51), Vector3(35, 0, 0), ROJO, "Metal")
	_b(a, "Edge", Vector3(0.03, 0.05, 0.46), Vector3(0, -0.52, -1.68), Z, CROMO, "Steel")
	_b(a, "Pick", Vector3(0.07, 0.24, 0.1), Vector3(0, 0.24, -1.68), Z, ROJO, "Metal")
	_b(a, "PickTip", Vector3(0.05, 0.12, 0.06), Vector3(0, 0.41, -1.68), Z, CROMO, "Steel")
	_b(a, "Wedge", Vector3(0.14, 0.03, 0.05), Vector3(0, 0.0, -1.81), Z, ACERO, "Steel")
	_b(a, "Chip", Vector3(0.055, 0.1, 0.1), Vector3(0, -0.3, -1.6), Z, ACERO, "Metal")


## ---------------------------------------------------------------- PALANCA (pata de cabra)
static func _palanca(a: Array) -> void:
	_c(a, "Bar", 0.1, 1.7, Vector3(0, 0, -0.6), ROJO_OSC, "Metal", "", "hexz")
	_c(a, "Tape", 0.115, 0.42, Vector3(0, 0, 0.05), NEGRO, "Rubber")
	_c(a, "Wear1", 0.102, 0.08, Vector3(0, 0, -0.9), ACERO, "Metal", "", "hexz")
	_c(a, "Wear2", 0.102, 0.05, Vector3(0, 0, -1.25), ACERO, "Metal", "", "hexz")
	_c(a, "Neck1", 0.1, 0.3, Vector3(0, -0.07, -1.55), ROJO_OSC, "Metal", "", "hexz", Vector3(-35, 0, 0))
	_c(a, "Neck2", 0.1, 0.28, Vector3(0, -0.27, -1.66), ROJO_OSC, "Metal", "", "hexz", Vector3(-75, 0, 0))
	_c(a, "Neck3", 0.1, 0.22, Vector3(0, -0.43, -1.6), ROJO_OSC, "Metal", "", "hexz", Vector3(-130, 0, 0))
	_b(a, "Claw", Vector3(0.12, 0.04, 0.16), Vector3(0, -0.47, -1.49), Vector3(-20, 0, 0), ACERO, "Steel")
	_b(a, "ClawSlot", Vector3(0.03, 0.045, 0.1), Vector3(0, -0.47, -1.46), Vector3(-20, 0, 0), NEGRO2, "Steel")
	_b(a, "Chisel", Vector3(0.12, 0.03, 0.18), Vector3(0, 0.02, 0.36), Vector3(-15, 0, 0), ACERO, "Steel")
