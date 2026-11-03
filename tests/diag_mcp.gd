@tool
extends EditorScript
## Diagnóstico temporal del plugin Godot AI (Claude, 2026-11-01). Se puede borrar.
## Abrir en el editor de scripts y Archivo > Ejecutar (Ctrl+Shift+X).

func _cmd(exe: String, args: PackedStringArray, max_ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	var info := OS.execute_with_pipe(exe, args, false)
	if info.is_empty():
		print("DIAG %s: no se pudo lanzar" % exe)
		return
	var pid: int = info.pid
	var io: FileAccess = info.stdio
	var salida := ""
	while OS.is_process_running(pid) and Time.get_ticks_msec() - t0 < max_ms:
		salida += io.get_as_text()
		OS.delay_msec(50)
	salida += io.get_as_text()
	var vivo := OS.is_process_running(pid)
	print("DIAG %s: %s tras %d ms, %d caracteres de salida" % [exe, "SIGUE COLGADO" if vivo else "terminó", Time.get_ticks_msec() - t0, salida.length()])
	for l in salida.split("\n"):
		if l.contains(":8001") or l.contains(":8002") or l.to_lower().contains("godot-ai") or l.to_lower().contains("python") or l.to_lower().contains("uv.exe"):
			print("DIAG   ", l.strip_edges())
	if vivo:
		OS.kill(pid)


func _run() -> void:
	print("DIAG ---- inicio")
	_cmd("netstat", ["-ano"], 8000)
	_cmd("tasklist", ["/FO", "CSV", "/NH"], 8000)
	_cmd("powershell", ["-NoProfile", "-NonInteractive", "-Command", "Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 8001,8002 } | Format-Table -AutoSize | Out-String"], 10000)
	var srv := TCPServer.new()
	for p in [8001, 8002]:
		var e := srv.listen(p, "127.0.0.1")
		print("DIAG puerto %d: %s" % [p, "LIBRE" if e == OK else "OCUPADO (error %d)" % e])
		srv.stop()
	print("DIAG ---- fin")
