class_name Armas
## Datos de las armas (port de ZConfig.Weapons / Slots / Loadout / Holsters del juego de Roblox),
## modelos (las mismas piezas que las Tools de ServerStorage.Weapons) y las poses procedurales
## del ProceduralAnimator (POSE, DRAW, MELEE, RELOAD). Todo en studs.

const D2R := PI / 180.0

## ---------------------------------------------------------------- configuración
const WEAPONS := {
	"Pistola": {
		"Kind": "Gun", "Sound": "Pistol", "Damage": 34.0, "HeadMult": 3.0, "LimbMult": 0.7,
		"RPM": 320.0, "Auto": false, "Mag": 12, "StartReserve": 48, "MaxReserve": 96,
		"Reload": 1.7, "HipSpread": 2.6, "AimSpread": 0.5, "Recoil": 2.2, "RecoilYaw": 0.6,
		"Range": 450.0, "Alert": 180.0, "Slot": "Corta", "DrawTime": 0.55, "Tip": "Pistola 9mm", "UnaMano": true,
	},
	"Rifle": {
		"Kind": "Gun", "Sound": "Rifle", "Damage": 30.0, "HeadMult": 3.0, "LimbMult": 0.7,
		"RPM": 620.0, "Auto": true, "Mag": 30, "StartReserve": 60, "MaxReserve": 180,
		"Reload": 2.5, "HipSpread": 4.2, "AimSpread": 0.9, "Recoil": 1.25, "RecoilYaw": 0.8,
		"Range": 700.0, "Alert": 260.0, "Slot": "Larga", "DrawTime": 0.85, "Tip": "Rifle de asalto",
	},
	"Cuchillo": {
		"Kind": "Melee", "Damage": 42.0, "HeadMult": 2.2, "Range": 5.5, "Cooldown": 0.5, "Stamina": 7.0,
		"Knockback": 6.0, "Stagger": 0.35, "Sound": "Flesh", "Slot": "BlancaCorta", "DrawTime": 0.45,
		"HitTime": 0.16, "Tip": "Cuchillo",
	},
	"Machete": {
		"Kind": "Melee", "Damage": 55.0, "HeadMult": 1.6, "Range": 7.5, "Cooldown": 0.75, "Stamina": 12.0,
		"Knockback": 18.0, "Stagger": 0.45, "Sound": "Flesh", "Slot": "BlancaLarga", "DrawTime": 0.75,
		"HitTime": 0.26, "Tip": "Machete",
	},
	"Bate": {
		"Kind": "Melee", "Damage": 38.0, "HeadMult": 1.8, "Range": 8.0, "Cooldown": 0.95, "Stamina": 16.0,
		"Knockback": 45.0, "Stagger": 1.2, "Sound": "Blunt", "Slot": "BlancaLarga", "DrawTime": 0.8,
		"HitTime": 0.36, "Tip": "Bate con clavos", "DosManos": true, "Derriba": 0.45,
	},
	## ---- v0.4: armas nuevas ("Base" = arma de la que toma poses y animaciones si no tiene las suyas)
	"Revolver": {
		"Kind": "Gun", "Base": "Pistola", "Sound": "Revolver", "Damage": 58.0, "HeadMult": 3.0, "LimbMult": 0.75,
		"RPM": 150.0, "Auto": false, "Mag": 6, "StartReserve": 24, "MaxReserve": 48,
		"Reload": 2.4, "HipSpread": 2.8, "AimSpread": 0.35, "Recoil": 4.2, "RecoilYaw": 0.9,
		"Range": 500.0, "Alert": 240.0, "Slot": "Corta", "DrawTime": 0.6, "Tip": "Revólver .357", "UnaMano": true,
	},
	"Subfusil": {
		"Kind": "Gun", "Base": "Rifle", "Sound": "SMG", "Damage": 21.0, "HeadMult": 2.6, "LimbMult": 0.7,
		"RPM": 850.0, "Auto": true, "Mag": 32, "StartReserve": 64, "MaxReserve": 192,
		"Reload": 2.1, "HipSpread": 3.6, "AimSpread": 1.2, "Recoil": 0.85, "RecoilYaw": 1.0,
		"Range": 380.0, "Alert": 200.0, "Slot": "Corta", "DrawTime": 0.65, "Tip": "Subfusil", "UnaMano": true,
	},
	"Escopeta": {
		"Kind": "Gun", "Base": "Rifle", "Sound": "Shotgun", "Damage": 15.0, "HeadMult": 2.0, "LimbMult": 0.8,
		"RPM": 68.0, "Auto": false, "Mag": 6, "StartReserve": 18, "MaxReserve": 42,
		"Reload": 0.5, "ShellTime": 0.5, "Pellets": 9, "PelletSpread": 4.2, "Pump": true,
		"HipSpread": 1.2, "AimSpread": 0.6, "Recoil": 6.5, "RecoilYaw": 1.6,
		"Range": 170.0, "Alert": 320.0, "Slot": "Larga", "DrawTime": 0.9, "Tip": "Escopeta de corredera",
	},
	"Francotirador": {
		"Kind": "Gun", "Base": "Rifle", "Sound": "Sniper", "Damage": 120.0, "HeadMult": 3.0, "LimbMult": 0.8,
		"RPM": 42.0, "Auto": false, "Mag": 5, "StartReserve": 15, "MaxReserve": 40,
		"Reload": 3.0, "HipSpread": 7.5, "AimSpread": 0.04, "Recoil": 7.5, "RecoilYaw": 1.2, "Bolt": true,
		"Range": 2200.0, "Alert": 430.0, "Slot": "Larga", "DrawTime": 1.05, "Tip": "Fusil de francotirador",
		"Scope": 13.0, # campo de visión con la mira telescópica (grados)
	},
	"Hacha": {
		"Kind": "Melee", "Base": "Machete", "Damage": 72.0, "HeadMult": 1.5, "Range": 7.8, "Cooldown": 1.05,
		"Stamina": 16.0, "Knockback": 26.0, "Stagger": 0.75, "Sound": "Flesh", "Slot": "BlancaLarga",
		"DrawTime": 0.85, "HitTime": 0.4, "Tip": "Hacha de bombero", "DosManos": true, "Derriba": 0.25,
	},
	"Palanca": {
		"Kind": "Melee", "Base": "Machete", "Damage": 46.0, "HeadMult": 1.8, "Range": 7.2, "Cooldown": 0.8,
		"Stamina": 12.0, "Knockback": 30.0, "Stagger": 0.9, "Sound": "Blunt", "Slot": "BlancaLarga",
		"DrawTime": 0.75, "HitTime": 0.27, "Tip": "Palanca", "Derriba": 0.3,
	},
}

