"""Render de revisión de los 12 archivos fuente, sin modificar sus bytes."""
import bpy, math
from pathlib import Path
from mathutils import Vector
SOURCE=Path(__file__).resolve().parent
ids=['civil','sanitario','obrero','mecanico','policia','bombero','excursionista','oficinista','repartidor','paciente','granjero','vagabundo']
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
for i,ident in enumerate(ids):
    with bpy.data.libraries.load(str(SOURCE/(ident+'.blend')),link=False) as (src,dst):
        dst.objects=src.objects
    for ob in dst.objects:
        if ob:
            scene.collection.objects.link(ob)
            ob.animation_data_clear()
    root=next(ob for ob in dst.objects if ob and ob.name.startswith('Zombi_'))
    root.location=(i%4*4.8-7.2, -(i//4)*7.5,3.12)
    bpy.ops.object.text_add(location=(root.location.x,root.location.y+1.8,.03),rotation=(0,0,math.pi))
    txt=bpy.context.object; txt.data.body=ident.upper(); txt.data.align_x='CENTER'; txt.data.size=.30
    txt.rotation_euler=(math.radians(68),0,math.pi)
mat=bpy.data.materials.new('Fondo'); mat.diffuse_color=(.065,.085,.095,1)
bpy.ops.mesh.primitive_plane_add(size=200)
bpy.context.object.data.materials.append(mat)
world=bpy.data.worlds.new('Estudio'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.35,.40,.47,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5; scene.world=world
for name,pos,power,size in [('Principal',(-10,12,20),2400,10),('Relleno',(12,0,12),1700,10),('Borde',(0,-20,14),2600,8)]:
    ob=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA')); scene.collection.objects.link(ob)
    ob.location=pos; ob.data.energy=power; ob.data.shape='DISK'; ob.data.size=size
    ob.rotation_euler=(Vector((0,-7,2))-ob.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera')); scene.collection.objects.link(cam)
cam.location=(12,31,25); target=Vector((0,-7,2.4)); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'; cam.data.ortho_scale=28; scene.camera=cam
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=False
scene.render.resolution_x=1500; scene.render.resolution_y=1250; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(SOURCE/'catalogo.png')
bpy.ops.render.render(write_still=True)
