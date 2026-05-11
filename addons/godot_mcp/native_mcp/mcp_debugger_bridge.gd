@tool
class_name MCPDebuggerBridge
extends EditorDebuggerPlugin

var _capture_prefixes: Array[String] = [
	"mcp",
	"debug_enter",
	"debug_exit",
	"stack_dump",
	"stack_frame_vars",
	"stack_frame_var",
	"output",
	"error"
]
var _captured_messages: Array[Dictionary] = []
var _max_messages: int = 500
var _connected_script_debuggers: Array[Object] = []
var _latest_stack_dump: Array = []
var _latest_stack_variables: Dictionary = {}
var _latest_evaluations: Dictionary = {}
var _pending_stack_vars_frame: int = 0
var _message_sequence: int = 0

func _setup_session(session_id: int) -> void:
	call_deferred("_refresh_script_debugger_connections")

func _has_capture(capture: String) -> bool:
	return _capture_prefixes.has("*") or _capture_prefixes.has(capture)

func _capture(message: String, data: Array, session_id: int) -> bool:
	_append_captured_message(session_id, message, data)
	return true

func add_capture_prefix(prefix: String) -> void:
	if prefix.is_empty() or _capture_prefixes.has(prefix):
		return
	_capture_prefixes.append(prefix)

func get_sessions_info() -> Array[Dictionary]:
	_refresh_script_debugger_connections()
	var result: Array[Dictionary] = []
	var sessions: Array = get_sessions()
	for index in range(sessions.size()):
		var session: EditorDebuggerSession = sessions[index]
		if not session:
			continue
		result.append({
			"session_id": index,
			"active": session.is_active(),
			"breaked": session.is_breaked(),
			"debuggable": session.is_debuggable()
		})
	return result

func set_breakpoint(path: String, line: int, enabled: bool, session_id: int = -1) -> Dictionary:
	return _for_each_session(session_id, func(session: EditorDebuggerSession) -> void:
		session.set_breakpoint(path, line, enabled)
	)

func send_debugger_message(message: String, data: Array, session_id: int = -1) -> Dictionary:
	_refresh_script_debugger_connections()
	var action: Callable = func(session: EditorDebuggerSession) -> void:
		session.send_message(message, data)
	return _for_each_session(session_id, action, true)

func request_stack_dump(session_id: int = -1) -> Dictionary:
	_refresh_script_debugger_connections()
	return send_debugger_message("get_stack_dump", [], session_id)

func request_stack_frame_vars(frame: int = 0, session_id: int = -1) -> Dictionary:
	_refresh_script_debugger_connections()
	_pending_stack_vars_frame = frame
	return send_debugger_message("get_stack_frame_vars", [frame], session_id)

func request_evaluate(expression: String, frame: int = 0, session_id: int = -1) -> Dictionary:
	_refresh_script_debugger_connections()
	return send_debugger_message("evaluate", [expression, frame], session_id)

func get_latest_stack_dump() -> Array:
	return _latest_stack_dump.duplicate(true)

func get_latest_stack_variables(frame: int = -1) -> Array:
	if frame >= 0:
		return _latest_stack_variables.get(frame, []).duplicate(true)
	var result: Array = []
	var frames: Array = _latest_stack_variables.keys()
	frames.sort()
	for frame_id in frames:
		result.append({
			"frame": frame_id,
			"variables": _latest_stack_variables[frame_id].duplicate(true)
		})
	return result

func get_latest_evaluation(expression: String = "") -> Variant:
	if not expression.is_empty():
		return _latest_evaluations.get(expression, null)
	if _latest_evaluations.is_empty():
		return null
	var keys: Array = _latest_evaluations.keys()
	keys.sort()
	return _latest_evaluations[keys[keys.size() - 1]]

func toggle_profiler(profiler: String, enabled: bool, data: Array, session_id: int = -1) -> Dictionary:
	var action: Callable = func(session: EditorDebuggerSession) -> void:
		session.toggle_profiler(profiler, enabled, data)
	return _for_each_session(session_id, action, true)

func get_captured_messages(count: int = 100, offset: int = 0, order: String = "desc") -> Dictionary:
	_refresh_script_debugger_connections()
	var messages: Array = _captured_messages.duplicate()
	if order == "desc":
		messages.reverse()
	var start: int = clampi(offset, 0, messages.size())
	var end: int = clampi(start + max(count, 0), start, messages.size())
	return {
		"messages": messages.slice(start, end),
		"count": end - start,
		"total_available": messages.size()
	}

func get_capture_prefixes() -> Array[String]:
	return _capture_prefixes.duplicate()

func get_latest_message_payload(message: String, match_fields: Dictionary = {}) -> Variant:
	for index in range(_captured_messages.size() - 1, -1, -1):
		var entry: Dictionary = _captured_messages[index]
		if str(entry.get("message", "")) != message:
			continue
		var captured_data: Array = entry.get("data", [])
		var payload: Variant = captured_data[0] if not captured_data.is_empty() else null
		if _payload_matches(payload, match_fields):
			return payload
	return null

