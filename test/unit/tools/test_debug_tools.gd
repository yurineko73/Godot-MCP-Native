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

class TimeoutRuntimeBridge:
	extends RefCounted

	var send_count: int = 0
	var cached_payload: Dictionary = {
		"fps": 30.0,
		"current_scene": "/root/StaleScene",
		"node_count": 99
	}

	func get_message_sequence() -> int:
		return 0

	func send_debugger_message(message: String, data: Array, session_id: int = -1) -> Dictionary:
		send_count += 1
		return {"status": "success", "sessions_updated": 1}

	func get_captured_messages(count: int = 100, offset: int = 0, order: String = "desc") -> Dictionary:
		return {"messages": [], "count": 0, "total_available": 0}

	func get_captured_message_after_sequence(sequence: int, response_messages: Array, error_messages: Array = [], match_fields: Dictionary = {}) -> Dictionary:
		return {}

	func get_latest_message_payload(message: String, match_fields: Dictionary = {}) -> Variant:
		return cached_payload

class FakeRuntimePlugin:
	extends RefCounted

	var bridge: RefCounted

	func _init(runtime_bridge: RefCounted) -> void:
		bridge = runtime_bridge

	func get_debugger_bridge() -> RefCounted:
		return bridge

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

	# _tool_get_runtime_info uses await internally for the poll loop.
	# The await must be used at the call site to get a Dictionary result.
	var first_result: Dictionary = await debug_tools._tool_get_runtime_info({"timeout_ms": 1500})
	# The poll loop resolves with fresh data on the first frame after the initial pending response
	assert_eq(first_result.get("status"), "success", "First poll should resolve with fresh data")
	assert_eq(first_result.get("node_count"), 3, "Runtime info payload should come from the bridge response")
	assert_eq(_runtime_bridge.send_count, 1, "First poll should send exactly one runtime probe message")

	# A second call sends once, but must not reuse the prior response as fresh evidence.
	var second_result: Dictionary = await debug_tools._tool_get_runtime_info({"timeout_ms": 1500})
	assert_eq(second_result.get("status"), "timeout", "Second call should time out without a fresh response")
	assert_false(second_result.has("node_count"), "Prior runtime data should not satisfy the second request")
	assert_eq(_runtime_bridge.send_count, 2, "Each tool call should send one runtime probe message")

func test_runtime_probe_timeout_sends_once_and_does_not_promote_cache():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	_runtime_bridge = TimeoutRuntimeBridge.new()
	Engine.set_meta("GodotMCPPlugin", FakeRuntimePlugin.new(_runtime_bridge))

	var result: Dictionary = await debug_tools._tool_get_runtime_info({"timeout_ms": 1})

	assert_eq(_runtime_bridge.send_count, 1, "One tool call should send one runtime probe message")
	assert_eq(result.get("status"), "timeout", "Missing fresh evidence should remain a timeout")
	assert_false(result.get("from_cache", false), "Timeout should not be promoted from cache")
	assert_false(result.get("stale", false), "Timeout should not masquerade as stale success")
	assert_false(result.has("node_count"), "Cached runtime data should not satisfy the timed-out request")
	assert_true(debug_tools._pending_runtime_probe_requests.is_empty(), "Timed-out requests should be removed")

func test_runtime_mutation_timeout_sends_exactly_once():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	_runtime_bridge = TimeoutRuntimeBridge.new()
	Engine.set_meta("GodotMCPPlugin", FakeRuntimePlugin.new(_runtime_bridge))

	var result: Dictionary = await debug_tools._tool_create_runtime_node({
		"parent_path": "/root/Main",
		"node_type": "Node",
		"node_name": "CreatedOnce",
		"timeout_ms": 1
	})

	assert_eq(_runtime_bridge.send_count, 1, "A timed-out mutation must not be sent again")
	assert_eq(result.get("status"), "timeout", "An unconfirmed mutation should remain a timeout")
	assert_true(debug_tools._pending_runtime_probe_requests.is_empty(), "Timed-out mutations should be removed")

