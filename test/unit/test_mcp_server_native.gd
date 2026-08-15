extends "res://addons/gut/test.gd"

class FakeSecurityServer extends RefCounted:
	var auth_manager: McpAuthManager = null
	var allow_remote: bool = false
	var cors_origin: String = ""

	func set_auth_manager(manager: McpAuthManager) -> void:
		auth_manager = manager

	func set_remote_config(remote_enabled: bool, allowed_origin: String) -> void:
		allow_remote = remote_enabled
		cors_origin = allowed_origin

var _plugin_script: GDScript = null

func before_each():
	_plugin_script = load("res://addons/godot_mcp/mcp_server_native.gd")

func after_each():
	_plugin_script = null

func _get_function_source(function_name: String) -> String:
	var source_code: String = _plugin_script.source_code
	var start_marker: String = "func " + function_name + "("
	var start_index: int = source_code.find(start_marker)
	if start_index < 0:
		return ""
	var next_function_index: int = source_code.find("\nfunc ", start_index + start_marker.length())
	if next_function_index < 0:
		return source_code.substr(start_index)
	return source_code.substr(start_index, next_function_index - start_index)

func test_plugin_script_loads():
	assert_ne(_plugin_script, null, "Plugin script should load successfully")

func test_plugin_has_enter_tree():
	assert_true(_plugin_script.has_method("_enter_tree") or _plugin_script.get_script_method_list().any(func(m): return m.name == "_enter_tree"), "Should have _enter_tree method")

func test_plugin_has_exit_tree():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_exit_tree"), "Should have _exit_tree method")

func test_plugin_has_start_server():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("start_server"), "Should have start_server method")

func test_plugin_has_stop_server():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("stop_server"), "Should have stop_server method")

func test_plugin_has_get_server_status():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("get_server_status"), "Should have get_server_status method")

func test_http_security_sync_applies_current_remote_and_auth_config():
	var server: FakeSecurityServer = FakeSecurityServer.new()
	_plugin_script.apply_http_security_config(
		server,
		true,
		"1234567890abcdef",
		true,
		"https://editor.example"
	)
	assert_ne(server.auth_manager, null, "Enabled auth should install a manager")
	assert_true(
		server.auth_manager.validate_request({"authorization": "Bearer 1234567890abcdef"}),
		"Installed auth manager should use the latest token"
	)
	assert_true(server.allow_remote, "Latest remote access setting should be applied")
	assert_eq(server.cors_origin, "https://editor.example", "Latest CORS origin should be applied")

func test_http_security_sync_clears_stale_auth_manager():
	var server: FakeSecurityServer = FakeSecurityServer.new()
	server.auth_manager = McpAuthManager.new()
	_plugin_script.apply_http_security_config(server, false, "", false, "*")
	assert_null(server.auth_manager, "Disabled auth should clear a manager from an earlier start")

func test_start_syncs_http_security_before_transport_start():
	var start_source: String = _get_function_source("_start_native_server")
	var sync_position: int = start_source.find("_sync_http_security_config()")
	var start_position: int = start_source.find("_native_server.start()")
	assert_true(sync_position >= 0, "Start should refresh HTTP security configuration")
	assert_true(start_position >= 0, "Start should invoke the server core")
	assert_true(sync_position < start_position, "Security configuration should refresh before the listener starts")

func test_find_files_recursive():
	var result: Array = []
	var dir: DirAccess = DirAccess.open("res://")
	if dir:
		_plugin_script._find_files_recursive(dir, ".tscn", result)
		assert_true(result.size() > 0, "Should find at least one .tscn file in the project")

func test_find_files_recursive_gd():
	var result: Array = []
	var dir: DirAccess = DirAccess.open("res://")
	if dir:
		_plugin_script._find_files_recursive(dir, ".gd", result)
		assert_true(result.size() > 0, "Should find at least one .gd file in the project")

func test_count_nodes():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child"
	root.add_child(child)
	var count: int = _plugin_script._count_nodes(root)
	assert_eq(count, 2, "Should count root + 1 child")

func test_get_node_tree():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child1"
	root.add_child(child)
	var tree: Array = _plugin_script._get_node_tree(root, 1)
	assert_eq(tree.size(), 1, "Should have 1 child")
	assert_eq(tree[0]["name"], "Child1", "Child name should match")

func test_get_godot_version():
	var version: Dictionary = _plugin_script._get_godot_version()
	assert_true(version.has("version"), "Should have version key")
	assert_true(version.has("major"), "Should have major key")
	assert_true(version["major"] >= 4, "Godot major should be >= 4")

func test_plugin_name():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_get_plugin_name"), "Should have _get_plugin_name method")
	assert_true(method_names.has("_has_main_screen"), "Should have _has_main_screen method for main screen plugin")
	assert_true(method_names.has("_make_visible"), "Should have _make_visible method for main screen plugin")
	assert_true(method_names.has("_get_plugin_icon"), "Should have _get_plugin_icon method for main screen plugin")
	assert_true(method_names.has("_create_main_screen_panel"), "Should have _create_main_screen_panel method")

