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
		"Range": 450.0, "Alert": 180.0, "Slot": "Corta", "DrawTime": 0.55, "Tip": "Pistola 9mm",
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
		"HitTime": 0.36, "Tip": "Bate con clavos",
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
	return {}


## Tool.Grip (GripPos con orientación identidad en todas las armas)
static func grip(nombre: String) -> Transform3D:
	match nombre:
		"Pistola": return cf(0, -0.066, 0.066)
		"Rifle": return cf(0, -0.049, 0.049)
		"Machete": return cf(0, 0, 0.05)
		"Bate": return cf(0, 0, 0.18)
		"Cuchillo": return cf(0, 0, 0.04)
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
	if nombre == "Rifle" or nombre == "Pistola":
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
	return {}


## golpes: pose del arma, giro de cintura e inclinación por claves de tiempo
static func golpe(nombre: String) -> Dictionary:
	# claves: [t, pose]; la pose es la del Handle relativa al pecho (dirección del arma = -Z del Handle).
	# El golpe (STRIKE) cae justo en HitTime. "lunge" = cuánto se echa el cuerpo hacia delante.
	match nombre:
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
	return {}


## recarga: giro del arma y recorrido de la mano izquierda (cargador, bolsa, palanca/corredera)
static func recarga(nombre: String) -> Dictionary:
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
## piezas: [nombre, forma, tamaño, posición (rel. al Handle), giro XYZ en grados, color, material]
const MODELOS := {
	"Pistola": [
		["Handle", "box", Vector3(0.211, 0.561, 0.330), Vector3(0, 0, 0), Vector3.ZERO, Color8(30, 30, 32), "Plastic"],
		["Slide", "box", Vector3(0.238, 0.251, 0.990), Vector3(0, 0.363, -0.277), Vector3.ZERO, Color8(45, 46, 48), "Metal"],
		["Guard", "box", Vector3(0.066, 0.079, 0.297), Vector3(0, 0.099, -0.297), Vector3.ZERO, Color8(30, 30, 32), "Plastic"],
		["Mag", "box", Vector3(0.158, 0.330, 0.251), Vector3(0, -0.198, 0.013), Vector3.ZERO, Color8(25, 25, 25), "Metal"],
	],
	"Rifle": [
		["Handle", "box", Vector3(0.147, 0.393, 0.221), Vector3(0, 0, 0), Vector3.ZERO, Color8(30, 30, 32), "Plastic"],
		["Receiver", "box", Vector3(0.206, 0.344, 1.130), Vector3(0, 0.270, -0.270), Vector3.ZERO, Color8(45, 46, 48), "Metal"],
		["Handguard", "box", Vector3(0.187, 0.226, 0.688), Vector3(0, 0.270, -1.179), Vector3.ZERO, Color8(60, 58, 50), "Plastic"],
		["Barrel", "box", Vector3(0.079, 0.079, 0.688), Vector3(0, 0.305, -1.769), Vector3.ZERO, Color8(30, 30, 32), "Metal"],
		["Stock", "box", Vector3(0.167, 0.369, 0.737), Vector3(0, 0.197, 0.639), Vector3.ZERO, Color8(30, 30, 32), "Plastic"],
		["Mag", "box", Vector3(0.138, 0.516, 0.221), Vector3(0, -0.025, -0.516), Vector3(-12, 0, 0), Color8(30, 30, 32), "Metal"],
		["Sight", "box", Vector3(0.069, 0.138, 0.246), Vector3(0, 0.501, -0.197), Vector3.ZERO, Color8(30, 30, 32), "Metal"],
	],
	"Machete": [
		["Handle", "box", Vector3(0.150, 0.190, 0.550), Vector3(0, 0, 0), Vector3.ZERO, Color8(40, 30, 22), "Wood"],
		["Blade", "box", Vector3(0.035, 0.275, 1.400), Vector3(0, 0.040, -0.975), Vector3.ZERO, Color8(165, 165, 160), "Metal"],
		["Guard", "box", Vector3(0.170, 0.250, 0.060), Vector3(0, 0.025, -0.290), Vector3.ZERO, Color8(30, 30, 32), "Metal"],
	],
	"Bate": [
		["Handle", "box", Vector3(0.180, 0.180, 0.780), Vector3(0, 0, 0), Vector3.ZERO, Color8(35, 30, 28), "Fabric"],
		["Body", "cylx", Vector3(1.920, 0.300, 0.300), Vector3(0, 0, -1.320), Vector3(0, 90, 0), Color8(150, 110, 70), "Wood"],
		["Knob", "box", Vector3(0.270, 0.270, 0.090), Vector3(0, 0, 0.420), Vector3.ZERO, Color8(150, 110, 70), "Wood"],
		["Nail", "box", Vector3(0.030, 0.030, 0.540), Vector3(0, 0, -1.608), Vector3(70, 90, 0), Color8(120, 120, 120), "Metal"],
		["Nail", "box", Vector3(0.030, 0.030, 0.540), Vector3(0, 0, -1.476), Vector3(140, 90, 0), Color8(120, 120, 120), "Metal"],
		["Nail", "box", Vector3(0.030, 0.030, 0.540), Vector3(0, 0, -1.344), Vector3(-150, 90, 0), Color8(120, 120, 120), "Metal"],
		["Nail", "box", Vector3(0.030, 0.030, 0.540), Vector3(0, 0, -1.212), Vector3(-80, 90, 0), Color8(120, 120, 120), "Metal"],
		["Nail", "box", Vector3(0.030, 0.030, 0.540), Vector3(0, 0, -1.080), Vector3(-10, 90, 0), Color8(120, 120, 120), "Metal"],
	],
	"Cuchillo": [
		["Handle", "box", Vector3(0.130, 0.170, 0.420), Vector3(0, 0, 0), Vector3.ZERO, Color8(28, 28, 28), "Rubber"],
		["Pommel", "box", Vector3(0.150, 0.180, 0.060), Vector3(0, 0, 0.230), Vector3.ZERO, Color8(90, 90, 95), "Metal"],
		["Guard", "box", Vector3(0.160, 0.300, 0.050), Vector3(0, 0.010, -0.235), Vector3.ZERO, Color8(90, 90, 95), "Metal"],
		["Blade", "box", Vector3(0.030, 0.170, 0.580), Vector3(0, 0.010, -0.550), Vector3.ZERO, Color8(185, 188, 192), "Metal"],
		["Tip", "box", Vector3(0.030, 0.170, 0.160), Vector3(0, -0.010, -0.900), Vector3(-26, 0, 0), Color8(185, 188, 192), "Metal"],
		["Spine", "box", Vector3(0.035, 0.030, 0.500), Vector3(0, 0.100, -0.500), Vector3.ZERO, Color8(120, 122, 126), "Metal"],
	],
}

