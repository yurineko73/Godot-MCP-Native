extends "res://addons/gut/test.gd"

var _editor_tools: RefCounted = null

func before_each() -> void:
	_editor_tools = load("res://addons/godot_mcp/tools/editor_tools_native.gd").new()

func after_each() -> void:
	_editor_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_get_file_system_navigation_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_file_system_navigation(server_core)
	var tool = server_core.get_tool("get_file_system_navigation")
	assert_not_null(tool, "get_file_system_navigation should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "current_path", "Navigation output should expose current_path")
	assert_has(properties, "current_directory", "Navigation output should expose current_directory")
	assert_has(properties, "selected_paths", "Navigation output should expose selected_paths")
	assert_has(properties, "selected_count", "Navigation output should expose selected_count")

func test_get_file_system_navigation_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_file_system_navigation({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Navigation read should fail cleanly without editor interface")
