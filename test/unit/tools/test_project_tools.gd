extends "res://addons/gut/test.gd"

class FakeRegistrationCore:
	extends RefCounted

	var tools := {}

	func register_tool(name: String, description: String, input_schema: Dictionary, callable_ref: Callable, output_schema: Dictionary, annotations: Dictionary, category: String, group: String) -> void:
		tools[name] = {
			"output_schema": output_schema
		}

class FakePluginEditorInterface:
	extends RefCounted

	var enabled_by_name: Dictionary = {}

	func is_plugin_enabled(plugin_name: String) -> bool:
		return bool(enabled_by_name.get(plugin_name, false))

	func set_plugin_enabled(plugin_name: String, enabled: bool) -> void:
		enabled_by_name[plugin_name] = enabled

class FakeEditorPaths:
	extends RefCounted

	var _config_dir: String

	func _init(config_dir: String) -> void:
		_config_dir = config_dir

	func get_config_dir() -> String:
		return _config_dir

class FakeFeatureProfileEditorInterface:
	extends RefCounted

	var current_profile: String = ""
	var editor_paths: RefCounted
	var enabled_by_name: Dictionary = {}

	func _init(config_dir: String) -> void:
		editor_paths = FakeEditorPaths.new(config_dir)

	func get_current_feature_profile() -> String:
		return current_profile

	func set_current_feature_profile(profile_name: String) -> void:
		current_profile = profile_name

	func get_editor_paths() -> RefCounted:
		return editor_paths

	func is_plugin_enabled(plugin_name: String) -> bool:
		return bool(enabled_by_name.get(plugin_name, false))

	func set_plugin_enabled(plugin_name: String, enabled: bool) -> void:
		enabled_by_name[plugin_name] = enabled

class FakeGodotMCPPlugin:
	extends RefCounted

	var _editor_interface: RefCounted

	func _init(editor_interface: RefCounted) -> void:
		_editor_interface = editor_interface

	func get_editor_interface() -> RefCounted:
		return _editor_interface

func test_project_info_format():
	var result: Dictionary = {
		"project_name": "Godot MCP Native",
		"project_path": "F:/gitProjects/Godot-MCP-Native/",
		"project_version": "",
		"project_description": "",
		"main_scene": "res://TestScene.tscn"
	}
	assert_has(result, "project_name", "Should have project_name")
	assert_has(result, "project_path", "Should have project_path")
	assert_has(result, "main_scene", "Should have main_scene")

func test_project_settings_filter():
	var settings: Dictionary = {
		"application/config/name": "Godot MCP Native",
		"application/run/main_scene": "res://TestScene.tscn",
		"debug/gdscript/warnings/unused_variable": true
	}
	var filtered: Dictionary = {}
	for key in settings:
		if key.begins_with("application/"):
			filtered[key] = settings[key]
	assert_eq(filtered.size(), 2, "Should filter to application/ settings only")
	assert_false(filtered.has("debug/gdscript/warnings/unused_variable"), "Should not have debug settings")

func test_project_settings_no_filter():
	var settings: Dictionary = {
		"application/config/name": "Godot MCP Native",
		"debug/gdscript/warnings/unused_variable": true
	}
	assert_eq(settings.size(), 2, "Without filter should return all settings")

func test_set_project_setting_registers_write_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_set_project_setting(server_core)

	var output_properties: Dictionary = server_core.tools["set_project_setting"]["output_schema"].get("properties", {})
	assert_has(output_properties, "status", "set_project_setting should expose status")
	assert_has(output_properties, "setting_name", "set_project_setting should expose setting_name")
	assert_has(output_properties, "existed_before", "set_project_setting should expose existed_before")
	assert_has(output_properties, "value_type", "set_project_setting should expose value_type")
	assert_has(output_properties, "previous_value", "set_project_setting should expose previous_value")
	assert_has(output_properties, "persisted_value", "set_project_setting should expose persisted_value")

