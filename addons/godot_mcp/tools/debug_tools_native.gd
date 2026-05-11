# debug_tools_native.gd - нативная реализация Debug Tools

@tool
class_name DebugToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null
var _log_buffer: Array[String] = []
var _max_log_lines: int = 1000
var _server_core: RefCounted = null
var _log_mutex: Mutex = Mutex.new()
var _execution_mutex: Mutex = Mutex.new()

func initialize(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface

func _get_editor_interface() -> EditorInterface:
	if _editor_interface:
		return _editor_interface
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_editor_interface"):
			return plugin.get_editor_interface()
	return null

func _get_user_scene_root() -> Node:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return null
	var scene_root: Node = editor_interface.get_edited_scene_root()
	if scene_root and not scene_root.name.begins_with("@") and scene_root.get_class() != "PanelContainer":
		return scene_root
	var open_scenes: Array = editor_interface.get_open_scenes()
	for scene in open_scenes:
		if scene and not scene.name.begins_with("@") and scene.get_class() != "PanelContainer":
			return scene
	return scene_root

# ============================================================================
# Регистрация инструментов
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	_server_core = server_core
	if server_core.has_signal("log_message"):
		server_core.log_message.connect(_on_log_message)
	
	_register_get_editor_logs(server_core)
	_register_execute_script(server_core)
	_register_get_performance_metrics(server_core)
	_register_debug_print(server_core)
	_register_execute_editor_script(server_core)
	_register_clear_output(server_core)
	_register_get_debugger_sessions(server_core)
	_register_set_debugger_breakpoint(server_core)
	_register_send_debugger_message(server_core)
	_register_toggle_debugger_profiler(server_core)
	_register_get_debugger_messages(server_core)
	_register_add_debugger_capture_prefix(server_core)
	_register_get_debug_stack_frames(server_core)
	_register_get_debug_stack_variables(server_core)
	_register_install_runtime_probe(server_core)
	_register_remove_runtime_probe(server_core)
	_register_request_debug_break(server_core)
	_register_send_debug_command(server_core)
	_register_get_runtime_info(server_core)
	_register_get_runtime_scene_tree(server_core)
	_register_inspect_runtime_node(server_core)
	_register_update_runtime_node_property(server_core)
	_register_call_runtime_node_method(server_core)
	_register_evaluate_runtime_expression(server_core)
	_register_await_runtime_condition(server_core)
	_register_assert_runtime_condition(server_core)

func _on_log_message(level: String, message: String) -> void:
	var log_entry: String = "[%s] %s" % [level, message]
	_log_mutex.lock()
	_log_buffer.append(log_entry)
	if _log_buffer.size() > _max_log_lines:
		_log_buffer = _log_buffer.slice(_log_buffer.size() - _max_log_lines)
	_log_mutex.unlock()

# ============================================================================
# get_editor_logs - получение логов редактора
# ============================================================================

func _register_get_editor_logs(server_core: RefCounted) -> void:
	var tool_name: String = "get_editor_logs"
	var description: String = "Get recent log messages from the editor or runtime. Supports filtering by source, type, and pagination."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"source": {
				"type": "string",
				"description": "Log source: 'mcp' (MCP server logs, default), 'runtime' (user://logs/godot.log).",
				"default": "mcp",
				"enum": ["mcp", "runtime"]
			},
			"type": {
				"type": "array",
				"items": {"type": "string"},
				"description": "Filter by log types (e.g. ['Error', 'Warning', 'Info']). Only applies to MCP source. Empty array returns all."
			},
			"count": {
				"type": "integer",
				"description": "Maximum number of log lines to return. Default is 100.",
				"default": 100
			},
			"offset": {
				"type": "integer",
				"description": "Number of log entries to skip. Default is 0.",
				"default": 0
			},
			"order": {
				"type": "string",
				"description": "Sort order: 'desc' (newest first, default) or 'asc' (oldest first).",
				"default": "desc",
				"enum": ["desc", "asc"]
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"logs": {
				"type": "array",
				"items": {"type": "object"}
			},
			"count": {"type": "integer"},
			"total_available": {"type": "integer"},
			"source": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_editor_logs"),
						  output_schema, annotations)

func _tool_get_editor_logs(params: Dictionary) -> Dictionary:
	var source: String = params.get("source", "mcp")
	var types: Array = params.get("type", [])
	var count: int = params.get("count", 100)
	var offset: int = params.get("offset", 0)
	var order: String = params.get("order", "desc")

	if source == "runtime":
		return _get_runtime_logs(types, count, offset, order)

	return _get_mcp_logs(types, count, offset, order)

func _get_debugger_bridge() -> RefCounted:
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_debugger_bridge"):
			return plugin.get_debugger_bridge()
	return null

func _register_get_debugger_sessions(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_debugger_sessions",
		"List Godot editor debugger sessions and their active/break state.",
		{"type": "object", "properties": {}},
		Callable(self, "_tool_get_debugger_sessions"),
		{"type": "object", "properties": {"sessions": {"type": "array"}, "count": {"type": "integer"}}},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_get_debugger_sessions(params: Dictionary) -> Dictionary:
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	var sessions: Array = bridge.get_sessions_info()
	return {"sessions": sessions, "count": sessions.size()}

func _register_set_debugger_breakpoint(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_debugger_breakpoint",
		"Enable or disable a breakpoint in active Godot debugger sessions.",
		{
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Script path, e.g. res://player.gd"},
				"line": {"type": "integer", "description": "1-based line number"},
				"enabled": {"type": "boolean", "description": "Whether the breakpoint is enabled"},
				"session_id": {"type": "integer", "description": "Optional debugger session id. Omit or use -1 for all sessions."}
			},
			"required": ["path", "line", "enabled"]
		},
		Callable(self, "_tool_set_debugger_breakpoint"),
		{"type": "object", "properties": {"status": {"type": "string"}, "sessions_updated": {"type": "integer"}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_set_debugger_breakpoint(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var line: int = params.get("line", 0)
	var enabled: bool = params.get("enabled", true)
	var session_id: int = params.get("session_id", -1)
	if path.is_empty():
		return {"error": "Missing required parameter: path"}
	if line < 1:
		return {"error": "line must be >= 1"}
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	return bridge.set_breakpoint(path, line, enabled, session_id)

func _register_send_debugger_message(server_core: RefCounted) -> void:
	server_core.register_tool(
		"send_debugger_message",
		"Send a custom debugger message to active Godot debugger sessions.",
		{
			"type": "object",
			"properties": {
				"message": {"type": "string"},
				"data": {"type": "array"},
				"session_id": {"type": "integer"}
			},
			"required": ["message"]
		},
		Callable(self, "_tool_send_debugger_message"),
		{"type": "object", "properties": {"status": {"type": "string"}, "sessions_updated": {"type": "integer"}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": true}
	)

func _tool_send_debugger_message(params: Dictionary) -> Dictionary:
	var message: String = params.get("message", "")
	var data: Array = params.get("data", [])
	var session_id: int = params.get("session_id", -1)
	if message.is_empty():
		return {"error": "Missing required parameter: message"}
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	return bridge.send_debugger_message(message, data, session_id)

func _register_toggle_debugger_profiler(server_core: RefCounted) -> void:
	server_core.register_tool(
		"toggle_debugger_profiler",
		"Toggle an EngineProfiler in active Godot debugger sessions.",
		{
			"type": "object",
			"properties": {
				"profiler": {"type": "string", "description": "Profiler name"},
				"enabled": {"type": "boolean"},
				"data": {"type": "array"},
				"session_id": {"type": "integer"}
			},
			"required": ["profiler", "enabled"]
		},
		Callable(self, "_tool_toggle_debugger_profiler"),
		{"type": "object", "properties": {"status": {"type": "string"}, "sessions_updated": {"type": "integer"}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": true}
	)

func _tool_toggle_debugger_profiler(params: Dictionary) -> Dictionary:
	var profiler: String = params.get("profiler", "")
	var enabled: bool = params.get("enabled", false)
	var data: Array = params.get("data", [])
	var session_id: int = params.get("session_id", -1)
	if profiler.is_empty():
		return {"error": "Missing required parameter: profiler"}
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	return bridge.toggle_profiler(profiler, enabled, data, session_id)

func _register_get_debugger_messages(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_debugger_messages",
		"Read custom messages captured by the Godot debugger bridge.",
		{
			"type": "object",
			"properties": {
				"count": {"type": "integer", "default": 100},
				"offset": {"type": "integer", "default": 0},
				"order": {"type": "string", "enum": ["asc", "desc"], "default": "desc"}
			}
		},
		Callable(self, "_tool_get_debugger_messages"),
		{"type": "object", "properties": {"messages": {"type": "array"}, "count": {"type": "integer"}, "total_available": {"type": "integer"}}},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_get_debugger_messages(params: Dictionary) -> Dictionary:
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	return bridge.get_captured_messages(params.get("count", 100), params.get("offset", 0), params.get("order", "desc"))

func _register_add_debugger_capture_prefix(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_debugger_capture_prefix",
		"Allow the debugger bridge to capture custom EngineDebugger messages with the given prefix.",
		{
			"type": "object",
			"properties": {
				"prefix": {"type": "string", "description": "Message prefix without the trailing colon, or * for all prefixes."}
			},
			"required": ["prefix"]
		},
		Callable(self, "_tool_add_debugger_capture_prefix"),
		{"type": "object", "properties": {"status": {"type": "string"}, "prefixes": {"type": "array"}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_add_debugger_capture_prefix(params: Dictionary) -> Dictionary:
	var prefix: String = params.get("prefix", "")
	if prefix.is_empty():
		return {"error": "Missing required parameter: prefix"}
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	bridge.add_capture_prefix(prefix)
	return {"status": "success", "prefixes": bridge.get_capture_prefixes()}

func _register_get_debug_stack_frames(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_debug_stack_frames",
		"Return the latest captured script stack frames and request a fresh stack dump from breaked sessions.",
		{
			"type": "object",
			"properties": {
				"refresh": {"type": "boolean", "default": true},
				"session_id": {"type": "integer", "description": "Optional debugger session id. Omit or use -1 for all active sessions."}
			}
		},
		Callable(self, "_tool_get_debug_stack_frames"),
		{"type": "object", "properties": {"frames": {"type": "array"}, "count": {"type": "integer"}, "refresh_result": {"type": "object"}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_get_debug_stack_frames(params: Dictionary) -> Dictionary:
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	var refresh_result: Dictionary = {}
	if params.get("refresh", true):
		refresh_result = bridge.request_stack_dump(params.get("session_id", -1))
	var frames: Array = bridge.get_latest_stack_dump()
	return {"frames": frames, "count": frames.size(), "refresh_result": refresh_result}

func _register_get_debug_stack_variables(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_debug_stack_variables",
		"Return latest captured local/member/global variables for a stack frame and request a fresh variable dump.",
		{
			"type": "object",
			"properties": {
				"frame": {"type": "integer", "default": 0},
				"refresh": {"type": "boolean", "default": true},
				"session_id": {"type": "integer", "description": "Optional debugger session id. Omit or use -1 for all active sessions."}
			}
		},
		Callable(self, "_tool_get_debug_stack_variables"),
		{"type": "object", "properties": {"frame": {"type": "integer"}, "variables": {"type": "array"}, "count": {"type": "integer"}, "refresh_result": {"type": "object"}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_get_debug_stack_variables(params: Dictionary) -> Dictionary:
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	var frame: int = params.get("frame", 0)
	if frame < 0:
		return {"error": "frame must be >= 0"}
	var refresh_result: Dictionary = {}
	if params.get("refresh", true):
		refresh_result = bridge.request_stack_frame_vars(frame, params.get("session_id", -1))
	var variables: Array = bridge.get_latest_stack_variables(frame)
	return {"frame": frame, "variables": variables, "count": variables.size(), "refresh_result": refresh_result}

func _register_install_runtime_probe(server_core: RefCounted) -> void:
	server_core.register_tool(
		"install_runtime_probe",
		"Add the MCP runtime probe node to the current scene so the running game can answer debugger messages.",
		{
			"type": "object",
			"properties": {
				"node_name": {"type": "string", "default": "MCPRuntimeProbe"},
				"persistent": {"type": "boolean", "default": true, "description": "Set owner so the probe is saved with the scene."}
			}
		},
		Callable(self, "_tool_install_runtime_probe"),
		{"type": "object", "properties": {"status": {"type": "string"}, "node_path": {"type": "string"}, "persistent": {"type": "boolean"}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_install_runtime_probe(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_name: String = params.get("node_name", "MCPRuntimeProbe")
	if node_name.is_empty():
		return {"error": "node_name cannot be empty"}
	var existing: Node = scene_root.get_node_or_null(NodePath(node_name))
	if existing:
		return {"status": "already_installed", "node_path": str(existing.get_path()), "persistent": existing.owner != null}
	var script: Script = load("res://addons/godot_mcp/runtime/mcp_runtime_probe.gd")
	if not script:
		return {"error": "Failed to load runtime probe script"}
	var probe: Node = Node.new()
	probe.name = node_name
	probe.set_script(script)
	scene_root.add_child(probe)
	var persistent: bool = params.get("persistent", true)
	if persistent:
		probe.owner = scene_root
	editor_interface.mark_scene_as_unsaved()
	return {"status": "success", "node_path": str(probe.get_path()), "persistent": persistent}

func _register_remove_runtime_probe(server_core: RefCounted) -> void:
	server_core.register_tool(
		"remove_runtime_probe",
		"Remove the MCP runtime probe node from the current scene.",
		{
			"type": "object",
			"properties": {
				"node_name": {"type": "string", "default": "MCPRuntimeProbe"}
			}
		},
		Callable(self, "_tool_remove_runtime_probe"),
		{"type": "object", "properties": {"status": {"type": "string"}, "removed_node": {"type": "string"}}},
		{"readOnlyHint": false, "destructiveHint": true, "idempotentHint": true, "openWorldHint": false}
	)

func _tool_remove_runtime_probe(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_name: String = params.get("node_name", "MCPRuntimeProbe")
	var existing: Node = scene_root.get_node_or_null(NodePath(node_name))
	if not existing:
		return {"status": "not_installed", "removed_node": ""}
	var removed_path: String = str(existing.get_path())
	scene_root.remove_child(existing)
	existing.queue_free()
	editor_interface.mark_scene_as_unsaved()
	return {"status": "success", "removed_node": removed_path}

func _register_request_debug_break(server_core: RefCounted) -> void:
	server_core.register_tool(
		"request_debug_break",
		"Ask the MCP runtime probe to enter Godot's script debugger break loop.",
		{
			"type": "object",
			"properties": {
				"session_id": {"type": "integer", "description": "Optional debugger session id. Omit or use -1 for all active sessions."}
			}
		},
		Callable(self, "_tool_request_debug_break"),
		{"type": "object", "properties": {"status": {"type": "string"}, "sessions_updated": {"type": "integer"}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": true}
	)

func _tool_request_debug_break(params: Dictionary) -> Dictionary:
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	return bridge.send_debugger_message("mcp:debug_break", [], params.get("session_id", -1))

func _register_send_debug_command(server_core: RefCounted) -> void:
	server_core.register_tool(
		"send_debug_command",
		"Send a raw Godot script-debugger command to active breaked sessions. Commands are handled by Godot's debug loop.",
		{
			"type": "object",
			"properties": {
				"command": {"type": "string", "enum": ["step", "next", "out", "continue", "get_stack_dump", "get_stack_frame_vars"]},
				"data": {"type": "array", "description": "Command payload, e.g. [0] for get_stack_frame_vars frame 0."},
				"session_id": {"type": "integer", "description": "Optional debugger session id. Omit or use -1 for all active sessions."}
			},
			"required": ["command"]
		},
		Callable(self, "_tool_send_debug_command"),
		{"type": "object", "properties": {"status": {"type": "string"}, "sessions_updated": {"type": "integer"}, "note": {"type": "string"}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": true}
	)

func _tool_send_debug_command(params: Dictionary) -> Dictionary:
	var command: String = params.get("command", "")
	var allowed: Array[String] = ["step", "next", "out", "continue", "get_stack_dump", "get_stack_frame_vars"]
	if not allowed.has(command):
		return {"error": "Unsupported debug command: " + command}
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	var result: Dictionary = bridge.send_debugger_message(command, params.get("data", []), params.get("session_id", -1))
	if command.begins_with("get_stack"):
		result["note"] = "Godot may route stack responses to the built-in ScriptEditorDebugger UI instead of EditorDebuggerPlugin captures."
	return result

func _register_get_runtime_info(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_runtime_info",
		"Query the running game instance through the MCP runtime probe and return runtime metrics.",
		{"type": "object", "properties": {"session_id": {"type": "integer"}, "timeout_ms": {"type": "integer", "default": 1500}}},
		Callable(self, "_tool_get_runtime_info"),
		{"type": "object", "properties": {"fps": {"type": "number"}, "physics_frames": {"type": "integer"}, "process_frames": {"type": "integer"}, "debugger_active": {"type": "boolean"}, "current_scene": {"type": "string"}, "node_count": {"type": "integer"}}},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": true}
	)

func _tool_get_runtime_info(params: Dictionary) -> Dictionary:
	var result: Dictionary = _request_runtime_probe("get_runtime_info", [], ["mcp:runtime_info"], params)
	if result.get("status", "") == "pending":
		var bridge: RefCounted = _get_debugger_bridge()
		if bridge:
			var probe_ready: Variant = bridge.get_latest_message_payload("mcp:probe_ready")
			if probe_ready is Dictionary:
				var fallback: Dictionary = probe_ready.duplicate(true)
				fallback["status"] = "stale"
				fallback["refresh_result"] = result.get("refresh_result", {})
				return fallback
	return result

func _register_get_runtime_scene_tree(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_runtime_scene_tree",
		"Read the live runtime scene tree from the running game instance.",
		{"type": "object", "properties": {"max_depth": {"type": "integer", "default": 6}, "session_id": {"type": "integer"}, "timeout_ms": {"type": "integer", "default": 1500}}},
		Callable(self, "_tool_get_runtime_scene_tree"),
		{"type": "object", "properties": {"name": {"type": "string"}, "type": {"type": "string"}, "path": {"type": "string"}, "child_count": {"type": "integer"}, "children": {"type": "array"}}},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": true}
	)

func _tool_get_runtime_scene_tree(params: Dictionary) -> Dictionary:
	return _request_runtime_probe("get_scene_tree", [params.get("max_depth", 6)], ["mcp:scene_tree"], params)

func _register_inspect_runtime_node(server_core: RefCounted) -> void:
	server_core.register_tool(
		"inspect_runtime_node",
		"Inspect a live runtime node and its serializable properties through the runtime probe.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"session_id": {"type": "integer"},
				"timeout_ms": {"type": "integer", "default": 1500}
			},
			"required": ["node_path"]
		},
		Callable(self, "_tool_inspect_runtime_node"),
		{"type": "object", "properties": {"name": {"type": "string"}, "type": {"type": "string"}, "path": {"type": "string"}, "properties": {"type": "object"}}},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": true}
	)

func _tool_inspect_runtime_node(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	return _request_runtime_probe("inspect_node", [node_path], ["mcp:node"], params, {"path": node_path})

func _register_update_runtime_node_property(server_core: RefCounted) -> void:
	server_core.register_tool(
		"update_runtime_node_property",
		"Modify a property on a live runtime node through the runtime probe.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"property_name": {"type": "string"},
				"property_value": {},
				"session_id": {"type": "integer"},
				"timeout_ms": {"type": "integer", "default": 1500}
			},
			"required": ["node_path", "property_name", "property_value"]
		},
		Callable(self, "_tool_update_runtime_node_property"),
		{"type": "object", "properties": {"node_path": {"type": "string"}, "property_name": {"type": "string"}, "old_value": {}, "new_value": {}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": true}
	)

func _tool_update_runtime_node_property(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var property_name: String = params.get("property_name", "")
	if node_path.is_empty() or property_name.is_empty() or not params.has("property_value"):
		return {"error": "node_path, property_name, and property_value are required"}
	return _request_runtime_probe("set_node_property", [node_path, property_name, params.get("property_value")], ["mcp:node_property_updated"], params, {"node_path": node_path, "property_name": property_name})

func _register_call_runtime_node_method(server_core: RefCounted) -> void:
	server_core.register_tool(
		"call_runtime_node_method",
		"Call a method on a live runtime node and return the serialized result.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"method_name": {"type": "string"},
				"arguments": {"type": "array"},
				"session_id": {"type": "integer"},
				"timeout_ms": {"type": "integer", "default": 1500}
			},
			"required": ["node_path", "method_name"]
		},
		Callable(self, "_tool_call_runtime_node_method"),
		{"type": "object", "properties": {"node_path": {"type": "string"}, "method_name": {"type": "string"}, "arguments": {"type": "array"}, "result": {}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": true}
	)

func _tool_call_runtime_node_method(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var method_name: String = params.get("method_name", "")
	if node_path.is_empty() or method_name.is_empty():
		return {"error": "node_path and method_name are required"}
	return _request_runtime_probe("call_node_method", [node_path, method_name, params.get("arguments", [])], ["mcp:node_method_result"], params, {"node_path": node_path, "method_name": method_name})

func _register_evaluate_runtime_expression(server_core: RefCounted) -> void:
	server_core.register_tool(
		"evaluate_runtime_expression",
		"Evaluate a GDScript Expression in the running game, optionally relative to a target node.",
		{
			"type": "object",
			"properties": {
				"expression": {"type": "string"},
				"node_path": {"type": "string"},
				"session_id": {"type": "integer"},
				"timeout_ms": {"type": "integer", "default": 1500}
			},
			"required": ["expression"]
		},
		Callable(self, "_tool_evaluate_runtime_expression"),
		{"type": "object", "properties": {"expression": {"type": "string"}, "node_path": {"type": "string"}, "value": {}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": true}
	)

func _tool_evaluate_runtime_expression(params: Dictionary) -> Dictionary:
	var expression: String = params.get("expression", "")
	if expression.is_empty():
		return {"error": "Missing required parameter: expression"}
	var payload: Array = [expression, params.get("node_path", "")]
	return _request_runtime_probe("evaluate_expression", payload, ["mcp:expression_result"], params, {"expression": expression})

func _register_await_runtime_condition(server_core: RefCounted) -> void:
	server_core.register_tool(
		"await_runtime_condition",
		"Poll a runtime expression until it becomes truthy or the timeout expires.",
		{
			"type": "object",
			"properties": {
				"expression": {"type": "string"},
				"node_path": {"type": "string"},
				"timeout_ms": {"type": "integer", "default": 3000},
				"poll_interval_ms": {"type": "integer", "default": 100},
				"session_id": {"type": "integer"}
			},
			"required": ["expression"]
		},
		Callable(self, "_tool_await_runtime_condition"),
		{"type": "object", "properties": {"condition_met": {"type": "boolean"}, "attempts": {"type": "integer"}, "elapsed_ms": {"type": "integer"}, "last_value": {}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": true}
	)

func _tool_await_runtime_condition(params: Dictionary) -> Dictionary:
	var expression: String = params.get("expression", "")
	if expression.is_empty():
		return {"error": "Missing required parameter: expression"}
	var result: Dictionary = _tool_evaluate_runtime_expression(params)
	if result.has("error"):
		return result
	if result.get("status", "") == "pending":
		return {
			"status": "pending",
			"condition_met": false,
			"last_value": null,
			"refresh_result": result.get("refresh_result", {})
		}
	var last_value: Variant = result.get("value", null)
	var condition_met: bool = _is_truthy_runtime_value(last_value)
	return {
		"status": "success" if condition_met else "failed",
		"condition_met": condition_met,
		"last_value": last_value,
		"refresh_result": result.get("refresh_result", {})
	}

func _register_assert_runtime_condition(server_core: RefCounted) -> void:
	server_core.register_tool(
		"assert_runtime_condition",
		"Assert that a runtime expression becomes truthy within the timeout window.",
		{
			"type": "object",
			"properties": {
				"expression": {"type": "string"},
				"node_path": {"type": "string"},
				"timeout_ms": {"type": "integer", "default": 3000},
				"poll_interval_ms": {"type": "integer", "default": 100},
				"session_id": {"type": "integer"},
				"description": {"type": "string"}
			},
			"required": ["expression"]
		},
		Callable(self, "_tool_assert_runtime_condition"),
		{"type": "object", "properties": {"status": {"type": "string"}, "description": {"type": "string"}, "attempts": {"type": "integer"}, "elapsed_ms": {"type": "integer"}, "last_value": {}}},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": true}
	)

func _tool_assert_runtime_condition(params: Dictionary) -> Dictionary:
	var wait_result: Dictionary = _tool_await_runtime_condition(params)
	if wait_result.has("error"):
		return wait_result
	if wait_result.get("status", "") == "pending":
		return {
			"status": "pending",
			"description": params.get("description", params.get("expression", "")),
			"last_value": null,
			"refresh_result": wait_result.get("refresh_result", {})
		}
	if not wait_result.get("condition_met", false):
		return {
			"error": "Runtime condition was not met within timeout",
			"description": params.get("description", params.get("expression", "")),
			"last_value": wait_result.get("last_value", null)
		}
	return {
		"status": "success",
		"description": params.get("description", params.get("expression", "")),
		"last_value": wait_result.get("last_value", null),
		"refresh_result": wait_result.get("refresh_result", {})
	}

func _request_runtime_probe(command: String, payload: Array, response_messages: Array, params: Dictionary, match_fields: Dictionary = {}) -> Dictionary:
	var bridge: RefCounted = _get_debugger_bridge()
	if not bridge:
		return {"error": "Debugger bridge is not available"}
	var refresh_result: Dictionary = bridge.send_debugger_message(
		"mcp:" + command,
		payload,
		int(params.get("session_id", -1))
	)
	if refresh_result.has("error"):
		return refresh_result
	if refresh_result.get("status", "") == "no_active_sessions":
		return {"status": "no_active_sessions", "refresh_result": refresh_result}
	for message_name in response_messages:
		var runtime_payload: Variant = bridge.get_latest_message_payload(message_name, match_fields)
		if runtime_payload is Dictionary:
			var response: Dictionary = runtime_payload.duplicate(true)
			response["status"] = "success"
			response["refresh_result"] = refresh_result
			return response
		if runtime_payload != null:
			return {"status": "success", "value": runtime_payload, "refresh_result": refresh_result}
	return {"status": "pending", "refresh_result": refresh_result, "response_messages": response_messages}

func _is_truthy_runtime_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING:
			return not String(value).is_empty()
		TYPE_ARRAY:
			return not value.is_empty()
		TYPE_DICTIONARY:
			return not value.is_empty()
		_:
			return true

func _get_mcp_logs(types: Array, count: int, offset: int, order: String) -> Dictionary:
	_log_mutex.lock()
	if _log_buffer.is_empty():
		_log_mutex.unlock()
		return {
			"logs": [],
			"count": 0,
			"total_available": 0,
			"source": "mcp"
		}

	var all_entries: Array = []
	for i in range(_log_buffer.size()):
		var line: String = _log_buffer[i]
		var log_type: String = "Info"
		var message: String = line
		if line.begins_with("[ERROR]"):
			log_type = "Error"
			message = line.substr(7).strip_edges()
		elif line.begins_with("[WARNING]"):
			log_type = "Warning"
			message = line.substr(9).strip_edges()
		elif line.begins_with("[INFO]"):
			log_type = "Info"
			message = line.substr(6).strip_edges()
		elif line.begins_with("[DEBUG]"):
			log_type = "Debug"
			message = line.substr(7).strip_edges()
		all_entries.append({"index": i, "type": log_type, "message": message})

	var total_available: int = all_entries.size()
	_log_mutex.unlock()

	var filtered: Array = all_entries
	if types.size() > 0:
		filtered = []
		for entry in all_entries:
			if types.has(entry["type"]):
				filtered.append(entry)

	if order == "desc":
		filtered.reverse()

	var start: int = mini(offset, filtered.size())
	var end: int = mini(start + count, filtered.size())
	var result_logs: Array = filtered.slice(start, end)

	return {
		"logs": result_logs,
		"count": result_logs.size(),
		"total_available": total_available,
		"source": "mcp"
	}

func _get_runtime_logs(types: Array, count: int, offset: int, order: String) -> Dictionary:
	var log_path: String = "user://logs/godot.log"
	if not FileAccess.file_exists(log_path):
		return {
			"logs": [],
			"count": 0,
			"total_available": 0,
			"source": "runtime",
			"note": "Runtime log file not found: " + log_path
		}

	var file: FileAccess = FileAccess.open(log_path, FileAccess.READ)
	if not file:
		return {
			"logs": [],
			"count": 0,
			"total_available": 0,
			"source": "runtime",
			"note": "Runtime log file not available. Logs are only created after running the project."
		}

	var all_lines: Array = []
	while not file.eof_reached():
		var line: String = file.get_line()
		if not line.is_empty():
			all_lines.append(line)
	file.close()

	var total_available: int = all_lines.size()
	if total_available == 0:
		return {
			"logs": [],
			"count": 0,
			"total_available": 0,
			"source": "runtime"
		}

	var entries: Array = []
	if order == "desc":
		for i in range(total_available - 1, -1, -1):
			entries.append({"index": i, "type": "Info", "message": all_lines[i]})
	else:
		for i in range(total_available):
			entries.append({"index": i, "type": "Info", "message": all_lines[i]})

	var start: int = mini(offset, entries.size())
	var end: int = mini(start + count, entries.size())
	var result_logs: Array = entries.slice(start, end)

	return {
		"logs": result_logs,
		"count": result_logs.size(),
		"total_available": total_available,
		"source": "runtime"
	}

# ============================================================================
# execute_script - выполнение кода скрипта
# ============================================================================

func _register_execute_script(server_core: RefCounted) -> void:
	var tool_name: String = "execute_script"
	var description: String = "Execute a GDScript expression or statement. Uses Godot's Expression class for safe evaluation."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"code": {
				"type": "string",
				"description": "GDScript code to execute (expression or statement)"
			},
			"bind_objects": {
				"type": "object",
				"description": "Optional dictionary of objects to bind to the expression"
			}
		},
		"required": ["code"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"result": {"type": "string"},
			"error": {"type": "string"}
		}
	}
	
	# annotations
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}
	
	# Регистрация инструмента
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_execute_script"),
						  output_schema, annotations)

func _tool_execute_script(params: Dictionary) -> Dictionary:
	var code: String = params.get("code", "")
	var bind_objects: Dictionary = params.get("bind_objects", {})
	
	if code.is_empty():
		return {"error": "Missing required parameter: code"}
	
	var expression: Expression = Expression.new()

	var bind_names: PackedStringArray = []
	var bind_values: Array = []
	var singletons: Dictionary = {
		"OS": OS,
		"Engine": Engine,
		"ProjectSettings": ProjectSettings,
		"Input": Input,
		"Time": Time,
		"JSON": JSON,
		"ClassDB": ClassDB,
		"Performance": Performance,
		"ResourceLoader": ResourceLoader,
		"ResourceSaver": ResourceSaver,
		"EditorInterface": EditorInterface,
	}
	for singleton_name in singletons:
		bind_names.append(singleton_name)
		bind_values.append(singletons[singleton_name])

	if not bind_objects.is_empty():
		for key in bind_objects:
			bind_names.append(key)
			bind_values.append(bind_objects[key])

	var parse_error: Error = expression.parse(code, bind_names)

	if parse_error != OK:
		return {
			"status": "error",
			"error": "Parse failed: " + expression.get_error_text()
		}

	var base_instance: RefCounted = self
	_execution_mutex.lock()
	var result: Variant = expression.execute(bind_values, base_instance, true)
	_execution_mutex.unlock()
	
	if expression.has_execute_failed():
		return {
			"status": "error",
			"error": "Execution failed: " + expression.get_error_text()
		}
	
	return {
		"status": "success",
		"result": str(result)
	}

# ============================================================================
# get_performance_metrics - получение метрик производительности
# ============================================================================

func _register_get_performance_metrics(server_core: RefCounted) -> void:
	var tool_name: String = "get_performance_metrics"
	var description: String = "Get performance metrics including FPS, memory usage, and object counts."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"fps": {"type": "number"},
			"object_count": {"type": "integer"},
			"resource_count": {"type": "integer"},
			"memory_usage_mb": {"type": "number"}
		}
	}
	
	# annotations - readOnlyHint = true
	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}
	
	# Регистрация инструмента
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_performance_metrics"),
						  output_schema, annotations)

func _tool_get_performance_metrics(params: Dictionary) -> Dictionary:
	# Получение метрик производительности через singleton Performance
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var object_count: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var resource_count: int = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var memory_usage: int = Performance.get_monitor(Performance.MEMORY_STATIC)  # Статическая память
	
	# Конвертация в МБ
	var memory_mb: float = memory_usage / 1024.0 / 1024.0
	
	return {
		"fps": fps,
		"object_count": object_count,
		"resource_count": resource_count,
		"memory_usage_mb": memory_mb
	}

# ============================================================================
# debug_print - вывод отладочного сообщения
# ============================================================================

func _register_debug_print(server_core: RefCounted) -> void:
	var tool_name: String = "debug_print"
	var description: String = "Print a debug message to the Godot output console."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"message": {
				"type": "string",
				"description": "Message to print"
			},
			"category": {
				"type": "string",
				"description": "Optional category tag for the message (e.g. 'MCP', 'AI', 'Debug')"
			}
		},
		"required": ["message"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"printed_message": {"type": "string"}
		}
	}
	
	# annotations
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}
	
	# Регистрация инструмента
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_debug_print"),
						  output_schema, annotations)

func _tool_debug_print(params: Dictionary) -> Dictionary:
	# Извлечение параметров
	var message: String = params.get("message", "")
	var category: String = params.get("category", "")
	
	# Проверка параметров
	if message.is_empty():
		return {"error": "Missing required parameter: message"}
	
	# Формирование сообщения для вывода
	var full_message: String
	if category.is_empty():
		full_message = "[MCP Debug] " + message
	else:
		full_message = "[" + category + "] " + message
	
	# Вывод в консоль Godot
	printerr(full_message)
	
	return {
		"status": "success",
		"printed_message": full_message
	}

# ============================================================================
# execute_editor_script - выполнение полного скрипта редактора
# ============================================================================

func _register_execute_editor_script(server_core: RefCounted) -> void:
	var tool_name: String = "execute_editor_script"
	var description: String = "Execute a full GDScript in the editor context. Unlike execute_script which only evaluates expressions, this tool can run multi-line scripts with loops, conditionals, and await. Output is captured via print()."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"code": {
				"type": "string",
				"description": "Full GDScript code to execute. Can contain multiple statements, loops, conditionals, and await."
			}
		},
		"required": ["code"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"success": {"type": "boolean"},
			"output": {"type": "array", "items": {"type": "string"}},
			"error": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": false,
		"openWorldHint": true
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_execute_editor_script"),
						  output_schema, annotations)

func _tool_execute_editor_script(params: Dictionary) -> Dictionary:
	var code: String = params.get("code", "")
	if code.is_empty():
		return {"success": false, "error": "Missing required parameter: code", "output": []}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"success": false, "error": "Editor interface not available", "output": []}

	var normalized_code: String = _normalize_indentation(code)

	var script: GDScript = GDScript.new()
	var wrapped_code: String = "extends RefCounted\n\nvar _output: Array = []\nvar edited_scene: Node = null\n\nfunc _custom_print(msg) -> void:\n\t_output.append(str(msg))\n\nfunc execute() -> Array:\n"
	for line in normalized_code.split("\n"):
		wrapped_code += "\t" + line + "\n"
	wrapped_code += "\n\treturn _output\n"

	script.set_source_code(wrapped_code)

	var reload_ok: Error = script.reload()
	if reload_ok != OK:
		return {"success": false, "error": "Script compilation failed. Check syntax. Note: use tab indentation for code blocks inside if/for/while.", "output": []}

	var instance: RefCounted = script.new()
	if not instance:
		return {"success": false, "error": "Failed to create script instance", "output": []}

	instance.set("_output", [])
	var edited_scene: Node = editor_interface.get_edited_scene_root()
	if edited_scene:
		instance.set("edited_scene", edited_scene)

	var result_output: Variant = instance.call("execute")

	var output: Array = []
	if result_output is Array:
		output = result_output
	elif result_output != null:
		output.append(str(result_output))

	var instance_output: Variant = instance.get("_output")
	if instance_output is Array:
		for item in instance_output:
			if not output.has(item):
				output.append(item)

	if instance is RefCounted:
		pass

	return {
		"success": true,
		"output": output
	}

func _normalize_indentation(code: String) -> String:
	var lines: PackedStringArray = code.split("\n")
	var min_indent: int = 999999
	for line in lines:
		if line.strip_edges().is_empty():
			continue
		var indent: int = 0
		for c in line:
			if c == "\t":
				indent += 4
			elif c == " ":
				indent += 1
			else:
				break
		if indent < min_indent:
			min_indent = indent
	if min_indent == 0 or min_indent == 999999:
		return code
	var result_lines: PackedStringArray = []
	for line in lines:
		if line.strip_edges().is_empty():
			result_lines.append("")
			continue
		var removed: int = 0
		var new_line: String = ""
		for c in line:
			if removed >= min_indent:
				new_line += c
			elif c == "\t":
				removed += 4
				if removed > min_indent:
					new_line += " ".repeat(removed - min_indent)
			elif c == " ":
				removed += 1
			else:
				new_line += c
				removed = min_indent
		result_lines.append(new_line)
	return "\n".join(result_lines)

# ============================================================================
# clear_output - очистка панели вывода и буфера логов
# ============================================================================

func _register_clear_output(server_core: RefCounted) -> void:
	var tool_name: String = "clear_output"
	var description: String = "Clear the editor output panel and MCP log buffer."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"clear_mcp_buffer": {
				"type": "boolean",
				"description": "Whether to clear the MCP log buffer. Default is true."
			},
			"clear_editor_panel": {
				"type": "boolean",
				"description": "Whether to clear the editor output panel. Default is true."
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"mcp_buffer_cleared": {"type": "boolean"},
			"editor_panel_cleared": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
		Callable(self, "_tool_clear_output"),
		output_schema, annotations)

func _tool_clear_output(params: Dictionary) -> Dictionary:
	var clear_mcp_buffer: bool = params.get("clear_mcp_buffer", true)
	var clear_editor_panel: bool = params.get("clear_editor_panel", true)

	var mcp_cleared: bool = false
	var mcp_panel_cleared: bool = false
	var panel_cleared: bool = false

	if clear_mcp_buffer:
		_log_mutex.lock()
		_log_buffer.clear()
		_log_mutex.unlock()
		mcp_cleared = true
		mcp_panel_cleared = _clear_mcp_panel_log()

	if clear_editor_panel:
		var editor_interface: EditorInterface = _get_editor_interface()
		if editor_interface:
			var base_control: Control = editor_interface.get_base_control()
			if base_control:
				var log_panel: Node = base_control.find_child("*Output*", true, false)
				if log_panel:
					var rich_text: RichTextLabel = _find_rich_text_label(log_panel)
					if rich_text:
						rich_text.clear()
						panel_cleared = true

	return {
		"status": "success",
		"mcp_buffer_cleared": mcp_cleared,
		"mcp_panel_cleared": mcp_panel_cleared,
		"editor_panel_cleared": panel_cleared
	}

func _clear_mcp_panel_log() -> bool:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return false
	var main_screen: Control = editor_interface.get_editor_main_screen()
	if not main_screen:
		return false
	for child in main_screen.get_children():
		if child.get_script() and child.get_script().resource_path.find("mcp_panel_native") >= 0:
			var text_edit: TextEdit = child.find_child("*TextEdit*", true, false)
			if text_edit and not text_edit.editable:
				text_edit.text = ""
				return true
	return false

func _find_rich_text_label(node: Node) -> RichTextLabel:
	if node is RichTextLabel:
		return node as RichTextLabel
	for child in node.get_children():
		var result: RichTextLabel = _find_rich_text_label(child)
		if result:
			return result
	return null
