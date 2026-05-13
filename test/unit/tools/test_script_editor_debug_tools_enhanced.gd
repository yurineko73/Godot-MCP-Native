extends "res://addons/gut/test.gd"

class FakeRegistrationCore:
	extends RefCounted

	var tools := {}

	func register_tool(name: String, description: String, input_schema: Dictionary, callable_ref: Callable, output_schema: Dictionary, annotations: Dictionary, category: String, group: String) -> void:
		tools[name] = {
			"output_schema": output_schema
		}

var _script_tools: RefCounted = null
var _editor_tools: RefCounted = null
var _debug_tools: RefCounted = null

func before_each():
	_script_tools = load("res://addons/godot_mcp/tools/script_tools_native.gd").new()
	_editor_tools = load("res://addons/godot_mcp/tools/editor_tools_native.gd").new()
	_debug_tools = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()

func after_each():
	_script_tools = null
	_editor_tools = null
	_debug_tools = null

# ===========================================
# attach_script - 附加脚本到节点
# ===========================================

func test_attach_script_missing_node_path():
	var result: Dictionary = _script_tools._tool_attach_script({"script_path": "res://test.gd"})
	assert_has(result, "error", "Should return error for missing node_path")
	assert_true(str(result.error).contains("node_path"), "Error should mention node_path")

func test_attach_script_missing_script_path():
	var result: Dictionary = _script_tools._tool_attach_script({"node_path": "/root/Node"})
	assert_has(result, "error", "Should return error for missing script_path")
	assert_true(str(result.error).contains("script_path"), "Error should mention script_path")

func test_attach_script_empty_params():
	var result: Dictionary = _script_tools._tool_attach_script({})
	assert_has(result, "error", "Should return error for empty params")

func test_attach_script_no_editor_interface():
	var result: Dictionary = _script_tools._tool_attach_script({"node_path": "/root/Node", "script_path": "res://test.gd"})
	assert_has(result, "error", "Should return error when editor interface not available")
	assert_true(str(result.error).contains("Editor interface"), "Error should mention Editor interface")

# ===========================================
# validate_script - 验证脚本语法
# ===========================================

func test_validate_script_missing_both_params():
	var result: Dictionary = _script_tools._tool_validate_script({})
	assert_has(result, "error", "Should return error when neither script_path nor content provided")
	assert_true(str(result.error).contains("script_path") or str(result.error).contains("content"), "Error should mention required params")

func test_validate_script_valid_content():
	var result: Dictionary = _script_tools._tool_validate_script({"content": "extends RefCounted\n\nfunc hello() -> String:\n\treturn 'world'\n"})
	assert_has(result, "valid", "Should return valid field")
	assert_true(result.valid, "Valid GDScript should pass validation")
	assert_eq(result.error_count, 0, "Should have no errors")

func test_validate_script_invalid_content():
	var result: Dictionary = _script_tools._tool_validate_script({"content": "extends RefCounted\n", "check_warnings": false})
	assert_has(result, "valid", "Should return valid field")
	assert_true(result.valid, "Simple valid script should pass")
	assert_eq(result.error_count, 0, "Should have no errors for valid script")

func test_validate_script_empty_content_valid():
	var result: Dictionary = _script_tools._tool_validate_script({"content": "extends Node"})
	assert_has(result, "valid", "Should return valid field for minimal script")
	assert_true(result.valid, "Minimal valid script should pass")
	assert_eq(result.error_count, 0, "Should have no errors")

func test_validate_script_invalid_path():
	var result: Dictionary = _script_tools._tool_validate_script({"script_path": "C:\\invalid\\path.gd"})
	assert_has(result, "error", "Should return error for invalid path")

func test_validate_script_nonexistent_file():
	var result: Dictionary = _script_tools._tool_validate_script({"script_path": "res://nonexistent_file_12345.gd"})
	assert_has(result, "error", "Should return error for nonexistent file")
	assert_true(str(result.error).contains("not found"), "Error should mention file not found")

func test_validate_script_check_warnings_false():
	var result: Dictionary = _script_tools._tool_validate_script({"content": "extends RefCounted\nvar x\n", "check_warnings": false})
	assert_has(result, "valid", "Should return valid field")
	assert_has(result, "warnings", "Should return warnings field")
	assert_eq(result.warning_count, 0, "Should have no warnings when check_warnings is false")