## 4 huecos: solo se lleva un arma de cada tipo
const SLOTS := [
	{"Id": "Corta", "Name": "Arma corta"},
	{"Id": "Larga", "Name": "Arma larga"},
	{"Id": "BlancaCorta", "Name": "Arma blanca corta"},
	{"Id": "BlancaLarga", "Name": "Arma blanca larga"},
]
const LOADOUT := ["Pistola", "Rifle", "Cuchillo", "Bate"]
const HOLSTER_TIME := 0.42

## ---------------------------------------------------------------- ayudas
## arma de la que toma poses y animaciones (las nuevas se parecen a alguna de las originales)
static func base(nombre: String) -> String:
	return str(WEAPONS.get(nombre, {}).get("Base", nombre))


## armas blancas que se cogen con las dos manos (no se pueden usar tumbado ni en la moto)
static func dos_manos(nombre: String) -> bool:
	return bool(WEAPONS.get(nombre, {}).get("DosManos", false))


## ¿se puede usar en la moto? (armas de fuego de una mano y armas blancas de una mano)
static func en_moto(nombre: String) -> bool:
	var w: Dictionary = WEAPONS.get(nombre, {})
	if w.is_empty():
		return false
	if w.Kind == "Gun":
		return bool(w.get("UnaMano", false))
	return not dos_manos(nombre)


static func ang(x: float, y: float, z: float) -> Transform3D:
	return Rbx.ang(x * D2R, y * D2R, z * D2R)


static func cf(x: float, y: float, z: float) -> Transform3D:
	return Rbx.cf(x, y, z)


## CFrame.lookAt(p, p + fwd, up)
static func at(p: Vector3, fwd: Vector3, up: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(fwd.normalized(), up), p)


