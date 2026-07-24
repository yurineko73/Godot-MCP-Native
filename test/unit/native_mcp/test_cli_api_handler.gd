extends "res://addons/gut/test.gd"

class FakeCore:
	extends RefCounted
	var tools: Dictionary = {}
	func get_all_tools() -> Dictionary:
		return tools

var _core: FakeCore
var _handler: CliApiHandler

func before_each() -> void:
	_core = FakeCore.new()
	_core.tools["echo"] = _legacy_tool("echo", {"readOnlyHint": true})
	_core.tools["delete"] = _legacy_tool("delete", {"readOnlyHint": false, "destructiveHint": true})
	_handler = CliApiHandler.new()
	_handler.configure(_core)

func _echo(arguments: Dictionary) -> Dictionary:
	return arguments

func _legacy_tool(name: String, annotations: Dictionary) -> MCPTypes.MCPTool:
	var tool := MCPTypes.MCPTool.new()
	tool.name = name
	tool.description = "Test " + name
	tool.input_schema = {"type": "object", "properties": {}}
	tool.annotations = annotations
	tool.callable = Callable(self, "_echo")
	tool.category = "core"
	tool.group = "Test"
	tool.enabled = true
	return tool

func test_search_returns_compact_results() -> void:
	var response: Dictionary = await _handler.handle_request("GET", "/cli/v1/tools/search?q=echo&limit=5", {}, "")
	assert_eq(response["status"], 200)
	assert_eq(response["body"]["data"]["tools"][0]["name"], "echo")
	assert_false(response["body"]["data"]["tools"][0].has("input_schema"))

func test_execute_rejects_non_object_arguments() -> void:
	var response: Dictionary = await _handler.handle_request("POST", "/cli/v1/tools/echo/execute", {}, '{"arguments":[]}')
	assert_eq(response["status"], 400)
	assert_eq(response["body"]["error"]["code"], "INVALID_ARGUMENTS")

func test_destructive_execute_requires_apply() -> void:
	var response: Dictionary = await _handler.handle_request("POST", "/cli/v1/tools/delete/execute", {}, '{"arguments":{}}')
	assert_eq(response["status"], 403)
	assert_eq(response["body"]["error"]["code"], "APPLY_REQUIRED")
