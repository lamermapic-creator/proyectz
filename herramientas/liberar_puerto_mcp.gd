@tool
extends EditorScript
## Herramienta del editor (abrir este script y Archivo → Ejecutar, o Ctrl+Shift+X).
## Cierra el servidor de Godot AI que tiene ocupados los puertos 8001/8002 (por ejemplo uno de una versión vieja
## que quedó suelto al actualizar el plugin: el dock dice "Incompatible server on port 8001"). Solo cierra servidores
## lanzados con "python -m godot_ai" (el viejo era un pythonw del sistema; los de uvx no salen así) y nunca el puente
## "attach" de Claude; cualquier otro lo enseña y lo deja. Enseña también quién lo lanzó (padre y abuelo). Después: "Restart Server" en el dock.
## El resultado sale en la Salida y en herramientas/liberar_puerto_mcp.log.

func _run() -> void:
	var ps := """
$ids = Get-NetTCPConnection -LocalPort 8001,8002 -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
if (-not $ids) { Write-Output 'Nadie escucha en 8001/8002' }
foreach ($id in $ids) {
  $w = Get-CimInstance Win32_Process -Filter "ProcessId=$id"
  Write-Output ('PUERTO pid=' + $id + ' ' + $w.Name + ' | ' + $w.CommandLine)
  $pp = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $w.ParentProcessId)
  if ($pp) {
    Write-Output ('  PADRE pid=' + $pp.ProcessId + ' ' + $pp.Name + ' | ' + $pp.CommandLine)
	$ab = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $pp.ParentProcessId)
    if ($ab) { Write-Output ('  ABUELO pid=' + $ab.ProcessId + ' ' + $ab.Name + ' | ' + $ab.CommandLine) }
  }
  if ($w.CommandLine -match '-m godot_ai' -and $w.CommandLine -notmatch 'attach') {
    Stop-Process -Id $id -Force
    Write-Output ('CERRADO ' + $id)
  } else {
    Write-Output ('NO SE CIERRA (no es un servidor viejo de godot-ai): ' + $id)
  }
}
"""
	var salida := []
	var codigo := OS.execute("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps], salida, true)
	var texto := "liberar_puerto_mcp: código %d\n%s" % [codigo, "\n".join(PackedStringArray(salida))]
	print(texto)
	var f := FileAccess.open("res://herramientas/liberar_puerto_mcp.log", FileAccess.WRITE)
	if f:
		f.store_string(texto)