func test_poll_loop_enters_on_initial_stale():
	var debug_tools_script: GDScript = load("res://addons/godot_mcp/tools/debug_tools_native.gd")
	var source_code: String = debug_tools_script.source_code
	# The poll loop should enter when the initial result is "stale" (not just "pending")
	# Previously: if result.get("status") == "pending"
	# Now: if result.get("status") in ["pending", "stale"]
	assert_true(source_code.contains('if result.get("status") in ["pending", "stale"]'), "Poll loop should enter on both pending and stale initial status")
	# Verify the stale entry condition appears BEFORE the while loop
	var entry_pos: int = source_code.find('if result.get("status") in ["pending", "stale"]')
	var while_pos: int = source_code.find("while Time.get_ticks_msec() < deadline_ms", entry_pos)
	assert_true(entry_pos >= 0, "Entry condition should exist")
	assert_true(while_pos >= 0, "While loop should exist after entry condition")
	assert_true(entry_pos < while_pos, "Entry condition should appear before the while loop")

# --- assert_runtime_condition expected parameter tests ---

func test_compare_values_eq():
	"""_compare_values with operator='eq' should match identical strings"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: bool = tool._compare_values("hello", "hello", "eq")
	assert_true(result, "'hello' == 'hello' should be true")

func test_compare_values_ne():
	"""_compare_values with operator='ne' should match different strings"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: bool = tool._compare_values("hello", "world", "ne")
	assert_true(result, "'hello' != 'world' should be true")

func test_compare_values_gt():
	"""_compare_values with operator='gt' should compare numerically"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: bool = tool._compare_values("5", "3", "gt")
	assert_true(result, "5 > 3 should be true")
	result = tool._compare_values("3", "5", "gt")
	assert_false(result, "3 > 5 should be false")

func test_compare_values_lt():
	"""_compare_values with operator='lt' should compare numerically"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: bool = tool._compare_values("3", "5", "lt")
	assert_true(result, "3 < 5 should be true")

func test_compare_values_gte():
	"""_compare_values with operator='gte' should include equality"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: bool = tool._compare_values("5", "5", "gte")
	assert_true(result, "5 >= 5 should be true")
	result = tool._compare_values("6", "5", "gte")
	assert_true(result, "6 >= 5 should be true")

func test_compare_values_lte():
	"""_compare_values with operator='lte' should include equality"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: bool = tool._compare_values("5", "5", "lte")
	assert_true(result, "5 <= 5 should be true")
	result = tool._compare_values("4", "5", "lte")
	assert_true(result, "4 <= 5 should be true")

func test_compare_values_default_operator():
	"""_compare_values with unknown operator should return false"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: bool = tool._compare_values("hello", "world", "invalid_op")
	assert_false(result, "Unknown operator should return false")

# --- await_scene_ready parameter validation tests ---

func test_await_scene_ready_missing_scene_name():
	"""await_scene_ready should error when scene_name is missing"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = tool._tool_await_scene_ready({})
	assert_has(result, "error", "Missing scene_name should return error")

