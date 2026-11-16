"""Manchas pequeñas y planas de píxeles, según las referencias limpias del usuario."""
import bpy,bmesh
import numpy as np
from mathutils import Vector
CEREBRO_VISIBLE=set()

def aplicar(ns,index,spec,frontal):
    rng=np.random.default_rng(17000+index)
    # Pocos cuadrados sobre una cuadrícula: sin ruido, gotas orgánicas ni volumen.
    rgba=np.zeros((32,32,4),dtype=np.float32)
    for i in range(9):
        x=int(rng.integers(6,26));y=int(rng.integers(6,26))
        rgba[y:y+int(rng.integers(1,3)),x:x+int(rng.integers(1,3))]=(.40,.045,.035,1)
    rgba=np.repeat(np.repeat(rgba,16,axis=0),16,axis=1)
    image=bpy.data.images.new('SangrePixel_%02d'%index,width=512,height=512,alpha=True)
    image.pixels.foreach_set(rgba.ravel());image.pack()
    mat=bpy.data.materials.new('SangreRopa_%02d'%index);mat.use_nodes=True
    bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Roughness'].default_value=.95
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest'
    mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    mat.node_tree.links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha']);mat.surface_render_method='DITHERED'
    bm=bmesh.new();uv=bm.loops.layers.uv.new('UVMap')
    coords=[(-.56,.29,frontal),(-.56,1.46,frontal),(.56,1.46,frontal),(.56,.29,frontal)]
    verts=[bm.verts.new(ns['g2b'](Vector(p)-Vector(ns['PIEZAS']['UpperTorso'][1]))) for p in coords]
    face=bm.faces.new(verts)
    for loop,coord in zip(face.loops,[(0,0),(0,1),(1,1),(1,0)]):loop[uv].uv=coord
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    me=bpy.data.meshes.new('SangrePlana');bm.to_mesh(me);bm.free();me.materials.append(mat)
    ob=bpy.data.objects.new('SangrePlana',me);ns['esc'].collection.objects.link(ob);ob.parent=ns['vacios']['UpperTorso']