func test_set_project_setting_reports_missing_invalid_and_unsupported_inputs():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_set_project_setting({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_set_project_setting({
			"setting_name": "not_a_valid_setting_name",
			"setting_value": "value"
		}).get("error", ""),
		"Invalid setting_name: expected slash-delimited project setting key",
		"Invalid setting names should be rejected explicitly"
	)
	assert_eq(
		project_tools._tool_set_project_setting({
			"setting_name": "display/window/size/viewport_width",
			"setting_value": "not-an-int"
		}).get("error", ""),
		"Unsupported setting_value for 'display/window/size/viewport_width': expected integer-compatible value",
		"Unsupported value shapes should be rejected against existing setting types"
	)
	assert_eq(
		project_tools._tool_set_project_setting({
			"setting_name": "mcp/unit/unsupported_setting",
			"setting_value": {"nested": true}
		}).get("error", ""),
		"Unsupported setting_value for 'mcp/unit/unsupported_setting': new custom settings only support boolean, integer, float, or string values",
		"Custom namespace settings should stay limited to scalar values in this slice"
	)

func test_set_project_setting_saves_custom_scalar_value():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var setting_name: String = "mcp/unit/temp_string_setting"
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.clear(setting_name)
		ProjectSettings.save()

	var result: Dictionary = project_tools._tool_set_project_setting({
		"setting_name": setting_name,
		"setting_value": "hello from gut"
	})

	assert_eq(result.get("status", ""), "success", "Valid custom setting writes should succeed")
	assert_eq(result.get("setting_name", ""), setting_name, "Should echo setting_name")
	assert_false(result.get("existed_before", true), "Fresh custom settings should report existed_before=false")
	assert_eq(result.get("value_type", ""), "String", "Custom string setting should report String type")
	assert_eq(result.get("previous_value", "sentinel"), null, "Fresh custom settings should report null previous_value")
	assert_eq(result.get("persisted_value", ""), "hello from gut", "Should return persisted scalar value")
	assert_true(ProjectSettings.has_setting(setting_name), "Custom setting should exist after successful write")
	assert_eq(str(ProjectSettings.get_setting(setting_name)), "hello from gut", "Custom setting should persist in ProjectSettings")

	ProjectSettings.clear(setting_name)
	ProjectSettings.save()

func test_clear_project_setting_registers_destructive_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_clear_project_setting(server_core)

	var output_properties: Dictionary = server_core.tools["clear_project_setting"]["output_schema"].get("properties", {})
	assert_has(output_properties, "status", "clear_project_setting should expose status")
	assert_has(output_properties, "setting_name", "clear_project_setting should expose setting_name")
	assert_has(output_properties, "existed_before", "clear_project_setting should expose existed_before")
	assert_has(output_properties, "removed", "clear_project_setting should expose removed")
	assert_has(output_properties, "previous_value", "clear_project_setting should expose previous_value")

func test_clear_project_setting_reports_missing_and_invalid_names():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_clear_project_setting({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_clear_project_setting({
			"setting_name": "not_a_valid_setting_name"
		}).get("error", ""),
		"Invalid setting_name: expected slash-delimited project setting key",
		"Invalid setting names should be rejected explicitly"
	)

func test_clear_project_setting_reports_missing_custom_key_without_error():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var setting_name: String = "mcp/unit/missing_clear_setting"
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.clear(setting_name)
		ProjectSettings.save()

	var result: Dictionary = project_tools._tool_clear_project_setting({
		"setting_name": setting_name
	})

	assert_eq(result.get("status", ""), "success", "Missing custom setting clear should still succeed")
	assert_false(result.get("existed_before", true), "Missing custom setting should report existed_before=false")
	assert_false(result.get("removed", true), "Missing custom setting should report removed=false")
	assert_eq(result.get("previous_value", "sentinel"), null, "Missing custom setting should report null previous_value")

func test_clear_project_setting_removes_existing_custom_key():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var setting_name: String = "mcp/unit/temp_clear_setting"
	ProjectSettings.set_setting(setting_name, "clear-me")
	ProjectSettings.save()

	var result: Dictionary = project_tools._tool_clear_project_setting({
		"setting_name": setting_name
	})

	assert_eq(result.get("status", ""), "success", "Existing custom setting clear should succeed")
	assert_true(result.get("existed_before", false), "Existing custom setting should report existed_before=true")
	assert_true(result.get("removed", false), "Existing custom setting should report removed=true")
	assert_eq(result.get("previous_value", ""), "clear-me", "Existing custom setting should report previous_value")
	assert_false(ProjectSettings.has_setting(setting_name), "Custom setting should no longer exist after clear")

func test_inspect_project_setting_registers_single_key_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_inspect_project_setting(server_core)

	var output_properties: Dictionary = server_core.tools["inspect_project_setting"]["output_schema"].get("properties", {})
	assert_has(output_properties, "setting_name", "inspect_project_setting should expose setting_name")
	assert_has(output_properties, "exists", "inspect_project_setting should expose exists")
	assert_has(output_properties, "value_type", "inspect_project_setting should expose value_type")
	assert_has(output_properties, "persisted_value", "inspect_project_setting should expose persisted_value")

func test_inspect_project_setting_reports_missing_and_invalid_names():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_inspect_project_setting({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_inspect_project_setting({
			"setting_name": "not_a_valid_setting_name"
		}).get("error", ""),
		"Invalid setting_name: expected slash-delimited project setting key",
		"Invalid setting names should be rejected explicitly"
	)

func test_inspect_project_setting_reports_missing_custom_key_without_error():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var setting_name: String = "mcp/unit/missing_inspect_setting"
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.clear(setting_name)
		ProjectSettings.save()

	var result: Dictionary = project_tools._tool_inspect_project_setting({
		"setting_name": setting_name
	})

	assert_eq(result.get("setting_name", ""), setting_name, "Missing setting inspection should echo setting_name")
	assert_false(result.get("exists", true), "Missing setting inspection should report exists=false")

func test_inspect_project_setting_returns_persisted_value_and_type():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var setting_name: String = "mcp/unit/temp_inspect_setting"
	ProjectSettings.set_setting(setting_name, "inspect-me")
	ProjectSettings.save()

	var result: Dictionary = project_tools._tool_inspect_project_setting({
		"setting_name": setting_name
	})

	assert_eq(result.get("setting_name", ""), setting_name, "Setting inspection should echo setting_name")
	assert_true(result.get("exists", false), "Setting inspection should report exists=true for a present key")
	assert_eq(result.get("value_type", ""), "String", "Setting inspection should report persisted value type")
	assert_eq(result.get("persisted_value", ""), "inspect-me", "Setting inspection should report persisted value")

	ProjectSettings.clear(setting_name)
	ProjectSettings.save()

func test_resource_extensions():
	var extensions: Array = [
		".tres", ".res", ".png", ".jpg", ".jpeg", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".glb", ".gltf", ".obj",
		".tscn", ".gd", ".cfg", ".json", ".gdshader"
	]
	assert_has(extensions, ".tscn", "Should include .tscn")
	assert_has(extensions, ".gd", "Should include .gd")
	assert_has(extensions, ".png", "Should include .png")
	assert_has(extensions, ".gdshader", "Should include .gdshader")

func test_resource_path_safety():
	assert_true(MCPTypes.is_path_safe("res://icon.svg"), "res:// resource should be safe")
	assert_false(MCPTypes.is_path_safe("C:\\Windows\\icon.png"), "Windows path should be unsafe")

func test_create_resource_types():
	var valid_types: Array = ["Curve", "Gradient", "StyleBoxFlat", "Animation"]
	assert_has(valid_types, "Curve", "Should support Curve resource")
	assert_has(valid_types, "Gradient", "Should support Gradient resource")

func test_resource_uri_format():
	var uri: String = "godot://scene/list"
	assert_true(uri.begins_with("godot://"), "Resource URI should start with godot://")

func test_collect_project_autoloads_from_properties_marks_singletons_and_sorts():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var properties: Array = [
		{"name": "autoload/GameState"},
		{"name": "autoload/Bootstrap"},
		{"name": "display/window/size/viewport_width"}
	]
	var values: Dictionary = {
		"autoload/GameState": "*res://autoload/game_state.gd",
		"autoload/Bootstrap": "res://autoload/bootstrap.gd"
	}
	var orders: Dictionary = {
		"autoload/GameState": 40,
		"autoload/Bootstrap": 12
	}
	var autoloads: Array = project_tools._collect_project_autoloads_from_properties(properties, values, orders)
	assert_eq(autoloads.size(), 2, "Should collect two autoload entries")
	assert_eq(autoloads[0].name, "Bootstrap", "Should sort autoloads by project setting order")
	assert_eq(autoloads[0].path, "res://autoload/bootstrap.gd", "Should preserve non-singleton autoload path")
	assert_false(autoloads[0].is_singleton, "Non-prefixed autoload should not be marked singleton")
	assert_eq(autoloads[1].name, "GameState", "Should include singleton autoload name")
	assert_eq(autoloads[1].path, "res://autoload/game_state.gd", "Singleton autoload should strip the * prefix")
	assert_true(autoloads[1].is_singleton, "Prefixed autoload should be marked singleton")

func test_upsert_project_autoload_registers_write_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_upsert_project_autoload(server_core)

	var output_properties: Dictionary = server_core.tools["upsert_project_autoload"]["output_schema"].get("properties", {})
	assert_has(output_properties, "name", "upsert_project_autoload should expose name")
	assert_has(output_properties, "path", "upsert_project_autoload should expose path")
	assert_has(output_properties, "is_singleton", "upsert_project_autoload should expose is_singleton")
	assert_has(output_properties, "setting_name", "upsert_project_autoload should expose setting_name")
	assert_has(output_properties, "existed_before", "upsert_project_autoload should expose existed_before")

func test_upsert_project_autoload_reports_input_and_path_errors():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_upsert_project_autoload({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_upsert_project_autoload({
			"name": "Bad/Name",
			"path": "res://addons/godot_mcp/tools/project_tools_native.gd"
		}).get("error", ""),
		"Invalid autoload name: path separators are not allowed",
		"Autoload names should reject path separators"
	)
	assert_true(
		str(project_tools._tool_upsert_project_autoload({
			"name": "TempAutoload",
			"path": "res://addons/godot_mcp/tools/not_allowed.txt"
		}).get("error", "")).begins_with("Invalid autoload path:"),
		"Unsupported autoload path extensions should be rejected"
	)
	assert_eq(
		project_tools._tool_upsert_project_autoload({
			"name": "TempAutoload",
			"path": "res://.tmp_project_tools_unit/missing_autoload.gd"
		}).get("error", ""),
		"File not found: res://.tmp_project_tools_unit/missing_autoload.gd",
		"Missing autoload target files should be reported truthfully"
	)

func test_upsert_project_autoload_saves_single_entry():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var autoload_name: String = "TempUnitAutoload"
	var autoload_path: String = temp_dir + "/temp_autoload.gd"
	var setting_name: String = "autoload/" + autoload_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))
	var file: FileAccess = FileAccess.open(autoload_path, FileAccess.WRITE)
	file.store_string("extends Node\n")
	file.close()
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.clear(setting_name)
		ProjectSettings.save()

	var result: Dictionary = project_tools._tool_upsert_project_autoload({
		"name": autoload_name,
		"path": autoload_path,
		"is_singleton": true
	})

	assert_eq(result.get("name", ""), autoload_name, "Autoload write should echo name")
	assert_eq(result.get("path", ""), autoload_path, "Autoload write should echo path")
	assert_true(result.get("is_singleton", false), "Autoload write should preserve singleton flag")
	assert_eq(result.get("setting_name", ""), setting_name, "Autoload write should expose setting_name")
	assert_false(result.get("existed_before", true), "Fresh autoload write should report existed_before=false")
	assert_eq(str(ProjectSettings.get_setting(setting_name, "")), "*" + autoload_path, "Autoload should persist with singleton marker")

	ProjectSettings.clear(setting_name)
	ProjectSettings.save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(autoload_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_remove_project_autoload_registers_destructive_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_remove_project_autoload(server_core)

	var output_properties: Dictionary = server_core.tools["remove_project_autoload"]["output_schema"].get("properties", {})
	assert_has(output_properties, "name", "remove_project_autoload should expose name")
	assert_has(output_properties, "setting_name", "remove_project_autoload should expose setting_name")
	assert_has(output_properties, "existed_before", "remove_project_autoload should expose existed_before")
	assert_has(output_properties, "removed", "remove_project_autoload should expose removed")
	assert_has(output_properties, "path", "remove_project_autoload should expose path")
	assert_has(output_properties, "is_singleton", "remove_project_autoload should expose is_singleton")

func test_remove_project_autoload_reports_missing_and_invalid_names():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_remove_project_autoload({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_remove_project_autoload({
			"name": "Bad/Name"
		}).get("error", ""),
		"Invalid autoload name: path separators are not allowed",
		"Autoload removal should reject path separators"
	)

func test_remove_project_autoload_reports_missing_entry_without_error():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var autoload_name: String = "MissingUnitAutoload"
	var setting_name: String = "autoload/" + autoload_name
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.clear(setting_name)
		ProjectSettings.save()

	var result: Dictionary = project_tools._tool_remove_project_autoload({
		"name": autoload_name
	})

	assert_eq(result.get("name", ""), autoload_name, "Missing autoload removal should echo name")
	assert_eq(result.get("setting_name", ""), setting_name, "Missing autoload removal should echo setting_name")
	assert_false(result.get("existed_before", true), "Missing autoload removal should report existed_before=false")
	assert_false(result.get("removed", true), "Missing autoload removal should report removed=false")

func test_remove_project_autoload_clears_existing_entry():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var autoload_name: String = "TempRemoveAutoload"
	var autoload_path: String = "res://addons/godot_mcp/tools/project_tools_native.gd"
	var setting_name: String = "autoload/" + autoload_name
	ProjectSettings.set_setting(setting_name, "*" + autoload_path)
	ProjectSettings.save()

	var result: Dictionary = project_tools._tool_remove_project_autoload({
		"name": autoload_name
	})

	assert_eq(result.get("name", ""), autoload_name, "Autoload removal should echo name")
	assert_eq(result.get("setting_name", ""), setting_name, "Autoload removal should echo setting_name")
	assert_true(result.get("existed_before", false), "Existing autoload removal should report existed_before=true")
	assert_true(result.get("removed", false), "Existing autoload removal should report removed=true")
	assert_eq(result.get("path", ""), autoload_path, "Autoload removal should report previous path")
	assert_true(result.get("is_singleton", false), "Autoload removal should report previous singleton flag")
	assert_false(ProjectSettings.has_setting(setting_name), "Autoload setting should no longer exist after removal")

func test_inspect_project_autoload_registers_single_entry_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_inspect_project_autoload(server_core)

	var output_properties: Dictionary = server_core.tools["inspect_project_autoload"]["output_schema"].get("properties", {})
	assert_has(output_properties, "name", "inspect_project_autoload should expose name")
	assert_has(output_properties, "setting_name", "inspect_project_autoload should expose setting_name")
	assert_has(output_properties, "exists", "inspect_project_autoload should expose exists")
	assert_has(output_properties, "path", "inspect_project_autoload should expose path")
	assert_has(output_properties, "is_singleton", "inspect_project_autoload should expose is_singleton")

func test_inspect_project_autoload_reports_missing_and_invalid_names():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_inspect_project_autoload({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_inspect_project_autoload({
			"name": "Bad/Name"
		}).get("error", ""),
		"Invalid autoload name: path separators are not allowed",
		"Autoload inspection should reject path separators"
	)

func test_inspect_project_autoload_reports_missing_entry_without_error():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var autoload_name: String = "MissingInspectAutoload"
	var setting_name: String = "autoload/" + autoload_name
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.clear(setting_name)
		ProjectSettings.save()

	var result: Dictionary = project_tools._tool_inspect_project_autoload({
		"name": autoload_name
	})

	assert_eq(result.get("name", ""), autoload_name, "Missing autoload inspection should echo name")
	assert_eq(result.get("setting_name", ""), setting_name, "Missing autoload inspection should echo setting_name")
	assert_false(result.get("exists", true), "Missing autoload inspection should report exists=false")

func test_inspect_project_autoload_returns_resolved_entry_truthfully():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var autoload_name: String = "TempInspectAutoload"
	var autoload_path: String = "res://addons/godot_mcp/tools/project_tools_native.gd"
	var setting_name: String = "autoload/" + autoload_name
	ProjectSettings.set_setting(setting_name, "*" + autoload_path)
	ProjectSettings.save()

	var result: Dictionary = project_tools._tool_inspect_project_autoload({
		"name": autoload_name
	})

	assert_eq(result.get("name", ""), autoload_name, "Autoload inspection should echo name")
	assert_eq(result.get("setting_name", ""), setting_name, "Autoload inspection should echo setting_name")
	assert_true(result.get("exists", false), "Autoload inspection should report exists=true for a present entry")
	assert_eq(result.get("path", ""), autoload_path, "Autoload inspection should report resolved path")
	assert_true(result.get("is_singleton", false), "Autoload inspection should report singleton flag")

	ProjectSettings.clear(setting_name)
	ProjectSettings.save()

func test_inspect_project_input_action_registers_single_entry_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_inspect_project_input_action(server_core)

	var output_properties: Dictionary = server_core.tools["inspect_project_input_action"]["output_schema"].get("properties", {})
	assert_has(output_properties, "action_name", "inspect_project_input_action should expose action_name")
	assert_has(output_properties, "exists", "inspect_project_input_action should expose exists")
	assert_has(output_properties, "deadzone", "inspect_project_input_action should expose deadzone")
	assert_has(output_properties, "event_count", "inspect_project_input_action should expose event_count")
	assert_has(output_properties, "events", "inspect_project_input_action should expose events")

func test_inspect_project_input_action_reports_missing_name():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_inspect_project_input_action({}), "error", "Missing parameters should return an error")

func test_inspect_project_input_action_reports_missing_entry_without_error():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	var result: Dictionary = project_tools._tool_inspect_project_input_action({
		"action_name": "missing_unit_project_action"
	})

	assert_eq(result.get("action_name", ""), "missing_unit_project_action", "Missing input action inspection should echo action_name")
	assert_false(result.get("exists", true), "Missing input action inspection should report exists=false")

func test_inspect_project_input_action_returns_serialized_action_truthfully():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var action_name: String = "temp_inspect_project_action"
	var setting_name: String = "input/" + action_name
	ProjectSettings.set_setting(setting_name, {
		"deadzone": 0.4,
		"events": [InputEventKey.new()]
	})
	var key_event: InputEventKey = (ProjectSettings.get_setting(setting_name) as Dictionary).get("events", [])[0]
	key_event.keycode = KEY_A
	key_event.pressed = true
	ProjectSettings.set_setting(setting_name, {
		"deadzone": 0.4,
		"events": [key_event]
	})
	ProjectSettings.save()
	InputMap.load_from_project_settings()

	var result: Dictionary = project_tools._tool_inspect_project_input_action({
		"action_name": action_name
	})

	assert_eq(result.get("action_name", ""), action_name, "Input action inspection should echo action_name")
	assert_true(result.get("exists", false), "Input action inspection should report exists=true for a present action")
	assert_eq(float(result.get("deadzone", 0.0)), 0.4, "Input action inspection should report deadzone")
	assert_eq(result.get("event_count", -1), 1, "Input action inspection should report event count")
	assert_eq(result.get("events", []).size(), 1, "Input action inspection should return serialized events")
	assert_eq(result.get("events", [])[0].get("type", ""), "key", "Input action inspection should serialize input events")

	ProjectSettings.clear(setting_name)
	ProjectSettings.save()
	InputMap.load_from_project_settings()

func test_inspect_project_global_class_registers_single_entry_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_inspect_project_global_class(server_core)

	var output_properties: Dictionary = server_core.tools["inspect_project_global_class"]["output_schema"].get("properties", {})
	assert_has(output_properties, "class_name", "inspect_project_global_class should expose class_name")
	assert_has(output_properties, "exists", "inspect_project_global_class should expose exists")
	assert_has(output_properties, "path", "inspect_project_global_class should expose path")
	assert_has(output_properties, "base", "inspect_project_global_class should expose base")
	assert_has(output_properties, "language", "inspect_project_global_class should expose language")

func test_inspect_project_global_class_reports_missing_name():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_inspect_project_global_class({}), "error", "Missing parameters should return an error")

func test_inspect_project_global_class_reports_missing_entry_without_error():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	var result: Dictionary = project_tools._tool_inspect_project_global_class({
		"class_name": "DefinitelyMissingGlobalClass123"
	})

	assert_eq(result.get("class_name", ""), "DefinitelyMissingGlobalClass123", "Missing global class inspection should echo class_name")
	assert_false(result.get("exists", true), "Missing global class inspection should report exists=false")

func test_inspect_project_global_class_returns_normalized_entry_truthfully():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	var result: Dictionary = project_tools._tool_inspect_project_global_class({
		"class_name": "ProjectToolsNative"
	})

	assert_eq(result.get("class_name", ""), "ProjectToolsNative", "Global class inspection should echo class_name")
	assert_true(result.get("exists", false), "Global class inspection should report exists=true for a present class")
	assert_eq(result.get("path", ""), "res://addons/godot_mcp/tools/project_tools_native.gd", "Global class inspection should report script path")
	assert_eq(result.get("base", ""), "RefCounted", "Global class inspection should report base type")
	assert_eq(result.get("language", ""), "GDScript", "Global class inspection should report language")

func test_inspect_project_test_registers_single_entry_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_inspect_project_test(server_core)

	var output_properties: Dictionary = server_core.tools["inspect_project_test"]["output_schema"].get("properties", {})
	assert_has(output_properties, "test_path", "inspect_project_test should expose test_path")
	assert_has(output_properties, "exists", "inspect_project_test should expose exists")
	assert_has(output_properties, "framework", "inspect_project_test should expose framework")
	assert_has(output_properties, "kind", "inspect_project_test should expose kind")
	assert_has(output_properties, "runnable", "inspect_project_test should expose runnable")

func test_list_project_test_runners_registers_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_list_project_test_runners(server_core)

	var output_properties: Dictionary = server_core.tools["list_project_test_runners"]["output_schema"].get("properties", {})
	assert_has(output_properties, "count", "list_project_test_runners should expose count")
	assert_has(output_properties, "runners", "list_project_test_runners should expose runners")

func test_list_project_test_runners_reports_supported_frameworks_truthfully():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	var result: Dictionary = project_tools._tool_list_project_test_runners({})
	var runners: Array = result.get("runners", [])
	assert_eq(result.get("count", -1), runners.size(), "Runner availability should echo runner count")

	var by_framework: Dictionary = {}
	for entry_variant in runners:
		var entry: Dictionary = entry_variant
		by_framework[String(entry.get("framework", ""))] = entry

	assert_true(by_framework.has("python"), "Runner availability should report python")
	assert_true(by_framework.has("gut"), "Runner availability should report gut")
	assert_has(by_framework["python"], "available", "Python runner entry should expose availability truth")
	assert_has(by_framework["python"], "probe_exit_code", "Python runner entry should expose probe exit code")
	assert_eq(Array(by_framework["python"].get("command", []))[0], "python", "Python runner entry should expose python probe command")
	assert_eq(by_framework["gut"].get("runner_path", ""), "res://addons/gut/gut_cmdln.gd", "GUT runner entry should expose gut runner path")
	assert_eq(bool(by_framework["gut"].get("available", false)), FileAccess.file_exists("res://addons/gut/gut_cmdln.gd"), "GUT runner availability should mirror gut_cmdln presence")

func test_inspect_project_test_reports_missing_path():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_inspect_project_test({}), "error", "Missing parameters should return an error")

func test_inspect_project_test_reports_missing_entry_without_error():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	var result: Dictionary = project_tools._tool_inspect_project_test({
		"test_path": "res://test/integration/does_not_exist_temp_test.py"
	})

	assert_eq(result.get("test_path", ""), "res://test/integration/does_not_exist_temp_test.py", "Missing test inspection should echo test_path")
	assert_false(result.get("exists", true), "Missing test inspection should report exists=false")

func test_inspect_project_test_returns_normalized_entry_truthfully():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var runner_availability: Dictionary = project_tools._get_project_test_runner_availability_map()

	var result: Dictionary = project_tools._tool_inspect_project_test({
		"test_path": "res://test/integration/test_project_test_runner_flow.py"
	})

	assert_eq(result.get("test_path", ""), "res://test/integration/test_project_test_runner_flow.py", "Test inspection should echo sanitized path")
	assert_true(result.get("exists", false), "Existing test inspection should report exists=true")
	assert_eq(result.get("framework", ""), "python", "Python test inspection should report python framework")
	assert_eq(result.get("kind", ""), "integration", "Python test inspection should report integration kind")
	assert_eq(bool(result.get("runnable", false)), bool(runner_availability.get("python", {}).get("available", false)), "Python test inspection should mirror shared runner availability truth")
	assert_eq(bool(result.get("available_runner", false)), bool(runner_availability.get("python", {}).get("available", false)), "Python test inspection should expose shared runner availability truth")
	assert_eq(result.get("name", ""), "test_project_test_runner_flow.py", "Test inspection should expose the file name")

func test_build_project_test_entry_uses_shared_runner_availability_truth():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var forced_availability: Dictionary = {
		"python": {"available": false},
		"gut": {"available": true}
	}

	var python_entry: Dictionary = project_tools._build_project_test_entry("res://test/integration/test_project_test_runner_flow.py", forced_availability)
	assert_false(python_entry.get("runnable", true), "Python test entries should respect shared runner availability")
	assert_false(python_entry.get("available_runner", true), "Python test entries should expose forced unavailable runner truth")

	var gut_entry: Dictionary = project_tools._build_project_test_entry("res://test/unit/test_mcp_tool_classifier.gd", forced_availability)
	assert_true(gut_entry.get("runnable", false), "GUT test entries should respect shared runner availability")
	assert_true(gut_entry.get("available_runner", false), "GUT test entries should expose forced available runner truth")

func test_set_project_plugin_enabled_registers_write_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_set_project_plugin_enabled(server_core)

	var output_properties: Dictionary = server_core.tools["set_project_plugin_enabled"]["output_schema"].get("properties", {})
	assert_has(output_properties, "plugin_path", "set_project_plugin_enabled should expose plugin_path")
	assert_has(output_properties, "plugin_name", "set_project_plugin_enabled should expose plugin_name")
	assert_has(output_properties, "enabled_requested", "set_project_plugin_enabled should expose enabled_requested")
	assert_has(output_properties, "enabled", "set_project_plugin_enabled should expose enabled")
	assert_has(output_properties, "existed_before", "set_project_plugin_enabled should expose existed_before")

func test_set_project_plugin_enabled_reports_missing_invalid_and_unavailable_editor_interface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	assert_has(project_tools._tool_set_project_plugin_enabled({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_set_project_plugin_enabled({
			"plugin_path": "res://addons/gut/not-plugin.txt",
			"enabled": true
		}).get("error", ""),
		"Invalid plugin_path: expected a res://addons/.../plugin.cfg path",
		"Plugin enablement should reject non-plugin.cfg paths"
	)
	assert_eq(
		project_tools._tool_set_project_plugin_enabled({
			"plugin_path": "res://addons/missing_fixture/plugin.cfg",
			"enabled": true
		}).get("error", ""),
		"Plugin not found: res://addons/missing_fixture/plugin.cfg",
		"Missing plugin paths should be reported truthfully"
	)
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	assert_eq(
		project_tools._tool_set_project_plugin_enabled({
			"plugin_path": "res://addons/gut/plugin.cfg",
			"enabled": true
		}).get("error", ""),
		"Editor interface not available",
		"Plugin enablement should fail cleanly when editor interface is unavailable"
	)
	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)

func test_set_project_plugin_enabled_toggles_single_plugin_state():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var editor_interface := FakePluginEditorInterface.new()
	var fake_plugin := FakeGodotMCPPlugin.new(editor_interface)
	var plugin_path: String = "res://addons/gut/plugin.cfg"
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	Engine.set_meta("GodotMCPPlugin", fake_plugin)
	editor_interface.enabled_by_name["gut"] = false

	var enable_result: Dictionary = project_tools._tool_set_project_plugin_enabled({
		"plugin_path": plugin_path,
		"enabled": true
	})
	assert_eq(enable_result.get("plugin_path", ""), plugin_path, "Plugin enablement should echo plugin_path")
	assert_eq(enable_result.get("plugin_name", ""), "gut", "Plugin enablement should derive directory-name plugin_name")
	assert_true(enable_result.get("enabled_requested", false), "Plugin enablement should echo enabled_requested=true")
	assert_true(enable_result.get("enabled", false), "Plugin enablement should report resulting enabled=true")
	assert_false(enable_result.get("existed_before", true), "Plugin enablement should report existed_before=false for disabled plugin")
	assert_true(editor_interface.is_plugin_enabled("gut"), "Fake editor interface should now report plugin enabled")

	var disable_result: Dictionary = project_tools._tool_set_project_plugin_enabled({
		"plugin_path": plugin_path,
		"enabled": false
	})
	assert_false(disable_result.get("enabled_requested", true), "Plugin disable should echo enabled_requested=false")
	assert_false(disable_result.get("enabled", true), "Plugin disable should report resulting enabled=false")
	assert_true(disable_result.get("existed_before", false), "Plugin disable should report existed_before=true for enabled plugin")
	assert_false(editor_interface.is_plugin_enabled("gut"), "Fake editor interface should now report plugin disabled")

	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)
	else:
		Engine.remove_meta("GodotMCPPlugin")

func test_set_project_feature_profile_registers_write_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_set_project_feature_profile(server_core)

	var output_properties: Dictionary = server_core.tools["set_project_feature_profile"]["output_schema"].get("properties", {})
	assert_has(output_properties, "profile_name_requested", "set_project_feature_profile should expose profile_name_requested")
	assert_has(output_properties, "previous_profile", "set_project_feature_profile should expose previous_profile")
	assert_has(output_properties, "current_profile", "set_project_feature_profile should expose current_profile")
	assert_has(output_properties, "used_default", "set_project_feature_profile should expose used_default")
	assert_has(output_properties, "profile_path", "set_project_feature_profile should expose profile_path")

func test_set_project_feature_profile_reports_missing_invalid_and_unavailable_cases():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	var temp_config_dir: String = ProjectSettings.globalize_path("res://.tmp_project_tools_unit/feature_profile_config_missing")
	if DirAccess.dir_exists_absolute(temp_config_dir):
		DirAccess.remove_absolute(temp_config_dir)

	assert_has(project_tools._tool_set_project_feature_profile({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_set_project_feature_profile({
			"profile_name": "Bad/Profile"
		}).get("error", ""),
		"Invalid profile_name: path separators are not allowed",
		"Feature profile activation should reject path separators"
	)
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	assert_eq(
		project_tools._tool_set_project_feature_profile({
			"profile_name": "SomeProfile"
		}).get("error", ""),
		"Editor interface not available",
		"Feature profile activation should fail cleanly when editor interface is unavailable"
	)
	var fake_editor := FakeFeatureProfileEditorInterface.new(temp_config_dir)
	var fake_plugin := FakeGodotMCPPlugin.new(fake_editor)
	Engine.set_meta("GodotMCPPlugin", fake_plugin)
	assert_eq(
		project_tools._tool_set_project_feature_profile({
			"profile_name": "MissingProfile"
		}).get("error", ""),
		"Feature profile not found: MissingProfile",
		"Missing feature profiles should be reported truthfully"
	)
	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)
	else:
		Engine.remove_meta("GodotMCPPlugin")

func test_set_project_feature_profile_activates_existing_profile_and_resets_default():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_config_res: String = "res://.tmp_project_tools_unit/feature_profile_config"
	var temp_config_dir: String = ProjectSettings.globalize_path(temp_config_res)
	var feature_profiles_dir: String = temp_config_dir.path_join("feature_profiles")
	var profile_name: String = "MCPTempFeatureProfile"
	var profile_path: String = feature_profiles_dir.path_join(profile_name + ".profile")
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	DirAccess.make_dir_recursive_absolute(feature_profiles_dir)
	var profile_file: FileAccess = FileAccess.open(profile_path, FileAccess.WRITE)
	profile_file.store_string("{\"disabled_classes\":[],\"disabled_editors\":[],\"disabled_properties\":{},\"disabled_features\":[]}")
	profile_file.close()

	var fake_editor := FakeFeatureProfileEditorInterface.new(temp_config_dir)
	var fake_plugin := FakeGodotMCPPlugin.new(fake_editor)
	Engine.set_meta("GodotMCPPlugin", fake_plugin)

	var activate_result: Dictionary = project_tools._tool_set_project_feature_profile({
		"profile_name": profile_name
	})
	assert_eq(activate_result.get("profile_name_requested", ""), profile_name, "Feature profile activation should echo requested profile name")
	assert_eq(activate_result.get("previous_profile", ""), "", "Fresh activation should report empty previous profile")
	assert_eq(activate_result.get("current_profile", ""), profile_name, "Feature profile activation should report the current active profile")
	assert_false(activate_result.get("used_default", true), "Explicit profile activation should report used_default=false")
	assert_eq(activate_result.get("profile_path", ""), profile_path, "Feature profile activation should expose resolved profile path")
	assert_eq(fake_editor.get_current_feature_profile(), profile_name, "Fake editor interface should now report the activated profile")

	var reset_result: Dictionary = project_tools._tool_set_project_feature_profile({
		"profile_name": ""
	})
	assert_eq(reset_result.get("profile_name_requested", "sentinel"), "", "Default reset should echo empty requested profile")
	assert_eq(reset_result.get("previous_profile", ""), profile_name, "Default reset should report the previous active profile")
	assert_eq(reset_result.get("current_profile", "sentinel"), "", "Default reset should report an empty current profile")
	assert_true(reset_result.get("used_default", false), "Default reset should report used_default=true")
	assert_eq(fake_editor.get_current_feature_profile(), "", "Fake editor interface should now report the default profile")

	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)
	else:
		Engine.remove_meta("GodotMCPPlugin")
	DirAccess.remove_absolute(profile_path)
	DirAccess.remove_absolute(feature_profiles_dir)
	DirAccess.remove_absolute(temp_config_dir)

func test_list_project_feature_profiles_registers_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_list_project_feature_profiles(server_core)

	var output_properties: Dictionary = server_core.tools["list_project_feature_profiles"]["output_schema"].get("properties", {})
	assert_has(output_properties, "profiles", "list_project_feature_profiles should expose profiles")
	assert_has(output_properties, "count", "list_project_feature_profiles should expose count")
	assert_has(output_properties, "current_profile", "list_project_feature_profiles should expose current_profile")

func test_list_project_feature_profiles_reports_unavailable_editor_interface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	assert_eq(
		project_tools._tool_list_project_feature_profiles({}).get("error", ""),
		"Editor interface not available",
		"Feature profile listing should fail cleanly when editor interface is unavailable"
	)
	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)

func test_list_project_feature_profiles_enumerates_current_profile_truthfully():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_config_res: String = "res://.tmp_project_tools_unit/feature_profile_listing_config"
	var temp_config_dir: String = ProjectSettings.globalize_path(temp_config_res)
	var feature_profiles_dir: String = temp_config_dir.path_join("feature_profiles")
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	DirAccess.make_dir_recursive_absolute(feature_profiles_dir)
	var profile_paths: Array[String] = [
		feature_profiles_dir.path_join("Artist.profile"),
		feature_profiles_dir.path_join("Designer.profile")
	]
	for profile_path in profile_paths:
		var file: FileAccess = FileAccess.open(profile_path, FileAccess.WRITE)
		file.store_string("{\"disabled_classes\":[],\"disabled_editors\":[],\"disabled_properties\":{},\"disabled_features\":[]}")
		file.close()

	var fake_editor := FakeFeatureProfileEditorInterface.new(temp_config_dir)
	fake_editor.current_profile = "Designer"
	var fake_plugin := FakeGodotMCPPlugin.new(fake_editor)
	Engine.set_meta("GodotMCPPlugin", fake_plugin)

	var result: Dictionary = project_tools._tool_list_project_feature_profiles({})
	assert_eq(result.get("count", -1), 2, "Feature profile listing should report both available profiles")
	assert_eq(result.get("current_profile", ""), "Designer", "Feature profile listing should report current active profile")
	var profiles: Array = result.get("profiles", [])
	assert_eq(profiles[0].get("name", ""), "Artist", "Feature profiles should be sorted by name")
	assert_false(profiles[0].get("is_current", true), "Non-active profile should report is_current=false")
	assert_eq(profiles[1].get("name", ""), "Designer", "Feature profile listing should include the active profile")
	assert_true(profiles[1].get("is_current", false), "Active profile should report is_current=true")

	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)
	else:
		Engine.remove_meta("GodotMCPPlugin")
	for profile_path in profile_paths:
		DirAccess.remove_absolute(profile_path)
	DirAccess.remove_absolute(feature_profiles_dir)
	DirAccess.remove_absolute(temp_config_dir)