## dónde va cada arma en el cuerpo: posición y orientación del Handle respecto a una pieza
## (el cañón / la hoja apunta hacia -Z del Handle)
static func holster(nombre: String) -> Dictionary:
	match nombre:
		# pistola en la funda del muslo derecho: cañón abajo, empuñadura hacia atrás
		"Pistola": return {"Part": "RightUpperLeg", "CF": at(Vector3(0.33, 0.45, 0.33), Vector3(0, -1, 0), Vector3(0, 0, -1))}
		# rifle a la espalda en bandolera: culata abajo a la derecha, cañón arriba a la izquierda
		"Rifle": return {"Part": "UpperTorso", "CF": at(Vector3(0.42, -0.5, 0.97), Vector3(-0.707, 0.707, 0), Vector3(0.707, 0.707, 0))}
		# cuchillo en la correa izquierda del pecho, empuñadura hacia abajo
		"Cuchillo": return {"Part": "UpperTorso", "CF": at(Vector3(-0.42, -0.25, -0.47), Vector3(0, 1, 0), Vector3(1, 0, 0))}
		# bate y machete metidos en la mochila, el mango asoma por encima del hombro derecho
		"Bate": return {"Part": "UpperTorso", "CF": at(Vector3(0.55, 1.05, 1.2), Vector3(-0.25, -1, 0), Vector3(0, 0, 1))}
		"Machete": return {"Part": "UpperTorso", "CF": at(Vector3(0.55, 1.0, 1.05), Vector3(-0.2, -1, 0), Vector3(0, 0, 1))}
		# revólver en la funda del muslo, como la pistola
		"Revolver": return {"Part": "RightUpperLeg", "CF": at(Vector3(0.34, 0.5, 0.3), Vector3(0, -1, 0), Vector3(0, 0, -1))}
		# subfusil colgado en el pecho, cañón hacia abajo a la izquierda
		"Subfusil": return {"Part": "UpperTorso", "CF": at(Vector3(0.12, -0.32, -0.66), Vector3(-0.55, -0.83, 0), Vector3(0, 0, -1))}
		# escopeta y fusil a la espalda como el rifle (solo se lleva un arma larga)
		"Escopeta": return {"Part": "UpperTorso", "CF": at(Vector3(0.42, -0.45, 0.98), Vector3(-0.707, 0.707, 0), Vector3(0.707, 0.707, 0))}
		"Francotirador": return {"Part": "UpperTorso", "CF": at(Vector3(0.42, -0.5, 1.0), Vector3(-0.707, 0.707, 0), Vector3(0.707, 0.707, 0))}
		# hacha y palanca en la mochila: el mango asoma por encima del hombro
		"Hacha": return {"Part": "UpperTorso", "CF": at(Vector3(0.55, 1.15, 1.2), Vector3(-0.25, -1, 0), Vector3(0, 0, 1))}
		"Palanca": return {"Part": "UpperTorso", "CF": at(Vector3(0.5, 1.0, 1.1), Vector3(-0.2, -1, 0), Vector3(0, 0, 1))}
	return {}


## Tool.Grip (GripPos con orientación identidad en todas las armas)
static func grip(nombre: String) -> Transform3D:
	match nombre:
		"Pistola": return cf(0, -0.066, 0.066)
		"Rifle": return cf(0, -0.049, 0.049)
		"Machete": return cf(0, 0, 0.05)
		"Bate": return cf(0, 0, 0.18)
		"Cuchillo": return cf(0, 0, 0.04)
		"Revolver": return cf(0, -0.06, 0.07)
		"Subfusil": return cf(0, -0.05, 0.05)
		"Escopeta": return cf(0, -0.05, 0.05)
		"Francotirador": return cf(0, -0.05, 0.05)
		"Hacha": return cf(0, 0, 0.2)
		"Palanca": return cf(0, 0, 0.12)
	return Transform3D.IDENTITY


## RightGripAttachment de la mano (R15): (0, -0.12, 0) girado -90° en X
static func grip_att() -> Transform3D:
	return cf(0, -0.12, 0) * Rbx.ang(-PI / 2, 0, 0)


## posición del Handle respecto a la mano derecha (como la soldadura RightGrip de Roblox)
static func handle_en_mano(nombre: String) -> Transform3D:
	return grip_att() * grip(nombre).affine_inverse()


