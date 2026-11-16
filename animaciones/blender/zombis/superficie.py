"""Microrelieve original, determinista y portable: normales de tejido y poros en GLB."""
import bpy
import numpy as np

def aplicar(ns, index):
    rng=np.random.default_rng(24500+index)
    size=512
    y,x=np.mgrid[0:size,0:size]
    for kind in ['Fabric','Skin']:
        h=rng.normal(0,.12,(size,size))
        if kind=='Fabric':
            h+=.28*np.sin(x*np.pi/2)*np.cos(y*np.pi/2)
            h+=.08*np.sin(x*.10+y*.03)
        else:
            h+=.035*np.sin(x*.3)*np.sin(y*.24)
        dy,dx=np.gradient(h)
        n=np.stack([-dx,-dy,np.ones_like(h)],axis=-1)
        n/=np.linalg.norm(n,axis=-1)[...,None]
        pixels=np.ones((size,size,4),dtype=np.float32); pixels[:,:,:3]=n*.5+.5
        image=bpy.data.images.new('MicroNormal_'+kind,width=size,height=size)
        image.colorspace_settings.name='Non-Color'; image.pixels.foreach_set(pixels.ravel()); image.pack()
        materials=set()
        for e in ns['vacios'].values():
            for ob in e.children:
                if ob.type!='MESH': continue
                applicable=[m for m in ob.data.materials if m and (m.name.startswith(kind+'_') or (kind=='Skin' and m.name.startswith('PielRostro')))]
                if not applicable: continue
                materials.update(applicable)
                if not ob.data.uv_layers:
                    uv=ob.data.uv_layers.new(name='UVMap')
                    for face in ob.data.polygons:
                        axis=max(range(3),key=lambda i:abs(face.normal[i]))
                        axes=[i for i in range(3) if i!=axis]
                        for li in face.loop_indices:
                            v=ob.data.vertices[ob.data.loops[li].vertex_index].co
                            uv.data[li].uv=(v[axes[0]]*2,v[axes[1]]*2)
        for m in materials:
            nodes=m.node_tree.nodes; links=m.node_tree.links
            tex=nodes.new('ShaderNodeTexImage'); tex.image=image
            normal=nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.32 if kind=='Skin' else .55
            links.new(tex.outputs['Color'],normal.inputs['Color'])
            links.new(normal.outputs['Normal'],nodes['Principled BSDF'].inputs['Normal'])