func test_inspect_project_feature_profile_registers_single_entry_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_inspect_project_feature_profile(server_core)

	var output_properties: Dictionary = server_core.tools["inspect_project_feature_profile"]["output_schema"].get("properties", {})
	assert_has(output_properties, "profile_name", "inspect_project_feature_profile should expose profile_name")
	assert_has(output_properties, "profile_path", "inspect_project_feature_profile should expose profile_path")
	assert_has(output_properties, "exists", "inspect_project_feature_profile should expose exists")
	assert_has(output_properties, "is_current", "inspect_project_feature_profile should expose is_current")

func test_inspect_project_feature_profile_reports_missing_invalid_and_unavailable_cases():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	assert_has(project_tools._tool_inspect_project_feature_profile({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_inspect_project_feature_profile({
			"profile_name": "Bad/Profile"
		}).get("error", ""),
		"Invalid profile_name: path separators are not allowed",
		"Feature profile inspection should reject path separators"
	)
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	assert_eq(
		project_tools._tool_inspect_project_feature_profile({
			"profile_name": "SomeProfile"
		}).get("error", ""),
		"Editor interface not available",
		"Feature profile inspection should fail cleanly when editor interface is unavailable"
	)
	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)

func test_inspect_project_feature_profile_reports_missing_entry_without_error():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_config_res: String = "res://.tmp_project_tools_unit/feature_profile_inspect_missing"
	var temp_config_dir: String = ProjectSettings.globalize_path(temp_config_res)
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	var fake_editor := FakeFeatureProfileEditorInterface.new(temp_config_dir)
	var fake_plugin := FakeGodotMCPPlugin.new(fake_editor)
	Engine.set_meta("GodotMCPPlugin", fake_plugin)

	var result: Dictionary = project_tools._tool_inspect_project_feature_profile({
		"profile_name": "MissingProfile"
	})
	assert_eq(result.get("profile_name", ""), "MissingProfile", "Missing feature profile inspection should echo profile_name")
	assert_false(result.get("exists", true), "Missing feature profile inspection should report exists=false")

	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)
	else:
		Engine.remove_meta("GodotMCPPlugin")

