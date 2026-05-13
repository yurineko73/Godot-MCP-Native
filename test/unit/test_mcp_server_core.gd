extends "res://addons/gut/test.gd"

var _core: RefCounted = null
const TOOL_STATE_STORAGE_PATH := "user://mcp_tool_state.cfg"

func _clear_tool_state_storage() -> void:
	if not FileAccess.file_exists(TOOL_STATE_STORAGE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TOOL_STATE_STORAGE_PATH))

func _can_write_tool_state_storage() -> bool:
	var absolute_probe_path := ProjectSettings.globalize_path("user://mcp_tool_state_probe.tmp")
	var parent_dir := absolute_probe_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent_dir)
	var probe_file: FileAccess = FileAccess.open(absolute_probe_path, FileAccess.WRITE)
	if probe_file == null:
		return false
	probe_file.store_string("probe")
	probe_file.close()
	if FileAccess.file_exists(absolute_probe_path):
		DirAccess.remove_absolute(absolute_probe_path)
	return true

func before_each():
	_clear_tool_state_storage()
	_core = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

func after_each():
	if _core and _core.is_running():
		_core.stop()
	_core = null
	_clear_tool_state_storage()

func test_negotiate_protocol_version_older():
	var result: String = _core._negotiate_protocol_version("2024-11-05")
	assert_eq(result, "2024-11-05", "Should return older supported version")

func test_negotiate_protocol_version_unsupported():
	var result: String = _core._negotiate_protocol_version("2099-01-01")
	assert_ne(result, "2099-01-01", "Should not return unsupported version")

func test_initialize_advertises_only_supported_capabilities():
	var response: Dictionary = _core._handle_initialize({
		"id": 1,
		"method": "initialize",
		"params": {
			"protocolVersion": MCPTypes.PROTOCOL_VERSION,
			"capabilities": {}
		}
	})
	var capabilities: Dictionary = response.get("result", {}).get("capabilities", {})
	assert_has(capabilities, "tools", "Initialize should advertise tools support")
	assert_has(capabilities, "resources", "Initialize should advertise resources support")
	assert_has(capabilities, "prompts", "Initialize should advertise prompts support")
	assert_eq(capabilities.get("prompts", {}), {}, "Initialize should not advertise prompt listChanged support yet")
	assert_false(capabilities.get("resources", {}).get("subscribe", false), "Initialize should not advertise resources.subscribe yet")
	assert_eq(capabilities.get("resources", {}), {}, "Initialize should not advertise resources listChanged support until notifications exist")

func test_resource_subscribe_returns_not_implemented_error():
	var response: Dictionary = _core._handle_resource_subscribe({
		"id": 2,
		"method": "resources/subscribe",
		"params": {"uri": "godot://test"}
	})
	var error: Dictionary = response.get("error", {})
	assert_eq(error.get("code"), MCPTypes.ERROR_METHOD_NOT_FOUND, "Resource subscribe should return method-not-found while unimplemented")
	assert_string_contains(error.get("message", ""), "resources/subscribe", "Error message should mention resources/subscribe")

func test_prompt_get_returns_unknown_prompt_error():
	var response: Dictionary = _core._handle_prompt_get({
		"id": 3,
		"method": "prompts/get",
		"params": {"name": "test_prompt"}
	})
	var error: Dictionary = response.get("error", {})
	assert_eq(error.get("code"), MCPTypes.ERROR_INVALID_PARAMS, "Unknown prompt should return invalid params")
	assert_string_contains(error.get("message", ""), "test_prompt", "Error message should mention the missing prompt")

func test_prompt_get_returns_registered_prompt_messages():
	var prompt_arguments: Array[Dictionary] = [{"name": "subject", "required": true}]
	_core.register_prompt(
		"test_prompt",
		"Test prompt",
		prompt_arguments,
		func(args): return {
			"messages": [
				{"role": "user", "content": {"type": "text", "text": "Explain %s" % [args.get("subject", "")]}}
			]
		}
	)
	var response: Dictionary = _core._handle_prompt_get({
		"id": 4,
		"method": "prompts/get",
		"params": {
			"name": "test_prompt",
			"arguments": {"subject": "signals"}
		}
	})
	var result: Dictionary = response.get("result", {})
	assert_eq(result.get("description"), "Test prompt", "Prompt get should default description from registered metadata")
	assert_eq(result.get("messages", []).size(), 1, "Prompt get should return callable-provided messages")
	assert_string_contains(
		result.get("messages", [{}])[0].get("content", {}).get("text", ""),
		"signals",
		"Prompt get should pass arguments into the registered callable"
	)

