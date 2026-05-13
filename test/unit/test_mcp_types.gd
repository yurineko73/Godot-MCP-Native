extends "res://addons/gut/test.gd"

func test_mcp_tool_info_valid():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.callable = func(args): return {}
	assert_true(tool.is_valid(), "Tool with all fields should be valid")
	assert_true(tool.enabled, "Newly created tool should be enabled by default")
	assert_eq(tool.category, "core", "Default category should be 'core'")
	assert_eq(tool.group, "", "Default group should be empty")

func test_mcp_tool_category_field():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.callable = func(args): return {}
	tool.category = "supplementary"
	assert_eq(tool.category, "supplementary", "Category should be settable")
	assert_true(tool.is_valid(), "Tool with supplementary category should still be valid")
	tool.category = "core"
	assert_eq(tool.category, "core", "Category should be changeable to core")

func test_mcp_tool_group_field():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.callable = func(args): return {}
	tool.group = "Node-Read"
	assert_eq(tool.group, "Node-Read", "Group should be settable")
	assert_true(tool.is_valid(), "Tool with group should still be valid")

func test_mcp_tool_to_dict_with_category():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.callable = func(args): return {}
	tool.category = "supplementary"
	tool.group = "Editor-Advanced"
	var d: Dictionary = tool.to_dict()
	assert_eq(d["name"], "test_tool", "Dict should have correct name")
	assert_eq(d["description"], "A test tool", "Dict should have correct description")
	assert_true(tool.is_valid(), "Tool should still be valid")

func test_mcp_tool_enabled_flag():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.callable = func(args): return {}
	assert_true(tool.enabled, "Tool should be enabled by default")
	tool.enabled = false
	assert_false(tool.enabled, "Tool should be disabled after setting enabled=false")
	assert_true(tool.is_valid(), "Disabled tool should still be valid")

func test_mcp_tool_info_missing_name():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.description = "A test tool"
	tool.callable = func(args): return {}
	assert_false(tool.is_valid(), "Tool without name should be invalid")

func test_mcp_tool_info_missing_description():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.callable = func(args): return {}
	assert_false(tool.is_valid(), "Tool without description should be invalid")

func test_mcp_tool_info_missing_callable():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	assert_false(tool.is_valid(), "Tool without callable should be invalid")

func test_mcp_tool_to_dict():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.input_schema = {"type": "object"}
	var d: Dictionary = tool.to_dict()
	assert_eq(d["name"], "test_tool", "Dict should have correct name")
	assert_eq(d["description"], "A test tool", "Dict should have correct description")
	assert_has(d, "inputSchema", "Dict should have inputSchema")

func test_mcp_tool_to_dict_with_output_schema():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.output_schema = {"type": "object"}
	var d: Dictionary = tool.to_dict()
	assert_has(d, "outputSchema", "Dict should have outputSchema when set")

func test_mcp_tool_to_dict_without_output_schema():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	var d: Dictionary = tool.to_dict()
	assert_false(d.has("outputSchema"), "Dict should not have outputSchema when empty")

func test_mcp_tool_annotations():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "test_tool"
	tool.description = "A test tool"
	tool.annotations = MCPTypes.MCPTool.create_annotations(true, false, true, false)
	var d: Dictionary = tool.to_dict()
	assert_has(d, "annotations", "Dict should have annotations when set")
	assert_eq(d["annotations"]["readOnlyHint"], true, "readOnlyHint should be true")

func test_mcp_resource_valid():
	var res: MCPTypes.MCPResource = MCPTypes.MCPResource.new()
	res.uri = "godot://scene/list"
	res.name = "Scene List"
	res.load_callable = func(params): return {}
	assert_true(res.is_valid(), "Resource with all fields should be valid")

func test_mcp_resource_missing_uri():
	var res: MCPTypes.MCPResource = MCPTypes.MCPResource.new()
	res.name = "Scene List"
	res.load_callable = func(params): return {}
	assert_false(res.is_valid(), "Resource without uri should be invalid")

func test_mcp_resource_missing_name():
	var res: MCPTypes.MCPResource = MCPTypes.MCPResource.new()
	res.uri = "godot://scene/list"
	res.load_callable = func(params): return {}
	assert_false(res.is_valid(), "Resource without name should be invalid")