func test_export_variables():
	var script_props: Array = _plugin_script.get_script_property_list()
	var prop_names: Array = script_props.map(func(p): return p["name"])
	assert_true(prop_names.has("auto_start"), "Should have auto_start export")
	assert_true(prop_names.has("transport_mode"), "Should have transport_mode export")
	assert_true(prop_names.has("http_port"), "Should have http_port export")
	assert_true(prop_names.has("auth_enabled"), "Should have auth_enabled export")
	assert_true(prop_names.has("log_level"), "Should have log_level export")
	assert_true(prop_names.has("vibe_coding_mode"), "Should have vibe_coding_mode export")

func test_has_load_tool_states_in_enter_tree():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_enter_tree"), "Should have _enter_tree method")
	# Verify load_tool_states is called before UI creation (test _enter_tree calls it)
	var source_code: String = _plugin_script.source_code
	assert_true(source_code.contains("load_tool_states"), "_enter_tree should call load_tool_states")
	assert_true(source_code.contains("_create_main_screen_panel"), "Should still create main screen panel")
	# Verify correct ordering: load_tool_states before _create_main_screen_panel
	var load_pos: int = source_code.find("load_tool_states")
	var panel_pos: int = source_code.find("_create_main_screen_panel")
	assert_true(load_pos >= 0, "load_tool_states should exist in source")
	assert_true(panel_pos >= 0, "_create_main_screen_panel should exist in source")
	assert_true(load_pos < panel_pos, "load_tool_states should be called BEFORE _create_main_screen_panel")

func test_has_autoload_registration_methods():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_ensure_runtime_probe_autoload"), "Should have _ensure_runtime_probe_autoload method")
	assert_true(method_names.has("_remove_runtime_probe_autoload"), "Should have _remove_runtime_probe_autoload method")

func test_autoload_registered_in_enter_tree():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_enter_tree"), "Should have _enter_tree method")
	var source_code: String = _plugin_script.source_code
	# Verify _ensure_runtime_probe_autoload is called in _enter_tree
	assert_true(source_code.contains("_ensure_runtime_probe_autoload"), "_enter_tree should call _ensure_runtime_probe_autoload")
	# Verify correct ordering: _register_all_tools -> _ensure_runtime_probe_autoload -> _create_main_screen_panel
	var register_pos: int = source_code.find("_register_all_tools")
	var autoload_pos: int = source_code.find("_ensure_runtime_probe_autoload")
	var panel_pos: int = source_code.find("_create_main_screen_panel")
	assert_true(register_pos >= 0, "_register_all_tools should exist in source")
	assert_true(autoload_pos >= 0, "_ensure_runtime_probe_autoload should exist in source")
	assert_true(panel_pos >= 0, "_create_main_screen_panel should exist in source")
	assert_true(register_pos < autoload_pos, "_ensure_runtime_probe_autoload should be called AFTER _register_all_tools")
	assert_true(autoload_pos < panel_pos, "_ensure_runtime_probe_autoload should be called BEFORE _create_main_screen_panel")

func test_autoload_removed_only_when_plugin_is_disabled():
	var method_names: Array = _plugin_script.get_script_method_list().map(func(method): return method["name"])
	assert_true(method_names.has("_disable_plugin"), "Plugin should define _disable_plugin")
	var disable_source: String = _get_function_source("_disable_plugin")
	var exit_source: String = _get_function_source("_exit_tree")
	assert_true(disable_source.contains("_remove_runtime_probe_autoload"), "Disabling the plugin should remove its runtime probe Autoload")
	assert_false(exit_source.contains("_remove_runtime_probe_autoload"), "Editor shutdown should not remove the runtime probe Autoload")

func test_runtime_probe_autoload_value_accepts_expected_path():
	assert_true(
		_plugin_script._is_runtime_probe_autoload_value("*res://addons/godot_mcp/runtime/mcp_runtime_probe.gd"),
		"Expected singleton Autoload path should match"
	)
	assert_true(
		_plugin_script._is_runtime_probe_autoload_value("res://addons/godot_mcp/runtime/mcp_runtime_probe.gd"),
		"Expected non-prefixed Autoload path should match"
	)
	assert_true(
		_plugin_script._is_runtime_probe_autoload_value("*uid://bsg12huaf1u5i"),
		"Godot-normalized UID Autoload path should match"
	)

func test_runtime_probe_autoload_value_rejects_foreign_path():
	assert_false(
		_plugin_script._is_runtime_probe_autoload_value("*res://autoload/user_runtime_probe.gd"),
		"A foreign Autoload with the same name must not be treated as plugin-owned"
	)
