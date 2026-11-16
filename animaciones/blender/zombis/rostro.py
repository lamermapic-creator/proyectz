"""Piel plana y uniforme: sin relieve, manchas realistas ni rasgos en capas."""
import bpy
import numpy as np

def esculpir(head,ns,index,skin,ident):
    for face in head.data.polygons: face.use_smooth=False
    uv=head.data.uv_layers.new(name='UVMap')
    for face in head.data.polygons:
        n=ns['C'].inverted()@face.normal
        axis=max(range(3),key=lambda i:abs(n[i]))
        axes=[i for i in range(3) if i!=axis]
        for li in face.loop_indices:
            g=ns['C'].inverted()@head.data.vertices[head.data.loops[li].vertex_index].co
            uv.data[li].uv=(g[axes[0]]+.5,g[axes[1]]+.5)
    pixels=np.ones((512,512,4),dtype=np.float32)
    pixels[:,:,:3]=np.array(skin)/255
    image=bpy.data.images.new('PielPlana_%02d'%index,width=512,height=512)
    image.pixels.foreach_set(pixels.ravel());image.pack()
    mat=head.data.materials[0].copy();mat.name='PielPlana_%02d'%index
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest'
    mat.node_tree.links.new(tex.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.92
    head.data.materials.clear();head.data.materials.append(mat)