func test_inspect_project_feature_profile_reports_path_and_current_truthfully():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_config_res: String = "res://.tmp_project_tools_unit/feature_profile_inspect"
	var temp_config_dir: String = ProjectSettings.globalize_path(temp_config_res)
	var feature_profiles_dir: String = temp_config_dir.path_join("feature_profiles")
	var profile_name: String = "Designer"
	var profile_path: String = feature_profiles_dir.path_join(profile_name + ".profile")
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	DirAccess.make_dir_recursive_absolute(feature_profiles_dir)
	var profile_file: FileAccess = FileAccess.open(profile_path, FileAccess.WRITE)
	profile_file.store_string("{\"disabled_classes\":[],\"disabled_editors\":[],\"disabled_properties\":{},\"disabled_features\":[]}")
	profile_file.close()

	var fake_editor := FakeFeatureProfileEditorInterface.new(temp_config_dir)
	fake_editor.current_profile = profile_name
	var fake_plugin := FakeGodotMCPPlugin.new(fake_editor)
	Engine.set_meta("GodotMCPPlugin", fake_plugin)

	var result: Dictionary = project_tools._tool_inspect_project_feature_profile({
		"profile_name": profile_name
	})
	assert_eq(result.get("profile_name", ""), profile_name, "Feature profile inspection should echo profile_name")
	assert_eq(result.get("profile_path", ""), profile_path, "Feature profile inspection should report resolved profile path")
	assert_true(result.get("exists", false), "Feature profile inspection should report exists=true for a present profile")
	assert_true(result.get("is_current", false), "Feature profile inspection should report active marker truthfully")

	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)
	else:
		Engine.remove_meta("GodotMCPPlugin")
	DirAccess.remove_absolute(profile_path)
	DirAccess.remove_absolute(feature_profiles_dir)
	DirAccess.remove_absolute(temp_config_dir)