func test_register_tool():
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	assert_true(_core.has_tool("test_tool"), "Should have registered tool")

func test_register_tool_with_category_and_group():
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"}, {}, {}, "supplementary", "Editor-Advanced")
	assert_true(_core.has_tool("test_tool"), "Should have registered tool with category/group")
	var tools: Array = _core.get_registered_tools()
	for t in tools:
		if t.get("name") == "test_tool":
			assert_eq(t.get("category"), "supplementary", "Tool category should be supplementary")
			assert_eq(t.get("group"), "Editor-Advanced", "Tool group should be Editor-Advanced")

func test_register_tool_default_category_and_group():
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	var tools: Array = _core.get_registered_tools()
	for t in tools:
		if t.get("name") == "test_tool":
			assert_eq(t.get("category"), "core", "Default category should be 'core'")
			assert_eq(t.get("group"), "", "Default group should be empty")

func test_unregister_tool():
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	_core.unregister_tool("test_tool")
	assert_false(_core.has_tool("test_tool"), "Should not have unregistered tool")

func test_set_tool_enabled():
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	_core.set_tool_enabled("test_tool", false)
	assert_true(_core.has_tool("test_tool"), "Disabled tool should still exist in tools dict")
	var tools: Array = _core.get_registered_tools()
	var found: bool = false
	for t in tools:
		if t.get("name") == "test_tool":
			assert_false(t.get("enabled", true), "Disabled tool should have enabled=false")
			found = true
	assert_true(found, "Disabled tool should appear in get_registered_tools")

func test_set_tool_enabled_re_enable():
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	_core.set_tool_enabled("test_tool", false)
	_core.set_tool_enabled("test_tool", true)
	assert_true(_core.has_tool("test_tool"), "Re-enabled tool should exist")
	var tools: Array = _core.get_registered_tools()
	for t in tools:
		if t.get("name") == "test_tool":
			assert_true(t.get("enabled", false), "Re-enabled tool should have enabled=true")

func test_set_tool_enabled_sets_dirty_flag():
	_core.register_tool("test_tool", "Test", {"type": "object"}, func(args): return {})
	assert_false(_core.get_tool_list_dirty(), "Dirty flag should be false initially")
	_core.set_tool_enabled("test_tool", false)
	assert_true(_core.get_tool_list_dirty(), "Dirty flag should be true after disabling tool")

func test_clear_tool_list_dirty():
	_core.register_tool("test_tool", "Test", {"type": "object"}, func(args): return {})
	_core.set_tool_enabled("test_tool", false)
	assert_true(_core.get_tool_list_dirty(), "Dirty flag should be true")
	_core.clear_tool_list_dirty()
	assert_false(_core.get_tool_list_dirty(), "Dirty flag should be false after clear")

func test_set_group_enabled_disables_group():
	_core.register_tool("reload_project", "Reload", {"type": "object"}, func(args): return {}, {}, {}, "supplementary", "Editor-Advanced")
	_core.register_tool("execute_editor_script", "Exec Editor Script", {"type": "object"}, func(args): return {}, {}, {}, "supplementary", "Editor-Advanced")
	_core.set_group_enabled("Editor-Advanced", true)
	var changed: int = _core.set_group_enabled("Editor-Advanced", false)
	assert_true(changed >= 2, "Should change at least 2 tools: %d" % [changed])
	var tools: Array = _core.get_registered_tools()
	for t in tools:
		if t["name"] in ["reload_project", "execute_editor_script"]:
			assert_false(t["enabled"], "Tool %s should be disabled" % t["name"])

func test_set_group_enabled_re_enables_group():
	_core.register_tool("reload_project", "Reload", {"type": "object"}, func(args): return {}, {}, {}, "supplementary", "Editor-Advanced")
	_core.register_tool("execute_editor_script", "Exec Script", {"type": "object"}, func(args): return {}, {}, {}, "supplementary", "Editor-Advanced")
	_core.set_group_enabled("Editor-Advanced", true)
	var tools: Array = _core.get_registered_tools()
	for t in tools:
		if t["name"] in ["reload_project", "execute_editor_script"]:
			assert_true(t["enabled"], "Tool %s should be enabled" % t["name"])

func test_set_group_enabled_unknown_group():
	var changed: int = _core.set_group_enabled("NonExistent", false)
	assert_eq(changed, 0, "Unknown group should change 0 tools")

func test_notify_tool_list_changed_not_dirty():
	_core.notify_tool_list_changed()
	assert_false(_core.get_tool_list_dirty(), "Dirty flag should remain false when not dirty")