## ---------------------------------------------------------------- poses (relativas al pecho)
static func pose(nombre: String, clave: String) -> Transform3D:
	match nombre:
		"Subfusil":
			match clave:
				"AIM": return cf(0.26, 0.52, -1.05)
				"HIP": return cf(0.42, 0.22, -1.05) * ang(-4, 6, 0)
				"LOW": return cf(0.42, -0.05, -1.0) * ang(-30, 18, 0)
				"SPRINT": return cf(0.35, 0.1, -0.9) * ang(35, 30, -20)
		"Escopeta":
			match clave:
				"AIM": return cf(0.28, 0.48, -0.95)
				"HIP": return cf(0.45, 0.18, -0.95) * ang(-4, 6, 0)
				"LOW": return cf(0.45, -0.08, -0.9) * ang(-34, 22, 0)
		"Francotirador":
			match clave:
				# con la mira: la culata en el hombro y la cara en la carrillera
				"AIM": return cf(0.26, 0.46, -0.92)
				"LOW": return cf(0.45, -0.1, -0.9) * ang(-36, 24, 0)
		"Hacha":
			match clave:
				"READY": return at(Vector3(0.6, 0.0, -0.75), Vector3(0.1, 0.9, -0.42), Vector3(0, 0.42, 0.9))
				"SPRINT": return at(Vector3(0.5, 0.5, -0.4), Vector3(-0.1, 0.55, 0.83), Vector3(0, 0.83, -0.55))
		"Palanca":
			match clave:
				"READY": return at(Vector3(0.75, -0.2, -0.85), Vector3(0.1, 0.5, -0.86), Vector3(0, 0.86, 0.5))
	if base(nombre) != nombre:
		return pose(base(nombre), clave)
	match nombre:
		"Rifle":
			match clave:
				"AIM": return cf(0.28, 0.5, -1.0)
				"HIP": return cf(0.45, 0.2, -1.0) * ang(-4, 6, 0)
				"LOW": return cf(0.45, -0.05, -0.95) * ang(-32, 22, 0)
				"SPRINT": return cf(0.3, 0.15, -0.85) * ang(40, 35, -25)
				"RELOAD": return cf(0.3, 0.0, -0.95) * ang(-12, 12, 40)
				"PRONE": return cf(0.32, 0.42, -1.3)
		"Pistola":
			match clave:
				"AIM": return cf(0.08, 0.6, -1.6)
				"HIP": return cf(0.25, 0.3, -1.4)
				"LOW": return cf(0.15, -0.25, -1.2) * ang(-45, 0, 0)
				"SPRINT": return cf(0.55, -0.4, -0.8) * ang(-55, 0, 0)
				"RELOAD": return cf(0.1, 0.2, -1.1) * ang(20, 15, -30)
				"PRONE": return cf(0.05, 0.55, -1.35)
		"Machete":
			match clave:
				"READY": return at(Vector3(0.8, -0.2, -0.85), Vector3(0.1, 0.55, -0.83), Vector3(0, 0.83, 0.55))
				"SPRINT": return cf(0.95, -0.55, -0.45) * ang(-40, 0, 0)
				"WIND": return cf(1.0, 1.2, 0.1) * ang(110, -25, 35)
				"STRIKE": return cf(-0.15, -0.2, -1.4) * ang(-35, 35, -50)
				"FOLLOW": return cf(-0.4, -0.6, -0.8) * ang(-70, 55, -60)
		"Bate":
			match clave:
				"READY": return at(Vector3(0.55, 0.15, -0.75), Vector3(0.15, 0.95, 0.25), Vector3(0, -0.25, -0.97))
				# corriendo: el bate al hombro, apuntando hacia atrás
				"SPRINT": return at(Vector3(0.5, 0.55, -0.4), Vector3(-0.1, 0.55, 0.83), Vector3(0, 0.83, -0.55))
				"WIND": return cf(0.75, 0.85, 0.3) * ang(60, -80, 30)
				"STRIKE": return cf(0.05, 0.1, -1.45) * ang(0, 15, -90)
				"FOLLOW": return cf(-0.75, 0.5, -0.4) * ang(45, 110, 0)
		"Cuchillo":
			match clave:
				"READY": return at(Vector3(0.62, -0.32, -0.8), Vector3(0.05, 0.25, -1), Vector3(0, 1, 0))
				"SPRINT": return cf(0.9, -0.6, -0.4) * ang(-50, 0, 0)
				"WIND": return cf(0.85, -0.25, 0.05) * ang(12, 12, 0)
				"STRIKE": return cf(0.25, 0.05, -1.6) * ang(-4, 6, 0)
				"FOLLOW": return cf(0.35, -0.1, -1.3) * ang(-15, 0, 0)
	return Transform3D.IDENTITY