func test_list_project_plugins_registers_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_list_project_plugins(server_core)

	var output_properties: Dictionary = server_core.tools["list_project_plugins"]["output_schema"].get("properties", {})
	assert_has(output_properties, "plugins", "list_project_plugins should expose plugins")
	assert_has(output_properties, "count", "list_project_plugins should expose count")

func test_list_project_plugins_reports_unavailable_editor_interface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	assert_eq(
		project_tools._tool_list_project_plugins({}).get("error", ""),
		"Editor interface not available",
		"Project plugin listing should fail cleanly when editor interface is unavailable"
	)
	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)

func test_list_project_plugins_enumerates_enabled_state_truthfully():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var editor_interface := FakePluginEditorInterface.new()
	var fake_plugin := FakeGodotMCPPlugin.new(editor_interface)
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	editor_interface.enabled_by_name["godot_mcp"] = true
	editor_interface.enabled_by_name["gut"] = false
	Engine.set_meta("GodotMCPPlugin", fake_plugin)

	var result: Dictionary = project_tools._tool_list_project_plugins({})
	assert_true(int(result.get("count", 0)) >= 2, "Project plugin listing should discover the installed plugins in addons/")
	var plugins: Array = result.get("plugins", [])
	var godot_mcp_entry: Dictionary = {}
	var gut_entry: Dictionary = {}
	for entry in plugins:
		if entry.get("name", "") == "godot_mcp":
			godot_mcp_entry = entry
		elif entry.get("name", "") == "gut":
			gut_entry = entry
	assert_false(godot_mcp_entry.is_empty(), "Project plugin listing should include godot_mcp")
	assert_false(gut_entry.is_empty(), "Project plugin listing should include gut")
	assert_eq(godot_mcp_entry.get("plugin_path", ""), "res://addons/godot_mcp/plugin.cfg", "Project plugin listing should expose godot_mcp plugin path")
	assert_true(godot_mcp_entry.get("enabled", false), "Project plugin listing should report enabled state from the editor interface")
	assert_eq(gut_entry.get("plugin_path", ""), "res://addons/gut/plugin.cfg", "Project plugin listing should expose gut plugin path")
	assert_false(gut_entry.get("enabled", true), "Project plugin listing should report disabled plugin state from the editor interface")

	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)
	else:
		Engine.remove_meta("GodotMCPPlugin")

func test_inspect_project_plugin_registers_single_plugin_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_inspect_project_plugin(server_core)

	var output_properties: Dictionary = server_core.tools["inspect_project_plugin"]["output_schema"].get("properties", {})
	assert_has(output_properties, "plugin_path", "inspect_project_plugin should expose plugin_path")
	assert_has(output_properties, "plugin_name", "inspect_project_plugin should expose plugin_name")
	assert_has(output_properties, "display_name", "inspect_project_plugin should expose display_name")
	assert_has(output_properties, "description", "inspect_project_plugin should expose description")
	assert_has(output_properties, "author", "inspect_project_plugin should expose author")
	assert_has(output_properties, "version", "inspect_project_plugin should expose version")
	assert_has(output_properties, "script", "inspect_project_plugin should expose script")
	assert_has(output_properties, "enabled", "inspect_project_plugin should expose enabled")

func test_inspect_project_plugin_reports_missing_invalid_and_unavailable_editor_interface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	assert_has(project_tools._tool_inspect_project_plugin({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_inspect_project_plugin({
			"plugin_path": "res://addons/gut/not_plugin.txt"
		}).get("error", ""),
		"Invalid plugin_path: expected a res://addons/.../plugin.cfg path",
		"Plugin inspection should reject non-plugin.cfg paths"
	)
	assert_eq(
		project_tools._tool_inspect_project_plugin({
			"plugin_path": "res://addons/missing_fixture/plugin.cfg"
		}).get("error", ""),
		"Plugin not found: res://addons/missing_fixture/plugin.cfg",
		"Missing plugin paths should be reported truthfully"
	)

	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	assert_eq(
		project_tools._tool_inspect_project_plugin({
			"plugin_path": "res://addons/gut/plugin.cfg"
		}).get("error", ""),
		"Editor interface not available",
		"Plugin inspection should fail cleanly when editor interface is unavailable"
	)
	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)

func test_inspect_project_plugin_reads_plugin_cfg_metadata_and_live_enabled_state():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var editor_interface := FakePluginEditorInterface.new()
	var fake_plugin := FakeGodotMCPPlugin.new(editor_interface)
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	editor_interface.enabled_by_name["gut"] = true
	Engine.set_meta("GodotMCPPlugin", fake_plugin)

	var result: Dictionary = project_tools._tool_inspect_project_plugin({
		"plugin_path": "res://addons/gut/plugin.cfg"
	})
	assert_eq(result.get("plugin_path", ""), "res://addons/gut/plugin.cfg", "Plugin inspection should echo plugin_path")
	assert_eq(result.get("plugin_name", ""), "gut", "Plugin inspection should derive directory-name plugin_name")
	assert_eq(result.get("display_name", ""), "Gut", "Plugin inspection should read plugin display name from plugin.cfg")
	assert_eq(result.get("description", ""), "Unit Testing tool for Godot.", "Plugin inspection should read description from plugin.cfg")
	assert_eq(result.get("author", ""), "Butch Wesley", "Plugin inspection should read author from plugin.cfg")
	assert_eq(result.get("version", ""), "9.6.0", "Plugin inspection should read version from plugin.cfg")
	assert_eq(result.get("script", ""), "gut_plugin.gd", "Plugin inspection should read script from plugin.cfg")
	assert_true(result.get("enabled", false), "Plugin inspection should report live enabled state from the editor interface")

	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)
	else:
		Engine.remove_meta("GodotMCPPlugin")

func test_get_project_configuration_summary_registers_bounded_read_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_get_project_configuration_summary(server_core)

	var output_properties: Dictionary = server_core.tools["get_project_configuration_summary"]["output_schema"].get("properties", {})
	assert_has(output_properties, "max_items_applied", "Project configuration summary should expose max_items_applied")
	assert_has(output_properties, "plugin_count", "Project configuration summary should expose plugin_count")
	assert_has(output_properties, "enabled_plugin_count", "Project configuration summary should expose enabled_plugin_count")
	assert_has(output_properties, "plugins", "Project configuration summary should expose plugins")
	assert_has(output_properties, "plugins_truncated", "Project configuration summary should expose plugins_truncated")
	assert_has(output_properties, "autoload_count", "Project configuration summary should expose autoload_count")
	assert_has(output_properties, "autoloads", "Project configuration summary should expose autoloads")
	assert_has(output_properties, "autoloads_truncated", "Project configuration summary should expose autoloads_truncated")
	assert_has(output_properties, "feature_profile_count", "Project configuration summary should expose feature_profile_count")
	assert_has(output_properties, "current_feature_profile", "Project configuration summary should expose current_feature_profile")
	assert_has(output_properties, "feature_profiles", "Project configuration summary should expose feature_profiles")
	assert_has(output_properties, "feature_profiles_truncated", "Project configuration summary should expose feature_profiles_truncated")

func test_get_project_configuration_summary_reports_invalid_and_unavailable_editor_interface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null

	assert_eq(
		project_tools._tool_get_project_configuration_summary({
			"max_items": 0
		}).get("error", ""),
		"Invalid max_items: expected integer >= 1",
		"Project configuration summary should reject non-positive max_items"
	)

	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	assert_eq(
		project_tools._tool_get_project_configuration_summary({}).get("error", ""),
		"Editor interface not available",
		"Project configuration summary should fail cleanly when editor interface is unavailable"
	)

	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)

