extends "res://addons/gut/test.gd"

func test_supplementary_read_tool_is_hidden_from_mcp_but_allowed_for_cli() -> void:
	var policy := ToolPolicy.from_metadata("supplementary", {"readOnlyHint": true, "destructiveHint": false, "openWorldHint": false})
	assert_true(policy.available)
	assert_false(policy.mcp_visible)
	assert_true(policy.cli_allowed)
	assert_eq(policy.risk_level, "read")
	assert_false(policy.requires_apply)

func test_destructive_annotation_requires_apply() -> void:
	var policy := ToolPolicy.from_metadata("core", {"readOnlyHint": false, "destructiveHint": true, "openWorldHint": false})
	assert_eq(policy.risk_level, "destructive")
	assert_true(policy.requires_apply)

func test_open_world_annotation_requires_permission() -> void:
	var policy := ToolPolicy.from_metadata("core", {"readOnlyHint": true, "destructiveHint": false, "openWorldHint": true})
	assert_true(policy.requires_open_world_permission)