static func tiene_pose(nombre: String, clave: String) -> bool:
	if str(WEAPONS.get(nombre, {}).get("Kind", "")) == "Gun":
		return clave in ["AIM", "HIP", "LOW", "SPRINT", "RELOAD", "PRONE"]
	return clave in ["READY", "SPRINT", "WIND", "STRIKE", "FOLLOW"]


const POSE_HOLSTER_REL := [0.95, -1.2, 0.1, -80.0] # (mano vacía tras guardar)


static func pose_holster() -> Transform3D:
	return cf(0.95, -1.2, 0.1) * ang(-80, 0, 0)


## sacar el arma: fracción del tiempo en que la mano va a por ella y punto intermedio del recorrido
static func draw(nombre: String) -> Dictionary:
	match nombre:
		"Pistola": return {"reach": 0.35, "mid": cf(0.75, -0.5, -0.45) * ang(-70, 0, 0)}
		"Rifle": return {"reach": 0.4, "mid": cf(1.05, 0.15, 0.2) * ang(-10, 70, -30)}
		"Cuchillo": return {"reach": 0.42, "mid": cf(-0.1, -0.2, -0.75) * ang(-40, 0, 0)}
		"Bate": return {"reach": 0.36, "mid": cf(0.85, 1.5, 0.05) * ang(80, 0, 0)}
		"Machete": return {"reach": 0.36, "mid": cf(0.85, 1.45, 0.05) * ang(80, 0, 0)}
		"Subfusil": return {"reach": 0.38, "mid": cf(0.25, -0.35, -0.8) * ang(-40, 20, 0)}
	if base(nombre) != nombre:
		return draw(base(nombre))
	return {}


