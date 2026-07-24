extends "res://addons/gut/test.gd"

var _registry: ToolRegistry
var _executor: ToolExecutor
var _call_count: int

func before_each() -> void:
	_registry = ToolRegistry.new()
	_executor = ToolExecutor.new(_registry)
	_call_count = 0

func _record(arguments: Dictionary) -> Dictionary:
	_call_count += 1
	return {"arguments": arguments}

func _register(name: String, annotations: Dictionary) -> void:
	var definition := ToolDefinition.new()
	definition.name = name
	definition.description = "Test tool"
	definition.callable = Callable(self, "_record")
	definition.annotations = annotations
	definition.policy = ToolPolicy.from_metadata("core", annotations)
	_registry.register_tool(definition)

func test_dry_run_previews_write_without_calling_handler() -> void:
	_register("write_tool", {"readOnlyHint": false, "destructiveHint": true})
	var context := ToolExecutionContext.new()
	context.caller = "cli"
	context.dry_run = true
	var result: ToolExecutionResult = await _executor.execute("write_tool", {"value": 1}, context)
	assert_true(result.ok)
	assert_true(result.data["preview"])
	assert_eq(_call_count, 0)

func test_destructive_call_requires_apply() -> void:
	_register("delete_tool", {"readOnlyHint": false, "destructiveHint": true})
	var context := ToolExecutionContext.new()
	context.caller = "cli"
	var result: ToolExecutionResult = await _executor.execute("delete_tool", {}, context)
	assert_false(result.ok)
	assert_eq(result.error_code, "APPLY_REQUIRED")
	assert_eq(_call_count, 0)

func test_mcp_context_can_preserve_existing_permission_behavior() -> void:
	_register("delete_tool", {"readOnlyHint": false, "destructiveHint": true})
	var context := ToolExecutionContext.new()
	context.caller = "mcp"
	context.apply_confirmed = true
	context.allow_open_world = true
	var result: ToolExecutionResult = await _executor.execute("delete_tool", {}, context)
	assert_true(result.ok)
	assert_eq(_call_count, 1)
