import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vista, poses_pie, diseno_pie
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
arma, cual, lista, vistas, pref = args[0], args[1], args[2].split(";"), args[3].split(";"), args[4]
arm = bpy.data.objects["Piloto"]
vista.preparar((420, 460), 8)
fwd = arm.matrix_world.to_3x3() @ Vector((0, 0, -1))
yaw = math.atan2(fwd.y, fwd.x)
for i, s in enumerate(lista):
	estado, pc = s.split(",")
	d = getattr(diseno_pie, cual)(arma, estado)
	poses_pie.aplicar(d, float(pc))
	for k, v in enumerate(vistas):
		az, alt, dist = (float(x) for x in v.split(","))
		vista.render(os.path.join(os.path.dirname(os.path.abspath(__file__)), "renders", "%s_%02d_%d.png" % (pref, i, k)), az, alt, dist, yaw=yaw)
