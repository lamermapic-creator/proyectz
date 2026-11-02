# moto_apuntado.json (Blender) -> scripts/jugador/poses_moto.gd (constantes de GDScript: se exportan siempre)
import json, sys
D = json.load(open(sys.argv[1]))
def q(v):
	return "Quaternion(%.5f, %.5f, %.5f, %.5f)" % tuple(v)
L = []
L.append("class_name PosesMoto")
L.append("## Poses de apuntado con la pistola en la moto, HECHAS EN BLENDER (no editar a mano): las genera")
L.append("## animaciones/blender/exportar.py a partir de animaciones/blender/poses.py sobre el piloto montado en Blender")
L.append("## (piloto.blend). Rejilla: CABECEOS (filas) x ANGULOS (columnas, rad, + izquierda, < -PI = detrás por encima")
L.append("## del hombro derecho). En cada pose, la rotación de: " + ", ".join(D["articulaciones"]) + ".")
L.append("")
L.append("const ARTICULACIONES := %s" % json.dumps(D["articulaciones"]))
L.append("const ANGULOS := %s" % json.dumps(D["angulos"]))
L.append("const CABECEOS := %s" % json.dumps(D["cabeceos"]))
L.append("const BASE := [%s]" % ", ".join(q(D["base"][n]) for n in D["articulaciones"]))
L.append("## pose recogida (el arma delante del pecho, cañón arriba), mirando hacia la derecha (-1) / izquierda (1)")
L.append("const RECOGIDA := {")
for k, v in D["recogida"].items():
	L.append("\t%s: [%s]," % (k, ", ".join(q(x) for x in v)))
L.append("}")
L.append("const REJILLA := [")
for fila in D["rejilla"]:
	L.append("\t[")
	for pose in fila:
		L.append("\t\t[%s]," % ", ".join(q(x) for x in pose))
	L.append("\t],")
L.append("]")
open(sys.argv[2], "w").write("\n".join(L) + "\n")
print("GD", sys.argv[2])
