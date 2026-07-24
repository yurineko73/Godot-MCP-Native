extends "res://addons/gut/test.gd"

var _core: RefCounted

func before_each() -> void:
	_core = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

func _echo(arguments: Dictionary) -> Dictionary:
	return arguments

func test_registration_populates_shared_registry() -> void:
	_core.register_tool("echo", "Echo test arguments", {"type": "object", "properties": {}}, Callable(self, "_echo"), {}, {"readOnlyHint": true}, "core", "Test")
	var registry: ToolRegistry = _core.get_tool_registry()
	assert_not_null(registry.get_tool("echo"))

func test_supplementary_tool_is_cli_allowed_without_mcp_visibility() -> void:
	_core.register_tool("advanced_echo", "Advanced echo", {"type": "object", "properties": {}}, Callable(self, "_echo"), {}, {"readOnlyHint": true}, "supplementary", "Test-Advanced")
	var definition: ToolDefinition = _core.get_tool_registry().get_tool("advanced_echo")
	assert_false(definition.policy.mcp_visible)
	assert_true(definition.policy.cli_allowed)
