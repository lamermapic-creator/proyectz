@tool
class_name RigPersonaje
extends Node3D
## El muñeco del superviviente (StarterCharacter del juego de Roblox), pieza por pieza.
## Esqueleto R15 con Motor6D: cada articulación coloca su pieza como en Roblox:
##   pieza1 = pieza0 * C0 * Transform * C1^-1
## Este nodo es el HumanoidRootPart (centro del cuerpo). Unidades: studs.

## Articulaciones: nombre -> [pieza0, pieza1, C0, C1] (todas sin rotación en reposo)
const MOTORES := [
	["Root", "HumanoidRootPart", "LowerTorso", Vector3(0, 0, 0), Vector3(0, 0.08, 0)],
	["Waist", "LowerTorso", "UpperTorso", Vector3(0, 0.28, 0), Vector3(0, -0.69, 0)],
	["Neck", "UpperTorso", "Head", Vector3(0, 0.67, 0), Vector3(0, -0.46, 0)],
	["LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3(-0.92, 0.51, 0), Vector3(0, 0.515, 0)],
	["LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3(0, -0.515, 0), Vector3(0, 0.475, 0)],
	["LeftWrist", "LeftLowerArm", "LeftHand", Vector3(0, -0.475, 0), Vector3(0, 0.21, 0)],
	["RightShoulder", "UpperTorso", "RightUpperArm", Vector3(0.92, 0.51, 0), Vector3(0, 0.515, 0)],
	["RightElbow", "RightUpperArm", "RightLowerArm", Vector3(0, -0.515, 0), Vector3(0, 0.475, 0)],
	["RightWrist", "RightLowerArm", "RightHand", Vector3(0, -0.475, 0), Vector3(0, 0.21, 0)],
	["LeftHip", "LowerTorso", "LeftUpperLeg", Vector3(-0.33, -0.17, 0), Vector3(0, 0.65, 0)],
	["LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3(0, -0.65, 0), Vector3(0, 0.625, 0)],
	["LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3(0, -0.625, 0.02), Vector3(0, 0.15, 0.2)],
	["RightHip", "LowerTorso", "RightUpperLeg", Vector3(0.33, -0.17, 0), Vector3(0, 0.65, 0)],
	["RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3(0, -0.65, 0), Vector3(0, 0.625, 0)],
	["RightAnkle", "RightLowerLeg", "RightFoot", Vector3(0, -0.625, 0.02), Vector3(0, 0.15, 0.2)],
]

## Piezas del cuerpo: nombre -> [tamaño, color RGB, material, posición en reposo respecto al centro]
const PIEZAS := {
	"LowerTorso": [Vector3(1.2, 0.6, 0.66), Color8(46, 56, 76), "Fabric", Vector3(0, -0.08, 0)],
	"UpperTorso": [Vector3(1.42, 1.38, 0.74), Color8(68, 76, 52), "Fabric", Vector3(0, 0.89, 0)],
	"Head": [Vector3(0.7, 0.86, 0.78), Color8(198, 146, 112), "SmoothPlastic", Vector3(0, 2.02, 0)],
	"LeftUpperArm": [Vector3(0.38, 1.05, 0.42), Color8(68, 76, 52), "Fabric", Vector3(-0.92, 0.885, 0)],
	"LeftLowerArm": [Vector3(0.34, 0.95, 0.38), Color8(68, 76, 52), "Fabric", Vector3(-0.92, -0.105, 0)],
	"LeftHand": [Vector3(0.28, 0.42, 0.22), Color8(32, 30, 28), "Leather", Vector3(-0.92, -0.79, 0)],
	"RightUpperArm": [Vector3(0.38, 1.05, 0.42), Color8(68, 76, 52), "Fabric", Vector3(0.92, 0.885, 0)],
	"RightLowerArm": [Vector3(0.34, 0.95, 0.38), Color8(68, 76, 52), "Fabric", Vector3(0.92, -0.105, 0)],
	"RightHand": [Vector3(0.28, 0.42, 0.22), Color8(32, 30, 28), "Leather", Vector3(0.92, -0.79, 0)],
	"LeftUpperLeg": [Vector3(0.52, 1.3, 0.56), Color8(46, 56, 76), "Fabric", Vector3(-0.33, -0.9, 0)],
	"LeftLowerLeg": [Vector3(0.44, 1.25, 0.46), Color8(46, 56, 76), "Fabric", Vector3(-0.33, -2.175, 0)],
	"LeftFoot": [Vector3(0.46, 0.3, 1.0), Color8(58, 42, 30), "Leather", Vector3(-0.33, -2.95, -0.18)],
	"RightUpperLeg": [Vector3(0.52, 1.3, 0.56), Color8(46, 56, 76), "Fabric", Vector3(0.33, -0.9, 0)],
	"RightLowerLeg": [Vector3(0.44, 1.25, 0.46), Color8(46, 56, 76), "Fabric", Vector3(0.33, -2.175, 0)],
	"RightFoot": [Vector3(0.46, 0.3, 1.0), Color8(58, 42, 30), "Leather", Vector3(0.33, -2.95, -0.18)],
}

## Ropa y detalles soldados a una pieza: [nombre, pieza, posición en reposo (respecto al centro),
## tamaño, color, material, giro Z (rad), forma, transparencia]
const DETALLES := [
	["Belt", "LowerTorso", Vector3(0, 0.12, 0), Vector3(1.24, 0.15, 0.7), Color8(58, 42, 30), "Leather", 0.0, "box", 0.0],
	["Buckle", "LowerTorso", Vector3(0, 0.12, -0.36), Vector3(0.16, 0.12, 0.04), Color8(160, 150, 120), "Metal", 0.0, "box", 0.0],
	["MagPouch1", "LowerTorso", Vector3(-0.36, 0, -0.4), Vector3(0.2, 0.32, 0.16), Color8(45, 50, 38), "Fabric", 0.0, "box", 0.0],
	["MagPouch2", "LowerTorso", Vector3(-0.14, 0, -0.4), Vector3(0.2, 0.32, 0.16), Color8(45, 50, 38), "Fabric", 0.0, "box", 0.0],
	["Collar", "UpperTorso", Vector3(0, 1.55, 0.02), Vector3(1, 0.2, 0.82), Color8(50, 56, 38), "Fabric", 0.0, "box", 0.0],
	["Shirt", "UpperTorso", Vector3(0, 1.27, -0.37), Vector3(0.36, 0.5, 0.04), Color8(120, 115, 105), "Fabric", 0.0, "box", 0.0],
	["Zipper", "UpperTorso", Vector3(0.05, 0.84, -0.38), Vector3(0.05, 1.2, 0.04), Color8(150, 150, 140), "Metal", 0.0, "box", 0.0],
	["PocketL", "UpperTorso", Vector3(-0.4, 1.04, -0.38), Vector3(0.34, 0.3, 0.05), Color8(50, 56, 38), "Fabric", 0.0, "box", 0.0],
	["StrapL", "UpperTorso", Vector3(-0.42, 0.91, -0.39), Vector3(0.13, 1.25, 0.05), Color8(40, 38, 32), "Fabric", 0.0, "box", 0.0],
	["PocketR", "UpperTorso", Vector3(0.4, 1.04, -0.38), Vector3(0.34, 0.3, 0.05), Color8(50, 56, 38), "Fabric", 0.0, "box", 0.0],
	["StrapR", "UpperTorso", Vector3(0.42, 0.91, -0.39), Vector3(0.13, 1.25, 0.05), Color8(40, 38, 32), "Fabric", 0.0, "box", 0.0],
	["Backpack", "UpperTorso", Vector3(0, 0.91, 0.6), Vector3(1.08, 1.1, 0.45), Color8(62, 56, 44), "Fabric", 0.0, "box", 0.0],
	["BackpackPocket", "UpperTorso", Vector3(0, 0.67, 0.88), Vector3(0.7, 0.45, 0.14), Color8(52, 47, 37), "Fabric", 0.0, "box", 0.0],
	["Bedroll", "UpperTorso", Vector3(0, 1.59, 0.62), Vector3(1.2, 0.34, 0.34), Color8(90, 70, 50), "Fabric", 0.0, "cylx", 0.0],
	["Hair", "Head", Vector3(0, 2.44, 0.03), Vector3(0.8, 0.24, 0.88), Color8(45, 32, 24), "Fabric", 0.0, "box", 0.0],
	["HairBack", "Head", Vector3(0, 2.17, 0.38), Vector3(0.8, 0.6, 0.24), Color8(45, 32, 24), "Fabric", 0.0, "box", 0.0],
	["EyeL", "Head", Vector3(-0.15, 2.1, -0.4), Vector3(0.075, 0.05, 0.03), Color8(35, 28, 22), "SmoothPlastic", 0.0, "box", 0.0],
	["BrowL", "Head", Vector3(-0.15, 2.19, -0.4), Vector3(0.17, 0.03, 0.03), Color8(45, 32, 24), "SmoothPlastic", 0.1047, "box", 0.0],
	["EarL", "Head", Vector3(-0.37, 2.04, 0.02), Vector3(0.07, 0.2, 0.14), Color8(198, 146, 112), "SmoothPlastic", 0.0, "box", 0.0],
	["EyeR", "Head", Vector3(0.15, 2.1, -0.4), Vector3(0.075, 0.05, 0.03), Color8(35, 28, 22), "SmoothPlastic", 0.0, "box", 0.0],
	["BrowR", "Head", Vector3(0.15, 2.19, -0.4), Vector3(0.17, 0.03, 0.03), Color8(45, 32, 24), "SmoothPlastic", -0.1047, "box", 0.0],
	["EarR", "Head", Vector3(0.37, 2.04, 0.02), Vector3(0.07, 0.2, 0.14), Color8(198, 146, 112), "SmoothPlastic", 0.0, "box", 0.0],
	["Nose", "Head", Vector3(0, 2.0, -0.42), Vector3(0.08, 0.15, 0.08), Color8(182, 134, 103), "SmoothPlastic", 0.0, "box", 0.0],
	["Mouth", "Head", Vector3(0, 1.82, -0.39), Vector3(0.17, 0.025, 0.03), Color8(110, 60, 55), "SmoothPlastic", 0.0, "box", 0.0],
	["Stubble", "Head", Vector3(0, 1.78, -0.36), Vector3(0.58, 0.22, 0.05), Color8(120, 95, 80), "Sand", 0.0, "box", 0.35],
	["HairFront", "Head", Vector3(0, 2.35, -0.36), Vector3(0.78, 0.1, 0.16), Color8(45, 32, 24), "Fabric", 0.0, "box", 0.0],
	["CuffL", "LeftLowerArm", Vector3(-0.92, -0.525, 0), Vector3(0.37, 0.14, 0.41), Color8(50, 56, 38), "Fabric", 0.0, "box", 0.0],
	["BootTopL", "LeftLowerLeg", Vector3(-0.33, -2.625, 0), Vector3(0.48, 0.38, 0.5), Color8(58, 42, 30), "Leather", 0.0, "box", 0.0],
	["SoleL", "LeftFoot", Vector3(-0.33, -3.07, -0.18), Vector3(0.48, 0.08, 1.02), Color8(25, 22, 20), "Rubber", 0.0, "box", 0.0],
	["CuffR", "RightLowerArm", Vector3(0.92, -0.525, 0), Vector3(0.37, 0.14, 0.41), Color8(50, 56, 38), "Fabric", 0.0, "box", 0.0],
	["Holster", "RightUpperLeg", Vector3(0.65, -0.78, 0), Vector3(0.18, 0.55, 0.36), Color8(28, 28, 28), "Leather", 0.0, "box", 0.0],
	["BootTopR", "RightLowerLeg", Vector3(0.33, -2.625, 0), Vector3(0.48, 0.38, 0.5), Color8(58, 42, 30), "Leather", 0.0, "box", 0.0],
	["SoleR", "RightFoot", Vector3(0.33, -3.07, -0.18), Vector3(0.48, 0.08, 1.02), Color8(25, 22, 20), "Rubber", 0.0, "box", 0.0],
]


## Una articulación Motor6D
class Motor:
	var name: String
	var part0: String
	var part1: String
	var c0: Transform3D
	var c1: Transform3D
	var c1inv: Transform3D
	var transform := Transform3D.IDENTITY # Motor6D.Transform (lo escribe el animador)
	var node: Node3D

	func apply() -> void:
		node.transform = c0 * transform * c1inv


## maniquí de pruebas: mismo esqueleto, sin ropa, de madera clara
@export var maniqui := false

var M := {}      # nombre -> Motor
var P := {}      # nombre de pieza -> Node3D (con su tamaño en meta "size")
var _meshes: Array[GeometryInstance3D] = []
var _fade := 0.0
var _mats := {}


func _ready() -> void:
	construir()


func construir() -> void:
	for c in get_children():
		if c.name == "Piezas":
			remove_child(c)
			c.free()
	M.clear()
	P.clear()
	_meshes.clear()
	var cont := Node3D.new()
	cont.name = "Piezas"
	add_child(cont)
	P["HumanoidRootPart"] = cont
	cont.set_meta("size", Vector3(1.6, 1.8, 0.8))
	for d in MOTORES:
		var m := Motor.new()
		m.name = d[0]
		m.part0 = d[1]
		m.part1 = d[2]
		m.c0 = Rbx.cfp(d[3])
		m.c1 = Rbx.cfp(d[4])
		m.c1inv = m.c1.affine_inverse()
		var nd := Node3D.new()
		nd.name = m.part1
		(P[m.part0] as Node3D).add_child(nd)
		m.node = nd
		P[m.part1] = nd
		var info: Array = PIEZAS[m.part1]
		nd.set_meta("size", info[0])
		var col: Color = info[1]
		var mat: String = info[2]
		if maniqui:
			col = Color8(196, 160, 112) if m.part1 in ["Head", "LeftHand", "RightHand"] else (Color8(168, 132, 90) if "Torso" in m.part1 else Color8(186, 150, 104))
			mat = "Wood"
		_malla(nd, m.part1, info[0], col, mat, Transform3D.IDENTITY, "head" if m.part1 == "Head" else "box", 0.0)
		M[m.name] = m
		m.apply()
	for d in DETALLES:
		if maniqui:
			break
		var padre: Node3D = P[d[1]]
		var base: Vector3 = PIEZAS[d[1]][3]
		var t := Transform3D(Basis(Rbx.ZAXIS, d[6]), d[2] - base)
		_malla(padre, d[0], d[3], d[4], d[5], t, d[7], d[8])


func _malla(padre: Node3D, nombre: String, tam: Vector3, color: Color, material: String, t: Transform3D, forma: String, transp: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "M_" + nombre
	match forma:
		"head":
			# cabeza de Roblox: cilindro de bordes suaves
			var cm := CylinderMesh.new()
			cm.top_radius = tam.z * 0.5
			cm.bottom_radius = tam.z * 0.5
			cm.height = tam.y
			cm.radial_segments = 20
			mi.mesh = cm
			t = t * Transform3D(Basis.from_scale(Vector3(tam.x / tam.z, 1, 1)), Vector3.ZERO)
		"cylx":
			# cilindro tumbado a lo largo de X (el eje de los cilindros de Roblox)
			var cm2 := CylinderMesh.new()
			cm2.top_radius = tam.y * 0.5
			cm2.bottom_radius = tam.y * 0.5
			cm2.height = tam.x
			mi.mesh = cm2
			t = t * Transform3D(Basis(Rbx.ZAXIS, PI / 2), Vector3.ZERO)
		_:
			var bm := BoxMesh.new()
			bm.size = tam
			mi.mesh = bm
	mi.transform = t
	mi.material_override = _material(color, material)
	if transp > 0.0:
		mi.transparency = transp
		mi.set_meta("transp0", transp)
	padre.add_child(mi)
	_meshes.append(mi)


func _material(c: Color, tipo: String) -> StandardMaterial3D:
	var k := "%s_%s" % [c.to_html(), tipo]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	match tipo:
		"Fabric":
			m.roughness = 0.95
		"Leather":
			m.roughness = 0.6
			m.metallic_specular = 0.4
		"Metal":
			m.metallic = 0.85
			m.roughness = 0.35
		"Rubber":
			m.roughness = 0.9
		"Sand":
			m.roughness = 1.0
		"Wood":
			m.roughness = 0.75
		_:
			m.roughness = 0.45
	_mats[k] = m
	return m


## Aplica Motor6D.Transform de todas las articulaciones a las piezas
func aplicar() -> void:
	for d in MOTORES:
		(M[d[0]] as Motor).apply()


## Transparencia local (cuando la cámara queda pegada al cuerpo)
func set_fade(f: float) -> void:
	if absf(f - _fade) < 0.002:
		return
	_fade = f
	for mi in _meshes:
		var t0: float = mi.get_meta("transp0", 0.0)
		mi.transparency = maxf(t0, f)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if f < 0.95 else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
