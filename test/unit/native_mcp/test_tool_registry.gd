extends "res://addons/gut/test.gd"

var _registry: ToolRegistry

func before_each() -> void:
	_registry = ToolRegistry.new()

func _echo(arguments: Dictionary) -> Dictionary:
	return arguments

func _tool(name: String, description: String, category: String = "core") -> ToolDefinition:
	var definition := ToolDefinition.new()
	definition.name = name
	definition.description = description
	definition.callable = Callable(self, "_echo")
	definition.category = category
	definition.policy = ToolPolicy.from_metadata(category, {"readOnlyHint": true})
	return definition

func test_exact_name_ranks_before_description_match() -> void:
	_registry.register_tool(_tool("runtime_tree", "Read something else"))
	_registry.register_tool(_tool("other", "Read runtime tree"))
	var results: Array[Dictionary] = _registry.search_tools("runtime tree", 5)
	assert_eq(results[0]["name"], "runtime_tree")

func test_cli_catalog_includes_hidden_supplementary_tool() -> void:
	_registry.register_tool(_tool("advanced_read", "Advanced read", "supplementary"))
	assert_eq(_registry.list_tools({"cli_allowed": true}).size(), 1)
	assert_eq(_registry.list_tools({"mcp_visible": true}).size(), 0)

func test_catalog_hash_is_independent_of_registration_order() -> void:
	var other := ToolRegistry.new()
	_registry.register_tool(_tool("a", "A"))
	_registry.register_tool(_tool("b", "B"))
	other.register_tool(_tool("b", "B"))
	other.register_tool(_tool("a", "A"))
	assert_eq(_registry.get_catalog_hash(), other.get_catalog_hash())
