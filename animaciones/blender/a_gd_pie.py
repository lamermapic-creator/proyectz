# diseno_pie.py (Blender) -> scripts/jugador/posturas_pie.gd
import sys, importlib.util, types
# diseno_pie importa poses_pie (bpy); aquí solo hacen falta los números
sys.modules["poses_pie"] = types.ModuleType("poses_pie")
sys.modules["mathutils"] = types.ModuleType("mathutils")
sys.modules["mathutils"].Vector = tuple
spec = importlib.util.spec_from_file_location("diseno_pie", sys.argv[1])
dp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dp)
L = ["class_name PosturasPie",
	"## Posturas con armas de fuego DE PIE, DISEÑADAS EN BLENDER (animaciones/blender/diseno_pie.py, revisadas con",
	"## ver_pie.py sobre pie_Rifle.blend / pie_Pistola.blend). Generado por a_gd_pie.py: no editar a mano.",
	"## Por arma base y estado: giro del pecho (blade), inclinación (lean), cabeza (nP, nR) y polos de los codos",
	"## (respecto al centro del pecho, girado con el rumbo). El arma va donde siempre (Armas.pose).",
	"",
	"const PC_CINTURA := %s" % dp.PC_CINTURA,
	"const PC_CUELLO := %s" % dp.PC_CUELLO,
	"const DATOS := {"]
for arma, est in dp.NUEVO.items():
	L.append('\t"%s": {' % arma)
	for e, p in est.items():
		L.append('\t\t"%s": {"blade": %s, "lean": %s, "nP": %s, "nR": %s, "polo_r": Vector3%s, "polo_l": Vector3%s},' % (
			e, p["blade"], p["lean"], p["nP"], p["nR"], tuple(p["polo_r"]), tuple(p["polo_l"])))
	L.append("\t},")
L.append("}")
open(sys.argv[2], "w").write("\n".join(L) + "\n")
print("GD", sys.argv[2])