## golpes: pose del arma, giro de cintura e inclinación por claves de tiempo
static func golpe(nombre: String) -> Dictionary:
	# claves: [t, pose]; la pose es la del Handle relativa al pecho (dirección del arma = -Z del Handle).
	# El golpe (STRIKE) cae justo en HitTime. "lunge" = cuánto se echa el cuerpo hacia delante.
	match nombre:
		"Hacha":
			# hachazo de arriba abajo a dos manos: sube por encima del hombro derecho y baja delante
			return {"dur": 1.05,
				"pose": [[0.0, pose("Hacha", "READY")],
					[0.26, at(Vector3(0.75, 1.25, 0.25), Vector3(-0.1, 0.55, 0.83), Vector3(0, 0.83, -0.55))],
					[0.34, at(Vector3(0.35, 1.0, -0.6), Vector3(-0.1, 0.75, -0.66), Vector3(0, 0.66, 0.75))],
					[0.4, at(Vector3(0.15, 0.15, -1.35), Vector3(-0.1, -0.45, -0.89), Vector3(0, 0.89, -0.45))],
					[0.55, at(Vector3(0.1, -0.45, -1.1), Vector3(-0.05, -0.85, -0.5), Vector3(0, 0.5, -0.86))],
					[1.05, pose("Hacha", "READY")]],
				"twist": [[0.0, 0.0], [0.26, -0.3], [0.4, 0.15], [0.55, 0.1], [1.05, 0.0]],
				"lean": [[0.0, 0.0], [0.26, 0.14], [0.4, -0.32], [0.55, -0.28], [1.05, 0.0]],
				"lunge": [[0.0, 0.0], [0.26, 0.0], [0.4, 1.0], [0.55, 0.85], [1.05, 0.0]]}
		"Cuchillo":
			# puñalada: lleva la mano a la cadera y clava hacia delante con todo el cuerpo
			return {"dur": 0.5,
				"pose": [[0.0, pose("Cuchillo", "READY")],
					[0.09, at(Vector3(0.85, -0.22, 0.0), Vector3(-0.1, 0.15, -1), Vector3(0, 1, 0))],
					[0.16, at(Vector3(0.15, 0.1, -1.85), Vector3(-0.15, 0.05, -1), Vector3(0, 1, 0))],
					[0.24, at(Vector3(0.22, 0.04, -1.7), Vector3(-0.12, 0.0, -1), Vector3(0, 1, 0))],
					[0.5, pose("Cuchillo", "READY")]],
				"twist": [[0.0, 0.0], [0.09, -0.35], [0.16, 0.3], [0.24, 0.25], [0.5, 0.0]],
				"lean": [[0.0, 0.0], [0.09, 0.04], [0.16, -0.2], [0.24, -0.16], [0.5, 0.0]],
				"lunge": [[0.0, 0.0], [0.09, 0.0], [0.16, 1.0], [0.24, 0.9], [0.5, 0.0]]}
		"Machete":
			# tajo en diagonal: sube por encima del hombro derecho y baja cruzando hacia la cadera izquierda
			return {"dur": 0.75,
				"pose": [[0.0, pose("Machete", "READY")],
					[0.16, at(Vector3(0.95, 0.95, 0.15), Vector3(-0.25, 0.75, 0.6), Vector3(0.2, -0.55, 0.8))],
					[0.26, at(Vector3(0.1, 0.15, -1.45), Vector3(-0.45, -0.25, -0.86), Vector3(0.5, 0.85, -0.1))],
					[0.38, at(Vector3(-0.6, -0.55, -0.75), Vector3(-0.6, -0.7, -0.35), Vector3(0.75, -0.2, 0.6))],
					[0.75, pose("Machete", "READY")]],
				"twist": [[0.0, 0.0], [0.16, -0.55], [0.26, 0.2], [0.38, 0.5], [0.75, 0.0]],
				"lean": [[0.0, 0.0], [0.16, 0.08], [0.26, -0.2], [0.38, -0.14], [0.75, 0.0]],
				"lunge": [[0.0, 0.0], [0.16, 0.0], [0.26, 1.0], [0.38, 0.8], [0.75, 0.0]]}
		"Bate":
			# batazo horizontal a dos manos: carga detrás del hombro, barre por delante y envuelve
			return {"dur": 0.95,
				"pose": [[0.0, pose("Bate", "READY")],
					[0.24, at(Vector3(1.05, 0.45, 0.3), Vector3(0.1, 0.55, 0.83), Vector3(0, 0.83, -0.55))],
					# las manos tiran hacia delante y el bate queda atrás, por fuera del cuerpo (látigo)
					[0.31, at(Vector3(0.65, 0.05, -0.8), Vector3(0.75, 0.15, 0.64), Vector3(0, 1, 0))],
					[0.335, at(Vector3(0.5, 0.0, -1.05), Vector3(0.95, 0.1, -0.3), Vector3(0, 1, 0))],
					[0.36, at(Vector3(0.2, -0.05, -1.05), Vector3(-0.9, 0.05, -0.43), Vector3(0, 1, 0))],
					[0.5, at(Vector3(-0.75, 0.2, -0.75), Vector3(-0.55, 0.3, 0.78), Vector3(0, 0.95, -0.35))],
					# vuelve por delante (no por encima de la cabeza)
					[0.72, at(Vector3(0.1, -0.15, -1.15), Vector3(0.4, 0.5, -0.77), Vector3(0, 0.84, 0.54))],
					[0.95, pose("Bate", "READY")]],
				"twist": [[0.0, 0.0], [0.24, -0.75], [0.31, -0.35], [0.335, -0.1], [0.36, 0.15], [0.5, 0.75], [0.72, 0.25], [0.95, 0.0]],
				"lean": [[0.0, 0.0], [0.24, 0.06], [0.31, -0.05], [0.335, -0.1], [0.36, -0.16], [0.5, -0.08], [0.72, -0.03], [0.95, 0.0]],
				"lunge": [[0.0, 0.0], [0.24, 0.0], [0.31, 0.4], [0.335, 0.6], [0.36, 0.8], [0.5, 0.6], [0.72, 0.2], [0.95, 0.0]]}
	if base(nombre) != nombre:
		return golpe(base(nombre))
	return {}