## puntos de referencia (Attachments), relativos al Handle
static func puntos(nombre: String) -> Dictionary:
	match nombre:
		"Pistola":
			return {"SupportGrip": Vector3(-0.132, -0.033, 0.033), "Muzzle": Vector3(0, 0.363 + 0.033, -0.277 - 0.528),
				"SlideRear": Vector3(0, 0.363 + 0.066, -0.277 + 0.363), "MagBottom": Vector3(0, -0.198 - 0.165, 0.013)}
		"Rifle":
			# Mag girada -12°: su base queda algo adelantada
			var mag_b := Vector3(0, -0.025, -0.516) + Basis(Vector3.RIGHT, -12 * D2R) * Vector3(0, -0.246, 0)
			return {"ChargingHandle": Vector3(-0.049, 0.270 + 0.221, -0.270 + 0.344), "LeftGrip": Vector3(0, 0.270 - 0.190, -0.270 - 0.510),
				"Muzzle": Vector3(0, 0.305, -1.769 - 0.369), "MagBottom": mag_b}
		"Bate":
			return {"LeftGrip": Vector3(0, 0, 0.180)}
	return {}


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
		"Wood":
			m.roughness = 0.8
		"Fabric", "Rubber":
			m.roughness = 0.95
		_:
			m.roughness = 0.5
	_mats[k] = m
	return m


## Construye el arma: un Node3D con el origen en el Handle, una malla por pieza y un Marker3D
## por punto de referencia. Las piezas se llaman igual que en Roblox (Mag, Slide...).
static func construir_modelo(nombre: String) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Arma_" + nombre
	raiz.set_meta("arma", nombre)
	for d in MODELOS.get(nombre, []):
		var mi := MeshInstance3D.new()
		mi.name = d[0]
		var t := Transform3D(Rbx.angb(d[4].x * D2R, d[4].y * D2R, d[4].z * D2R), d[3])
		if d[1] == "cylx":
			var cm := CylinderMesh.new()
			cm.top_radius = d[2].y * 0.5
			cm.bottom_radius = d[2].y * 0.5
			cm.height = d[2].x
			cm.radial_segments = 14
			mi.mesh = cm
			t = t * Transform3D(Basis(Vector3(0, 0, 1), PI / 2), Vector3.ZERO)
		else:
			var bm := BoxMesh.new()
			bm.size = d[2]
			mi.mesh = bm
		mi.transform = t
		mi.material_override = material(d[5], d[6])
		raiz.add_child(mi)
	for k in puntos(nombre):
		var mk := Marker3D.new()
		mk.name = k
		mk.position = puntos(nombre)[k]
		raiz.add_child(mk)
	# funda de cuero del cuchillo (solo en el cuerpo, ver Arsenal)
	return raiz


static func es_larga_blanca(nombre: String) -> bool:
	var w: Dictionary = WEAPONS.get(nombre, {})
	return not w.is_empty() and w.Kind == "Melee" and w.Slot != "BlancaCorta"
