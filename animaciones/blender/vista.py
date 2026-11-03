# Cámaras y luz para ver el piloto. Importar desde otros scripts: vista.preparar(), vista.render(ruta, az, alt, dist)
import bpy, math
from mathutils import Vector, Matrix


def preparar(res=(560, 520), muestras=12):
	esc = bpy.context.scene
	esc.render.engine = 'CYCLES'
	esc.cycles.device = 'CPU'
	esc.cycles.samples = muestras
	esc.cycles.use_denoising = False
	esc.render.resolution_x, esc.render.resolution_y = res
	esc.render.resolution_percentage = 100
	esc.render.film_transparent = False
	if esc.world is None:
		esc.world = bpy.data.worlds.new("Mundo")
	esc.world.use_nodes = True
	bg = esc.world.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.75, 0.8, 0.85, 1)
	bg.inputs[1].default_value = 0.9
	if "Sol" not in bpy.data.objects:
		l = bpy.data.lights.new("Sol", 'SUN')
		l.energy = 3.0
		o = bpy.data.objects.new("Sol", l)
		esc.collection.objects.link(o)
		o.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
	if "Suelo" not in bpy.data.objects:
		bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
		bpy.context.active_object.name = "Suelo"
		m = bpy.data.materials.new("suelo")
		m.diffuse_color = (0.55, 0.57, 0.6, 1)
		m.use_nodes = True
		m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.57, 0.6, 1)
		bpy.context.active_object.data.materials.append(m)
	if "Cam" not in bpy.data.objects:
		c = bpy.data.cameras.new("Cam")
		c.lens = 40
		o = bpy.data.objects.new("Cam", c)
		esc.collection.objects.link(o)
		esc.camera = o


def foco_godot():
	# centro del piloto, en el mundo de Blender
	arm = bpy.data.objects["Piloto"]
	pb = arm.pose.bones["Waist"]
	return arm.matrix_world @ (pb.head + Vector((0, 0.6, 0)))


def render(ruta, az, alt=0.3, dist=9.0, foco=None, yaw=0.0):
	# az en grados alrededor del piloto (0 = desde su derecha, 90 = desde delante), en el plano del suelo
	esc = bpy.context.scene
	f = foco if foco is not None else foco_godot()
	# en Blender (Z arriba): delante del piloto (Godot -Z) es +Y girado por el rumbo
	a = math.radians(az) + yaw
	d = Vector((math.cos(a), math.sin(a), alt)).normalized()
	cam = bpy.data.objects["Cam"]
	cam.location = f + d * dist
	dirv = f - cam.location
	cam.rotation_euler = dirv.to_track_quat('-Z', 'Y').to_euler()
	esc.render.filepath = ruta
	bpy.ops.render.render(write_still=True)
