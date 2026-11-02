@tool
extends EditorScript
## Diagnóstico temporal del plugin Godot AI (Claude, 2026-11-01). Se puede borrar.
## Repite paso a paso la comprobación del plugin, cada paso en un hilo con tiempo máximo.

var _log := ""
func _p(t: String) -> void:
	print(t)
	_log += t + "\n"


func _paso(nombre: String, f: Callable, max_ms: int) -> Variant:
	var th := Thread.new()
	var t0 := Time.get_ticks_msec()
	th.start(f)
	while th.is_alive() and Time.get_ticks_msec() - t0 < max_ms:
		OS.delay_msec(20)
	if th.is_alive():
		_p("DIAG2 %s: SIGUE COLGADO tras %d ms" % [nombre, max_ms])
		return null
	var r = th.wait_to_finish()
	var txt := str(r)
	_p("DIAG2 %s: %d ms -> %s" % [nombre, Time.get_ticks_msec() - t0, txt.substr(0, 300)])
	return r


func _run() -> void:
	_p("DIAG2 ---- inicio")
	var listeners = _paso("netstat (snapshot)", func(): return McpPortResolver.windows_listener_snapshot().get("listeners", {}).has(8001), 15000)
	_paso("ruta capacidad", func(): return McpTransportCapability.path_for_http_port(8001), 5000)
	var cap = _paso("leer capacidad", func(): return McpTransportCapability.read_for_http_port(8001, ""), 20000)
	_paso("estado HTTP", func(): return McpServerLifecycleManager.probe_live_server_status(8001, 3000, ""), 20000)
	_paso("pid vivo 122680", func(): return McpPortResolver.pid_alive(122680), 15000)
	_paso("huella 122680", func(): return McpPortResolver.process_fingerprint(122680), 20000)
	_p("DIAG2 ---- fin")
