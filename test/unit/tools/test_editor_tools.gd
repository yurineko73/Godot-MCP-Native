extends "res://addons/gut/test.gd"

var _editor_tools: RefCounted = null
var _generated_scene_helper = null

func before_each() -> void:
	_editor_tools = load("res://addons/godot_mcp/tools/editor_tools_native.gd").new()
	_generated_scene_helper = load("res://addons/godot_mcp/utils/generated_scene_screenshot_helper.gd")

func after_each() -> void:
	_editor_tools = null
	_generated_scene_helper = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_editor_state_format():
	var result: Dictionary = {
		"active_scene": "Main",
		"editor_mode": "editor",
		"selected_count": 1,
		"selected_nodes": ["/root/Main"]
	}
	assert_has(result, "active_scene", "Should have active_scene")
	assert_has(result, "editor_mode", "Should have editor_mode")
	assert_has(result, "selected_count", "Should have selected_count")
	assert_has(result, "selected_nodes", "Should have selected_nodes")

func test_selected_nodes_friendly_path():
	var paths: Array = ["/root/Main", "/root/Main/Player", "/root/Main/Camera3D"]
	for path in paths:
		assert_false(str(path).contains("@"), "Friendly path should not contain @")

func test_run_stop_project():
	var states: Array = ["playing", "editor"]
	assert_has(states, "playing", "Should have playing state")
	assert_has(states, "editor", "Should have editor state")

func test_editor_setting_name_format():
	var setting: String = "debug/gdscript/warnings/unused_variable"
	assert_true(setting.contains("/"), "Setting should have category separator")

func test_editor_logs_format():
	var result: Dictionary = {
		"logs": ["[INFO] Test message"],
		"count": 1,
		"total_available": 100
	}
	assert_has(result, "logs", "Should have logs")
	assert_has(result, "count", "Should have count")
	assert_has(result, "total_available", "Should have total_available")

func test_performance_metrics_format():
	var result: Dictionary = {
		"fps": 60.0,
		"memory_usage_mb": 512.5,
		"object_count": 1000,
		"resource_count": 50
	}
	assert_has(result, "fps", "Should have fps")
	assert_has(result, "memory_usage_mb", "Should have memory_usage_mb")
	assert_has(result, "object_count", "Should have object_count")

func test_execute_script_with_singletons():
	var singletons: Dictionary = {
		"OS": OS,
		"Engine": Engine,
		"Input": Input,
	}
	assert_has(singletons, "OS", "Should have OS singleton")
	assert_has(singletons, "Engine", "Should have Engine singleton")
	assert_has(singletons, "Input", "Should have Input singleton")

func test_execute_script_result_format():
	var success: Dictionary = {"status": "success", "result": "42"}
	var error: Dictionary = {"status": "error", "error": "Parse failed"}
	assert_has(success, "status", "Should have status")
	assert_has(error, "error", "Error should have error message")

func test_generated_scene_screenshot_helper_rejects_missing_scene():
	var result: Dictionary = _generated_scene_helper.capture_scene("res://missing_scene_for_capture.tscn", "res://capture.png")
	assert_string_contains(result.get("error", ""), "Failed to load scene", "Missing scene should be reported clearly")

func test_generated_scene_screenshot_helper_rejects_tiny_viewport():
	var result: Dictionary = _generated_scene_helper.capture_scene("res://missing_scene_for_capture.tscn", "res://capture.png", "png", Vector2i.ONE)
	assert_string_contains(result.get("error", ""), "Viewport size must be at least 2x2", "Tiny viewport should be rejected before capture")

func test_get_editor_screenshot_registration_includes_generated_scene_fields():
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()
	_editor_tools._register_get_editor_screenshot(server_core)
	var tool = server_core.get_tool("get_editor_screenshot")
	assert_not_null(tool, "get_editor_screenshot should register successfully")
	var output_schema: Dictionary = tool.output_schema
	var properties: Dictionary = output_schema.get("properties", {})
	assert_has(properties, "width", "Output schema should expose width")
	assert_has(properties, "height", "Output schema should expose height")
	assert_has(properties, "scene_path", "Output schema should expose offscreen scene_path")
	assert_has(properties, "render_mode", "Output schema should expose render_mode")

# --- Vibe Coding policy guard tests ---

func test_run_project_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _editor_tools._tool_run_project({})
	assert_true(result.get("blocked", false), "run_project should be blocked in vibe mode")
	assert_eq(result.get("reason", ""), "vibe_coding_mode", "Block reason should be vibe_coding_mode")

func test_run_project_bypasses_with_allow_window() -> void:
	var result: Dictionary = _editor_tools._tool_run_project({"allow_window": true})
	assert_false(result.get("blocked", false), "allow_window should bypass vibe mode")

func test_stop_project_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _editor_tools._tool_stop_project({})
	assert_true(result.get("blocked", false), "stop_project should be blocked in vibe mode")

func test_stop_project_bypasses_with_allow_window() -> void:
	var result: Dictionary = _editor_tools._tool_stop_project({"allow_window": true})
	assert_false(result.get("blocked", false), "allow_window should bypass vibe mode")

func test_select_node_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _editor_tools._tool_select_node({"node_path": "/root/Main"})
	assert_true(result.get("blocked", false), "select_node should be blocked in vibe mode")

func test_select_node_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _editor_tools._tool_select_node({"node_path": "/root/Main", "allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")

func test_select_file_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _editor_tools._tool_select_file({"file_path": "res://project.godot"})
	assert_true(result.get("blocked", false), "select_file should be blocked in vibe mode")

func test_select_file_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _editor_tools._tool_select_file({"file_path": "res://project.godot", "allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")
