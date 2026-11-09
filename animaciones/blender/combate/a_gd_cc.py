# Muestrea el diseño del combate cuerpo a cuerpo (diseno_cc.py, el mismo que se ve en Blender con ver_cc.py) y escribe
# scripts/jugador/combate_cc.gd (CombateCC).
# Uso: python3 a_gd_cc.py ../../../scripts/jugador/combate_cc.gd
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diseno_cc as DC

N = 40   # muestras por acción (u de 0 a 1, incluidos los dos extremos)


def f5(x):
	return "%.4f" % x


def fmt(xs):
	return "[" + ", ".join(f5(x) for x in xs) + "]"


def pose_fija(d):
	return "{" + ", ".join('"%s": %s' % (k, f5(v)) for k, v in d.items()) + "}"


def accion(a, sangria):
	s = sangria
	L = [s + "{"]
	L.append(s + '\t"dur": %s, "golpe": %s,' % (f5(a["dur"]), f5(a["golpe"])))
	for k in ("lado", "nombre"):
		if k in a:
			L.append(s + '\t"%s": "%s",' % (k, a[k]))
	if "pieza" in a:
		L.append(s + '\t"pieza": "%s",' % a["pieza"])
	for k in ("danio", "empuje", "derribo", "tambaleo"):
		if k in a:
			L.append(s + '\t"%s": %s,' % (k, f5(a[k])))
	L.append(s + '\t"canales": {')
	for k in DC.canales(a["claves"]):
		L.append(s + '\t\t"%s": %s,' % (k, fmt([DC.muestra(a, k, i / (N - 1)) for i in range(N)])))
	L.append(s + "\t},")
	L.append(s + "},")
	return L


salida = sys.argv[1]
L = []
L.append("class_name CombateCC")
L.append("## GENERADO por animaciones/blender/combate/a_gd_cc.py a partir de diseno_cc.py (el diseño que se ve en Blender")
L.append("## con ver_cc.py): NO editar a mano. Combate cuerpo a cuerpo: GUARDIA y BLOQUEO por clase de arma (poses fijas)")
L.append("## y EMPUJON (por clase, varias variantes), GOLPES (armas blancas), PUNOS, PATADA y PISOTON por claves, muestreadas de u = 0 a 1.")
L.append("## Canales y marcos: ver diseno_cc.py. Lo usa Animador._paso_cc; las reglas del juego están en Arsenal (cc_*).")
L.append("")
L.append("const N := %d" % N)
L.append("")
L.append("const GUARDIA := {")
for c, d in DC.GUARDIA.items():
	L.append('\t"%s": %s,' % (c, pose_fija(d)))
L.append("}")
L.append("")
L.append("const BLOQUEO := {")
for c, d in DC.BLOQUEO.items():
	L.append('\t"%s": %s,' % (c, pose_fija(d)))
L.append("}")
L.append("")
L.append("const EMPUJON := {")
for c, lista in DC.EMPUJON.items():
	L.append('\t"%s": [' % c)
	for a in lista:
		L += accion(a, "\t\t")
	L.append("\t],")
L.append("}")
L.append("")
L.append("const GOLPES := {")
for c, lista in DC.GOLPES.items():
	L.append('\t"%s": [' % c)
	for a in lista:
		L += accion(a, "\t\t")
	L.append("\t],")
L.append("}")
L.append("")
L.append("const PUNOS := [")
for a in DC.PUNOS:
	L += accion(a, "\t")
L.append("]")
L.append("")
L.append("const PATADA := [")
for a in DC.PATADA:
	L += accion(a, "\t")
L.append("]")
L.append("")
L.append("const SUELO := {")
for c, a in DC.SUELO.items():
	L.append('\t"%s":' % c)
	L += accion(a, "\t")
L.append("}")
L.append("")
L.append("const PISOTON := [")
for a in DC.PISOTON:
	L += accion(a, "\t")
L.append("]")
L.append("")
L.append("")
L.append("## pose de una acción en u (0..1): todos sus canales")
L.append("static func pose(accion: Dictionary, u: float) -> Dictionary:")
L.append("\tvar r := {}")
L.append("\tvar c: Dictionary = accion.canales")
L.append("\tfor k in c:")
L.append("\t\tr[k] = _abierta(c[k], u)")
L.append("\treturn r")
L.append("")
L.append("")
L.append("static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:")
L.append("\tvar t2 := t * t")
L.append("\treturn 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t2 * t)")
L.append("")
L.append("")
L.append("static func _abierta(a: Array, u: float) -> float:")
L.append("\tvar x := clampf(u, 0.0, 1.0) * float(a.size() - 1)")
L.append("\tvar i := mini(int(x), a.size() - 2)")
L.append("\tvar t := x - float(i)")
L.append("\treturn _cr(float(a[maxi(i - 1, 0)]), float(a[i]), float(a[i + 1]), float(a[mini(i + 2, a.size() - 1)]), t)")
open(salida, "w").write("\n".join(L) + "\n")
print("escrito", salida)
