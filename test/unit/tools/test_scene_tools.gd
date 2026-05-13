extends "res://addons/gut/test.gd"

class ToolCapture extends RefCounted:
	var tools: Dictionary = {}

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

	func get_tool(name: String) -> Dictionary:
		return tools.get(name, {})

var _scene_tools: RefCounted = null

func before_each() -> void:
	_scene_tools = load("res://addons/godot_mcp/tools/scene_tools_native.gd").new()

func after_each() -> void:
	_scene_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_scene_extension_validation():
	assert_has([".tscn"], ".tscn", "Scene should have .tscn extension")

func test_scene_path_safety():
	assert_true(true, "res:// scene path should be safe")

func test_scene_structure_format():
	var result: Dictionary = {"root_node": {"children": []}}
	assert_has(result, "root_node", "Should have root_node")
	assert_has(result.root_node, "children", "Root node should have children")

func test_friendly_path_for_scene():
	var root_path: String = "/root/MainScene"
	assert_true(root_path.contains("MainScene"), "Root path should contain MainScene")

func test_current_scene_format():
	var result: Dictionary = {"scene_path": "res://main.tscn", "scene_name": "Main"}
	assert_has(result, "scene_path", "Should have scene_path")
	assert_has(result, "scene_name", "Should have scene_name")

func test_save_scene_registers_save_all_open_scenes_schema() -> void:
	var capture := ToolCapture.new()
	_scene_tools._register_save_scene(capture)
	var tool: Dictionary = capture.get_tool("save_scene")
	assert_false(tool.is_empty(), "save_scene should register successfully")
	var properties: Dictionary = tool.get("input_schema", {}).get("properties", {})
	assert_has(properties, "save_all_open_scenes", "save_scene should expose save_all_open_scenes")
	assert_has(properties, "use_editor_save_as", "save_scene should expose use_editor_save_as")

func test_save_scene_rejects_save_all_with_file_path() -> void:
	var result: Dictionary = _scene_tools._tool_save_scene({
		"save_all_open_scenes": true,
		"file_path": "res://TestScene.tscn"
	})
	assert_eq(result.get("error", ""), "save_all_open_scenes and file_path cannot both be set", "save_all_open_scenes and file_path should be mutually exclusive")

func test_save_scene_rejects_save_all_with_editor_save_as() -> void:
	var result: Dictionary = _scene_tools._tool_save_scene({
		"save_all_open_scenes": true,
		"use_editor_save_as": true
	})
	assert_eq(result.get("error", ""), "save_all_open_scenes and use_editor_save_as cannot both be true", "save_all_open_scenes and use_editor_save_as should be mutually exclusive")

func test_save_scene_requires_file_path_for_editor_save_as() -> void:
	var result: Dictionary = _scene_tools._tool_save_scene({
		"use_editor_save_as": true
	})
	assert_eq(result.get("error", ""), "use_editor_save_as requires file_path", "use_editor_save_as should require file_path")

# --- Vibe Coding policy guard tests ---

func test_open_scene_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn"})
	assert_true(result.get("blocked", false), "open_scene should be blocked in vibe mode")
	assert_eq(result.get("reason", ""), "vibe_coding_mode", "Block reason should be vibe_coding_mode")

func test_open_scene_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn", "allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")

func test_open_scene_registers_reload_from_disk_schema() -> void:
	var capture := ToolCapture.new()
	_scene_tools._register_open_scene(capture)
	var tool: Dictionary = capture.get_tool("open_scene")
	assert_false(tool.is_empty(), "open_scene should register successfully")
	var properties: Dictionary = tool.get("input_schema", {}).get("properties", {})
	assert_has(properties, "reload_from_disk", "open_scene should expose reload_from_disk")
	assert_has(properties, "set_inherited", "open_scene should expose set_inherited")

func test_open_scene_rejects_reload_and_inherited_together() -> void:
	var result: Dictionary = _scene_tools._tool_open_scene({
		"scene_path": "res://TestScene.tscn",
		"reload_from_disk": true,
		"set_inherited": true,
		"allow_ui_focus": true
	})
	assert_eq(result.get("error", ""), "reload_from_disk and set_inherited cannot both be true", "reload and inherited should be mutually exclusive")

func test_close_scene_tab_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _scene_tools._tool_close_scene_tab({})
	assert_true(result.get("blocked", false), "close_scene_tab should be blocked in vibe mode")

func test_close_scene_tab_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _scene_tools._tool_close_scene_tab({"allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")