func test_mcp_resource_to_dict():
	var res: MCPTypes.MCPResource = MCPTypes.MCPResource.new()
	res.uri = "godot://scene/list"
	res.name = "Scene List"
	res.mime_type = "application/json"
	var d: Dictionary = res.to_dict()
	assert_eq(d["uri"], "godot://scene/list", "Dict should have correct uri")
	assert_eq(d["name"], "Scene List", "Dict should have correct name")
	assert_eq(d["mimeType"], "application/json", "Dict should have correct mimeType")

func test_mcp_prompt_valid():
	var prompt: MCPTypes.MCPPrompt = MCPTypes.MCPPrompt.new()
	prompt.name = "test_prompt"
	assert_true(prompt.is_valid(), "Prompt with name should be valid")

func test_mcp_prompt_missing_name():
	var prompt: MCPTypes.MCPPrompt = MCPTypes.MCPPrompt.new()
	assert_false(prompt.is_valid(), "Prompt without name should be invalid")

func test_create_response():
	var resp: Dictionary = MCPTypes.create_response(1, {"status": "ok"})
	assert_eq(resp["jsonrpc"], "2.0", "Should have jsonrpc version")
	assert_eq(resp["id"], 1, "Should have correct id")
	assert_has(resp, "result", "Should have result")

func test_create_error_response():
	var resp: Dictionary = MCPTypes.create_error_response(2, -32600, "Invalid request")
	assert_eq(resp["jsonrpc"], "2.0", "Should have jsonrpc version")
	assert_has(resp, "error", "Should have error")
	assert_eq(resp["error"]["code"], -32600, "Should have correct error code")
	assert_eq(resp["error"]["message"], "Invalid request", "Should have correct message")

func test_create_error_response_with_data():
	var resp: Dictionary = MCPTypes.create_error_response(3, -32602, "Invalid params", {"detail": "missing field"})
	assert_has(resp["error"], "data", "Should have error data")
	assert_eq(resp["error"]["data"]["detail"], "missing field", "Should have correct data")

func test_is_path_safe_valid():
	assert_true(MCPTypes.is_path_safe("res://test.tscn"), "res:// path should be safe")

func test_is_path_safe_traversal():
	assert_false(MCPTypes.is_path_safe("res://../etc/passwd"), "Traversal path should be unsafe")

func test_is_path_safe_absolute():
	assert_false(MCPTypes.is_path_safe("/etc/passwd"), "Absolute path should be unsafe")

func test_sanitize_path():
	var result: String = MCPTypes.sanitize_path("res://test../file.gd")
	assert_false(result.contains(".."), "Should remove .. from path")

func test_sanitize_path_adds_prefix():
	var result: String = MCPTypes.sanitize_path("test.gd")
	assert_true(result.begins_with("res://"), "Should add res:// prefix")

func test_create_capabilities():
	var caps: Dictionary = MCPTypes.create_capabilities()
	assert_has(caps, "tools", "Should have tools capability")
	assert_has(caps, "resources", "Should have resources capability")
	assert_has(caps, "prompts", "Default capabilities should advertise prompts support")
	assert_eq(caps["tools"], {"listChanged": true}, "Default tools capability should expose listChanged")
	assert_eq(caps["resources"], {}, "Default resources capability should not advertise listChanged without notifications")
	assert_eq(caps["prompts"], {}, "Default prompts capability should not advertise listChanged")
	assert_false(caps["resources"].get("subscribe", false), "Default capabilities should not advertise resources.subscribe")

func test_create_capabilities_with_explicit_optional_features():
	var caps: Dictionary = MCPTypes.create_capabilities(true, true, true, true, true)
	assert_eq(caps["resources"], {"subscribe": true, "listChanged": true}, "Explicit opt-in should advertise resources.subscribe")
	assert_eq(caps["prompts"], {"listChanged": true}, "Explicit opt-in should advertise prompts support")

func test_create_capabilities_without_prompts_support():
	var caps: Dictionary = MCPTypes.create_capabilities(true, false, true, false, false)
	assert_false(caps.has("prompts"), "Prompt capability should be omitted when prompt support is disabled")

func test_protocol_version():
	assert_eq(MCPTypes.PROTOCOL_VERSION, "2025-11-25", "Protocol version should be 2025-11-25")