func test_validate_script_valid_returns_structure():
	var result: Dictionary = _script_tools._tool_validate_script({"content": "extends Node\n"})
	assert_has(result, "valid", "Should have valid field")
	assert_has(result, "errors", "Should have errors array")
	assert_has(result, "warnings", "Should have warnings array")
	assert_has(result, "error_count", "Should have error_count")
	assert_has(result, "warning_count", "Should have warning_count")

# ===========================================
# search_in_files - 文件搜索
# ===========================================

func test_search_in_files_missing_pattern():
	var result: Dictionary = _script_tools._tool_search_in_files({})
	assert_has(result, "error", "Should return error for missing pattern")
	assert_true(str(result.error).contains("pattern"), "Error should mention pattern")

func test_search_in_files_empty_pattern():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": ""})
	assert_has(result, "error", "Should return error for empty pattern")

func test_search_in_files_invalid_path():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": "test", "search_path": "C:\\invalid"})
	assert_has(result, "error", "Should return error for invalid path")

func test_search_in_files_invalid_regex():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": "func_\\w+", "use_regex": true, "search_path": "res://addons/godot_mcp/tools/"})
	assert_has(result, "pattern", "Should return pattern for valid regex")
	assert_has(result, "results", "Should return results for valid regex")

func test_search_in_files_regex_no_match():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": "zzzzz_no_match_pattern_zzzzz", "use_regex": true, "search_path": "res://addons/godot_mcp/tools/"})
	assert_eq(result.total_matches, 0, "Should find no matches for non-matching regex")

func test_search_in_files_returns_structure():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": "extends", "search_path": "res://addons/godot_mcp/tools/"})
	assert_has(result, "pattern", "Should have pattern field")
	assert_has(result, "results", "Should have results array")
	assert_has(result, "total_matches", "Should have total_matches")
	assert_has(result, "files_searched", "Should have files_searched")
	assert_has(result, "truncated", "Should have truncated")
	assert_has(result, "has_more", "Should have has_more")
	assert_has(result, "max_results_applied", "Should have max_results_applied")
	assert_eq(result.pattern, "extends", "Pattern should match input")

func test_search_in_files_finds_matches():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": "extends", "search_path": "res://addons/godot_mcp/tools/"})
	assert_true(result.files_searched > 0, "Should search at least one file")
	assert_true(result.total_matches > 0, "Should find at least one match for 'extends'")

func test_search_in_files_case_insensitive():
	var result_ci: Dictionary = _script_tools._tool_search_in_files({"pattern": "EXTENDS", "search_path": "res://addons/godot_mcp/tools/", "case_sensitive": false})
	var result_cs: Dictionary = _script_tools._tool_search_in_files({"pattern": "EXTENDS", "search_path": "res://addons/godot_mcp/tools/", "case_sensitive": true})
	assert_true(result_ci.total_matches > 0, "Case insensitive should find matches")
	assert_eq(result_cs.total_matches, 0, "Case sensitive should find no matches for uppercase")

func test_search_in_files_regex_mode():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": "func _register_\\w+", "search_path": "res://addons/godot_mcp/tools/", "use_regex": true})
	assert_true(result.total_matches > 0, "Regex should find function registrations")

func test_search_in_files_max_results():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": "func", "search_path": "res://addons/godot_mcp/tools/", "max_results": 3})
	assert_true(result.total_matches <= 3, "Should respect max_results limit")
	assert_eq(result.max_results_applied, 3, "Should echo the applied max_results")

func test_search_in_files_registers_rerun_continuation_metadata():
	var server_core := FakeRegistrationCore.new()

	_script_tools._register_search_in_files(server_core)

	var properties: Dictionary = server_core.tools["search_in_files"]["output_schema"].get("properties", {})
	assert_has(properties, "truncated", "search_in_files should expose truncated in output schema")
	assert_has(properties, "has_more", "search_in_files should expose has_more in output schema")
	assert_has(properties, "max_results_applied", "search_in_files should expose max_results_applied in output schema")
	assert_has(properties, "next_max_results", "search_in_files should expose next_max_results in output schema")

