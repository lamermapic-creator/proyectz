# Mide lo suave que es la animación a partir de un registro de tests/visual.gd --registro=<csv> (a 30 fps fijos).
# Para cada pieza: tirón (jerk, 3.ª derivada de la posición respecto al cuerpo) mediano y percentil 98, y los
# "saltos" (fotogramas en que la aceleración cambia de golpe más de lo normal). Más bajo = más fluido.
# Uso: python3 tests/fluidez.py registro.csv [t_desde] [t_hasta]
import sys, csv, math, statistics
ruta = sys.argv[1]
t0 = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
t1 = float(sys.argv[3]) if len(sys.argv) > 3 else 1e9
datos = {}
for f in csv.DictReader(open(ruta)):
	t = float(f["t"])
	if t < t0 or t > t1:
		continue
	datos.setdefault(f["pieza"], []).append((t, float(f["lx"]), float(f["ly"]), float(f["lz"])))
dt = 1 / 30
res = {}
for n, xs in datos.items():
	if len(xs) < 6:
		continue
	jerks = []
	for i in range(3, len(xs)):
		j = [ (xs[i][k] - 3 * xs[i-1][k] + 3 * xs[i-2][k] - xs[i-3][k]) / dt**3 for k in (1, 2, 3)]
		jerks.append(math.sqrt(sum(c * c for c in j)))
	jerks.sort()
	med = statistics.median(jerks)
	p98 = jerks[int(len(jerks) * 0.98) - 1]
	res[n] = (med, p98, jerks[-1])
cuerpo = [n for n in res if "Foot" not in n]
pies = [n for n in res if "Foot" in n]
tot_med = sum(res[n][0] for n in cuerpo) / len(cuerpo)
tot_p98 = sum(res[n][1] for n in cuerpo) / len(cuerpo)
pies_p98 = sum(res[n][1] for n in pies) / max(1, len(pies))
pies_max = max(res[n][2] for n in pies) if pies else 0
for n, (m, p, mx) in sorted(res.items()):
	print("  %-14s jerk mediano %7.0f  p98 %8.0f  max %8.0f" % (n, m, p, mx))
print("FLUIDEZ cuerpo_mediano=%.0f cuerpo_p98=%.0f pies_p98=%.0f pies_max=%.0f" % (tot_med, tot_p98, pies_p98, pies_max))
if "--picos" in sys.argv:
	pic = []
	for n, xs in datos.items():
		for i in range(3, len(xs)):
			j = [(xs[i][k] - 3 * xs[i-1][k] + 3 * xs[i-2][k] - xs[i-3][k]) / dt**3 for k in (1, 2, 3)]
			pic.append((math.sqrt(sum(c * c for c in j)), xs[i][0], n))
	pic.sort(reverse=True)
	for v, t, n in pic[:14]:
		print("  pico %6.0f t=%.2f %s" % (v, t, n))
