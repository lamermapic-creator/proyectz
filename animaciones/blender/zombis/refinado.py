"""v7: bloques limpios según las referencias del usuario, sin pliegues superpuestos."""
import bpy
from rostro import esculpir
from deterioro import aplicar as deteriorar


def aplicar(ns,index,spec):
    ident,_,shirt,pants,kind=spec
    # Rehacer solo el arte: se conservan los quince vacíos y sus centros R15.
    for piece in ns['vacios'].values():
        for ob in list(piece.children):
            bpy.data.objects.remove(ob,do_unlink=True)
    box=ns['caja']
    skin=[(155,183,167),(160,183,181),(169,184,162),(160,176,158)][index%4]
    boot=(35,38,40); hair=(48,46,40)
    # Paleta plana, con los tres ejemplos como anclas de color.
    if ident=='granjero': shirt,pants=(191,157,62),(73,105,132)
    if ident=='repartidor': shirt,pants=(173,70,66),(73,105,139)
    if ident=='vagabundo': shirt,pants=(103,90,77),(88,81,67)
    for part,(size,pos) in ns['PIEZAS'].items():
        category=part.replace('Left','').replace('Right','')
        color=skin if category in ['Head','LowerArm','Hand'] else pants if category in ['LowerTorso','UpperLeg','LowerLeg'] else boot if category=='Foot' else shirt
        ob=box(part,'Cuerpo_'+part,pos,size,color,'Skin' if color==skin else 'Fabric')
        if part=='Head':
            ob.name='Craneo'
            esculpir(ob,ns,index,skin,ident)
    # Cara legible con rasgos casi al ras, sin labios ni párpados en capas.
    for side in [-1,1]:
        box('Head','Ojo',(side*.15,2.09,-.392),(.10,.105,.005),(121,128,104),'Eye')
        box('Head','Iris',(side*.15,2.114,-.396),(.061,.046,.003),(58,60,48),'Eye')
        box('Head','Oreja',(side*.365,2.02,.015),(.035,.15,.08),skin,'Skin')
    box('Head','Nariz',(0,1.995,-.405),(.045,.09,.034),skin,'Skin')
    box('Head','Boca',(0,1.82,-.393),(.21,.065 if index%3 else .09,.005),(111,64,52),'Skin')
    # Palma y pulgar simples; tres incisiones visuales sugieren dedos cuadrados.
    for side,prefix in [(-1,'Left'),(1,'Right')]:
        box(prefix+'Hand','Pulgar',(side*.92-side*.17,-.79,-.01),(.065,.12,.10),skin,'Skin')
        for i in range(3):
            box(prefix+'Hand','DivisionDedos',(side*.92-.07+i*.07,-.94,-.111),(.006,.10,.002),tuple(int(c*.84) for c in skin),'Skin')
    T='UpperTorso';H='Head'
    # Solo elementos grandes que identifican el oficio; ninguna arruga o parche.
    if kind not in ['obra','bombero','gorra','peto']:
        box(H,'Cabello',(0,2.43,.045),(.71,.09,.70),hair,'Hair')
        box(H,'CabelloNuca',(0,2.25,.36),(.71,.29,.06),hair,'Hair')
    if kind in ['obra','bombero']:
        color=(198,163,64) if kind=='obra' else (125,57,43)
        box(H,'Casco',(0,2.46,.02),(.77,.22,.83),color)
        box(H,'AlaCasco',(0,2.34,-.04),(.94,.045,.99),color)
        for x in [-.43,.43]: box(T,'Reflectante',(x,.93,-.374),(.09,1.02,.008),(190,188,130))
    if kind=='gorra':
        box(H,'Gorra',(0,2.43,.02),(.74,.20,.79),shirt)
        box(H,'Visera',(0,2.34,-.48),(.72,.035,.30),shirt)
    if kind=='peto':
        box(H,'Sombrero',(0,2.49,.03),(.76,.28,.77),(165,132,83))
        box(H,'AlaSombrero',(0,2.34,-.03),(1.02,.05,1.02),(181,150,99))
        box(T,'Peto',(0,.73,-.383),(1.04,.90,.020),pants)
        for x in [-.46,.46]:
            box(T,'Tirante',(x,1.25,-.383),(.12,.60,.020),pants)
            box(T,'Hebilla',(x,1.04,-.398),(.085,.045,.009),(155,155,138),'Metal')
    if kind in ['medico','mono','camisa']:
        # Un bolsillo de costura discreto, casi plano.
        box(T,'Bolsillo',(-.34,1.02,-.375),(.27,.27,.008),tuple(int(c*.94) for c in shirt))
    if kind=='medico':
        box(T,'Identificacion',(.35,1.12,-.377),(.17,.21,.009),(192,194,174))
    if kind=='corbata':
        box(T,'Corbata',(0,1.09,-.379),(.10,.67,.013),(98,51,44))
    if kind=='policia':
        box(T,'Chaleco',(0,.88,-.39),(1.17,1.12,.04),(37,44,54))
        box(T,'Placa',(-.34,1.18,-.415),(.14,.17,.012),(161,145,80),'Metal')
    if kind=='mochila':
        box(T,'Mochila',(0,.91,.49),(.91,1.02,.24),shirt)
        for x in [-.45,.45]: box(T,'Correa',(x,.96,-.377),(.10,1.08,.012),(54,55,44))
    if kind=='paciente':
        box('LeftLowerArm','Pulsera',(-.92,-.47,-.194),(.34,.045,.008),(189,190,162))
    # Detalle original y plano de sangre por píxeles; cero pliegues sobre el cuerpo.
    frontal=-.418 if kind=='policia' else -.398 if kind=='peto' else -.381 if kind in ['mochila','corbata'] else -.378
    deteriorar(ns,index,spec,frontal)
    forbidden=('Pliegue','Tendon','Coagulo','Desgaste','Parche','Hilo','Nudillo','Labio','Cerebro')
    assert not any(ob.name.startswith(forbidden) for e in ns['vacios'].values() for ob in e.children)