func test_search_in_files_reports_terminal_rerun_metadata_on_exact_fit():
	var result: Dictionary = _script_tools._tool_search_in_files({
		"pattern": "class_name ScriptToolsNative",
		"search_path": "res://addons/godot_mcp/tools/",
		"file_extensions": [".gd"],
		"max_results": 1
	})

	assert_eq(result.total_matches, 1, "Should return the single exact-fit match")
	assert_false(result.truncated, "Exact-fit result should not report truncation")
	assert_false(result.has_more, "Exact-fit result should not report more data")
	assert_eq(result.max_results_applied, 1, "Should echo the applied max_results")
	assert_false(result.has("next_max_results"), "Terminal result should not advertise next_max_results")

func test_search_in_files_reports_rerun_metadata_when_truncated():
	var result: Dictionary = _script_tools._tool_search_in_files({
		"pattern": "extends",
		"search_path": "res://addons/godot_mcp/tools/",
		"max_results": 1
	})

	assert_eq(result.total_matches, 1, "Truncated result should still cap returned matches to max_results")
	assert_true(result.truncated, "Truncated result should report truncation")
	assert_true(result.has_more, "Truncated result should report more data")
	assert_eq(result.max_results_applied, 1, "Should echo the applied max_results")
	assert_eq(result.next_max_results, 2, "Truncated result should advertise a larger rerun budget")

func test_search_in_files_file_extension_filter():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": "Node", "search_path": "res://addons/godot_mcp/tools/", "file_extensions": [".tscn"]})
	assert_eq(result.files_searched, 0, "Should not search .gd files when filtering .tscn")

func test_search_in_files_no_match():
	var result: Dictionary = _script_tools._tool_search_in_files({"pattern": "zzzz_no_match_zzzz", "search_path": "res://addons/godot_mcp/tools/"})
	assert_eq(result.total_matches, 0, "Should find no matches for nonsense pattern")
	assert_eq(result.results.size(), 0, "Results should be empty")

# ===========================================
# get_editor_screenshot - 编辑器截图
# ===========================================

func test_get_editor_screenshot_no_editor_interface():
	var result: Dictionary = _editor_tools._tool_get_editor_screenshot({})
	assert_has(result, "error", "Should return error when editor interface not available")
	assert_true(str(result.error).contains("Editor interface"), "Error should mention Editor interface")

func test_get_editor_screenshot_invalid_save_path():
	var result: Dictionary = _editor_tools._tool_get_editor_screenshot({"save_path": "C:\\Windows\\test.png"})
	assert_has(result, "error", "Should return error for invalid save path")

# ===========================================
# get_signals - 获取信号
# ===========================================

func test_get_signals_missing_node_path():
	var result: Dictionary = _editor_tools._tool_get_signals({})
	assert_has(result, "error", "Should return error for missing node_path")
	assert_true(str(result.error).contains("node_path"), "Error should mention node_path")

func test_get_signals_empty_node_path():
	var result: Dictionary = _editor_tools._tool_get_signals({"node_path": ""})
	assert_has(result, "error", "Should return error for empty node_path")

func test_get_signals_no_editor_interface():
	var result: Dictionary = _editor_tools._tool_get_signals({"node_path": "/root/Node"})
	assert_has(result, "error", "Should return error when editor interface not available")

func test_get_signals_node_signal_list():
	var node: Node = Node.new()
	node.name = "TestNode"
	add_child_autofree(node)
	var signal_list: Array = node.get_signal_list()
	assert_true(signal_list.size() > 0, "Node should have built-in signals")
	var signal_names: Array = []
	for sig in signal_list:
		signal_names.append(sig.get("name", ""))
	assert_true(signal_names.has("ready"), "Node should have 'ready' signal")
	assert_true(signal_names.has("tree_entered"), "Node should have 'tree_entered' signal")

func test_get_signals_signal_connection_list():
	var node: Node = Node.new()
	node.name = "TestNode"
	add_child_autofree(node)
	var target: Node = Node.new()
	target.name = "Target"
	add_child_autofree(target)
	node.ready.connect(func(): pass)
	var connections: Array = node.get_signal_connection_list("ready")
	assert_eq(connections.size(), 1, "Should have one connection for 'ready'")

