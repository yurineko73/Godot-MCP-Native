extends "res://addons/gut/test.gd"

class FakeRegistrationCore:
	extends RefCounted

	var tools := {}

	func register_tool(name: String, description: String, input_schema: Dictionary, callable_ref: Callable, output_schema: Dictionary, annotations: Dictionary, category: String, group: String) -> void:
		tools[name] = {
			"output_schema": output_schema
		}

func test_script_path_validation():
	var valid_paths: Array = ["res://test.gd", "res://scripts/player.gd", "res://addons/my_addon/main.gd"]
	for path in valid_paths:
		assert_true(MCPTypes.is_path_safe(path), path + " should be safe")

func test_script_path_traversal():
	var unsafe_paths: Array = ["res://../secret.gd", "res://scripts/../../etc/passwd"]
	for path in unsafe_paths:
		assert_false(MCPTypes.is_path_safe(path), path + " should be unsafe")

func test_script_extension_check():
	var ext: String = "res://test.gd".get_extension()
	assert_eq(ext, "gd", "Should extract gd extension")

func test_script_extension_tscn():
	var ext: String = "res://scene.tscn".get_extension()
	assert_eq(ext, "tscn", "Should extract tscn extension")

func test_script_base_name():
	var base: String = "res://scripts/player.gd".get_file()
	assert_eq(base, "player.gd", "Should extract file name")

func test_json_parse_string_to_dict():
	var json: String = '{"extends_from":"Node","functions":["_ready","_process"]}'
	var parsed: Variant = JSON.parse_string(json)
	assert_true(parsed is Dictionary, "Should parse to Dictionary")
	assert_has(parsed, "functions", "Should have functions key")

func test_analyze_script_output_format():
	var result: Dictionary = {
		"script_path": "res://test.gd",
		"extends_from": "Node",
		"functions": ["_ready", "_process"],
		"properties": [],
		"signals": [],
		"line_count": 50
	}
	assert_has(result, "script_path", "Should have script_path")
	assert_has(result, "extends_from", "Should have extends_from")
	assert_has(result, "functions", "Should have functions")
	assert_has(result, "line_count", "Should have line_count")

func test_modify_script_line_number():
	var content: String = "line1\nline2\nline3"
	var lines: PackedStringArray = content.split("\n")
	assert_eq(lines.size(), 3, "Should have 3 lines")
	assert_eq(lines[1], "line2", "Line 2 should be 'line2'")

func test_create_script_template():
	var content: String = "extends Node\n\nfunc _ready() -> void:\n\tpass\n"
	var line_count: int = content.split("\n").size()
	assert_gt(line_count, 0, "Template should have lines")

func test_script_symbol_discovery_tools_register_rerun_continuation_metadata():
	var script_tools: RefCounted = load("res://addons/godot_mcp/tools/script_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	script_tools._register_find_script_symbol_definition(server_core)
	script_tools._register_find_script_symbol_references(server_core)

	for tool_name in ["find_script_symbol_definition", "find_script_symbol_references"]:
		var properties: Dictionary = server_core.tools[tool_name]["output_schema"].get("properties", {})
		assert_has(properties, "truncated", "%s should expose truncated in output schema" % tool_name)
		assert_has(properties, "has_more", "%s should expose has_more in output schema" % tool_name)
		assert_has(properties, "max_results_applied", "%s should expose max_results_applied in output schema" % tool_name)
		assert_has(properties, "next_max_results", "%s should expose next_max_results in output schema" % tool_name)

func test_script_symbol_discovery_rerun_continuation_helper_marks_truncated_results():
	var script_tools: RefCounted = load("res://addons/godot_mcp/tools/script_tools_native.gd").new()
	var result: Dictionary = script_tools._with_max_results_continuation({"definitions": [1]}, 3, true)

	assert_true(result.get("truncated", false), "Truncated script discovery result should report truncation")
	assert_true(result.get("has_more", false), "Truncated script discovery result should report more data")
	assert_eq(result.get("max_results_applied"), 3, "Script discovery result should echo applied max_results")
	assert_eq(result.get("next_max_results"), 6, "Truncated script discovery result should advertise a larger rerun budget")

func test_script_symbol_discovery_rerun_continuation_helper_marks_complete_results():
	var script_tools: RefCounted = load("res://addons/godot_mcp/tools/script_tools_native.gd").new()
	var result: Dictionary = script_tools._with_max_results_continuation({"references": []}, 3, false)

	assert_false(result.get("truncated", true), "Complete script discovery result should not report truncation")
	assert_false(result.get("has_more", true), "Complete script discovery result should not report more data")
	assert_eq(result.get("max_results_applied"), 3, "Script discovery result should echo applied max_results")
	assert_false(result.has("next_max_results"), "Complete script discovery result should not advertise a larger rerun budget")

func test_rename_script_symbol_registers_rerun_continuation_metadata():
	var script_tools: RefCounted = load("res://addons/godot_mcp/tools/script_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	script_tools._register_rename_script_symbol(server_core)

	var properties: Dictionary = server_core.tools["rename_script_symbol"]["output_schema"].get("properties", {})
	assert_has(properties, "truncated", "rename_script_symbol should expose truncated in output schema")
	assert_has(properties, "has_more", "rename_script_symbol should expose has_more in output schema")
	assert_has(properties, "max_results_applied", "rename_script_symbol should expose max_results_applied in output schema")
	assert_has(properties, "next_max_results", "rename_script_symbol should expose next_max_results in output schema")

func test_trim_rename_changed_files_respects_budget():
	var script_tools: RefCounted = load("res://addons/godot_mcp/tools/script_tools_native.gd").new()
	var changed_files: Array = [
		{
			"script_path": "res://a.gd",
			"replacement_count": 2,
			"changes": [
				{"line": 1, "replacement_count": 1},
				{"line": 2, "replacement_count": 1}
			]
		},
		{
			"script_path": "res://b.gd",
			"replacement_count": 2,
			"changes": [
				{"line": 3, "replacement_count": 1},
				{"line": 4, "replacement_count": 1}
			]
		}
	]

	var trimmed: Array = script_tools._trim_rename_changed_files(changed_files, 3)

	assert_eq(trimmed.size(), 2, "Trimming should keep both files while budget remains")
	assert_eq(script_tools._count_rename_replacements(trimmed), 3, "Trimmed changed files should respect the requested budget")
	assert_eq(int(trimmed[1].get("replacement_count", 0)), 1, "Last file should be trimmed to the remaining replacement budget")
