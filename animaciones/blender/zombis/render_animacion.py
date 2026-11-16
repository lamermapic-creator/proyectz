"""Marcha: 12 PNG en /tmp/zombis-preview. Con --detalle: primer plano en detalle.png."""
import bpy, math, sys
from mathutils import Vector
from pathlib import Path
source=Path('/tmp/zombis-v3') if '--vista-previa' in sys.argv else Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(source/'sanitario.blend'))
scene=bpy.context.scene
detalle='--detalle' in sys.argv
for ob in scene.objects:
    if ob.animation_data:
        for track in ob.animation_data.nla_tracks: track.mute=track.name!=('reposo' if detalle else 'caminar')
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-3.11))
mat=bpy.data.materials.new('Suelo'); mat.diffuse_color=(.06,.08,.10,1)
bpy.context.object.data.materials.append(mat)
world=bpy.data.worlds.new('Fondo'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.37,.42,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.65; scene.world=world
light=bpy.data.objects.new('Luz',bpy.data.lights.new('Luz','AREA')); scene.collection.objects.link(light)
light.location=(-4,6,7); light.data.energy=950; light.data.size=5
light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Camara',bpy.data.cameras.new('Camara')); scene.collection.objects.link(cam)
cam.location=(7,14,4); cam.rotation_euler=(Vector((0,0,-.2))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'; cam.data.ortho_scale=7; scene.camera=cam
scene.render.engine='CYCLES'; scene.cycles.samples=12; scene.cycles.use_denoising=False
scene.render.resolution_x=360; scene.render.resolution_y=440; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
out=Path('/tmp/zombis-preview'); out.mkdir(exist_ok=True)
if detalle:
    cam.location=(1.2,4.5,2.6)
    cam.rotation_euler=(Vector((0,0,2.0))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=1.65
    scene.render.resolution_x=700; scene.render.resolution_y=700
    scene.cycles.samples=48
for i,frame in enumerate([1] if detalle else range(1,49,4)):
    scene.frame_set(frame)
    scene.render.filepath=str(source/'detalle.png') if detalle else str(out/('%02d.png'%i))
    bpy.ops.render.render(write_still=True)
