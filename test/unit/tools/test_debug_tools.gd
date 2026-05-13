extends "res://addons/gut/test.gd"

class FakeRuntimeBridge:
	extends RefCounted

	var send_count: int = 0
	var capture_refresh_count: int = 0
	var message_sequence: int = 0
	var latest_payload: Variant = null

	func get_message_sequence() -> int:
		return message_sequence

	func send_debugger_message(message: String, data: Array, session_id: int = -1) -> Dictionary:
		send_count += 1
		return {"status": "success", "sessions_updated": 1}

	func get_captured_messages(count: int = 100, offset: int = 0, order: String = "desc") -> Dictionary:
		capture_refresh_count += 1
		if capture_refresh_count >= 2 and latest_payload == null:
			message_sequence += 1
			latest_payload = {
				"fps": 60.0,
				"physics_frames": 10,
				"process_frames": 20,
				"debugger_active": true,
				"current_scene": "/root/TestScene",
				"node_count": 3
			}
		return {"messages": [], "count": 0, "total_available": 0}

	func get_captured_message_after_sequence(sequence: int, response_messages: Array, error_messages: Array = [], match_fields: Dictionary = {}) -> Dictionary:
		if latest_payload != null and message_sequence > sequence and response_messages.has("mcp:runtime_info"):
			return {"message": "mcp:runtime_info", "data": [latest_payload], "sequence": message_sequence}
		return {}

	func get_latest_message_payload(message: String, match_fields: Dictionary = {}) -> Variant:
		if message == "mcp:runtime_info":
			return latest_payload
		return null

class FakeRuntimePlugin:
	extends RefCounted

	var bridge: RefCounted

	func _init(runtime_bridge: RefCounted) -> void:
		bridge = runtime_bridge

	func get_debugger_bridge() -> RefCounted:
		return bridge

class FakeRegistrationCore:
	extends RefCounted

	var tools := {}

	func register_tool(name: String, description: String, input_schema: Dictionary, callable_ref: Callable, output_schema: Dictionary, annotations: Dictionary, category: String, group: String) -> void:
		tools[name] = {
			"description": description,
			"input_schema": input_schema,
			"callable": callable_ref,
			"output_schema": output_schema,
			"annotations": annotations,
			"category": category,
			"group": group
		}

var _runtime_bridge: RefCounted = null

func before_each() -> void:
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func after_each() -> void:
	_runtime_bridge = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_debug_print_format():
	var message: String = "[TEST] Hello world"
	assert_true(message.contains("[TEST]"), "Debug message should have category prefix")

func test_debug_log_buffer():
	var log_entry: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"level": "INFO",
		"message": "Test message"
	}
	assert_has(log_entry, "timestamp", "Should have timestamp")
	assert_has(log_entry, "level", "Should have level")
	assert_has(log_entry, "message", "Should have message")

func test_execute_script_simple():
	var expression: Expression = Expression.new()
	var error: Error = expression.parse("1 + 2", [])
	assert_eq(error, OK, "Simple expression should parse OK")
	if error == OK:
		var result: Variant = expression.execute([], null, true)
		assert_eq(result, 3, "1 + 2 should equal 3")

func test_execute_script_with_singleton_binding():
	var expression: Expression = Expression.new()
	var bind_names: PackedStringArray = ["OS"]
	var bind_values: Array = [OS]
	var error: Error = expression.parse("OS.get_name()", bind_names)
	assert_eq(error, OK, "Expression with OS binding should parse OK")
	if error == OK:
		var result: Variant = expression.execute(bind_values, null, true)
		assert_ne(result, "", "OS.get_name() should return non-empty string")

func test_execute_script_execution_error():
	var expression: Expression = Expression.new()
	var error: Error = expression.parse("undefined_variable_xyz", [])
	assert_eq(error, OK, "Parse should succeed even with undefined var")
	if error == OK:
		expression.execute([], null, false)
		assert_true(expression.has_execute_failed(), "Execution should fail with undefined variable")

func test_performance_metrics_types():
	var fps: float = 60.0
	var memory: float = 512.5
	var objects: int = 1000
	assert_gt(fps, 0.0, "FPS should be positive")
	assert_gt(memory, 0.0, "Memory should be positive")
	assert_gt(objects, 0, "Object count should be positive")

func test_log_level_ordering():
	assert_lt(MCPTypes.LogLevel.ERROR, MCPTypes.LogLevel.WARN, "ERROR < WARN")
	assert_lt(MCPTypes.LogLevel.WARN, MCPTypes.LogLevel.INFO, "WARN < INFO")
	assert_lt(MCPTypes.LogLevel.INFO, MCPTypes.LogLevel.DEBUG, "INFO < DEBUG")

func test_mutex_thread_safety():
	var mutex: Mutex = Mutex.new()
	mutex.lock()
	mutex.unlock()
	assert_true(true, "Mutex lock/unlock should not crash")

