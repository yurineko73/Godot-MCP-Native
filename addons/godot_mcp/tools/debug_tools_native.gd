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
