@tool
extends EditorScript
## Diagnóstico del plugin Godot AI (dock atascado en "Starting server…"). Claude, 2026-11-07. Solo mira, no cierra nada.
## Abrir en el editor de scripts y Archivo → Ejecutar (Ctrl+Shift+X). Resultado en la Salida y en tests/diag_puertos.log.
## Si salen "HIJO … powershell.exe" con "$first = & {" que llevan minutos: son los colgados (ver CLAUDE.md, Conexión).

func _run() -> void:
	var ps := "Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq %d } | ForEach-Object { 'HIJO ' + $_.ProcessId + ' ' + $_.Name + ' desde ' + $_.CreationDate.ToString('HH:mm:ss') + ' | ' + $_.CommandLine.Substring(0, [Math]::Min(120, $_.CommandLine.Length)) }; Get-NetTCPConnection -LocalPort 8001,8002 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { 'ESCUCHA ' + $_.LocalPort + ' pid=' + $_.OwningProcess + ' ' + (Get-Process -Id $_.OwningProcess).Name }" % OS.get_process_id()
	var out := []
	var code := OS.execute("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps], out, true)
	var txt := "DIAG %s código %d\n%s" % [Time.get_datetime_string_from_system(), code, "\n".join(PackedStringArray(out))]
	print(txt)
	var f := FileAccess.open("res://tests/diag_puertos.log", FileAccess.WRITE)
	if f:
		f.store_string(txt)