func test_get_project_configuration_summary_returns_bounded_truthful_current_state():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var previous_plugin = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	var temp_config_res: String = "res://.tmp_project_tools_unit/project_summary_profiles"
	var temp_config_dir: String = ProjectSettings.globalize_path(temp_config_res)
	var feature_profiles_dir: String = temp_config_dir.path_join("feature_profiles")
	DirAccess.make_dir_recursive_absolute(feature_profiles_dir)
	var profile_paths := [
		feature_profiles_dir.path_join("Artist.profile"),
		feature_profiles_dir.path_join("Designer.profile")
	]
	for profile_path in profile_paths:
		var file: FileAccess = FileAccess.open(profile_path, FileAccess.WRITE)
		if file != null:
			file.store_string("{}")
			file.close()

	var setting_names := [
		"autoload/UnitSummaryBootstrap",
		"autoload/UnitSummaryGameState"
	]
	ProjectSettings.set_setting(setting_names[0], "res://addons/gut/gut.gd")
	ProjectSettings.set_setting(setting_names[1], "*res://addons/godot_mcp/tools/project_tools_native.gd")

	var fake_editor := FakeFeatureProfileEditorInterface.new(temp_config_dir)
	fake_editor.current_profile = "Designer"
	fake_editor.enabled_by_name["godot_mcp"] = true
	fake_editor.enabled_by_name["gut"] = false
	var fake_plugin := FakeGodotMCPPlugin.new(fake_editor)
	Engine.set_meta("GodotMCPPlugin", fake_plugin)

	var result: Dictionary = project_tools._tool_get_project_configuration_summary({
		"max_items": 1
	})
	assert_eq(result.get("max_items_applied", -1), 1, "Project configuration summary should echo bounded max_items")
	assert_true(int(result.get("plugin_count", 0)) >= 2, "Project configuration summary should report installed plugin count")
	assert_eq(result.get("enabled_plugin_count", -1), 1, "Project configuration summary should count enabled plugins from the editor interface")
	assert_eq(result.get("plugins", []).size(), 1, "Project configuration summary should bound plugin entries")
	assert_true(result.get("plugins_truncated", false), "Project configuration summary should mark bounded plugin entries as truncated")
	assert_true(int(result.get("autoload_count", 0)) >= 2, "Project configuration summary should count autoload entries")
	assert_eq(result.get("autoloads", []).size(), 1, "Project configuration summary should bound autoload entries")
	assert_true(result.get("autoloads_truncated", false), "Project configuration summary should mark bounded autoload entries as truncated")
	assert_eq(result.get("current_feature_profile", ""), "Designer", "Project configuration summary should report the active feature profile")
	assert_eq(result.get("feature_profile_count", -1), 2, "Project configuration summary should count available feature profiles")
	assert_eq(result.get("feature_profiles", []).size(), 1, "Project configuration summary should bound feature profile entries")
	assert_true(result.get("feature_profiles_truncated", false), "Project configuration summary should mark bounded profile entries as truncated")

	if previous_plugin != null:
		Engine.set_meta("GodotMCPPlugin", previous_plugin)
	else:
		Engine.remove_meta("GodotMCPPlugin")
	for setting_name in setting_names:
		if ProjectSettings.has_setting(setting_name):
			ProjectSettings.clear(setting_name)
	for profile_path in profile_paths:
		DirAccess.remove_absolute(profile_path)
	DirAccess.remove_absolute(feature_profiles_dir)
	DirAccess.remove_absolute(temp_config_dir)

func test_normalize_global_class_entries_preserves_metadata():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var classes: Array = [
		{
			"class": "MyRuntimeNode",
			"path": "res://scripts/my_runtime_node.gd",
			"base": "Node",
			"language": "GDScript",
			"is_tool": false,
			"is_abstract": false,
			"icon": ""
		}
	]
	var normalized: Array = project_tools._normalize_global_class_entries(classes)
	assert_eq(normalized.size(), 1, "Should normalize one global class entry")
	assert_eq(normalized[0].name, "MyRuntimeNode", "Should expose class name as name")
	assert_eq(normalized[0].path, "res://scripts/my_runtime_node.gd", "Should preserve script path")
	assert_eq(normalized[0].base, "Node", "Should preserve base type")
	assert_eq(normalized[0].language, "GDScript", "Should preserve language")
	assert_false(normalized[0].is_tool, "Should preserve tool flag")

func test_get_class_api_metadata_returns_classdb_metadata():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._tool_get_class_api_metadata({
		"class_name": "Node",
		"filter": "process"
	})
	assert_eq(result.source, "classdb", "Engine classes should be sourced from ClassDB")
	assert_eq(result.class_name, "Node", "Should report requested class name")
	assert_eq(result.base_class, "Object", "Should report Node base class")
	assert_gt(result.methods.size(), 0, "Filtered ClassDB methods should be returned")
	assert_gt(result.properties.size(), 0, "Filtered ClassDB properties should be returned")
	assert_true(result.signals.is_empty(), "Process filter should exclude unrelated signals")
	for method in result.methods:
		assert_true(str(method.get("name", "")).to_lower().contains("process"), "Filtered methods should match filter text")

func test_get_class_api_metadata_returns_global_class_metadata_with_base_api():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._tool_get_class_api_metadata({
		"class_name": "ProjectToolsNative",
		"include_base_api": true
	})
	var has_initialize: bool = false
	for method in result.methods:
		if method.get("name", "") == "initialize":
			has_initialize = true
			break
	assert_eq(result.source, "global_class", "Project class should be sourced from global_class metadata")
	assert_eq(result.class_name, "ProjectToolsNative", "Should report requested global class name")
	assert_eq(result.script_path, "res://addons/godot_mcp/tools/project_tools_native.gd", "Should preserve global class script path")
	assert_eq(result.base_class, "RefCounted", "Should preserve global class base type")
	assert_gt(result.methods.size(), 0, "Global class script methods should be returned")
	assert_true(has_initialize, "Should include script-defined methods")
	assert_true(result.has("base_api"), "Should include base API metadata when requested")
	assert_eq(result.base_api.get("class_name", ""), "RefCounted", "Base API should be resolved from ClassDB")

func test_get_class_api_metadata_reports_missing_class():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._tool_get_class_api_metadata({"class_name": "DefinitelyMissingClass123"})
	assert_has(result, "error", "Missing classes should return an error payload")

func test_project_diagnostics_tools_register_rerun_continuation_metadata():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_scan_missing_resource_dependencies(server_core)
	project_tools._register_scan_cyclic_resource_dependencies(server_core)
	project_tools._register_detect_broken_scripts(server_core)
	project_tools._register_audit_project_health(server_core)

	for tool_name in [
		"scan_missing_resource_dependencies",
		"scan_cyclic_resource_dependencies",
		"detect_broken_scripts",
		"audit_project_health"
	]:
		var properties: Dictionary = server_core.tools[tool_name]["output_schema"].get("properties", {})
		assert_has(properties, "truncated", "%s should expose truncated in output schema" % tool_name)
		assert_has(properties, "has_more", "%s should expose has_more in output schema" % tool_name)
		assert_has(properties, "max_results_applied", "%s should expose max_results_applied in output schema" % tool_name)
		assert_has(properties, "next_max_results", "%s should expose next_max_results in output schema" % tool_name)

func test_list_project_resources_registers_optional_detail_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_list_project_resources(server_core)

	var output_properties: Dictionary = server_core.tools["list_project_resources"]["output_schema"].get("properties", {})
	assert_has(output_properties, "details_included", "list_project_resources should expose details_included")
	assert_has(output_properties, "include_property_values", "list_project_resources should expose include_property_values")
	assert_has(output_properties, "property_filter_applied", "list_project_resources should expose property_filter_applied")
	assert_has(output_properties, "max_properties_applied", "list_project_resources should expose max_properties_applied")
	assert_has(output_properties, "resource_details", "list_project_resources should expose resource_details")

func test_inspect_project_resource_registers_bounded_detail_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_inspect_project_resource(server_core)

	var output_properties: Dictionary = server_core.tools["inspect_project_resource"]["output_schema"].get("properties", {})
	assert_has(output_properties, "resource_path", "inspect_project_resource should expose resource_path")
	assert_has(output_properties, "property_filter_applied", "inspect_project_resource should expose property_filter_applied")
	assert_has(output_properties, "include_property_values", "inspect_project_resource should expose include_property_values")
	assert_has(output_properties, "property_count", "inspect_project_resource should expose property_count")
	assert_has(output_properties, "returned_property_count", "inspect_project_resource should expose returned_property_count")
	assert_has(output_properties, "properties_truncated", "inspect_project_resource should expose properties_truncated")
	assert_has(output_properties, "has_more_properties", "inspect_project_resource should expose has_more_properties")
	assert_has(output_properties, "max_properties_applied", "inspect_project_resource should expose max_properties_applied")

func test_inspect_project_resource_reports_missing_params_and_missing_files():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	var missing_param: Dictionary = project_tools._tool_inspect_project_resource({})
	assert_has(missing_param, "error", "Missing resource_path should return an error")

	var missing_file: Dictionary = project_tools._tool_inspect_project_resource({"resource_path": "res://.tmp_project_tools_unit/does_not_exist_resource.tres"})
	assert_eq(missing_file.get("error", ""), "File not found: res://.tmp_project_tools_unit/does_not_exist_resource.tres", "Missing resource files should be reported truthfully")

