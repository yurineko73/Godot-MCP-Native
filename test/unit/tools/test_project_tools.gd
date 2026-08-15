extends "res://addons/gut/test.gd"

func test_project_info_format():
	var result: Dictionary = {
		"project_name": "Godot MCP Native",
		"project_path": "F:/gitProjects/Godot-MCP-Native/",
		"project_version": "",
		"project_description": "",
		"main_scene": "res://TestScene.tscn"
	}
	assert_has(result, "project_name", "Should have project_name")
	assert_has(result, "project_path", "Should have project_path")
	assert_has(result, "main_scene", "Should have main_scene")

func test_project_settings_filter():
	var settings: Dictionary = {
		"application/config/name": "Godot MCP Native",
		"application/run/main_scene": "res://TestScene.tscn",
		"debug/gdscript/warnings/unused_variable": true
	}
	var filtered: Dictionary = {}
	for key in settings:
		if key.begins_with("application/"):
			filtered[key] = settings[key]
	assert_eq(filtered.size(), 2, "Should filter to application/ settings only")
	assert_false(filtered.has("debug/gdscript/warnings/unused_variable"), "Should not have debug settings")

func test_project_settings_no_filter():
	var settings: Dictionary = {
		"application/config/name": "Godot MCP Native",
		"debug/gdscript/warnings/unused_variable": true
	}
	assert_eq(settings.size(), 2, "Without filter should return all settings")

func test_resource_extensions():
	var extensions: Array = [
		".tres", ".res", ".png", ".jpg", ".jpeg", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".glb", ".gltf", ".obj",
		".tscn", ".gd", ".cfg", ".json", ".gdshader"
	]
	assert_has(extensions, ".tscn", "Should include .tscn")
	assert_has(extensions, ".gd", "Should include .gd")
	assert_has(extensions, ".png", "Should include .png")
	assert_has(extensions, ".gdshader", "Should include .gdshader")

func test_resource_path_safety():
	assert_true(MCPTypes.is_path_safe("res://icon.svg"), "res:// resource should be safe")
	assert_false(MCPTypes.is_path_safe("C:\\Windows\\icon.png"), "Windows path should be unsafe")

func test_create_resource_types():
	var valid_types: Array = ["Curve", "Gradient", "StyleBoxFlat", "Animation"]
	assert_has(valid_types, "Curve", "Should support Curve resource")
	assert_has(valid_types, "Gradient", "Should support Gradient resource")

func test_resource_uri_format():
	var uri: String = "godot://scene/list"
	assert_true(uri.begins_with("godot://"), "Resource URI should start with godot://")

func test_collect_project_autoloads_from_properties_marks_singletons_and_sorts():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var properties: Array = [
		{"name": "autoload/GameState"},
		{"name": "autoload/Bootstrap"},
		{"name": "display/window/size/viewport_width"}
	]
	var values: Dictionary = {
		"autoload/GameState": "*res://autoload/game_state.gd",
		"autoload/Bootstrap": "res://autoload/bootstrap.gd"
	}
	var orders: Dictionary = {
		"autoload/GameState": 40,
		"autoload/Bootstrap": 12
	}
	var autoloads: Array = project_tools._collect_project_autoloads_from_properties(properties, values, orders)
	assert_eq(autoloads.size(), 2, "Should collect two autoload entries")
	assert_eq(autoloads[0].name, "Bootstrap", "Should sort autoloads by project setting order")
	assert_eq(autoloads[0].path, "res://autoload/bootstrap.gd", "Should preserve non-singleton autoload path")
	assert_false(autoloads[0].is_singleton, "Non-prefixed autoload should not be marked singleton")
	assert_eq(autoloads[1].name, "GameState", "Should include singleton autoload name")
	assert_eq(autoloads[1].path, "res://autoload/game_state.gd", "Singleton autoload should strip the * prefix")
	assert_true(autoloads[1].is_singleton, "Prefixed autoload should be marked singleton")

func test_normalize_global_class_entries_preserves_metadata():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var classes: Array = [
		{
			"class": "MyRuntimeNode",
			"path": "res://scripts/my_runtime_node.gd",
			"base": "Node",
			"language": "GDScript",
			"is_tool": false,
			"is_abstract": false,
			"icon": ""
		}
	]
	var normalized: Array = project_tools._normalize_global_class_entries(classes)
	assert_eq(normalized.size(), 1, "Should normalize one global class entry")
	assert_eq(normalized[0].name, "MyRuntimeNode", "Should expose class name as name")
	assert_eq(normalized[0].path, "res://scripts/my_runtime_node.gd", "Should preserve script path")
	assert_eq(normalized[0].base, "Node", "Should preserve base type")
	assert_eq(normalized[0].language, "GDScript", "Should preserve language")
	assert_false(normalized[0].is_tool, "Should preserve tool flag")

