"""Valida los bytes GLB y el catálogo con Python estándar. No escribe archivos."""
import hashlib, json, math, struct
from pathlib import Path

root=Path(__file__).resolve().parents[3]
folder=root/'modelos/zombis'
catalog=json.loads((folder/'catalogo.json').read_text())
assert len(catalog['modelos']) == 12
assert catalog['version'] == 7
assert catalog['presupuesto_triangulos'] == 16000
assert {s['id'] for s in catalog['modelos'] if s['cerebro_visible']} == set()
for spec in catalog['modelos']:
    data=(folder/(spec['id']+'.glb')).read_bytes()
    assert hashlib.sha256(data).hexdigest()==spec['sha256'], spec['id']+' hash'
    magic,version,length=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and length==len(data)
    jlen,kind=struct.unpack_from('<I4s',data,12)
    assert kind==b'JSON'
    doc=json.loads(data[20:20+jlen])
    assert not doc.get('extensionsRequired')
    assert len(doc.get('images', [])) == 2
    assert not any('normalTexture' in m for m in doc['materials'])
    for image in doc['images']:
        assert 'uri' not in image and image['mimeType']=='image/png'
        view=doc['bufferViews'][image['bufferView']]
        binary_start=20+jlen+8
        png=data[binary_start+view.get('byteOffset',0):binary_start+view.get('byteOffset',0)+view['byteLength']]
        assert png[:8]==b'\x89PNG\r\n\x1a\n'
        assert struct.unpack_from('>II',png,16)==(512,512)
    assert len(doc['meshes'])==15
    assert any(m['name'].startswith('Cerebro') for m in doc['materials']) == spec['cerebro_visible']
    assert any(m['name'].startswith('SangreRopa') and m.get('alphaMode')=='BLEND' for m in doc['materials'])
    # Inspección de los bytes exportados: normales planas, nunca interpoladas como una esfera.
    def valores(accessor_id):
        acc=doc['accessors'][accessor_id]; view=doc['bufferViews'][acc['bufferView']]
        fmt={5121:'B',5123:'H',5125:'I',5126:'f'}[acc['componentType']]
        count={'SCALAR':1,'VEC3':3}[acc['type']]
        stride=view.get('byteStride',struct.calcsize('<'+fmt)*count)
        start=20+jlen+8+view.get('byteOffset',0)+acc.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*count,data,start+i*stride) for i in range(acc['count'])]
    triangles=0
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode',4)==4
            material=doc['materials'][primitive['material']]
            if 'baseColorTexture' in material.get('pbrMetallicRoughness',{}):
                assert 'TEXCOORD_0' in primitive['attributes']
            acc=doc['accessors'][primitive['attributes']['POSITION']]
            assert all(math.isfinite(v) for v in acc['min']+acc['max'])
            normales=valores(primitive['attributes']['NORMAL'])
            indices=[i[0] for i in valores(primitive['indices'])]
            for i in range(0,len(indices),3):
                n=[normales[j] for j in indices[i:i+3]]
                assert all(abs(n[0][axis]-v[axis])<1e-5 for v in n[1:] for axis in range(3)), spec['id']+' normal redondeada'
            triangles+=doc['accessors'][primitive['indices']]['count']//3
    assert 0<triangles<=catalog['presupuesto_triangulos']
    assert {a['name'] for a in doc['animations']}==set(catalog['animaciones'])
    for anim in doc['animations']:
        assert anim['channels']
        for sampler in anim['samplers']:
            times=doc['accessors'][sampler['input']]
            assert times['count']>1 and times['max'][0]>times['min'][0]
    print('OK',spec['id'],triangles,'triángulos; 6 clips; hash correcto')
print('CATALOGO_OK 12')