func test_inspect_project_resource_returns_bounded_single_resource_details():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var resource_path: String = temp_dir + "/inspect_stylebox.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.2, 0.3, 1.0)
	var save_error: Error = ResourceSaver.save(style_box, resource_path)
	assert_eq(save_error, OK, "Should save temporary StyleBoxFlat resource for single-resource inspection")

	var result: Dictionary = project_tools._tool_inspect_project_resource({
		"resource_path": resource_path,
		"include_property_values": true,
		"property_filter": "bg_color",
		"max_properties": 2
	})

	assert_eq(result.get("resource_path", ""), resource_path, "Should preserve requested resource path")
	assert_eq(result.get("class_name", ""), "StyleBoxFlat", "Should report the concrete resource class")
	assert_eq(result.get("property_filter_applied", ""), "bg_color", "Should echo the applied property filter")
	assert_true(result.get("include_property_values", false), "Should echo include_property_values when enabled")
	assert_eq(int(result.get("max_properties_applied", 0)), 2, "Should echo the applied max_properties")
	assert_eq(int(result.get("property_count", 0)), 1, "Filtered inspection should only count matching properties")
	assert_eq(int(result.get("returned_property_count", 0)), 1, "Filtered inspection should return the matching property")
	assert_false(result.get("properties_truncated", true), "Single matching property should not be truncated")
	var properties: Array = result.get("properties", [])
	assert_eq(properties.size(), 1, "Should return one filtered property entry")
	assert_eq(str(properties[0].get("name", "")), "bg_color", "Filtered property should be bg_color")
	assert_has(properties[0], "value", "Value serialization should be present when requested")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_update_project_resource_properties_registers_write_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_update_project_resource_properties(server_core)

	var output_properties: Dictionary = server_core.tools["update_project_resource_properties"]["output_schema"].get("properties", {})
	assert_has(output_properties, "status", "update_project_resource_properties should expose status")
	assert_has(output_properties, "resource_path", "update_project_resource_properties should expose resource_path")
	assert_has(output_properties, "class_name", "update_project_resource_properties should expose class_name")
	assert_has(output_properties, "updated_properties", "update_project_resource_properties should expose updated_properties")
	assert_has(output_properties, "updated_property_count", "update_project_resource_properties should expose updated_property_count")