## recarga: giro del arma y recorrido de la mano izquierda (cargador, bolsa, palanca/corredera)
static func recarga(nombre: String, cartuchos := 0) -> Dictionary:
	match nombre:
		"Revolver":
			# abre el tambor hacia la izquierda, saca el cargador rápido de la bolsa y lo mete
			return {"dur": 2.4,
				"gun": [[0.0, Transform3D.IDENTITY], [0.3, ang(10, 0, 45)], [2.0, ang(10, 0, 45)], [2.2, ang(-4, 0, 0)], [2.4, Transform3D.IDENTITY]],
				"hand": [[0.0, "gun", "grip"], [0.35, "gun", "mag", Vector3(-0.1, 0, 0)], [0.8, "pouch"], [1.05, "pouch"],
					[1.5, "gun", "mag", Vector3(0, 0, -0.35)], [1.75, "gun", "mag"], [2.05, "gun", "mag", Vector3(-0.05, 0.1, 0)], [2.4, "gun", "grip"]],
				"events": [[0.95, "new"], [1.75, "insert"]]}
		"Escopeta":
			# cartucho a cartucho por la ventana de carga (debajo del cajón)
			var n := maxi(1, cartuchos)
			var t0 := 0.35
			var g := [[0.0, Transform3D.IDENTITY], [t0, ang(-6, 0, -35)]]
			var h := [[0.0, "gun", "grip"], [t0, "gun", "mag", Vector3(0, -0.15, 0.1)]]
			var ev := []
			for i in n:
				var a0 := t0 + i * 0.5
				h.append([a0 + 0.15, "pouch"])
				h.append([a0 + 0.32, "gun", "mag", Vector3(0, -0.2, 0.05)])
				h.append([a0 + 0.45, "gun", "mag"])
				ev.append([a0 + 0.18, "shell_new_%d" % i])
				ev.append([a0 + 0.44, "shell_in_%d" % i])
			var fin := t0 + n * 0.5
			g.append([fin, ang(-6, 0, -35)])
			g.append([fin + 0.2, Transform3D.IDENTITY])
			h.append([fin + 0.2, "gun", "grip"])
			return {"dur": fin + 0.25, "gun": g, "hand": h, "events": ev}
	if base(nombre) != nombre:
		return recarga(base(nombre))
	match nombre:
		"Rifle":
			return {"dur": 2.5,
				"gun": [[0.0, Transform3D.IDENTITY], [0.5, ang(-8, 0, 0)], [1.6, ang(6, 0, 0)], [1.75, Transform3D.IDENTITY], [2.1, ang(0, 0, -10)], [2.5, Transform3D.IDENTITY]],
				"hand": [[0.0, "gun", "grip"], [0.35, "gun", "mag"], [0.55, "gun", "mag", Vector3(0, -0.15, 0)],
					[0.95, "pouch"], [1.15, "pouch"],
					[1.5, "gun", "mag", Vector3(0, -0.5, 0)], [1.7, "gun", "mag"],
					[1.95, "gun", "charge"], [2.1, "gun", "charge", Vector3(0, 0, 0.45)], [2.5, "gun", "grip"]],
				"events": [[0.5, "drop"], [1.0, "new"], [1.68, "insert"]]}
		"Pistola":
			return {"dur": 1.7,
				"gun": [[0.0, Transform3D.IDENTITY], [0.35, ang(-5, 0, 0)], [1.0, ang(8, 0, 0)], [1.15, Transform3D.IDENTITY], [1.45, ang(-6, 0, 0)], [1.7, Transform3D.IDENTITY]],
				"hand": [[0.0, "gun", "grip"], [0.25, "gun", "mag"], [0.4, "gun", "mag", Vector3(0, -0.2, 0)],
					[0.7, "pouch"], [0.8, "pouch"],
					[1.0, "gun", "mag", Vector3(0, -0.45, 0)], [1.12, "gun", "mag"],
					[1.3, "gun", "slide", Vector3(0, 0.05, -0.1)], [1.45, "gun", "slide", Vector3(0, 0.05, 0.35)], [1.7, "gun", "grip"]],
				"events": [[0.35, "drop"], [0.72, "new"], [1.1, "insert"]]}
	return {}


## ---------------------------------------------------------------- modelos
## Los modelos (v0.4, unas 3 veces más piezas que los de Roblox) están en ModelosArmas
## (scripts/armas/modelos_armas.gd). Aquí solo se construyen.
static var _mats := {}


static func material(c: Color, tipo: String) -> StandardMaterial3D:
	var k := "%s_%s" % [c.to_html(), tipo]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	match tipo:
		"Metal":
			m.metallic = 0.8
			m.roughness = 0.35
		"Steel":
			m.metallic = 0.9
			m.roughness = 0.22
		"Brass":
			m.metallic = 0.95
			m.roughness = 0.3
		"Wood":
			m.roughness = 0.8
		"Fabric", "Rubber", "Leather":
			m.roughness = 0.95
		"Polymer":
			m.roughness = 0.62
		"Glass":
			m.metallic = 0.6
			m.roughness = 0.05
		"Glow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.emission_enabled = true
			m.emission = c
		_:
			m.roughness = 0.5
	_mats[k] = m
	return m