func test_get_class_api_metadata_returns_classdb_metadata():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._tool_get_class_api_metadata({
		"class_name": "Node",
		"filter": "process"
	})
	assert_eq(result.source, "classdb", "Engine classes should be sourced from ClassDB")
	assert_eq(result.class_name, "Node", "Should report requested class name")
	assert_eq(result.base_class, "Object", "Should report Node base class")
	assert_gt(result.methods.size(), 0, "Filtered ClassDB methods should be returned")
	assert_gt(result.properties.size(), 0, "Filtered ClassDB properties should be returned")
	assert_true(result.signals.is_empty(), "Process filter should exclude unrelated signals")
	for method in result.methods:
		assert_true(str(method.get("name", "")).to_lower().contains("process"), "Filtered methods should match filter text")

func test_get_class_api_metadata_returns_global_class_metadata_with_base_api():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._tool_get_class_api_metadata({
		"class_name": "ProjectToolsNative",
		"include_base_api": true
	})
	var has_initialize: bool = false
	for method in result.methods:
		if method.get("name", "") == "initialize":
			has_initialize = true
			break
	assert_eq(result.source, "global_class", "Project class should be sourced from global_class metadata")
	assert_eq(result.class_name, "ProjectToolsNative", "Should report requested global class name")
	assert_eq(result.script_path, "res://addons/godot_mcp/tools/project_tools_native.gd", "Should preserve global class script path")
	assert_eq(result.base_class, "RefCounted", "Should preserve global class base type")
	assert_gt(result.methods.size(), 0, "Global class script methods should be returned")
	assert_true(has_initialize, "Should include script-defined methods")
	assert_true(result.has("base_api"), "Should include base API metadata when requested")
	assert_eq(result.base_api.get("class_name", ""), "RefCounted", "Base API should be resolved from ClassDB")

func test_get_class_api_metadata_reports_missing_class():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._tool_get_class_api_metadata({"class_name": "DefinitelyMissingClass123"})
	assert_has(result, "error", "Missing classes should return an error payload")

func test_list_project_tests_uses_default_test_root_for_missing_or_blank_search_path():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var default_result: Dictionary = project_tools._tool_list_project_tests({})
	var blank_result: Dictionary = project_tools._tool_list_project_tests({"search_path": "   "})
	assert_false(default_result.has("error"), "Default search should reach test discovery")
	assert_false(blank_result.has("error"), "Blank search should use the default test root")
	assert_eq(default_result.search_path, "res://test/", "Default search should use the test root directory")
	assert_eq(blank_result.search_path, "res://test/", "Blank search should use the test root directory")
	for entry in default_result.tests:
		assert_true(str(entry.get("test_path", "")).begins_with("res://test/"), "Default search should only return tests under the test root")
	for entry in blank_result.tests:
		assert_true(str(entry.get("test_path", "")).begins_with("res://test/"), "Blank search should only return tests under the test root")

func test_run_project_tests_uses_default_test_root_without_executing_discovered_tests():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var default_result: Dictionary = project_tools._tool_run_project_tests({"framework": "unsupported"})
	var blank_result: Dictionary = project_tools._tool_run_project_tests({"search_path": "   ", "framework": "unsupported"})
	assert_false(default_result.has("error"), "Default batch run should reach discovery")
	assert_false(blank_result.has("error"), "Blank batch search should use the default test root")
	assert_eq(default_result.search_path, "res://test/", "Default batch run should use the test root directory")
	assert_eq(blank_result.search_path, "res://test/", "Blank batch run should use the test root directory")
	assert_eq(default_result.total_count, 0, "An unsupported framework should avoid executing project tests")
	assert_eq(blank_result.total_count, 0, "An unsupported framework should avoid executing project tests")

func test_project_test_tools_reject_paths_outside_test_tree_and_traversal():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var outside_result: Dictionary = project_tools._tool_list_project_tests({"search_path": "res://addons"})
	var traversal_result: Dictionary = project_tools._tool_list_project_tests({"search_path": "res://test/../addons"})
	var batch_outside_result: Dictionary = project_tools._tool_run_project_tests({"search_path": "res://addons"})
	assert_has(outside_result, "error", "Test discovery must reject directories outside the test tree")
	assert_has(traversal_result, "error", "Test discovery must reject traversal outside the test tree")
	assert_has(batch_outside_result, "error", "Batch test execution must preserve the discovery path boundary")

func test_validate_test_path_rejects_traversal_segments_before_sanitization():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	for traversal_path in ["res://test/../addons", "res://test/../../addons", "res://test//../addons"]:
		var result: Dictionary = project_tools._validate_test_path(traversal_path, true)
		assert_has(result, "error", "Test path traversal must be rejected before sanitization: " + traversal_path)

func test_validate_test_path_allows_temporary_integration_directory():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._validate_test_path("res://test/integration/.tmp_project_test_path", true)
	assert_false(result.has("error"), "Temporary integration directories should remain valid test roots")
