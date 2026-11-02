# Guarda en piloto.blend una acción "Apuntado_barrido" para verlas en Blender: la mira da la vuelta (cabeceo 0)
# por la izquierda hasta detrás y luego pasa por encima del hombro derecho; abrir piloto.blend y darle a Play
import bpy, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import poses
arm = bpy.data.objects["Piloto"]
NOM = ["Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist"]
c = arm.pose.bones["LeftElbow"].constraints.get("IK") or arm.pose.bones["LeftElbow"].constraints.new('IK')
c.target = bpy.data.objects["punoL"]
c.chain_count = 2
arm.animation_data_create()
acc = bpy.data.actions.new("Apuntado_barrido")
arm.animation_data.action = acc
f = 1
secuencia = [x * 0.25 for x in range(0, 12)] + [2.85, -3.43] + [-3.43 + x * 0.25 for x in range(1, 14)] + [0.0]
for a in secuencia:
	if a == -3.43 and f > 1:
		poses.pose_recogida(-2.5)
		for n in NOM:
			arm.pose.bones[n].rotation_mode = 'QUATERNION'
			arm.pose.bones[n].keyframe_insert("rotation_quaternion", frame=f + 6)
		f += 12
	poses.pose(a, 0.0)
	for n in NOM:
		pb = arm.pose.bones[n]
		pb.rotation_mode = 'QUATERNION'
		pb.keyframe_insert("rotation_quaternion", frame=f)
	f += 6
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = f
bpy.ops.wm.save_mainfile()
print("ACCION", f)
