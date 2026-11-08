@tool
extends EditorScript
## Diagnóstico temporal del plugin Godot AI (Claude, 2026-11-07). Se puede borrar. Solo mira, no cierra nada.
## Ejecuta el mismo script de PowerShell que el plugin (ascendencia del proceso) de dos formas, con tiempo máximo.
## Resultado en la Salida y en tests/diag_puertos2.log.

var _log := ""
static var _ps_out: Array = []
static var _ps_code := -99
static var _hilos: Array = []

func _p(t: String) -> void:
	print(t)
	_log += t + "\n"


func _run() -> void:
	_p("DIAG3 ---- inicio " + Time.get_datetime_string_from_system())
	var yo := OS.get_process_id()
	var script: String = McpPortResolver._windows_process_snapshot_script(yo)
	var exe := OS.get_environment("SystemRoot").replace("\\", "/") + "/System32/WindowsPowerShell/v1.0/powershell.exe"
	var args := PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script])
	# 1) con tubería, sin bloquear
	var t0 := Time.get_ticks_msec()
	var info := OS.execute_with_pipe(exe, args, false)
	var salida := ""
	if not info.is_empty():
		while OS.is_process_running(info.pid) and Time.get_ticks_msec() - t0 < 20000:
			salida += info.stdio.get_as_text()
			OS.delay_msec(50)
		salida += info.stdio.get_as_text()
		var vivo := OS.is_process_running(info.pid)
		_p("DIAG3 tuberia: %s tras %d ms: %s" % ["COLGADO" if vivo else "terminó", Time.get_ticks_msec() - t0, salida.strip_edges().left(600)])
		if vivo:
			OS.kill(info.pid)
	# 2) igual que el plugin: OS.execute bloqueante dentro de un hilo
	var th := Thread.new()
	_hilos.append(th)
	t0 = Time.get_ticks_msec()
	th.start(func(): _ps_code = OS.execute(exe, args, _ps_out, true))
	while th.is_alive() and Time.get_ticks_msec() - t0 < 20000:
		OS.delay_msec(50)
	if th.is_alive():
		_p("DIAG3 como el plugin (hilo + OS.execute): COLGADO tras 20 s")
	else:
		th.wait_to_finish()
		_p("DIAG3 como el plugin: código %d tras %d ms: %s" % [_ps_code, Time.get_ticks_msec() - t0, str(_ps_out).strip_edges().left(600)])
	_p("DIAG3 ---- fin")
	var f := FileAccess.open("res://tests/diag_puertos2.log", FileAccess.WRITE)
	if f:
		f.store_string(_log)
