"""Blender 4.3: acciones de combate del superviviente y exportación de sus curvas IK."""
from pathlib import Path
import json
import sys
import bpy

carpeta = Path(__file__).resolve().parent
sys.path.insert(0, str(carpeta))
import diseno_cc as dc

def clips():
	for arma, lista in dc.GOLPES.items():
		for i, golpe in enumerate(lista):
			yield f"{arma}_{i+1}", golpe
	for golpe in dc.PUNOS:
		yield golpe["nombre"], golpe
	yield "Suelo", dc.SUELO


def crear():
	import ver_cc as vista
	arm = vista.arm
	for obj in list(arm.children):
		if obj.parent_bone == "RightWrist" and obj.type == "MESH" and not obj.name.startswith("M_"):
			obj.hide_render = obj.hide_viewport = True
	arm.animation_data_clear()
	arm.animation_data_create()
	for nombre, golpe in clips():
		act = bpy.data.actions.new("CC_" + nombre)
		act.use_fake_user = True
		arm.animation_data.action = act
		fin = golpe["dur"] * 60
		curvas = {}
		for canal in dc.canales(golpe["claves"]):
			arm[canal] = 0.0
			curva = act.fcurves.new(f'["{canal}"]', action_group="Controles IK")
			curvas[canal] = curva
			for u, _pose in golpe["claves"]:
				valor = dc.muestra(golpe, canal, u)
				t = u
				if 0 < u < 1:
					# El peso cambia de pie antes de que gire el pecho. El codo recoge
					# después del contacto y la cabeza amortigua la vuelta a guardia.
					if canal.startswith(("cad_", "pel_")):
						t -= 0.075
					elif canal.startswith("cue_"):
						t += 0.045
					if canal == "cad_x":
						valor += (-1 if golpe.get("lado") == "L" else 1) * (0.10 if u < golpe["golpe"] else -0.12)
					if canal in ("mr_z", "ml_z", "a_pz") and u < golpe["golpe"]:
						valor += 0.16
					if canal == "cin_r":
						valor += 0.13 * dc.muestra(golpe, "cin_y", u)
				k = curva.keyframe_points.insert(1 + t * fin, valor)
				k.handle_left_type = k.handle_right_type = "AUTO_CLAMPED"
		# Hornea la vista del esqueleto; el juego evalúa los controles sobre su IK dinámica.
		for frame in range(1, round(fin)+2, 2):
			bpy.context.scene.frame_set(frame)
			pose = {k: f.evaluate(frame) for k, f in curvas.items()}
			if "a_px" in pose:
				for eje in "xyz":
					pose["mr_"+eje] = pose["a_p"+eje]
					if nombre.startswith("Bate"):
						pose["ml_"+eje] = pose["mr_"+eje] + 0.35*pose["a_f"+eje]
						pose["pl_"+eje] = dict(x=-1.4,y=-1,z=0)[eje]
			vista.poner(pose)
			for pb in arm.pose.bones:
				for canal in ("location", "rotation_quaternion" if pb.rotation_mode == "QUATERNION" else "rotation_euler"):
					pb.keyframe_insert(data_path=canal, frame=frame, group=pb.name)
		act.pose_markers.new("Contacto").frame = round(1 + golpe["golpe"]*fin)
	arm.animation_data.action = bpy.data.actions["CC_directo"]
	bpy.context.scene.render.fps = 60
	bpy.context.scene.frame_set(1)
	bpy.context.preferences.filepaths.save_version = 0
	bpy.ops.wm.save_as_mainfile(filepath=str(carpeta/"golpes.blend"), compress=True)


if __name__ == "__main__":
	if "--crear" in sys.argv:
		crear()
	else:
		salida = {}
		for nombre, golpe in clips():
			act = bpy.data.actions["CC_"+nombre]
			salida[nombre] = {f.data_path[2:-2]: [f.evaluate(1 + golpe["dur"]*60*i/39) for i in range(40)]
				for f in act.fcurves if f.data_path.startswith('["')}
		Path(sys.argv[-1]).write_text(json.dumps(salida))
