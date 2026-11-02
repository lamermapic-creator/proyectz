class_name PosturasPie
## Posturas con armas de fuego DE PIE, DISEÑADAS EN BLENDER (animaciones/blender/diseno_pie.py, revisadas con
## ver_pie.py sobre pie_Rifle.blend / pie_Pistola.blend). Generado por a_gd_pie.py: no editar a mano.
## Por arma base y estado: giro del pecho (blade), inclinación (lean), cabeza (nP, nR) y polos de los codos
## (respecto al centro del pecho, girado con el rumbo). El arma va donde siempre (Armas.pose).

const PC_CINTURA := 0.3
const PC_CUELLO := 0.4
const DATOS := {
	"Rifle": {
		"AIM": {"blade": 0.45, "lean": -0.1, "nP": -0.16, "nR": -0.18, "polo_r": Vector3(1.7, -0.35, 0.35), "polo_l": Vector3(-0.45, -1.9, -0.7)},
		"HIP": {"blade": 0.32, "lean": -0.06, "nP": -0.06, "nR": -0.05, "polo_r": Vector3(1.9, -1.0, 0.6), "polo_l": Vector3(-0.7, -1.9, -0.5)},
		"LOW": {"blade": 0.3, "lean": -0.05, "nP": -0.06, "nR": 0.0, "polo_r": Vector3(1.9, -1.4, 0.9), "polo_l": Vector3(-1.0, -1.9, -0.2)},
		"SPRINT": {"blade": 0.12, "lean": -0.04, "nP": 0.0, "nR": 0.0, "polo_r": Vector3(1.9, -1.4, 0.6), "polo_l": Vector3(-1.6, -1.6, 0.2)},
	},
	"Pistola": {
		"AIM": {"blade": 0.08, "lean": -0.07, "nP": -0.06, "nR": 0.0, "polo_r": Vector3(1.2, -1.7, 0.1), "polo_l": Vector3(-1.2, -1.7, 0.1)},
		"HIP": {"blade": 0.06, "lean": -0.05, "nP": -0.03, "nR": 0.0, "polo_r": Vector3(1.4, -1.8, 0.4), "polo_l": Vector3(-1.3, -1.8, 0.3)},
		"LOW": {"blade": 0.05, "lean": -0.04, "nP": -0.08, "nR": 0.0, "polo_r": Vector3(1.4, -1.8, 0.5), "polo_l": Vector3(-1.3, -1.8, 0.4)},
		"SPRINT": {"blade": 0.0, "lean": -0.04, "nP": 0.0, "nR": 0.0, "polo_r": Vector3(1.9, -1.4, 0.9), "polo_l": Vector3(-1.9, -1.5, 0.3)},
	},
}