func request_runtime_message(message: String, data: Array = [], response_messages: Array = [], error_messages: Array = ["mcp:error"], session_id: int = -1, timeout_ms: int = 1500) -> Dictionary:
	var baseline_sequence: int = _message_sequence
	var send_result: Dictionary = send_debugger_message("mcp:" + message, data, session_id)
	if send_result.has("error"):
		return send_result
	if send_result.get("sessions_updated", 0) <= 0:
		return send_result

	var wait_until: int = Time.get_ticks_msec() + maxi(timeout_ms, 1)
	while Time.get_ticks_msec() <= wait_until:
		var captured: Dictionary = _find_captured_message_after_sequence(baseline_sequence, response_messages, error_messages)
		if not captured.is_empty():
			var payload: Variant = null
			var captured_data: Array = captured.get("data", [])
			if not captured_data.is_empty():
				payload = captured_data[0]
			if error_messages.has(captured.get("message", "")):
				return {
					"error": _extract_runtime_error(payload),
					"message": captured.get("message", ""),
					"payload": payload,
					"captured": captured
				}
			return {
				"status": "success",
				"message": captured.get("message", ""),
				"payload": payload,
				"captured": captured
			}
		OS.delay_msec(10)

	return {
		"error": "Timed out waiting for runtime response: " + message,
		"status": "timeout",
		"response_messages": response_messages
	}

func _refresh_script_debugger_connections() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var base: Node = tree.root
	if not base:
		return
	var pending: Array[Node] = [base]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.get_class() == "ScriptEditorDebugger":
			_connect_script_debugger(node)
		for child in node.get_children():
			pending.append(child)

func _connect_script_debugger(debugger: Object) -> void:
	if _connected_script_debuggers.has(debugger):
		return
	if debugger.has_signal("stack_dump"):
		debugger.connect("stack_dump", Callable(self, "_on_stack_dump"))
	if debugger.has_signal("stack_frame_vars"):
		debugger.connect("stack_frame_vars", Callable(self, "_on_stack_frame_vars"))
	if debugger.has_signal("stack_frame_var"):
		debugger.connect("stack_frame_var", Callable(self, "_on_stack_frame_var"))
	if debugger.has_signal("debug_data"):
		debugger.connect("debug_data", Callable(self, "_on_debug_data"))
	_connected_script_debuggers.append(debugger)

func _on_stack_dump(stack: Array) -> void:
	_latest_stack_dump = stack.duplicate(true)
	_latest_stack_variables.clear()
	_append_captured_message(-1, "stack_dump", [stack])

func _on_stack_frame_vars(size: Variant) -> void:
	_latest_stack_variables[_pending_stack_vars_frame] = []
	_append_captured_message(-1, "stack_frame_vars", [size])

func _on_stack_frame_var(data: Array) -> void:
	var variable: Dictionary = _decode_stack_variable(data)
	if not _latest_stack_variables.has(_pending_stack_vars_frame):
		_latest_stack_variables[_pending_stack_vars_frame] = []
	_latest_stack_variables[_pending_stack_vars_frame].append(variable)
	_append_captured_message(-1, "stack_frame_var", [variable])

func _on_debug_data(message: String, data: Array) -> void:
	if message == "evaluation_return":
		var variable: Dictionary = _decode_stack_variable(data)
		var expression_name: String = str(variable.get("name", ""))
		if not expression_name.is_empty():
			_latest_evaluations[expression_name] = variable.duplicate(true)
		_append_captured_message(-1, "evaluation_return", [variable])

func _decode_stack_variable(data: Array) -> Dictionary:
	var scope_names: Array[String] = ["local", "member", "global", "constant"]
	var scope_id: int = int(data[1]) if data.size() > 1 else -1
	return {
		"name": str(data[0]) if data.size() > 0 else "",
		"scope": scope_names[scope_id] if scope_id >= 0 and scope_id < scope_names.size() else str(scope_id),
		"type": type_string(int(data[2])) if data.size() > 2 else "",
		"value": data[3] if data.size() > 3 else null,
		"raw": data
	}

func _append_captured_message(session_id: int, message: String, data: Array) -> void:
	_message_sequence += 1
	_captured_messages.append({
		"sequence": _message_sequence,
		"session_id": session_id,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system()
	})
	if _captured_messages.size() > _max_messages:
		_captured_messages = _captured_messages.slice(_captured_messages.size() - _max_messages)

func _find_captured_message_after_sequence(sequence: int, response_messages: Array, error_messages: Array) -> Dictionary:
	for entry in _captured_messages:
		if int(entry.get("sequence", 0)) <= sequence:
			continue
		var message: String = str(entry.get("message", ""))
		if response_messages.has(message) or error_messages.has(message):
			return entry
	return {}

func _extract_runtime_error(payload: Variant) -> String:
	if payload is Dictionary:
		return str(payload.get("message", payload))
	return str(payload)

func _payload_matches(payload: Variant, match_fields: Dictionary) -> bool:
	if match_fields.is_empty():
		return true
	if not (payload is Dictionary):
		return false
	for key in match_fields:
		if payload.get(key) != match_fields[key]:
			return false
	return true

func _for_each_session(session_id: int, action: Callable, require_active: bool = false) -> Dictionary:
	var sessions: Array = get_sessions()
	if sessions.is_empty():
		return {"status": "no_sessions", "sessions_updated": 0}
	if session_id >= 0:
		var session: EditorDebuggerSession = get_session(session_id)
		if not session:
			return {"error": "Debugger session not found: " + str(session_id)}
		if require_active and not session.is_active():
			return {"status": "no_active_sessions", "sessions_updated": 0}
		action.call(session)
		return {"status": "success", "sessions_updated": 1}
	var updated: int = 0
	for session in sessions:
		if session and (not require_active or session.is_active()):
			action.call(session)
			updated += 1
	if require_active and updated == 0:
		return {"status": "no_active_sessions", "sessions_updated": 0}
	return {"status": "success", "sessions_updated": updated}