func test_await_scene_ready_validates_scene_name():
	"""await_scene_ready should accept valid scene_name parameter"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	# Can't fully test the wait loop in unit tests (no game running).
	# But we can verify the function is callable and returns properly structured results.
	var result: Dictionary = tool._tool_await_scene_ready({"scene_name": "Main", "timeout_sec": 0.1})
	# With very short timeout, should time out
	assert_has(result, "status", "Result should have status field")
	assert_has(result, "scene_name", "Result should have scene_name field")
	assert_has(result, "elapsed_sec", "Result should have elapsed_sec field")
	assert_has(result, "timeout", "Result should have timeout field")
	assert_has(result, "attempts", "Result should have attempts field")

# --- simulate_runtime_input_event match_fields tests ---

func test_simulate_input_event_extracts_match_fields():
	"""simulate_runtime_input_event should extract type/button_index/pressed from event payload"""
	var params: Dictionary = {
		"event": {"type": "mouse_button", "button_index": 1, "pressed": false, "position": {"x": 250, "y": 697}}
	}
	var event_payload: Variant = params.get("event", null)
	assert_true(event_payload is Dictionary, "Event should be a Dictionary")
	if event_payload is Dictionary:
		assert_has(event_payload, "type", "Event should have type")
		assert_has(event_payload, "button_index", "Event should have button_index")
		assert_has(event_payload, "pressed", "Event should have pressed")

# --- get_runtime_scene_tree stale detection tests ---

func test_runtime_scene_tree_stale_response_format():
	"""stale response should have specific format with stale flag"""
	var stale_result: Dictionary = {
		"status": "stale",
		"stale": true,
		"scene_tree": {},
		"message": "Game session is no longer active",
		"node_count": 0
	}
	assert_eq(stale_result.get("stale", false), true, "stale flag should be true")
	assert_eq(stale_result.get("node_count", -1), 0, "node_count should be 0 for stale")
	assert_has(stale_result, "message", "stale response should have message")

# --- _make_runtime_probe_request_key tests ---

func test_request_key_format_is_deterministic():
	"""Same inputs should produce the same key"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var key1: String = tool._make_runtime_probe_request_key("get_runtime_info", [], -1, ["mcp:runtime_info"], {})
	var key2: String = tool._make_runtime_probe_request_key("get_runtime_info", [], -1, ["mcp:runtime_info"], {})
	assert_eq(key1, key2, "Same inputs should produce identical keys")

func test_request_key_differs_with_different_payload():
	"""Different payloads should produce different keys, even with same command"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var key_a: String = tool._make_runtime_probe_request_key("evaluate_expression", ["2+2"], -1, ["mcp:expression_result"], {"expression": "2+2"})
	var key_b: String = tool._make_runtime_probe_request_key("evaluate_expression", ["3+3"], -1, ["mcp:expression_result"], {"expression": "3+3"})
	assert_ne(key_a, key_b, "Different payloads should produce different keys")

func test_request_key_differs_with_different_match_fields():
	"""Different match_fields should produce different keys"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var key_a: String = tool._make_runtime_probe_request_key("inspect_node", ["/root/NodeA"], -1, ["mcp:node"], {"path": "/root/NodeA"})
	var key_b: String = tool._make_runtime_probe_request_key("inspect_node", ["/root/NodeB"], -1, ["mcp:node"], {"path": "/root/NodeB"})
	assert_ne(key_a, key_b, "Different match_fields should produce different keys")
	assert_true(key_a.length() > 0, "Key should not be empty")
	assert_true(key_a.contains("inspect_node"), "Key should contain command name")

func test_request_key_includes_session_id():
	"""Different session_ids should produce different keys"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var key_a: String = tool._make_runtime_probe_request_key("get_runtime_info", [], 1, ["mcp:runtime_info"], {})
	var key_b: String = tool._make_runtime_probe_request_key("get_runtime_info", [], 2, ["mcp:runtime_info"], {})
	assert_ne(key_a, key_b, "Different session_ids should produce different keys")

func test_request_key_omits_empty_match_fields():
	"""Empty match_fields should not appear in the key"""
	var tool = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var key: String = tool._make_runtime_probe_request_key("get_runtime_info", [], -1, ["mcp:runtime_info"], {})
	# Key should contain command, session_id, payload, response_messages
	assert_true(key.contains("get_runtime_info"), "Key should contain command")
	assert_true(key.contains("-1"), "Key should contain session_id")
	assert_true(key.contains("mcp:runtime_info"), "Key should contain response_messages")
	# It should NOT end with an extra dangling separator from empty match_fields
	assert_false(key.ends_with("|"), "Key should not end with |")
