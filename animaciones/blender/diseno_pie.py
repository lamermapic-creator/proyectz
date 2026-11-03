# Diseños de las posturas de pie (viejos = los del juego antes de Blender, para comparar; nuevos = los de Blender)
from mathutils import Vector
import poses_pie as pp


def viejo(arma, estado):
	pv = {k: pp.tf(v) for k, v in pp.DR["poses_viejas"].items()}
	rifle = arma == "Rifle"
	apunta = estado == "AIM"
	blade = (0.4 if apunta else 0.25) if rifle and estado != "SPRINT" else 0.0
	def f(pc):
		if estado == "AIM" or estado == "HIP":
			return pp.rx(pc) @ pv[estado]
		if estado == "LOW":
			return pp.rx(pc * 0.35) @ pv[estado]
		return pv[estado]
	k = 1.0 if estado in ("AIM", "HIP") else 0.35
	nP0 = -0.12 if (rifle and apunta) else 0.0
	nR0 = -0.1 if (rifle and apunta) else 0.0
	return {"arma": f, "w": lambda pc: (-blade, 0.35 * pc, 0.0), "n": lambda pc: (blade * 0.9, nP0 + 0.35 * pc, nR0),
		"polo_r": (1.9, -1.4, 0.9), "polo_l": (-1.9, -1.5, 0.3), "apoyo": "LeftGrip" if rifle else "SupportGrip",
		"pc_torso": 0.35}


## ---------------------------------------------------------------- posturas nuevas (Blender, 2026-11-01)
## Rifle: culata en el hombro con el codo derecho más alto y hacia fuera, el izquierdo bajo el guardamanos, el cuerpo
## de perfil (blade) y algo echado hacia delante, la mejilla sobre la culata. Pistola: isósceles con los dos brazos
## estirados y los codos algo flexionados hacia abajo, el pecho de frente y echado un poco hacia delante.
NUEVO = {
	"Rifle": {
		"AIM": {"blade": 0.45, "lean": -0.10, "nP": -0.16, "nR": -0.18, "polo_r": (1.7, -0.35, 0.35), "polo_l": (-0.45, -1.9, -0.7)},
		"HIP": {"blade": 0.32, "lean": -0.06, "nP": -0.06, "nR": -0.05, "polo_r": (1.9, -1.0, 0.6), "polo_l": (-0.7, -1.9, -0.5)},
		"LOW": {"blade": 0.30, "lean": -0.05, "nP": -0.06, "nR": 0.0, "polo_r": (1.9, -1.4, 0.9), "polo_l": (-1.0, -1.9, -0.2)},
		"SPRINT": {"blade": 0.12, "lean": -0.04, "nP": 0.0, "nR": 0.0, "polo_r": (1.9, -1.4, 0.6), "polo_l": (-1.6, -1.6, 0.2)},
	},
	"Pistola": {
		"AIM": {"blade": 0.08, "lean": -0.07, "nP": -0.06, "nR": 0.0, "polo_r": (1.2, -1.7, 0.1), "polo_l": (-1.2, -1.7, 0.1)},
		"HIP": {"blade": 0.06, "lean": -0.05, "nP": -0.03, "nR": 0.0, "polo_r": (1.4, -1.8, 0.4), "polo_l": (-1.3, -1.8, 0.3)},
		"LOW": {"blade": 0.05, "lean": -0.04, "nP": -0.08, "nR": 0.0, "polo_r": (1.4, -1.8, 0.5), "polo_l": (-1.3, -1.8, 0.4)},
		"SPRINT": {"blade": 0.0, "lean": -0.04, "nP": 0.0, "nR": 0.0, "polo_r": (1.9, -1.4, 0.9), "polo_l": (-1.9, -1.5, 0.3)},
	},
}
# reparto del cabeceo: el arma sube/baja entera (hay que apuntar); el pecho y la cabeza acompañan
PC_CINTURA = 0.30
PC_CUELLO = 0.40


def nuevo(arma, estado):
	pv = {k: pp.tf(v) for k, v in pp.DR["poses_viejas"].items()}
	p = NUEVO[arma][estado]
	k = 1.0 if estado in ("AIM", "HIP") else (0.35 if estado == "LOW" else 0.0)
	def f(pc):
		return pp.rx(pc * k) @ pv[estado]
	return {"arma": f, "w": lambda pc: (-p["blade"], p["lean"] + PC_CINTURA * pc * k, 0.0),
		"n": lambda pc: (p["blade"] * 0.9, p["nP"] + PC_CUELLO * pc * k - p["lean"] * 0.6, p["nR"]),
		"polo_r": p["polo_r"], "polo_l": p["polo_l"], "apoyo": "LeftGrip" if arma == "Rifle" else "SupportGrip"}