static func puntos(nombre: String) -> Dictionary:
	return ModelosArmas.puntos(nombre)


## Construye el arma: un Node3D con el origen en el Handle, una malla por pieza y un Marker3D por punto
## de referencia. Las piezas con grupo (p. ej. "Mag", "Pump", "Bolt") van dentro de un Node3D con ese
## nombre, para poder moverlas o soltarlas juntas (el cargador al recargar, la corredera de la escopeta).
## Formas: box, cylz/cylx/cyly (cilindro; tam.x = diámetro, tam.z = largo), conoz (tam.y = diámetro del
## extremo de atrás), hexz (barra hexagonal), esf (esfera, tam.x = diámetro).
static func construir_modelo(nombre: String) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Arma_" + nombre
	raiz.set_meta("arma", nombre)
	var grupos := {}
	for d in ModelosArmas.piezas(nombre):
		var padre: Node3D = raiz
		var grupo: String = d[7] if d.size() > 7 else ""
		if grupo != "":
			if not grupos.has(grupo):
				var gn := Node3D.new()
				gn.name = grupo
				raiz.add_child(gn)
				grupos[grupo] = gn
			padre = grupos[grupo]
		var mi := MeshInstance3D.new()
		mi.name = d[0]
		var t := Transform3D(Rbx.angb(d[4].x * D2R, d[4].y * D2R, d[4].z * D2R), d[3])
		var tam: Vector3 = d[2]
		match d[1]:
			"cylz", "cylx", "cyly", "conoz", "hexz":
				var cm := CylinderMesh.new()
				cm.top_radius = tam.x * 0.5
				cm.bottom_radius = (tam.y if d[1] == "conoz" else tam.x) * 0.5
				cm.height = tam.z
				cm.radial_segments = 6 if d[1] == "hexz" else (16 if tam.x > 0.12 else 10)
				cm.rings = 1
				mi.mesh = cm
				match d[1]:
					"cylz", "conoz", "hexz":
						# el cilindro de Godot va a lo largo de Y: se tumba a lo largo de Z (la tapa "top" hacia -Z)
						t = t * Transform3D(Basis(Vector3(1, 0, 0), -PI / 2), Vector3.ZERO)
					"cylx":
						t = t * Transform3D(Basis(Vector3(0, 0, 1), PI / 2), Vector3.ZERO)
			"esf":
				var sm := SphereMesh.new()
				sm.radius = tam.x * 0.5
				sm.height = tam.x
				sm.radial_segments = 10
				sm.rings = 5
				mi.mesh = sm
			_:
				var bm := BoxMesh.new()
				bm.size = tam
				mi.mesh = bm
		mi.transform = t
		mi.material_override = material(d[5], d[6])
		if tam.length() < 0.25:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		padre.add_child(mi)
	var pts := puntos(nombre)
	for k in pts:
		var mk := Marker3D.new()
		var ruta: String = k
		var padre2: Node3D = raiz
		if ruta.contains("/"):
			var partes := ruta.split("/")
			padre2 = grupos.get(partes[0], raiz)
			ruta = partes[1]
		mk.name = ruta
		mk.position = pts[k]
		padre2.add_child(mk)
	return raiz


## posición de un punto de referencia en el espacio del arma (aunque esté dentro de un grupo que se mueve)
static func punto_local(mdl: Node3D, nombre: String) -> Vector3:
	var n := mdl.find_child(nombre, true, false) as Node3D
	if n == null:
		return Vector3.ZERO
	var p := n.position
	var padre := n.get_parent() as Node3D
	while padre != null and padre != mdl:
		p = padre.transform * p
		padre = padre.get_parent() as Node3D
	return p


static func es_larga_blanca(nombre: String) -> bool:
	var w: Dictionary = WEAPONS.get(nombre, {})
	return not w.is_empty() and w.Kind == "Melee" and w.Slot != "BlancaCorta"


## todas las armas (para el menú de trucos y el armero del nivel)
static func todas() -> Array:
	return WEAPONS.keys()
