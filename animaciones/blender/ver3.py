import bpy, sys, math
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vista, poses
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
lista = [tuple(float(x) for x in s.split(",")) for s in args[0].split(";")]
vistas = [tuple(float(x) for x in s.split(",")) for s in args[1].split(";")]  # az,alt,dist (az relativo al frente)
pref = args[2]
arm = bpy.data.objects["Piloto"]
c = arm.pose.bones["LeftElbow"].constraints.new('IK')
c.target = bpy.data.objects["punoL"]
c.chain_count = 2
vista.preparar((520, 480), 8)
fwd = arm.matrix_world.to_3x3() @ Vector((0, 0, -1))
yaw = math.atan2(fwd.y, fwd.x)
for i, (a, p) in enumerate(lista):
	if a > 90:
		poses.pose_recogida(p)
	else:
		poses.pose(a, p)
	for k, (az, alt, dist) in enumerate(vistas):
		if az > 900:
			az = math.degrees(a) + 180
		vista.render(os.path.join(os.path.dirname(os.path.abspath(__file__)), "renders", "%s_%02d_%d.png" % (pref, i, k)), az, alt, dist, yaw=yaw)