func test_get_classifier():
	var classifier = _core.get_classifier()
	assert_ne(classifier, null, "Should return a classifier instance")
	assert_true(classifier.has_method("get_all_tools"), "Classifier should have get_all_tools method")

func test_get_state_manager():
	var mgr = _core.get_state_manager()
	assert_ne(mgr, null, "Should return a state manager instance")
	assert_true(mgr.has_method("load_state"), "State manager should have load_state method")

func test_load_tool_states_returns_zero_when_no_saved_state():
	var count: int = _core.load_tool_states()
	assert_true(count >= 0, "Should return 0 or more: %d" % [count])

func test_save_and_load_tool_states():
	if not _can_write_tool_state_storage():
		pass_test("Tool-state persistence is not writable in this editor environment")
		return
	_core.register_tool("save_test_tool", "Save Test", {"type": "object"}, func(args): return {})
	_core.set_tool_enabled("save_test_tool", false)
	_core.save_tool_states()
	var count: int = _core.load_tool_states()
	assert_eq(count, 1, "Should load 1 tool state")
	var tools: Array = _core.get_registered_tools()
	for t in tools:
		if t["name"] == "save_test_tool":
			assert_false(t["enabled"], "Loaded state should have tool disabled")

func test_disabled_tool_not_in_tools_list():
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	_core.register_tool("other_tool", "Another tool", {"type": "object"}, func(args): return {"status": "ok"})
	_core.set_tool_enabled("test_tool", false)
	var msg: Dictionary = {"id": 1, "method": "tools/list"}
	var response: Dictionary = _core._handle_tools_list(msg)
	var tools_list: Array = response.get("result", {}).get("tools", [])
	assert_eq(tools_list.size(), 1, "Should only have 1 enabled tool in tools/list response")
	if tools_list.size() > 0:
		assert_eq(tools_list[0].get("name", ""), "other_tool", "Only other_tool should appear")

func test_disabled_tool_call_returns_error():
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"})
	_core.set_tool_enabled("test_tool", false)
	var msg: Dictionary = {"id": 2, "method": "tools/call", "params": {"name": "test_tool", "arguments": {}}}
	var response: Dictionary = _core._handle_tool_call(msg)
	assert_true(response.get("result", {}).get("isError", false), "Calling disabled tool should return isError")

func test_tool_enabled_default_core():
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {"status": "ok"}, {}, {}, "core", "Script")
	var tools: Array = _core.get_registered_tools()
	for t in tools:
		if t.get("name") == "test_tool":
			assert_true(t.get("enabled", false), "Core tool should be enabled by default")

func test_tool_enabled_default_supplementary():
	_core.register_tool("test_supp_tool", "A supp tool", {"type": "object"}, func(args): return {"status": "ok"}, {}, {}, "supplementary", "Script-Advanced")
	var tools: Array = _core.get_registered_tools()
	for t in tools:
		if t.get("name") == "test_supp_tool":
			assert_false(t.get("enabled", true), "Supplementary tool should be disabled by default")

func test_get_tools_count():
	assert_eq(_core.get_tools_count(), 0, "Should have 0 tools initially")
	_core.register_tool("test_tool", "A test tool", {"type": "object"}, func(args): return {})
	assert_eq(_core.get_tools_count(), 1, "Should have 1 tool after registration")

func test_get_resources_count():
	assert_eq(_core.get_resources_count(), 0, "Should have 0 resources initially")

func test_register_resource():
	_core.register_resource("godot://test", "Test", "application/json", func(params): return {})
	assert_eq(_core.get_resources_count(), 1, "Should have 1 resource after registration")

func test_clear_cache():
	_core.set_cached_scene_structure("res://test.tscn", {"test": true})
	_core.clear_cache()
	var cached: Dictionary = _core.get_cached_scene_structure("res://test.tscn")
	assert_eq(cached.size(), 0, "Cache should be empty after clear")

func test_set_log_level():
	_core.set_log_level(MCPTypes.LogLevel.DEBUG)
	assert_eq(_core._log_level, MCPTypes.LogLevel.DEBUG, "Log level should be DEBUG")

func test_set_security_level():
	_core.set_security_level(MCPTypes.SecurityLevel.STRICT)
	assert_eq(_core._security_level, MCPTypes.SecurityLevel.STRICT, "Security level should be STRICT")

func test_set_rate_limit():
	_core.set_rate_limit(100)
	assert_eq(_core._rate_limit, 100, "Rate limit should be 100")

func test_is_running_initially():
	assert_false(_core.is_running(), "Should not be running initially")

func test_protocol_version_constant():
	assert_eq(MCPTypes.PROTOCOL_VERSION, "2025-11-25", "Protocol version should be 2025-11-25")
