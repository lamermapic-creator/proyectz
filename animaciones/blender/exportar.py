# Calcula la rejilla de poses de apuntado (ángulo x cabeceo) y la pose recogida, y las escribe a JSON para el juego
import bpy, sys, json
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import poses
args = sys.argv[sys.argv.index("--") + 1:]
salida = args[0]
A = [round(-3.75 + 0.25 * i, 4) for i in range(28)]          # -3.75 .. 3.0
P = [-1.2, -0.8, -0.4, 0.0, 0.4, 0.8, 1.1]
NOMBRES = ["Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist"]
rejilla = []
for p in P:
	fila = []
	for a in A:
		T = poses.pose(a, p)
		fila.append([poses.a_lista(T[n]) for n in NOMBRES])
	rejilla.append(fila)
rec = {}
for lado in (-1.0, 1.0):
	T = poses.pose_recogida(lado * 2.5)
	rec["%d" % lado] = [poses.a_lista(T[n]) for n in NOMBRES]
base = {n: poses.a_lista(poses.BASE[n]) for n in NOMBRES}
json.dump({"version": 1, "articulaciones": NOMBRES, "angulos": A, "cabeceos": P, "rejilla": rejilla,
	"recogida": rec, "base": base,
	"nota": "Hecho en Blender (animaciones/blender/poses.py). Rotaciones (x, y, z, w) de las Transform de los Motor6D."},
	open(salida, "w"))
print("EXPORTADO", len(A) * len(P), "poses ->", salida)
