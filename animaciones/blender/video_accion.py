import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vista
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
esc = bpy.context.scene
vista.preparar((640, 480), 6)
arm = bpy.data.objects["Piloto"]
fwd = arm.matrix_world.to_3x3() @ Vector((0, 0, -1))
yaw = math.atan2(fwd.y, fwd.x)
esc.frame_set(1)
f0 = vista.foco_godot()
a = math.radians(float(args[0])) + yaw
d = Vector((math.cos(a), math.sin(a), 0.45)).normalized()
cam = bpy.data.objects["Cam"]
cam.location = f0 + d * 9.0
cam.rotation_euler = (f0 - cam.location).to_track_quat('-Z', 'Y').to_euler()
esc.render.engine = args[1]
esc.render.fps = 30
esc.render.filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), "renders", "accion_") 
esc.frame_step = int(args[2]) if len(args) > 2 else 1
bpy.ops.render.render(animation=True)