func test_set_debugger_breakpoint_missing_path():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_set_debugger_breakpoint({"line": 1, "enabled": true})
	assert_has(result, "error", "Should return error for missing path")
	assert_true(str(result.error).contains("path"), "Error should mention path")

func test_set_debugger_breakpoint_invalid_line():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_set_debugger_breakpoint({"path": "res://player.gd", "line": 0, "enabled": true})
	assert_has(result, "error", "Should return error for invalid line")
	assert_true(str(result.error).contains("line"), "Error should mention line")

func test_send_debugger_message_missing_message():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_send_debugger_message({})
	assert_has(result, "error", "Should return error for missing message")
	assert_true(str(result.error).contains("message"), "Error should mention message")

func test_toggle_debugger_profiler_missing_profiler():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_toggle_debugger_profiler({"enabled": true})
	assert_has(result, "error", "Should return error for missing profiler")
	assert_true(str(result.error).contains("profiler"), "Error should mention profiler")

func test_add_debugger_capture_prefix_missing_prefix():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_add_debugger_capture_prefix({})
	assert_has(result, "error", "Should return error for missing prefix")
	assert_true(str(result.error).contains("prefix"), "Error should mention prefix")

func test_install_runtime_probe_empty_node_name():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_install_runtime_probe({"node_name": ""})
	assert_has(result, "error", "Should return error for empty node_name before editing scene")
	assert_true(str(result.error).contains("Editor interface") or str(result.error).contains("node_name"), "Error should be explicit")

func test_send_debug_command_rejects_unknown_command():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_send_debug_command({"command": "unsupported"})
	assert_has(result, "error", "Should return error for unsupported command")
	assert_true(str(result.error).contains("Unsupported"), "Error should mention unsupported command")

func test_get_debug_stack_variables_rejects_negative_frame():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_get_debug_stack_variables({"frame": -1})
	assert_has(result, "error", "Should return error for invalid frame")
	assert_true(str(result.error).contains("bridge") or str(result.error).contains("available"), "Error should mention debugger state")

func test_runtime_probe_polling_reuses_pending_request():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	_runtime_bridge = FakeRuntimeBridge.new()
	Engine.set_meta("GodotMCPPlugin", FakeRuntimePlugin.new(_runtime_bridge))

	var first_result: Dictionary = debug_tools._tool_get_runtime_info({"timeout_ms": 1500})
	assert_eq(first_result.get("status"), "pending", "First runtime probe request should remain pending before bridge response arrives")
	assert_eq(_runtime_bridge.send_count, 1, "First poll should send exactly one runtime probe message")

	var second_result: Dictionary = debug_tools._tool_get_runtime_info({"timeout_ms": 1500})
	assert_eq(second_result.get("status"), "success", "Second poll should consume the response that arrived for the pending request")
	assert_eq(second_result.get("node_count"), 3, "Runtime info payload should come from the bridge response")
	assert_eq(_runtime_bridge.send_count, 1, "Polling a pending runtime request should not re-send the debugger message")

func test_get_mcp_logs_marks_truncation():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	debug_tools._log_buffer.append("[INFO] first")
	debug_tools._log_buffer.append("[WARNING] second")
	debug_tools._log_buffer.append("[ERROR] third")

	var result: Dictionary = debug_tools._get_mcp_logs([], 2, 0, "asc")
	assert_eq(result.get("count"), 2, "Result should honor requested count")
	assert_eq(result.get("total_available"), 3, "Result should report filtered total")
	assert_true(result.get("truncated", false), "Limited log result should report truncation")
	assert_true(result.get("has_more", false), "Limited log result should report more data")
	assert_eq(result.get("next_cursor"), 2, "Limited log result should advertise the next cursor")

func test_get_mcp_logs_last_page_is_complete():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	debug_tools._log_buffer.append("[INFO] first")
	debug_tools._log_buffer.append("[WARNING] second")
	debug_tools._log_buffer.append("[ERROR] third")

	var result: Dictionary = debug_tools._get_mcp_logs([], 2, 2, "asc")
	assert_eq(result.get("count"), 1, "Trailing log page should report its own count")
	assert_eq(result.get("total_available"), 3, "Trailing log page should preserve filtered total")
	assert_false(result.get("truncated", true), "Last log page should not report truncation")
	assert_false(result.get("has_more", true), "Last log page should not report more data")
	assert_false(result.has("next_cursor"), "Last log page should not advertise another cursor")

func test_debug_history_tools_register_continuation_metadata():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	debug_tools._register_get_debugger_messages(server_core)
	debug_tools._register_get_debug_state_events(server_core)
	debug_tools._register_get_debug_output(server_core)

	for tool_name in ["get_debugger_messages", "get_debug_state_events", "get_debug_output"]:
		var output_schema: Dictionary = server_core.tools[tool_name]["output_schema"]
		var properties: Dictionary = output_schema.get("properties", {})
		assert_has(properties, "truncated", "%s should expose truncated in output schema" % tool_name)
		assert_has(properties, "has_more", "%s should expose has_more in output schema" % tool_name)
		assert_has(properties, "next_cursor", "%s should expose next_cursor in output schema" % tool_name)

