"""Valida los bytes GLB y el catálogo con Python estándar. No escribe archivos."""
import hashlib, json, math, struct
from pathlib import Path

root=Path(__file__).resolve().parents[3]
folder=root/'modelos/zombis'
catalog=json.loads((folder/'catalogo.json').read_text())
assert len(catalog['modelos']) == 12
assert catalog['version'] == 2
assert catalog['presupuesto_triangulos'] == 16000
for spec in catalog['modelos']:
    data=(folder/(spec['id']+'.glb')).read_bytes()
    assert hashlib.sha256(data).hexdigest()==spec['sha256'], spec['id']+' hash'
    magic,version,length=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and length==len(data)
    jlen,kind=struct.unpack_from('<I4s',data,12)
    assert kind==b'JSON'
    doc=json.loads(data[20:20+jlen])
    assert not doc.get('images') and not doc.get('extensionsRequired')
    assert len(doc['meshes'])==15
    triangles=0
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode',4)==4
            acc=doc['accessors'][primitive['attributes']['POSITION']]
            assert all(math.isfinite(v) for v in acc['min']+acc['max'])
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