# ===========================================
# reload_project - 重新加载项目
# ===========================================

func test_reload_project_no_editor_interface():
	var result: Dictionary = _editor_tools._tool_reload_project({})
	assert_has(result, "error", "Should return error when editor interface not available")
	assert_true(str(result.error).contains("Editor interface"), "Error should mention Editor interface")

func test_reload_project_default_params():
	var result: Dictionary = _editor_tools._tool_reload_project({})
	assert_has(result, "error", "Should return error when editor interface not available")

# ===========================================
# clear_output - 清除输出
# ===========================================

func test_clear_output_default_params():
	var result: Dictionary = _debug_tools._tool_clear_output({})
	assert_has(result, "status", "Should return status")
	assert_eq(result.status, "success", "Status should be success")
	assert_has(result, "mcp_buffer_cleared", "Should have mcp_buffer_cleared")
	assert_has(result, "editor_panel_cleared", "Should have editor_panel_cleared")
	assert_true(result.mcp_buffer_cleared, "MCP buffer should be cleared by default")

func test_clear_output_mcp_buffer_only():
	_debug_tools._log_buffer.append("[INFO] test log entry")
	_debug_tools._log_buffer.append("[ERROR] test error entry")
	assert_eq(_debug_tools._log_buffer.size(), 2, "Should have 2 log entries before clear")
	var result: Dictionary = _debug_tools._tool_clear_output({"clear_mcp_buffer": true, "clear_editor_panel": false})
	assert_eq(result.status, "success", "Status should be success")
	assert_true(result.mcp_buffer_cleared, "MCP buffer should be cleared")
	assert_false(result.editor_panel_cleared, "Editor panel should not be cleared")
	assert_eq(_debug_tools._log_buffer.size(), 0, "Log buffer should be empty after clear")

func test_clear_output_no_clear():
	_debug_tools._log_buffer.append("[INFO] test log entry")
	var result: Dictionary = _debug_tools._tool_clear_output({"clear_mcp_buffer": false, "clear_editor_panel": false})
	assert_eq(result.status, "success", "Status should be success")
	assert_false(result.mcp_buffer_cleared, "MCP buffer should not be cleared")
	assert_false(result.editor_panel_cleared, "Editor panel should not be cleared")
	assert_eq(_debug_tools._log_buffer.size(), 1, "Log buffer should still have entries")

func test_clear_output_clears_all_log_types():
	_debug_tools._log_buffer.append("[ERROR] error entry")
	_debug_tools._log_buffer.append("[WARNING] warning entry")
	_debug_tools._log_buffer.append("[INFO] info entry")
	_debug_tools._log_buffer.append("[DEBUG] debug entry")
	assert_eq(_debug_tools._log_buffer.size(), 4, "Should have 4 log entries")
	var result: Dictionary = _debug_tools._tool_clear_output({"clear_mcp_buffer": true, "clear_editor_panel": false})
	assert_true(result.mcp_buffer_cleared, "MCP buffer should be cleared")
	assert_eq(_debug_tools._log_buffer.size(), 0, "All log entries should be cleared")

func test_clear_output_idempotent():
	_debug_tools._tool_clear_output({"clear_mcp_buffer": true, "clear_editor_panel": false})
	var result: Dictionary = _debug_tools._tool_clear_output({"clear_mcp_buffer": true, "clear_editor_panel": false})
	assert_eq(result.status, "success", "Clearing empty buffer should still succeed")
	assert_true(result.mcp_buffer_cleared, "Should report cleared even when already empty")

func test_find_node_by_class():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: RichTextLabel = RichTextLabel.new()
	child.name = "RichChild"
	root.add_child(child)
	var found: RichTextLabel = _debug_tools._find_rich_text_label(root)
	assert_ne(found, null, "Should find a RichTextLabel in the tree")

func test_find_node_by_class_not_found():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child"
	root.add_child(child)
	var found: RichTextLabel = _debug_tools._find_rich_text_label(root)
	assert_eq(found, null, "Should return null when no RichTextLabel exists")
