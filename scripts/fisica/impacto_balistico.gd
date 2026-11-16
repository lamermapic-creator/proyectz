class_name ImpactoBalistico
extends RefCounted
## Impulsos acotados para las masas R15 del juego (no son daño ni velocidad del proyectil).
## Por perdigón; nueve perdigones no aplican nueve retrocesos de rifle.
const IMPULSOS := {"Pistola": 0.65, "Revolver": 1.05, "Rifle": 0.95, "Subfusil": 0.45,
	"Escopeta": 0.20, "Francotirador": 1.70}
const ARTICULACION := {"Head": "Neck", "UpperTorso": "Waist", "LowerTorso": "Waist",
	"LeftUpperArm": "LeftShoulder", "RightUpperArm": "RightShoulder",
	"LeftLowerArm": "LeftElbow", "RightLowerArm": "RightElbow", "LeftHand": "LeftWrist", "RightHand": "RightWrist",
	"LeftUpperLeg": "LeftHip", "RightUpperLeg": "RightHip", "LeftLowerLeg": "LeftKnee", "RightLowerLeg": "RightKnee",
	"LeftFoot": "LeftAnkle", "RightFoot": "RightAnkle"}
var _muelles := {}

static func impulso(arma: String) -> float:
	return float(IMPULSOS.get(arma, 0.65))

static func punto_local(rig: RigPersonaje, pieza: String, punto: Vector3) -> Vector3:
	var nd: Node3D = rig.P.get(pieza, rig.P.UpperTorso)
	var p := nd.global_transform.affine_inverse() * punto
	var medio: Vector3 = nd.get_meta("size") * 0.5
	return p.clamp(-medio, medio)

## Un muelle por articulación; torque según el brazo hasta el punto de entrada de la bala.
func registrar(rig: RigPersonaje, pieza: String, j: Vector3, punto: Vector3) -> void:
	var articulacion: String = ARTICULACION.get(pieza, "Waist")
	var m: RigPersonaje.Motor = rig.M[articulacion]
	var padre: Node3D = rig.P[m.part0]
	var pivote := padre.global_transform * m.c0
	var torque := padre.global_basis.orthonormalized().inverse() * (punto - pivote.origin).cross(j)
	var impulso_angular := (torque * (10.0 if articulacion != "Waist" else 3.5)).limit_length(7.0)
	if not _muelles.has(articulacion):
		_muelles[articulacion] = [Vector3.ZERO, Vector3.ZERO]
	_muelles[articulacion][1] = ((_muelles[articulacion][1] as Vector3) + impulso_angular).limit_length(9.0)

func aplicar(rig: RigPersonaje, dt: float) -> void:
	# Solución exacta del muelle críticamente amortiguado: no cambia con los FPS.
	var w := 17.0
	for mn in _muelles.keys():
		var x: Vector3 = _muelles[mn][0]
		var v: Vector3 = _muelles[mn][1]
		var c := v + x * w
		var e := exp(-w * dt)
		x = ((x + c * dt) * e).limit_length(0.32)
		v = (v - c * w * dt) * e
		_muelles[mn] = [x, v]
		if x.length_squared() + v.length_squared() < 0.00001:
			_muelles.erase(mn)
		var m: RigPersonaje.Motor = rig.M[mn]
		m.transform = m.transform * Rbx.ang(x.x, x.y, x.z)