func test_update_project_resource_properties_reports_input_errors():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_update_project_resource_properties({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_update_project_resource_properties({
			"resource_path": "res://.tmp_project_tools_unit/does_not_exist_resource.tres",
			"properties": {"bg_color": {"r": 1.0, "g": 1.0, "b": 1.0}}
		}).get("error", ""),
		"File not found: res://.tmp_project_tools_unit/does_not_exist_resource.tres",
		"Missing resource files should be reported truthfully"
	)

func test_update_project_resource_properties_rejects_unknown_properties_and_unsupported_shapes():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var resource_path: String = temp_dir + "/update_stylebox_invalid.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	var save_error: Error = ResourceSaver.save(style_box, resource_path)
	assert_eq(save_error, OK, "Should save temporary StyleBoxFlat resource for invalid update tests")

	var unknown_result: Dictionary = project_tools._tool_update_project_resource_properties({
		"resource_path": resource_path,
		"properties": {"definitely_missing_property": 1}
	})
	assert_eq(unknown_result.get("error", ""), "Unknown resource property: definitely_missing_property", "Unknown resource properties should be rejected")

	var unsupported_result: Dictionary = project_tools._tool_update_project_resource_properties({
		"resource_path": resource_path,
		"properties": {"bg_color": {"hex": "#ffffff"}}
	})
	assert_true(str(unsupported_result.get("error", "")).contains("Unsupported value for property 'bg_color'"), "Unsupported value shapes should be rejected explicitly")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_update_project_resource_properties_saves_updated_values():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var resource_path: String = temp_dir + "/update_stylebox_valid.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style_box.corner_radius_top_left = 1
	var save_error: Error = ResourceSaver.save(style_box, resource_path)
	assert_eq(save_error, OK, "Should save temporary StyleBoxFlat resource for valid update tests")

	var update_result: Dictionary = project_tools._tool_update_project_resource_properties({
		"resource_path": resource_path,
		"properties": {
			"bg_color": {"r": 0.4, "g": 0.6, "b": 0.8, "a": 1.0},
			"corner_radius_top_left": 9
		}
	})

	assert_eq(update_result.get("status", ""), "success", "Valid resource updates should save successfully")
	assert_eq(update_result.get("class_name", ""), "StyleBoxFlat", "Should report updated resource class")
	assert_eq(int(update_result.get("updated_property_count", 0)), 2, "Should report the number of updated properties")
	assert_eq(update_result.get("updated_properties", []), ["bg_color", "corner_radius_top_left"], "Updated properties should be sorted and echoed")

	var reloaded_detail: Dictionary = project_tools._tool_inspect_project_resource({
		"resource_path": resource_path,
		"include_property_values": true,
		"property_filter": "bg_color",
		"max_properties": 5
	})
	var bg_property: Dictionary = reloaded_detail.get("properties", [])[0]
	var bg_value: Dictionary = bg_property.get("value", {})
	assert_eq(str(bg_property.get("name", "")), "bg_color", "Inspect helper should expose updated bg_color")
	assert_true(abs(float(bg_value.get("r", 0.0)) - 0.4) < 0.0001, "Saved bg_color.r should round-trip through disk")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_duplicate_project_resource_registers_save_as_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_duplicate_project_resource(server_core)

	var output_properties: Dictionary = server_core.tools["duplicate_project_resource"]["output_schema"].get("properties", {})
	assert_has(output_properties, "status", "duplicate_project_resource should expose status")
	assert_has(output_properties, "source_path", "duplicate_project_resource should expose source_path")
	assert_has(output_properties, "destination_path", "duplicate_project_resource should expose destination_path")
	assert_has(output_properties, "class_name", "duplicate_project_resource should expose class_name")

func test_duplicate_project_resource_reports_input_and_path_errors():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_duplicate_project_resource({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_duplicate_project_resource({
			"source_path": "res://.tmp_project_tools_unit/missing_source.tres",
			"destination_path": "res://.tmp_project_tools_unit/copy.tres"
		}).get("error", ""),
		"File not found: res://.tmp_project_tools_unit/missing_source.tres",
		"Missing source resources should be reported truthfully"
	)
	assert_eq(
		project_tools._tool_duplicate_project_resource({
			"source_path": "res://same_path.tres",
			"destination_path": "res://same_path.tres"
		}).get("error", ""),
		"Destination path must differ from source path",
		"Source and destination must differ"
	)

func test_duplicate_project_resource_rejects_existing_destination():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var source_path: String = temp_dir + "/duplicate_source.tres"
	var destination_path: String = temp_dir + "/duplicate_existing.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	var save_error: Error = ResourceSaver.save(style_box, source_path)
	assert_eq(save_error, OK, "Should save duplicate source resource")
	save_error = ResourceSaver.save(style_box, destination_path)
	assert_eq(save_error, OK, "Should save duplicate destination resource")

	var result: Dictionary = project_tools._tool_duplicate_project_resource({
		"source_path": source_path,
		"destination_path": destination_path
	})
	assert_eq(result.get("error", ""), "File already exists: " + destination_path, "Existing destination files should be rejected")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(destination_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_duplicate_project_resource_saves_copy_to_new_path():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var source_path: String = temp_dir + "/duplicate_source_valid.tres"
	var destination_path: String = temp_dir + "/nested/duplicate_copy_valid.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.33, 0.44, 0.55, 1.0)
	style_box.corner_radius_top_left = 7
	var save_error: Error = ResourceSaver.save(style_box, source_path)
	assert_eq(save_error, OK, "Should save duplicate source resource for valid duplicate test")

	var duplicate_result: Dictionary = project_tools._tool_duplicate_project_resource({
		"source_path": source_path,
		"destination_path": destination_path
	})
	assert_eq(duplicate_result.get("status", ""), "success", "Valid duplication should succeed")
	assert_eq(duplicate_result.get("class_name", ""), "StyleBoxFlat", "Duplicated resource should preserve class")
	assert_true(FileAccess.file_exists(destination_path), "Duplicated resource file should exist at destination")

	var source_detail: Dictionary = project_tools._tool_inspect_project_resource({
		"resource_path": source_path,
		"include_property_values": true,
		"property_filter": "bg_color",
		"max_properties": 5
	})
	var destination_detail: Dictionary = project_tools._tool_inspect_project_resource({
		"resource_path": destination_path,
		"include_property_values": true,
		"property_filter": "bg_color",
		"max_properties": 5
	})
	var source_color: Dictionary = source_detail.get("properties", [])[0].get("value", {})
	var destination_color: Dictionary = destination_detail.get("properties", [])[0].get("value", {})
	assert_true(abs(float(source_color.get("r", 0.0)) - float(destination_color.get("r", 0.0))) < 0.0001, "Duplicated resource should preserve persisted color values")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(destination_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(destination_path.get_base_dir()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_delete_project_resource_registers_delete_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_delete_project_resource(server_core)

	var output_properties: Dictionary = server_core.tools["delete_project_resource"]["output_schema"].get("properties", {})
	assert_has(output_properties, "status", "delete_project_resource should expose status")
	assert_has(output_properties, "resource_path", "delete_project_resource should expose resource_path")
	assert_has(output_properties, "removed", "delete_project_resource should expose removed")

func test_delete_project_resource_reports_missing_and_invalid_paths():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_delete_project_resource({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_delete_project_resource({
			"resource_path": "res://.tmp_project_tools_unit/missing_delete_resource.tres"
		}).get("error", ""),
		"File not found: res://.tmp_project_tools_unit/missing_delete_resource.tres",
		"Missing resources should be reported truthfully"
	)
	assert_true(
		str(project_tools._tool_delete_project_resource({
			"resource_path": "res://.tmp_project_tools_unit/not_a_resource.txt"
		}).get("error", "")).begins_with("Invalid path:"),
		"Non-resource extensions should be rejected"
	)

func test_delete_project_resource_removes_existing_file():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var resource_path: String = temp_dir + "/delete_stylebox_valid.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	var save_error: Error = ResourceSaver.save(style_box, resource_path)
	assert_eq(save_error, OK, "Should save temporary resource for delete test")
	assert_true(FileAccess.file_exists(resource_path), "Delete test resource should exist before deletion")

	var delete_result: Dictionary = project_tools._tool_delete_project_resource({
		"resource_path": resource_path
	})
	assert_eq(delete_result.get("status", ""), "success", "Valid resource deletion should succeed")
	assert_eq(delete_result.get("resource_path", ""), resource_path, "Delete result should echo resource path")
	assert_true(delete_result.get("removed", false), "Delete result should confirm removal")
	assert_false(FileAccess.file_exists(resource_path), "Deleted resource file should no longer exist")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_move_project_resource_registers_move_surface():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var server_core := FakeRegistrationCore.new()

	project_tools._register_move_project_resource(server_core)

	var output_properties: Dictionary = server_core.tools["move_project_resource"]["output_schema"].get("properties", {})
	assert_has(output_properties, "status", "move_project_resource should expose status")
	assert_has(output_properties, "source_path", "move_project_resource should expose source_path")
	assert_has(output_properties, "destination_path", "move_project_resource should expose destination_path")
	assert_has(output_properties, "moved", "move_project_resource should expose moved")

func test_move_project_resource_reports_input_and_path_errors():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

	assert_has(project_tools._tool_move_project_resource({}), "error", "Missing parameters should return an error")
	assert_eq(
		project_tools._tool_move_project_resource({
			"source_path": "res://.tmp_project_tools_unit/missing_move_source.tres",
			"destination_path": "res://.tmp_project_tools_unit/moved_copy.tres"
		}).get("error", ""),
		"File not found: res://.tmp_project_tools_unit/missing_move_source.tres",
		"Missing source resources should be reported truthfully"
	)
	assert_eq(
		project_tools._tool_move_project_resource({
			"source_path": "res://same_move_path.tres",
			"destination_path": "res://same_move_path.tres"
		}).get("error", ""),
		"Destination path must differ from source path",
		"Source and destination must differ for resource moves"
	)
	assert_true(
		str(project_tools._tool_move_project_resource({
			"source_path": "res://.tmp_project_tools_unit/not_a_resource.txt",
			"destination_path": "res://.tmp_project_tools_unit/moved_copy.tres"
		}).get("error", "")).begins_with("Invalid source path:"),
		"Non-resource source extensions should be rejected"
	)

func test_move_project_resource_rejects_existing_destination():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var source_path: String = temp_dir + "/move_source.tres"
	var destination_path: String = temp_dir + "/move_existing.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	var save_error: Error = ResourceSaver.save(style_box, source_path)
	assert_eq(save_error, OK, "Should save move source resource")
	save_error = ResourceSaver.save(style_box, destination_path)
	assert_eq(save_error, OK, "Should save move destination resource")

	var result: Dictionary = project_tools._tool_move_project_resource({
		"source_path": source_path,
		"destination_path": destination_path
	})
	assert_eq(result.get("error", ""), "File already exists: " + destination_path, "Existing destination files should be rejected for moves")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(destination_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_move_project_resource_moves_existing_file_and_preserves_values():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var source_path: String = temp_dir + "/move_source_valid.tres"
	var destination_path: String = temp_dir + "/nested/move_destination_valid.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.22, 0.55, 0.88, 1.0)
	style_box.corner_radius_top_left = 5
	var save_error: Error = ResourceSaver.save(style_box, source_path)
	assert_eq(save_error, OK, "Should save move source resource for valid move test")
	assert_true(FileAccess.file_exists(source_path), "Move source resource should exist before move")

	var move_result: Dictionary = project_tools._tool_move_project_resource({
		"source_path": source_path,
		"destination_path": destination_path
	})
	assert_eq(move_result.get("status", ""), "success", "Valid resource move should succeed")
	assert_eq(move_result.get("source_path", ""), source_path, "Move result should echo source path")
	assert_eq(move_result.get("destination_path", ""), destination_path, "Move result should echo destination path")
	assert_true(move_result.get("moved", false), "Move result should confirm move")
	assert_false(FileAccess.file_exists(source_path), "Moved resource should no longer exist at the source path")
	assert_true(FileAccess.file_exists(destination_path), "Moved resource file should exist at destination")

	var moved_detail: Dictionary = project_tools._tool_inspect_project_resource({
		"resource_path": destination_path,
		"include_property_values": true,
		"property_filter": "bg_color",
		"max_properties": 5
	})
	var moved_color: Dictionary = moved_detail.get("properties", [])[0].get("value", {})
	assert_true(abs(float(moved_color.get("r", 0.0)) - 0.22) < 0.0001, "Moved resource should preserve persisted color values")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(destination_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(destination_path.get_base_dir()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_build_project_resource_detail_reports_bounded_property_metadata():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var resource_path: String = temp_dir + "/detail_stylebox.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	var save_error: Error = ResourceSaver.save(style_box, resource_path)
	assert_eq(save_error, OK, "Should save temporary StyleBoxFlat resource for detail inspection")

	var detail: Dictionary = project_tools._build_project_resource_detail(resource_path, "", false, 3)

	assert_true(detail.get("is_loadable", false), "Temporary resource should be loadable")
	assert_eq(detail.get("class_name", ""), "StyleBoxFlat", "Should report the concrete resource class")
	assert_eq(int(detail.get("returned_property_count", 0)), 3, "Should cap returned properties to the requested budget")
	assert_true(detail.get("property_count", 0) >= 3, "Should report total matching property count")
	if int(detail.get("property_count", 0)) > 3:
		assert_true(detail.get("properties_truncated", false), "Should report truncation when more properties exist")
		assert_true(detail.get("has_more_properties", false), "Should report continuation when more properties exist")
		assert_eq(int(detail.get("next_max_properties", 0)), 6, "Should advertise a larger follow-up property budget")

	var properties: Array = detail.get("properties", [])
	for property_entry in properties:
		assert_has(property_entry, "name", "Serialized property entries should include names")
		assert_false(property_entry.has("value"), "Value serialization should stay opt-in")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_build_project_resource_detail_includes_serialized_values_when_requested():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var resource_path: String = temp_dir + "/detail_stylebox_with_values.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.25, 0.5, 0.75, 1.0)
	var save_error: Error = ResourceSaver.save(style_box, resource_path)
	assert_eq(save_error, OK, "Should save temporary StyleBoxFlat resource for value serialization")

	var detail: Dictionary = project_tools._build_project_resource_detail(resource_path, "bg_color", true, 5)

	assert_true(detail.get("is_loadable", false), "Temporary resource should be loadable")
	assert_eq(int(detail.get("property_count", 0)), int(detail.get("returned_property_count", 0)), "Filtered resource detail should return every matching property when under budget")
	var properties: Array = detail.get("properties", [])
	assert_gt(properties.size(), 0, "Filtered detail should include the requested property")
	assert_eq(str(properties[0].get("name", "")), "bg_color", "Property filter should keep matching StyleBoxFlat properties")
	assert_has(properties[0], "value", "Value serialization should be included when requested")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_with_max_results_continuation_marks_truncated_results():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._with_max_results_continuation({"issues": [1]}, 5, true)

	assert_true(result.get("truncated", false), "Truncated diagnostics result should report truncation")
	assert_true(result.get("has_more", false), "Truncated diagnostics result should report more data")
	assert_eq(result.get("max_results_applied"), 5, "Diagnostics result should echo applied max_results")
	assert_eq(result.get("next_max_results"), 10, "Truncated diagnostics result should advertise a larger rerun budget")

func test_with_max_results_continuation_marks_complete_results():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._with_max_results_continuation({"issues": []}, 5, false)

	assert_false(result.get("truncated", true), "Complete diagnostics result should not report truncation")
	assert_false(result.get("has_more", true), "Complete diagnostics result should not report more data")
	assert_eq(result.get("max_results_applied"), 5, "Diagnostics result should echo applied max_results")
	assert_false(result.has("next_max_results"), "Complete diagnostics result should not advertise a larger rerun budget")

func test_count_broken_script_severities_counts_errors_and_warning_entries():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var counts: Dictionary = project_tools._count_broken_script_severities([
		{"severity": "error", "warnings": []},
		{"severity": "warning", "warnings": [{"line": 1}]},
		{"severity": "error", "warnings": [{"line": 2}]}
	])

	assert_eq(int(counts.get("broken_count", 0)), 2, "Should count entries with error severity as broken scripts")
	assert_eq(int(counts.get("warning_count", 0)), 2, "Should count entries carrying warning payloads as warning scripts")

func test_collect_broken_script_issues_respects_limit_without_hiding_exact_fit_truth():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var scripts: Array[String] = [
		"res://test/does_not_exist_a.gd",
		"res://test/does_not_exist_b.gd",
		"res://test/does_not_exist_c.gd"
	]

	var issues: Array = project_tools._collect_broken_script_issues(scripts, true, 2)

	assert_eq(issues.size(), 2, "Broken script issue collection should stop at the requested probe limit")
	assert_eq(str(issues[0].get("script_path", "")), "res://test/does_not_exist_a.gd", "Should preserve script ordering when collecting issues")
	assert_eq(str(issues[1].get("script_path", "")), "res://test/does_not_exist_b.gd", "Should preserve script ordering when collecting issues")

func test_collect_missing_resource_dependency_issues_respects_limit_and_order():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var temp_dir: String = "res://.tmp_project_tools_unit"
	var scene_path_a: String = temp_dir + "/missing_a.tscn"
	var scene_path_b: String = temp_dir + "/missing_b.tscn"
	var scene_text_a: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://.tmp_project_tools_unit/does_not_exist_a.gd\" id=\"1_missing\"]\n\n[node name=\"MissingA\" type=\"Node\"]\nscript = ExtResource(\"1_missing\")\n"
	var scene_text_b: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://.tmp_project_tools_unit/does_not_exist_b.gd\" id=\"1_missing\"]\n\n[node name=\"MissingB\" type=\"Node\"]\nscript = ExtResource(\"1_missing\")\n"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))
	var file_a: FileAccess = FileAccess.open(scene_path_a, FileAccess.WRITE)
	file_a.store_string(scene_text_a)
	file_a.close()
	var file_b: FileAccess = FileAccess.open(scene_path_b, FileAccess.WRITE)
	file_b.store_string(scene_text_b)
	file_b.close()
	var resources: Array[String] = [
		scene_path_a,
		scene_path_b
	]

	var issues: Array = project_tools._collect_missing_resource_dependency_issues(resources, 2)

	assert_eq(issues.size(), 2, "Missing dependency issue collection should stop at the requested probe limit")
	assert_eq(str(issues[0].get("owner_path", "")), scene_path_a, "Should preserve resource ordering when collecting issues")
	assert_eq(str(issues[1].get("owner_path", "")), scene_path_b, "Should preserve resource ordering when collecting issues")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_path_a))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_path_b))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_dir))

func test_collect_cyclic_dependency_issues_respects_limit_and_preserves_owner_order():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var resources: Array[String] = [
		"res://cycle_a.tscn",
		"res://cycle_b.tscn",
		"res://cycle_c.tscn"
	]
	var graph: Dictionary = {
		"res://cycle_a.tscn": ["res://cycle_b.tscn"],
		"res://cycle_b.tscn": ["res://cycle_a.tscn"],
		"res://cycle_c.tscn": []
	}

	var issues: Array = project_tools._collect_cyclic_dependency_issues(resources, graph, 1)

	assert_eq(issues.size(), 1, "Cyclic dependency issue collection should stop at the requested probe limit")
	assert_eq(str(issues[0].get("owner_path", "")), "res://cycle_a.tscn", "Should preserve resource ordering when collecting cycle issues")
	assert_eq(Array(issues[0].get("cycle_path", [])).size(), 3, "Cycle issue should include the closed cycle path")