func test_debug_variable_tools_register_continuation_metadata():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	debug_tools._register_get_debug_variables(server_core)
	debug_tools._register_expand_debug_variable(server_core)

	for tool_name in ["get_debug_variables", "expand_debug_variable"]:
		var output_schema: Dictionary = server_core.tools[tool_name]["output_schema"]
		var properties: Dictionary = output_schema.get("properties", {})
		assert_has(properties, "truncated", "%s should expose truncated in output schema" % tool_name)
		assert_has(properties, "has_more", "%s should expose has_more in output schema" % tool_name)
		assert_has(properties, "next_cursor", "%s should expose next_cursor in output schema" % tool_name)

func test_debugger_bridge_captured_messages_marks_truncation():
	var bridge: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd").new()
	bridge._captured_messages = [
		{"message": "alpha"},
		{"message": "beta"},
		{"message": "gamma"}
	]

	var result: Dictionary = bridge.get_captured_messages(2, 0, "asc")
	assert_eq(result.get("count"), 2, "Message window should honor count")
	assert_eq(result.get("total_available"), 3, "Message window should report total available messages")
	assert_true(result.get("truncated", false), "Limited message window should report truncation")
	assert_true(result.get("has_more", false), "Limited message window should report more data")
	assert_eq(result.get("next_cursor"), 2, "Limited message window should advertise the next cursor")

func test_debugger_bridge_state_events_marks_truncation():
	var bridge: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd").new()
	bridge._state_events = [
		{"state": "breaked", "reason": "pause"},
		{"state": "running", "reason": "continue"},
		{"state": "stopped", "reason": "quit"}
	]

	var result: Dictionary = bridge.get_state_events(2, 0, "asc")
	assert_eq(result.get("count"), 2, "State event window should honor count")
	assert_eq(result.get("total_available"), 3, "State event window should report total available events")
	assert_true(result.get("truncated", false), "Limited state event window should report truncation")
	assert_true(result.get("has_more", false), "Limited state event window should report more data")
	assert_eq(result.get("next_cursor"), 2, "Limited state event window should advertise the next cursor")

func test_debugger_bridge_output_events_marks_truncation_after_category_filter():
	var bridge: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd").new()
	bridge._output_events = [
		{"category": "stdout", "text": "one"},
		{"category": "stderr", "text": "ignore"},
		{"category": "stdout", "text": "two"}
	]

	var result: Dictionary = bridge.get_output_events(1, 0, "asc", "stdout")
	assert_eq(result.get("count"), 1, "Filtered output window should honor count")
	assert_eq(result.get("total_available"), 2, "Filtered output window should report filtered total")
	assert_true(result.get("truncated", false), "Filtered output window should report truncation")
	assert_true(result.get("has_more", false), "Filtered output window should report more data")
	assert_eq(result.get("next_cursor"), 1, "Filtered output window should advertise the next cursor")

func test_debugger_bridge_variables_reference_marks_truncation():
	var bridge: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd").new()
	bridge._variable_references[1] = [
		{"name": "size"},
		{"name": "0"},
		{"name": "1"},
		{"name": "2"}
	]

	var result: Dictionary = bridge.get_variables_by_reference(1, 2, 0)
	assert_eq(result.get("variables_reference"), 1, "Variable page should preserve variables_reference")
	assert_eq(result.get("count"), 2, "Variable page should honor count")
	assert_eq(result.get("total_available"), 4, "Variable page should report total available entries")
	assert_true(result.get("truncated", false), "Variable page should report truncation when limited")
	assert_true(result.get("has_more", false), "Variable page should report more data when limited")
	assert_eq(result.get("next_cursor"), 2, "Variable page should advertise the next cursor")

func test_expand_debug_variable_marks_truncation():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var bridge: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd").new()
	bridge._latest_evaluations["array_value"] = {"type": "Array", "value": [10, 20, 30]}
	Engine.set_meta("GodotMCPPlugin", FakeRuntimePlugin.new(bridge))

	var result: Dictionary = debug_tools._tool_expand_debug_variable({
		"scope": "evaluation",
		"variable_path": ["array_value"],
		"count": 2,
		"offset": 0
	})
	assert_eq(result.get("count"), 2, "Expanded variable page should honor count")
	assert_eq(result.get("total_available"), 4, "Expanded variable page should report total available entries")
	assert_true(result.get("truncated", false), "Expanded variable page should report truncation when limited")
	assert_true(result.get("has_more", false), "Expanded variable page should report more data when limited")
	assert_eq(result.get("next_cursor"), 2, "Expanded variable page should advertise the next cursor")
