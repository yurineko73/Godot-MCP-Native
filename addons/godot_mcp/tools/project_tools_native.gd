# project_tools_native.gd - Project Tools原生实现

@tool
class_name ProjectToolsNative
extends RefCounted

var _editor_interface = null

func initialize(editor_interface) -> void:
	_editor_interface = editor_interface

func _get_editor_interface():
	if _editor_interface:
		return _editor_interface
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_editor_interface"):
			return plugin.get_editor_interface()
	return null

# ============================================================================
# 工具注册
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	_register_get_project_info(server_core)
	_register_get_project_settings(server_core)
	_register_set_project_setting(server_core)
	_register_inspect_project_setting(server_core)
	_register_clear_project_setting(server_core)
	_register_list_project_tests(server_core)
	_register_list_project_test_runners(server_core)
	_register_inspect_project_test(server_core)
	_register_run_project_test(server_core)
	_register_run_project_tests(server_core)
	_register_list_project_input_actions(server_core)
	_register_inspect_project_input_action(server_core)
	_register_upsert_project_input_action(server_core)
	_register_remove_project_input_action(server_core)
	_register_list_project_autoloads(server_core)
	_register_inspect_project_autoload(server_core)
	_register_upsert_project_autoload(server_core)
	_register_remove_project_autoload(server_core)
	_register_set_project_plugin_enabled(server_core)
	_register_list_project_plugins(server_core)
	_register_inspect_project_plugin(server_core)
	_register_set_project_feature_profile(server_core)
	_register_inspect_project_feature_profile(server_core)
	_register_list_project_feature_profiles(server_core)
	_register_get_project_configuration_summary(server_core)
	_register_list_project_global_classes(server_core)
	_register_inspect_project_global_class(server_core)
	_register_get_class_api_metadata(server_core)
	_register_inspect_csharp_project_support(server_core)
	_register_compare_render_screenshots(server_core)
	_register_inspect_tileset_resource(server_core)
	_register_list_project_resources(server_core)
	_register_inspect_project_resource(server_core)
	_register_update_project_resource_properties(server_core)
	_register_duplicate_project_resource(server_core)
	_register_delete_project_resource(server_core)
	_register_move_project_resource(server_core)
	_register_create_resource(server_core)
	_register_get_project_structure(server_core)
	_register_reimport_resources(server_core)
	_register_get_import_metadata(server_core)
	_register_get_resource_uid_info(server_core)
	_register_fix_resource_uid(server_core)
	_register_get_resource_dependencies(server_core)
	_register_scan_missing_resource_dependencies(server_core)
	_register_scan_cyclic_resource_dependencies(server_core)
	_register_detect_broken_scripts(server_core)
	_register_audit_project_health(server_core)

# ============================================================================
# get_project_info - 获取项目信息
# ============================================================================

func _register_get_project_info(server_core: RefCounted) -> void:
	var tool_name: String = "get_project_info"
	var description: String = "Get general information about the Godot project, including name, version, and description."

	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"project_name": {"type": "string"},
			"project_version": {"type": "string"},
			"project_description": {"type": "string"},
			"main_scene": {"type": "string"},
			"project_path": {"type": "string"},
			"godot_version": {"type": "string"}
		}
	}

	# annotations - readOnlyHint = true
	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_project_info"),
						  output_schema, annotations,
						  "core", "Project")

func _tool_get_project_info(params: Dictionary) -> Dictionary:
	var project_name: String = ProjectSettings.get_setting("application/config/name", "")
	var project_version: String = ProjectSettings.get_setting("application/config/version", "")
	var project_description: String = ProjectSettings.get_setting("application/config/description", "")
	var main_scene_uid: String = ProjectSettings.get_setting("application/run/main_scene", "")

	var main_scene: String = main_scene_uid
	if main_scene_uid.begins_with("uid://"):
		if ClassDB.class_exists("ResourceUID"):
			main_scene = ResourceUID.uid_to_path(main_scene_uid)

	var project_path: String = ProjectSettings.globalize_path("res://")
	var godot_version: Dictionary = Engine.get_version_info()
	var version_str: String = "%d.%d.%s" % [godot_version.get("major", 0), godot_version.get("minor", 0), godot_version.get("status", "")]

	return {
		"project_name": project_name,
		"project_version": project_version,
		"project_description": project_description,
		"main_scene": main_scene,
		"project_path": project_path,
		"godot_version": version_str
	}

# ============================================================================
# get_project_settings - 获取项目设置
# ============================================================================

func _register_get_project_settings(server_core: RefCounted) -> void:
	var tool_name: String = "get_project_settings"
	var description: String = "Get project settings. Optionally filter by a prefix."

	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"filter": {
				"type": "string",
				"description": "Optional prefix to filter settings (e.g. 'display/', 'input/'). Returns all if not provided."
			}
		}
	}

	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"settings": {"type": "object"},
			"count": {"type": "integer"}
		}
	}

	# annotations - readOnlyHint = true
	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_project_settings"),
						  output_schema, annotations,
						  "core", "Project")

func _tool_get_project_settings(params: Dictionary) -> Dictionary:
	var filter: String = params.get("filter", "")

	var settings: Dictionary = {}
	var setting_count: int = 0

	var all_properties: Array = ProjectSettings.get_property_list()

	for property_info in all_properties:
		var setting_name: String = property_info.get("name", "")

		if not filter.is_empty() and not setting_name.begins_with(filter):
			continue

		var value: Variant = ProjectSettings.get_setting(setting_name)
		settings[setting_name] = str(value)
		setting_count += 1

	return {
		"settings": settings,
		"count": setting_count
	}

# ============================================================================
# project input actions - 项目级 InputMap
# ============================================================================

func _register_set_project_setting(server_core: RefCounted) -> void:
	var tool_name: String = "set_project_setting"
	var description: String = "Set one project setting value, save project.godot, and return the persisted value."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"setting_name": {
				"type": "string",
				"description": "Existing project setting key to update, or a custom key under the mcp/ namespace."
			},
			"setting_value": {
				"description": "New scalar value for the setting."
			}
		},
		"required": ["setting_name", "setting_value"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"setting_name": {"type": "string"},
			"existed_before": {"type": "boolean"},
			"value_type": {"type": "string"},
			"previous_value": {},
			"persisted_value": {}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_set_project_setting"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_set_project_setting(params: Dictionary) -> Dictionary:
	var setting_name: String = str(params.get("setting_name", "")).strip_edges()
	if setting_name.is_empty():
		return {"error": "Missing required parameter: setting_name"}
	if not params.has("setting_value"):
		return {"error": "Missing required parameter: setting_value"}

	var validity: Dictionary = _validate_project_setting_name(setting_name)
	if not bool(validity.get("ok", false)):
		return {"error": str(validity.get("error", "Invalid project setting name"))}

	var existed_before: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name) if existed_before else null
	var expected_type: int = typeof(previous_value) if existed_before else TYPE_NIL
	var coerced: Dictionary = _coerce_project_setting_value(params.get("setting_value"), expected_type, existed_before)
	if not bool(coerced.get("ok", false)):
		return {"error": "Unsupported setting_value for '%s': %s" % [setting_name, str(coerced.get("error", "unknown error"))]}

	ProjectSettings.set_setting(setting_name, coerced.get("value"))
	var save_error: Error = ProjectSettings.save()
	if save_error != OK:
		return {"error": "Failed to save project settings: " + str(save_error)}

	var persisted_value: Variant = ProjectSettings.get_setting(setting_name, null)
	return {
		"status": "success",
		"setting_name": setting_name,
		"existed_before": existed_before,
		"value_type": type_string(typeof(persisted_value)),
		"previous_value": _serialize_project_resource_value(previous_value),
		"persisted_value": _serialize_project_resource_value(persisted_value)
	}

func _register_inspect_project_setting(server_core: RefCounted) -> void:
	var tool_name: String = "inspect_project_setting"
	var description: String = "Inspect one project setting key and return its current existence truth, persisted value, and value type."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"setting_name": {
				"type": "string",
				"description": "Existing project setting key, or a custom key under the mcp/ namespace."
			}
		},
		"required": ["setting_name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"setting_name": {"type": "string"},
			"exists": {"type": "boolean"},
			"value_type": {"type": "string"},
			"persisted_value": {}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_inspect_project_setting"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_inspect_project_setting(params: Dictionary) -> Dictionary:
	var setting_name: String = str(params.get("setting_name", "")).strip_edges()
	if setting_name.is_empty():
		return {"error": "Missing required parameter: setting_name"}

	var validity: Dictionary = _validate_project_setting_name(setting_name)
	if not bool(validity.get("ok", false)):
		return {"error": str(validity.get("error", "Invalid project setting name"))}

	var exists: bool = ProjectSettings.has_setting(setting_name)
	if not exists:
		return {
			"setting_name": setting_name,
			"exists": false
		}

	var persisted_value: Variant = ProjectSettings.get_setting(setting_name, null)
	return {
		"setting_name": setting_name,
		"exists": true,
		"value_type": type_string(typeof(persisted_value)),
		"persisted_value": _serialize_project_resource_value(persisted_value)
	}

func _register_clear_project_setting(server_core: RefCounted) -> void:
	var tool_name: String = "clear_project_setting"
	var description: String = "Clear one project setting key, save project.godot, and report whether it existed."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"setting_name": {
				"type": "string",
				"description": "Existing project setting key to clear, or a custom key under the mcp/ namespace."
			}
		},
		"required": ["setting_name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"setting_name": {"type": "string"},
			"existed_before": {"type": "boolean"},
			"removed": {"type": "boolean"},
			"previous_value": {}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_clear_project_setting"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_clear_project_setting(params: Dictionary) -> Dictionary:
	var setting_name: String = str(params.get("setting_name", "")).strip_edges()
	if setting_name.is_empty():
		return {"error": "Missing required parameter: setting_name"}

	var validity: Dictionary = _validate_project_setting_name(setting_name)
	if not bool(validity.get("ok", false)):
		return {"error": str(validity.get("error", "Invalid project setting name"))}

	var existed_before: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name) if existed_before else null
	if not existed_before:
		return {
			"status": "success",
			"setting_name": setting_name,
			"existed_before": false,
			"removed": false,
			"previous_value": null
		}

	ProjectSettings.clear(setting_name)
	var save_error: Error = ProjectSettings.save()
	if save_error != OK:
		return {"error": "Failed to save project settings: " + str(save_error)}

	return {
		"status": "success",
		"setting_name": setting_name,
		"existed_before": true,
		"removed": true,
		"previous_value": _serialize_project_resource_value(previous_value)
	}

func _register_list_project_input_actions(server_core: RefCounted) -> void:
	var tool_name: String = "list_project_input_actions"
	var description: String = "List project InputMap actions stored in ProjectSettings, including serialized input events."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"action_name": {
				"type": "string",
				"description": "Optional exact action name filter."
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"actions": {"type": "array"},
			"count": {"type": "integer"},
			"filter": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_list_project_input_actions"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_list_project_input_actions(params: Dictionary) -> Dictionary:
	var action_name: String = str(params.get("action_name", "")).strip_edges()
	var actions: Array = _collect_project_input_actions(action_name)
	return {
		"actions": actions,
		"count": actions.size(),
		"filter": action_name
	}

func _register_inspect_project_input_action(server_core: RefCounted) -> void:
	var tool_name: String = "inspect_project_input_action"
	var description: String = "Inspect one project InputMap action and return existence truth plus current deadzone and serialized events."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"action_name": {"type": "string"}
		},
		"required": ["action_name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"action_name": {"type": "string"},
			"exists": {"type": "boolean"},
			"deadzone": {"type": "number"},
			"event_count": {"type": "integer"},
			"events": {"type": "array"},
			"setting_name": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_inspect_project_input_action"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_inspect_project_input_action(params: Dictionary) -> Dictionary:
	var action_name: String = str(params.get("action_name", "")).strip_edges()
	if action_name.is_empty():
		return {"error": "Missing required parameter: action_name"}

	var actions: Array = _collect_project_input_actions(action_name)
	if actions.is_empty():
		return {
			"action_name": action_name,
			"exists": false
		}

	var action_entry: Dictionary = actions[0]
	action_entry["exists"] = true
	return action_entry

func _register_upsert_project_input_action(server_core: RefCounted) -> void:
	var tool_name: String = "upsert_project_input_action"
	var description: String = "Create or update a project InputMap action in ProjectSettings and save project.godot."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"action_name": {"type": "string"},
			"deadzone": {"type": "number", "default": 0.5},
			"erase_existing": {"type": "boolean", "default": false},
			"events": {"type": "array", "description": "Optional structured input event payloads to store on the action."}
		},
		"required": ["action_name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"action_name": {"type": "string"},
			"existed_before": {"type": "boolean"},
			"deadzone": {"type": "number"},
			"event_count": {"type": "integer"},
			"events": {"type": "array"},
			"added_events": {"type": "array"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_upsert_project_input_action"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_upsert_project_input_action(params: Dictionary) -> Dictionary:
	var action_name: String = str(params.get("action_name", "")).strip_edges()
	if action_name.is_empty():
		return {"error": "Missing required parameter: action_name"}

	var deadzone: float = float(params.get("deadzone", 0.5))
	var erase_existing: bool = bool(params.get("erase_existing", false))
	var raw_events: Array = params.get("events", [])
	var setting_name: String = "input/" + action_name
	var existed_before: bool = ProjectSettings.has_setting(setting_name)

	var stored_events: Array = []
	var added_events: Array = []
	if existed_before and not erase_existing:
		var existing_value: Variant = ProjectSettings.get_setting(setting_name, {})
		if existing_value is Dictionary:
			stored_events = (existing_value.get("events", []) as Array).duplicate()
	for raw_event in raw_events:
		if not (raw_event is Dictionary):
			return {"error": "Each event entry must be an object"}
		var built_event: InputEvent = _build_project_input_event(raw_event)
		if built_event == null:
			return {"error": "Unsupported input event payload: " + JSON.stringify(raw_event)}
		stored_events.append(built_event)
		added_events.append(_serialize_project_input_event(built_event))

	ProjectSettings.set_setting(setting_name, {
		"deadzone": deadzone,
		"events": stored_events
	})
	var save_error: Error = ProjectSettings.save()
	if save_error != OK:
		return {"error": "Failed to save project settings: " + str(save_error)}
	InputMap.load_from_project_settings()

	var listed_actions: Array = _collect_project_input_actions(action_name)
	var action_entry: Dictionary = listed_actions[0] if not listed_actions.is_empty() else {}
	action_entry["added_events"] = added_events
	action_entry["existed_before"] = existed_before
	return action_entry

func _register_remove_project_input_action(server_core: RefCounted) -> void:
	var tool_name: String = "remove_project_input_action"
	var description: String = "Remove a project InputMap action from ProjectSettings and save project.godot."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"action_name": {"type": "string"}
		},
		"required": ["action_name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"action_name": {"type": "string"},
			"removed": {"type": "boolean"},
			"event_count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_remove_project_input_action"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_remove_project_input_action(params: Dictionary) -> Dictionary:
	var action_name: String = str(params.get("action_name", "")).strip_edges()
	if action_name.is_empty():
		return {"error": "Missing required parameter: action_name"}

	var setting_name: String = "input/" + action_name
	if not ProjectSettings.has_setting(setting_name):
		return {
			"action_name": action_name,
			"removed": false,
			"event_count": 0
		}

	var existing_value: Variant = ProjectSettings.get_setting(setting_name, {})
	var event_count: int = 0
	if existing_value is Dictionary:
		event_count = (existing_value.get("events", []) as Array).size()

	ProjectSettings.clear(setting_name)
	var save_error: Error = ProjectSettings.save()
	if save_error != OK:
		return {"error": "Failed to save project settings: " + str(save_error)}
	InputMap.load_from_project_settings()

	return {
		"action_name": action_name,
		"removed": true,
		"event_count": event_count
	}

# ============================================================================
# list_project_autoloads - 列出项目 Autoload
# ============================================================================

func _register_list_project_autoloads(server_core: RefCounted) -> void:
	var tool_name: String = "list_project_autoloads"
	var description: String = "List project autoload entries with resolved path, singleton flag, and project setting order."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"filter": {
				"type": "string",
				"description": "Optional case-insensitive filter that matches autoload name or path."
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"autoloads": {"type": "array", "items": {"type": "object"}},
			"count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_list_project_autoloads"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_list_project_autoloads(params: Dictionary) -> Dictionary:
	var filter: String = str(params.get("filter", "")).strip_edges().to_lower()
	var values_by_name: Dictionary = {}
	var orders_by_name: Dictionary = {}
	for property_info in ProjectSettings.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if not property_name.begins_with("autoload/"):
			continue
		values_by_name[property_name] = ProjectSettings.get_setting(property_name)
		orders_by_name[property_name] = ProjectSettings.get_order(property_name)

	var autoloads: Array = _collect_project_autoloads_from_properties(ProjectSettings.get_property_list(), values_by_name, orders_by_name)
	if not filter.is_empty():
		var filtered_autoloads: Array = []
		for entry in autoloads:
			var entry_name: String = str(entry.get("name", "")).to_lower()
			var entry_path: String = str(entry.get("path", "")).to_lower()
			if entry_name.contains(filter) or entry_path.contains(filter):
				filtered_autoloads.append(entry)
		autoloads = filtered_autoloads

	return {
		"autoloads": autoloads,
		"count": autoloads.size()
	}

func _register_inspect_project_autoload(server_core: RefCounted) -> void:
	var tool_name: String = "inspect_project_autoload"
	var description: String = "Inspect one project autoload entry by name and return its resolved path, singleton flag, and existence truth."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"name": {
				"type": "string",
				"description": "Autoload entry name to inspect."
			}
		},
		"required": ["name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"setting_name": {"type": "string"},
			"exists": {"type": "boolean"},
			"path": {"type": "string"},
			"is_singleton": {"type": "boolean"},
			"order": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_inspect_project_autoload"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_inspect_project_autoload(params: Dictionary) -> Dictionary:
	var autoload_name: String = str(params.get("name", "")).strip_edges()
	if autoload_name.is_empty():
		return {"error": "Missing required parameter: name"}
	if autoload_name.contains("/") or autoload_name.contains("\\"):
		return {"error": "Invalid autoload name: path separators are not allowed"}

	var setting_name: String = "autoload/" + autoload_name
	if not ProjectSettings.has_setting(setting_name):
		return {
			"name": autoload_name,
			"setting_name": setting_name,
			"exists": false
		}

	var values_by_name: Dictionary = {setting_name: ProjectSettings.get_setting(setting_name)}
	var orders_by_name: Dictionary = {setting_name: ProjectSettings.get_order(setting_name)}
	var entries: Array = _collect_project_autoloads_from_properties(
		[{"name": setting_name}],
		values_by_name,
		orders_by_name
	)
	var entry: Dictionary = entries[0] if not entries.is_empty() else {}
	entry["exists"] = true
	return entry

func _register_upsert_project_autoload(server_core: RefCounted) -> void:
	var tool_name: String = "upsert_project_autoload"
	var description: String = "Create or update one project autoload entry and save project.godot."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"name": {
				"type": "string",
				"description": "Autoload entry name."
			},
			"path": {
				"type": "string",
				"description": "Autoload target path. Supports .gd, .cs, and .tscn resources under res://."
			},
			"is_singleton": {
				"type": "boolean",
				"description": "Whether the autoload should be registered as a singleton.",
				"default": true
			}
		},
		"required": ["name", "path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"path": {"type": "string"},
			"is_singleton": {"type": "boolean"},
			"setting_name": {"type": "string"},
			"existed_before": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_upsert_project_autoload"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_upsert_project_autoload(params: Dictionary) -> Dictionary:
	var autoload_name: String = str(params.get("name", "")).strip_edges()
	if autoload_name.is_empty():
		return {"error": "Missing required parameter: name"}
	if autoload_name.contains("/") or autoload_name.contains("\\"):
		return {"error": "Invalid autoload name: path separators are not allowed"}

	var autoload_path: String = str(params.get("path", "")).strip_edges()
	if autoload_path.is_empty():
		return {"error": "Missing required parameter: path"}
	var path_validation: Dictionary = PathValidator.validate_file_path(autoload_path, [".gd", ".cs", ".tscn"])
	if not path_validation["valid"]:
		return {"error": "Invalid autoload path: " + path_validation["error"]}
	autoload_path = path_validation["sanitized"]
	if not FileAccess.file_exists(autoload_path):
		return {"error": "File not found: " + autoload_path}

	var is_singleton: bool = bool(params.get("is_singleton", true))
	var setting_name: String = "autoload/" + autoload_name
	var existed_before: bool = ProjectSettings.has_setting(setting_name)
	var stored_value: String = ("*" if is_singleton else "") + autoload_path

	ProjectSettings.set_setting(setting_name, stored_value)
	var save_error: Error = ProjectSettings.save()
	if save_error != OK:
		return {"error": "Failed to save project settings: " + str(save_error)}

	var values_by_name: Dictionary = {setting_name: ProjectSettings.get_setting(setting_name)}
	var orders_by_name: Dictionary = {setting_name: ProjectSettings.get_order(setting_name)}
	var entries: Array = _collect_project_autoloads_from_properties(
		[{"name": setting_name}],
		values_by_name,
		orders_by_name
	)
	var entry: Dictionary = entries[0] if not entries.is_empty() else {}
	entry["existed_before"] = existed_before
	return entry

func _register_remove_project_autoload(server_core: RefCounted) -> void:
	var tool_name: String = "remove_project_autoload"
	var description: String = "Remove one project autoload entry and save project.godot."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"name": {
				"type": "string",
				"description": "Autoload entry name to remove."
			}
		},
		"required": ["name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"setting_name": {"type": "string"},
			"existed_before": {"type": "boolean"},
			"removed": {"type": "boolean"},
			"path": {"type": "string"},
			"is_singleton": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_remove_project_autoload"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_remove_project_autoload(params: Dictionary) -> Dictionary:
	var autoload_name: String = str(params.get("name", "")).strip_edges()
	if autoload_name.is_empty():
		return {"error": "Missing required parameter: name"}
	if autoload_name.contains("/") or autoload_name.contains("\\"):
		return {"error": "Invalid autoload name: path separators are not allowed"}

	var setting_name: String = "autoload/" + autoload_name
	if not ProjectSettings.has_setting(setting_name):
		return {
			"name": autoload_name,
			"setting_name": setting_name,
			"existed_before": false,
			"removed": false
		}

	var previous_value: String = str(ProjectSettings.get_setting(setting_name, ""))
	var previous_is_singleton: bool = previous_value.begins_with("*")
	var previous_path: String = previous_value.substr(1) if previous_is_singleton else previous_value

	ProjectSettings.clear(setting_name)
	var save_error: Error = ProjectSettings.save()
	if save_error != OK:
		return {"error": "Failed to save project settings: " + str(save_error)}

	return {
		"name": autoload_name,
		"setting_name": setting_name,
		"existed_before": true,
		"removed": true,
		"path": previous_path,
		"is_singleton": previous_is_singleton
	}

func _register_set_project_plugin_enabled(server_core: RefCounted) -> void:
	var tool_name: String = "set_project_plugin_enabled"
	var description: String = "Enable or disable one installed editor plugin by its res://addons/.../plugin.cfg path."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"plugin_path": {
				"type": "string",
				"description": "Plugin config path under res://addons/, for example res://addons/gut/plugin.cfg."
			},
			"enabled": {
				"type": "boolean",
				"description": "Whether the plugin should be enabled."
			}
		},
		"required": ["plugin_path", "enabled"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"plugin_path": {"type": "string"},
			"plugin_name": {"type": "string"},
			"enabled_requested": {"type": "boolean"},
			"enabled": {"type": "boolean"},
			"existed_before": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_set_project_plugin_enabled"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_set_project_plugin_enabled(params: Dictionary) -> Dictionary:
	var plugin_path: String = str(params.get("plugin_path", "")).strip_edges()
	if plugin_path.is_empty():
		return {"error": "Missing required parameter: plugin_path"}
	if not params.has("enabled"):
		return {"error": "Missing required parameter: enabled"}
	if not _is_valid_plugin_config_path(plugin_path):
		return {"error": "Invalid plugin_path: expected a res://addons/.../plugin.cfg path"}
	if not FileAccess.file_exists(plugin_path):
		return {"error": "Plugin not found: " + plugin_path}

	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	if not editor_interface.has_method("is_plugin_enabled") or not editor_interface.has_method("set_plugin_enabled"):
		return {"error": "Editor interface does not support plugin enablement"}

	var plugin_name: String = _get_plugin_name_from_path(plugin_path)
	var enabled_requested: bool = bool(params.get("enabled", false))
	var existed_before: bool = bool(editor_interface.is_plugin_enabled(plugin_name))
	editor_interface.set_plugin_enabled(plugin_name, enabled_requested)
	var enabled: bool = bool(editor_interface.is_plugin_enabled(plugin_name))

	return {
		"plugin_path": plugin_path,
		"plugin_name": plugin_name,
		"enabled_requested": enabled_requested,
		"enabled": enabled,
		"existed_before": existed_before
	}

func _register_list_project_plugins(server_core: RefCounted) -> void:
	var tool_name: String = "list_project_plugins"
	var description: String = "List installed editor plugins discovered under res://addons/*/plugin.cfg and report their current enabled state."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"plugins": {"type": "array", "items": {"type": "object"}},
			"count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_list_project_plugins"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_list_project_plugins(_params: Dictionary) -> Dictionary:
	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	if not editor_interface.has_method("is_plugin_enabled"):
		return {"error": "Editor interface does not support plugin listing"}

	var plugins: Array = _collect_project_plugins()
	for entry in plugins:
		entry["enabled"] = bool(editor_interface.is_plugin_enabled(str(entry.get("name", ""))))

	return {
		"plugins": plugins,
		"count": plugins.size()
	}

func _register_inspect_project_plugin(server_core: RefCounted) -> void:
	var tool_name: String = "inspect_project_plugin"
	var description: String = "Inspect one installed editor plugin by its res://addons/.../plugin.cfg path and report plugin.cfg metadata plus current enabled state."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"plugin_path": {
				"type": "string",
				"description": "Plugin config path under res://addons/, for example res://addons/gut/plugin.cfg."
			}
		},
		"required": ["plugin_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"plugin_path": {"type": "string"},
			"plugin_name": {"type": "string"},
			"display_name": {"type": "string"},
			"description": {"type": "string"},
			"author": {"type": "string"},
			"version": {"type": "string"},
			"script": {"type": "string"},
			"enabled": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_inspect_project_plugin"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_inspect_project_plugin(params: Dictionary) -> Dictionary:
	if not params.has("plugin_path"):
		return {"error": "Missing required parameter: plugin_path"}

	var plugin_path: String = str(params.get("plugin_path", "")).strip_edges()
	if not _is_valid_plugin_config_path(plugin_path):
		return {"error": "Invalid plugin_path: expected a res://addons/.../plugin.cfg path"}
	if not FileAccess.file_exists(plugin_path):
		return {"error": "Plugin not found: " + plugin_path}

	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	if not editor_interface.has_method("is_plugin_enabled"):
		return {"error": "Editor interface does not support plugin inspection"}

	var plugin_name: String = _get_plugin_name_from_path(plugin_path)
	var plugin_metadata: Dictionary = _load_plugin_config_metadata(plugin_path)
	if plugin_metadata.has("error"):
		return plugin_metadata

	return {
		"plugin_path": plugin_path,
		"plugin_name": plugin_name,
		"display_name": str(plugin_metadata.get("display_name", "")),
		"description": str(plugin_metadata.get("description", "")),
		"author": str(plugin_metadata.get("author", "")),
		"version": str(plugin_metadata.get("version", "")),
		"script": str(plugin_metadata.get("script", "")),
		"enabled": bool(editor_interface.is_plugin_enabled(plugin_name))
	}

func _register_set_project_feature_profile(server_core: RefCounted) -> void:
	var tool_name: String = "set_project_feature_profile"
	var description: String = "Activate one existing editor feature profile by name, or reset back to the default profile."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"profile_name": {
				"type": "string",
				"description": "Feature profile name to activate. Pass an empty string to reset to the default profile."
			}
		},
		"required": ["profile_name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"profile_name_requested": {"type": "string"},
			"previous_profile": {"type": "string"},
			"current_profile": {"type": "string"},
			"used_default": {"type": "boolean"},
			"profile_path": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_set_project_feature_profile"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_set_project_feature_profile(params: Dictionary) -> Dictionary:
	if not params.has("profile_name"):
		return {"error": "Missing required parameter: profile_name"}

	var profile_name: String = str(params.get("profile_name", "")).strip_edges()
	if profile_name.contains("/") or profile_name.contains("\\"):
		return {"error": "Invalid profile_name: path separators are not allowed"}

	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	if not editor_interface.has_method("get_current_feature_profile") or not editor_interface.has_method("set_current_feature_profile"):
		return {"error": "Editor interface does not support feature profile selection"}

	var previous_profile: String = str(editor_interface.get_current_feature_profile())
	var profile_path: String = ""
	var used_default: bool = profile_name.is_empty()
	if not used_default:
		if not editor_interface.has_method("get_editor_paths"):
			return {"error": "Editor interface does not expose editor paths"}
		var editor_paths = editor_interface.get_editor_paths()
		if editor_paths == null or not editor_paths.has_method("get_config_dir"):
			return {"error": "Editor paths not available"}
		profile_path = _get_feature_profile_path(editor_paths.get_config_dir(), profile_name)
		if not FileAccess.file_exists(profile_path):
			return {"error": "Feature profile not found: " + profile_name}

	editor_interface.set_current_feature_profile(profile_name)
	var current_profile: String = str(editor_interface.get_current_feature_profile())
	return {
		"profile_name_requested": profile_name,
		"previous_profile": previous_profile,
		"current_profile": current_profile,
		"used_default": used_default,
		"profile_path": profile_path
	}

func _register_inspect_project_feature_profile(server_core: RefCounted) -> void:
	var tool_name: String = "inspect_project_feature_profile"
	var description: String = "Inspect one feature profile by name and report resolved path, existence truth, and whether it is currently active."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"profile_name": {
				"type": "string",
				"description": "Feature profile name to inspect."
			}
		},
		"required": ["profile_name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"profile_name": {"type": "string"},
			"profile_path": {"type": "string"},
			"exists": {"type": "boolean"},
			"is_current": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_inspect_project_feature_profile"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_inspect_project_feature_profile(params: Dictionary) -> Dictionary:
	if not params.has("profile_name"):
		return {"error": "Missing required parameter: profile_name"}

	var profile_name: String = str(params.get("profile_name", "")).strip_edges()
	if profile_name.is_empty():
		return {"error": "Missing required parameter: profile_name"}
	if profile_name.contains("/") or profile_name.contains("\\"):
		return {"error": "Invalid profile_name: path separators are not allowed"}

	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	if not editor_interface.has_method("get_current_feature_profile") or not editor_interface.has_method("get_editor_paths"):
		return {"error": "Editor interface does not support feature profile inspection"}

	var editor_paths = editor_interface.get_editor_paths()
	if editor_paths == null or not editor_paths.has_method("get_config_dir"):
		return {"error": "Editor paths not available"}

	var profile_path: String = _get_feature_profile_path(editor_paths.get_config_dir(), profile_name)
	var current_profile: String = str(editor_interface.get_current_feature_profile())
	var exists: bool = FileAccess.file_exists(profile_path)
	return {
		"profile_name": profile_name,
		"profile_path": profile_path,
		"exists": exists,
		"is_current": exists and profile_name == current_profile
	}

func _register_list_project_feature_profiles(server_core: RefCounted) -> void:
	var tool_name: String = "list_project_feature_profiles"
	var description: String = "List available editor feature profiles from the editor config directory and mark which profile is currently active."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"profiles": {"type": "array", "items": {"type": "object"}},
			"count": {"type": "integer"},
			"current_profile": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_list_project_feature_profiles"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_list_project_feature_profiles(_params: Dictionary) -> Dictionary:
	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	if not editor_interface.has_method("get_current_feature_profile") or not editor_interface.has_method("get_editor_paths"):
		return {"error": "Editor interface does not support feature profile listing"}

	var editor_paths = editor_interface.get_editor_paths()
	if editor_paths == null or not editor_paths.has_method("get_config_dir"):
		return {"error": "Editor paths not available"}

	var current_profile: String = str(editor_interface.get_current_feature_profile())
	var feature_profiles_dir: String = editor_paths.get_config_dir().path_join("feature_profiles")
	var profiles: Array = []
	var dir: DirAccess = DirAccess.open(feature_profiles_dir)
	if dir != null:
		dir.list_dir_begin()
		var entry_name: String = dir.get_next()
		while not entry_name.is_empty():
			if not dir.current_is_dir() and entry_name.ends_with(".profile"):
				var profile_name: String = entry_name.trim_suffix(".profile")
				profiles.append({
					"name": profile_name,
					"profile_path": feature_profiles_dir.path_join(entry_name),
					"is_current": profile_name == current_profile
				})
			entry_name = dir.get_next()
		dir.list_dir_end()
	profiles.sort_custom(Callable(self, "_compare_named_entries"))

	return {
		"profiles": profiles,
		"count": profiles.size(),
		"current_profile": current_profile
	}

func _register_get_project_configuration_summary(server_core: RefCounted) -> void:
	var tool_name: String = "get_project_configuration_summary"
	var description: String = "Return a bounded summary of installed project plugins, configured autoloads, and available feature profiles."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"max_items": {
				"type": "integer",
				"description": "Maximum number of entries to include per summary list. Defaults to 10.",
				"minimum": 1,
				"default": 10
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"max_items_applied": {"type": "integer"},
			"plugin_count": {"type": "integer"},
			"enabled_plugin_count": {"type": "integer"},
			"plugins": {"type": "array", "items": {"type": "object"}},
			"plugins_truncated": {"type": "boolean"},
			"autoload_count": {"type": "integer"},
			"autoloads": {"type": "array", "items": {"type": "object"}},
			"autoloads_truncated": {"type": "boolean"},
			"feature_profile_count": {"type": "integer"},
			"current_feature_profile": {"type": "string"},
			"feature_profiles": {"type": "array", "items": {"type": "object"}},
			"feature_profiles_truncated": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_project_configuration_summary"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_get_project_configuration_summary(params: Dictionary) -> Dictionary:
	var max_items: int = int(params.get("max_items", 10))
	if max_items < 1:
		return {"error": "Invalid max_items: expected integer >= 1"}

	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	if not editor_interface.has_method("is_plugin_enabled") or not editor_interface.has_method("get_current_feature_profile") or not editor_interface.has_method("get_editor_paths"):
		return {"error": "Editor interface does not support project configuration summary"}

	var plugins: Array = _collect_project_plugins()
	var enabled_plugin_count: int = 0
	for entry in plugins:
		var enabled: bool = bool(editor_interface.is_plugin_enabled(str(entry.get("name", ""))))
		entry["enabled"] = enabled
		if enabled:
			enabled_plugin_count += 1

	var values_by_name: Dictionary = {}
	var orders_by_name: Dictionary = {}
	for property_info in ProjectSettings.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if not property_name.begins_with("autoload/"):
			continue
		values_by_name[property_name] = ProjectSettings.get_setting(property_name)
		orders_by_name[property_name] = int(property_info.get("order", 0))
	var autoloads: Array = _collect_project_autoloads_from_properties(ProjectSettings.get_property_list(), values_by_name, orders_by_name)

	var editor_paths = editor_interface.get_editor_paths()
	if editor_paths == null or not editor_paths.has_method("get_config_dir"):
		return {"error": "Editor paths not available"}

	var current_feature_profile: String = str(editor_interface.get_current_feature_profile())
	var feature_profiles_dir: String = editor_paths.get_config_dir().path_join("feature_profiles")
	var feature_profiles: Array = []
	var dir: DirAccess = DirAccess.open(feature_profiles_dir)
	if dir != null:
		dir.list_dir_begin()
		var entry_name: String = dir.get_next()
		while not entry_name.is_empty():
			if not dir.current_is_dir() and entry_name.ends_with(".profile"):
				var profile_name: String = entry_name.trim_suffix(".profile")
				feature_profiles.append({
					"name": profile_name,
					"profile_path": feature_profiles_dir.path_join(entry_name),
					"is_current": profile_name == current_feature_profile
				})
			entry_name = dir.get_next()
		dir.list_dir_end()
	feature_profiles.sort_custom(Callable(self, "_compare_named_entries"))

	return {
		"max_items_applied": max_items,
		"plugin_count": plugins.size(),
		"enabled_plugin_count": enabled_plugin_count,
		"plugins": plugins.slice(0, min(max_items, plugins.size())),
		"plugins_truncated": plugins.size() > max_items,
		"autoload_count": autoloads.size(),
		"autoloads": autoloads.slice(0, min(max_items, autoloads.size())),
		"autoloads_truncated": autoloads.size() > max_items,
		"feature_profile_count": feature_profiles.size(),
		"current_feature_profile": current_feature_profile,
		"feature_profiles": feature_profiles.slice(0, min(max_items, feature_profiles.size())),
		"feature_profiles_truncated": feature_profiles.size() > max_items
	}

# ============================================================================
# list_project_global_classes - 列出项目全局脚本类
# ============================================================================

func _register_list_project_global_classes(server_core: RefCounted) -> void:
	var tool_name: String = "list_project_global_classes"
	var description: String = "List project global script classes registered through class_name metadata."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"filter": {
				"type": "string",
				"description": "Optional case-insensitive filter that matches class name, base type, or script path."
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"classes": {"type": "array", "items": {"type": "object"}},
			"count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_list_project_global_classes"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_list_project_global_classes(params: Dictionary) -> Dictionary:
	var filter: String = str(params.get("filter", "")).strip_edges().to_lower()
	var class_entries: Array = []
	if ProjectSettings.has_method("get_global_class_list"):
		class_entries = _normalize_global_class_entries(ProjectSettings.get_global_class_list())
	if not filter.is_empty():
		var filtered_entries: Array = []
		for entry in class_entries:
			var entry_name: String = str(entry.get("name", "")).to_lower()
			var base_name: String = str(entry.get("base", "")).to_lower()
			var path: String = str(entry.get("path", "")).to_lower()
			if entry_name.contains(filter) or base_name.contains(filter) or path.contains(filter):
				filtered_entries.append(entry)
		class_entries = filtered_entries
	return {
		"classes": class_entries,
		"count": class_entries.size()
	}

func _register_inspect_project_global_class(server_core: RefCounted) -> void:
	var tool_name: String = "inspect_project_global_class"
	var description: String = "Inspect one project global class entry and return its normalized metadata."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"class_name": {
				"type": "string",
				"description": "Project global class_name to inspect."
			}
		},
		"required": ["class_name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"class_name": {"type": "string"},
			"exists": {"type": "boolean"},
			"path": {"type": "string"},
			"base": {"type": "string"},
			"language": {"type": "string"},
			"is_tool": {"type": "boolean"},
			"is_abstract": {"type": "boolean"},
			"icon": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_inspect_project_global_class"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_inspect_project_global_class(params: Dictionary) -> Dictionary:
	var target_class_name: String = str(params.get("class_name", "")).strip_edges()
	if target_class_name.is_empty():
		return {"error": "Missing required parameter: class_name"}

	var class_entries: Array = []
	if ProjectSettings.has_method("get_global_class_list"):
		class_entries = _normalize_global_class_entries(ProjectSettings.get_global_class_list())
	for entry in class_entries:
		if str(entry.get("name", "")) == target_class_name:
			return {
				"class_name": target_class_name,
				"exists": true,
				"path": str(entry.get("path", "")),
				"base": str(entry.get("base", "")),
				"language": str(entry.get("language", "")),
				"is_tool": bool(entry.get("is_tool", false)),
				"is_abstract": bool(entry.get("is_abstract", false)),
				"icon": str(entry.get("icon", ""))
			}

	return {
		"class_name": target_class_name,
		"exists": false
	}

# ============================================================================
# get_class_api_metadata - 获取类型化 API 元数据
# ============================================================================

func _register_get_class_api_metadata(server_core: RefCounted) -> void:
	var tool_name: String = "get_class_api_metadata"
	var description: String = "Get typed API metadata for an engine ClassDB class or a project global script class."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"class_name": {
				"type": "string",
				"description": "Class name to inspect, such as 'Node' or a project global class_name."
			},
			"filter": {
				"type": "string",
				"description": "Optional case-insensitive filter applied to method/property/signal/constant names."
			},
			"include_base_api": {
				"type": "boolean",
				"description": "For project global classes, whether to include base ClassDB metadata. Default is true.",
				"default": true
			}
		},
		"required": ["class_name"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"class_name": {"type": "string"},
			"source": {"type": "string"},
			"base_class": {"type": "string"},
			"methods": {"type": "array"},
			"properties": {"type": "array"},
			"signals": {"type": "array"},
			"constants": {"type": "array"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_class_api_metadata"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_get_class_api_metadata(params: Dictionary) -> Dictionary:
	var target_class_name: String = str(params.get("class_name", "")).strip_edges()
	if target_class_name.is_empty():
		return {"error": "Missing required parameter: class_name"}
	var filter: String = str(params.get("filter", "")).strip_edges().to_lower()
	var include_base_api: bool = params.get("include_base_api", true)

	if ClassDB.class_exists(target_class_name):
		return _build_classdb_api_metadata(target_class_name, filter)

	var global_class: Dictionary = _find_project_global_class_entry(target_class_name)
	if global_class.is_empty():
		return {"error": "Class not found: " + target_class_name}

	var script_path: String = str(global_class.get("path", ""))
	var script: Script = load(script_path)
	if not script:
		return {"error": "Failed to load global class script: " + script_path}

	var result: Dictionary = {
		"class_name": target_class_name,
		"source": "global_class",
		"base_class": str(global_class.get("base", "")),
		"script_path": script_path,
		"language": str(global_class.get("language", "")),
		"is_tool": bool(global_class.get("is_tool", false)),
		"is_abstract": bool(global_class.get("is_abstract", false)),
		"methods": _normalize_method_entries(script.get_script_method_list(), filter),
		"properties": _normalize_property_entries(script.get_script_property_list(), filter),
		"signals": _normalize_signal_entries(script.get_script_signal_list(), filter),
		"constants": []
	}

	if include_base_api:
		var base_class: String = str(global_class.get("base", ""))
		if not base_class.is_empty() and ClassDB.class_exists(base_class):
			result["base_api"] = _build_classdb_api_metadata(base_class, filter)

	return result

# ============================================================================
# list_project_tests - 发现项目测试
# ============================================================================

func _register_list_project_tests(server_core: RefCounted) -> void:
	server_core.register_tool(
		"list_project_tests",
		"Discover runnable project tests under the Godot project's test directories. Reports Python integration tests and GUT unit tests, including whether each test is currently runnable.",
		{
			"type": "object",
			"properties": {
				"search_path": {"type": "string", "description": "Optional res:// path to limit discovery."},
				"framework": {"type": "string", "description": "Optional framework filter: python or gut."}
			}
		},
		Callable(self, "_tool_list_project_tests"),
		{
			"type": "object",
			"properties": {
				"count": {"type": "integer"},
				"search_path": {"type": "string"},
				"tests": {"type": "array"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Project-Advanced"
	)

func _tool_list_project_tests(params: Dictionary) -> Dictionary:
	var search_path: String = str(params.get("search_path", "res://test")).strip_edges()
	if search_path.is_empty():
		search_path = "res://test"
	var framework_filter: String = str(params.get("framework", "")).strip_edges().to_lower()

	var validation: Dictionary = _validate_test_path(search_path, true)
	if validation.has("error"):
		return validation
	search_path = String(validation["sanitized"])

	var absolute_root: String = ProjectSettings.globalize_path(search_path)
	var dir: DirAccess = DirAccess.open(absolute_root)
	if dir == null:
		return {"error": "Test directory not found: " + search_path}

	var runner_availability: Dictionary = _get_project_test_runner_availability_map()
	var tests: Array = []
	_collect_project_tests_recursive(search_path, absolute_root, framework_filter, runner_availability, tests)
	tests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("test_path", "")) < String(b.get("test_path", ""))
	)

	return {
		"count": tests.size(),
		"search_path": search_path,
		"tests": tests
	}

# ============================================================================
# list_project_test_runners - 列出项目测试 runner 可用性
# ============================================================================

func _register_list_project_test_runners(server_core: RefCounted) -> void:
	server_core.register_tool(
		"list_project_test_runners",
		"Report current runner availability for supported project test frameworks without executing project tests.",
		{
			"type": "object",
			"properties": {}
		},
		Callable(self, "_tool_list_project_test_runners"),
		{
			"type": "object",
			"properties": {
				"count": {"type": "integer"},
				"runners": {"type": "array"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Project-Advanced"
	)

func _tool_list_project_test_runners(_params: Dictionary) -> Dictionary:
	var runners: Array = _get_project_test_runner_entries()
	return {
		"count": runners.size(),
		"runners": runners
	}

# ============================================================================
# inspect_project_test - 检查单个项目测试
# ============================================================================

func _register_inspect_project_test(server_core: RefCounted) -> void:
	server_core.register_tool(
		"inspect_project_test",
		"Inspect one project test entry and return the same normalized metadata shape used by list_project_tests.",
		{
			"type": "object",
			"properties": {
				"test_path": {"type": "string", "description": "res:// path to a single project test file under test/."}
			},
			"required": ["test_path"]
		},
		Callable(self, "_tool_inspect_project_test"),
		{
			"type": "object",
			"properties": {
				"test_path": {"type": "string"},
				"exists": {"type": "boolean"},
				"framework": {"type": "string"},
				"kind": {"type": "string"},
				"runnable": {"type": "boolean"},
				"available_runner": {"type": "boolean"},
				"name": {"type": "string"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Project-Advanced"
	)

func _tool_inspect_project_test(params: Dictionary) -> Dictionary:
	var test_path: String = str(params.get("test_path", "")).strip_edges()
	if test_path.is_empty():
		return {"error": "Missing required parameter: test_path"}

	var validation: Dictionary = _validate_test_path(test_path, false)
	if validation.has("error"):
		return validation
	test_path = String(validation["sanitized"])

	var entry: Dictionary = _build_project_test_entry(test_path, _get_project_test_runner_availability_map())
	if entry.is_empty():
		return {
			"test_path": test_path,
			"exists": false
		}

	entry["exists"] = true
	return entry

# ============================================================================
# run_project_test - 运行项目测试
# ============================================================================

func _register_run_project_test(server_core: RefCounted) -> void:
	server_core.register_tool(
		"run_project_test",
		"Run a single project test script. Python integration tests are executed with python. GUT unit tests are executed through Godot headless when addons/gut is available.",
		{
			"type": "object",
			"properties": {
				"test_path": {"type": "string", "description": "res:// path to a project test file under test/."},
				"timeout_ms": {"type": "integer", "description": "Reserved timeout hint for the caller. The process itself runs synchronously."}
			},
			"required": ["test_path"]
		},
		Callable(self, "_tool_run_project_test"),
		{
			"type": "object",
			"properties": {
				"status": {"type": "string"},
				"framework": {"type": "string"},
				"test_path": {"type": "string"},
				"exit_code": {"type": "integer"},
				"command": {"type": "array"},
				"output": {"type": "array"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Project-Advanced"
	)

func _tool_run_project_test(params: Dictionary) -> Dictionary:
	var test_path: String = str(params.get("test_path", "")).strip_edges()
	if test_path.is_empty():
		return {"error": "Missing required parameter: test_path"}

	var validation: Dictionary = _validate_test_path(test_path, false)
	if validation.has("error"):
		return validation
	test_path = String(validation["sanitized"])

	var extension: String = test_path.get_extension().to_lower()
	var absolute_test_path: String = ProjectSettings.globalize_path(test_path)
	if not FileAccess.file_exists(test_path):
		return {"error": "Test file not found: " + test_path}

	match extension:
		"py":
			return _run_python_project_test(test_path, absolute_test_path)
		"gd":
			return _run_gut_project_test(test_path)
		_:
			return {"error": "Unsupported project test type: " + extension}

func _register_run_project_tests(server_core: RefCounted) -> void:
	server_core.register_tool(
		"run_project_tests",
		"Discover and run multiple project tests from a directory. Reuses the same framework filters as list_project_tests and aggregates pass/fail counts.",
		{
			"type": "object",
			"properties": {
				"search_path": {"type": "string", "description": "Optional res:// path to limit discovery. Default is res://test."},
				"framework": {"type": "string", "description": "Optional framework filter: python or gut."},
				"only_runnable": {"type": "boolean", "description": "Whether to skip discovered tests that are not currently runnable. Default is true."}
			}
		},
		Callable(self, "_tool_run_project_tests"),
		{
			"type": "object",
			"properties": {
				"status": {"type": "string"},
				"search_path": {"type": "string"},
				"framework": {"type": "string"},
				"total_count": {"type": "integer"},
				"passed_count": {"type": "integer"},
				"failed_count": {"type": "integer"},
				"skipped_count": {"type": "integer"},
				"results": {"type": "array"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Project-Advanced"
	)

func _tool_run_project_tests(params: Dictionary) -> Dictionary:
	var list_result: Dictionary = _tool_list_project_tests({
		"search_path": params.get("search_path", "res://test"),
		"framework": params.get("framework", "")
	})
	if list_result.has("error"):
		return list_result

	var only_runnable: bool = bool(params.get("only_runnable", true))
	var discovered_tests: Array = list_result.get("tests", [])
	var results: Array = []
	var passed_count: int = 0
	var failed_count: int = 0
	var skipped_count: int = 0

	for entry in discovered_tests:
		if not (entry is Dictionary):
			continue
		var test_entry: Dictionary = entry
		if only_runnable and not bool(test_entry.get("runnable", false)):
			skipped_count += 1
			results.append({
				"status": "skipped",
				"test_path": String(test_entry.get("test_path", "")),
				"framework": String(test_entry.get("framework", "")),
				"reason": "No available runner"
			})
			continue
		var test_result: Dictionary = _tool_run_project_test({"test_path": String(test_entry.get("test_path", ""))})
		results.append(test_result)
		if test_result.get("status", "") == "passed":
			passed_count += 1
		else:
			failed_count += 1

	var aggregate_status: String = "passed"
	if failed_count > 0:
		aggregate_status = "failed"
	elif passed_count == 0 and skipped_count > 0:
		aggregate_status = "skipped"

	return {
		"status": aggregate_status,
		"search_path": list_result.get("search_path", ""),
		"framework": str(params.get("framework", "")).strip_edges().to_lower(),
		"total_count": results.size(),
		"passed_count": passed_count,
		"failed_count": failed_count,
		"skipped_count": skipped_count,
		"results": results
	}

func _validate_test_path(path: String, expect_directory: bool) -> Dictionary:
	if path.is_empty():
		return {"error": "Test path cannot be empty"}
	if not path.begins_with("res://"):
		return {"error": "Test path must start with res://"}
	if not (path.begins_with("res://test/") or path.begins_with("res://.tmp_") or path.contains("/.tmp_")):
		return {"error": "Test path must stay under res://test/ or a temporary test directory"}
	var validation: Dictionary = PathValidator.validate_directory_path(path) if expect_directory else PathValidator.validate_path(path)
	if not validation.get("valid", false):
		return {"error": "Invalid path: " + str(validation.get("error", "unknown"))}
	return {"sanitized": String(validation.get("sanitized", path))}

func _collect_project_tests_recursive(search_path: String, absolute_root: String, framework_filter: String, runner_availability: Dictionary, tests: Array) -> void:
	var dir: DirAccess = DirAccess.open(absolute_root)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry_name: String = dir.get_next()
		if entry_name.is_empty():
			break
		if entry_name == "." or entry_name == "..":
			continue
		var child_res_path: String = search_path.path_join(entry_name)
		var child_abs_path: String = absolute_root.path_join(entry_name)
		if dir.current_is_dir():
			_collect_project_tests_recursive(child_res_path, child_abs_path, framework_filter, runner_availability, tests)
			continue
		var test_entry: Dictionary = _build_project_test_entry(child_res_path, runner_availability)
		if test_entry.is_empty():
			continue
		var framework: String = String(test_entry.get("framework", ""))
		if not framework_filter.is_empty() and framework != framework_filter:
			continue
		tests.append(test_entry)
	dir.list_dir_end()

func _build_project_test_entry(test_path: String, runner_availability: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(test_path):
		return {}
	var extension: String = test_path.get_extension().to_lower()
	var framework: String = ""
	var kind: String = ""
	match extension:
		"py":
			framework = "python"
			kind = "integration"
		"gd":
			framework = "gut"
			kind = "unit"
		_:
			return {}
	var runner_info: Dictionary = runner_availability.get(framework, {})
	var runnable: bool = bool(runner_info.get("available", false))
	return {
		"test_path": test_path,
		"framework": framework,
		"kind": kind,
		"runnable": runnable,
		"available_runner": runnable,
		"name": test_path.get_file()
	}

func _get_project_test_runner_entries() -> Array:
	var entries: Array = []

	var python_logs: Array = []
	var python_exit_code: int = OS.execute("python", ["--version"], python_logs, true)
	var python_available: bool = python_exit_code == OK
	entries.append({
		"framework": "python",
		"kind": "integration",
		"available": python_available,
		"probe_exit_code": python_exit_code,
		"command": ["python", "--version"],
		"reason": "python command is executable in the current environment" if python_available else "python command is not available in the current environment"
	})

	var gut_cmdln_path: String = "res://addons/gut/gut_cmdln.gd"
	var gut_available: bool = FileAccess.file_exists(gut_cmdln_path)
	entries.append({
		"framework": "gut",
		"kind": "unit",
		"available": gut_available,
		"runner_path": gut_cmdln_path,
		"command": [OS.get_executable_path(), "--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", gut_cmdln_path, "-gtest=<path>", "-gexit"],
		"reason": "GUT command-line runner is installed" if gut_available else "GUT is not installed at res://addons/gut/gut_cmdln.gd"
	})

	return entries

func _get_project_test_runner_availability_map() -> Dictionary:
	var availability: Dictionary = {}
	for entry_variant in _get_project_test_runner_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var framework: String = String(entry.get("framework", ""))
		if framework.is_empty():
			continue
		availability[framework] = entry
	return availability

func _build_project_resource_detail(resource_path: String, property_filter: String, include_property_values: bool, max_properties: int) -> Dictionary:
	var detail: Dictionary = {
		"resource_path": resource_path,
		"is_loadable": false,
		"class_name": "",
		"script_path": "",
		"property_count": 0,
		"returned_property_count": 0,
		"properties": [],
		"properties_truncated": false,
		"has_more_properties": false,
		"max_properties_applied": max_properties
	}

	var resource: Resource = ResourceLoader.load(resource_path)
	if not resource:
		detail["load_error"] = "Failed to load resource"
		return detail

	detail["is_loadable"] = true
	detail["class_name"] = resource.get_class()
	var script: Script = resource.get_script() as Script
	if script:
		detail["script_path"] = String(script.resource_path)

	var matching_property_count: int = _count_project_resource_properties(resource, property_filter)
	var sampled_properties: Array = _collect_project_resource_properties(resource, property_filter, include_property_values, max_properties + 1)
	var has_more_properties: bool = sampled_properties.size() > max_properties
	if has_more_properties:
		sampled_properties.resize(max_properties)

	detail["property_count"] = matching_property_count
	detail["returned_property_count"] = sampled_properties.size()
	detail["properties"] = sampled_properties
	detail["properties_truncated"] = has_more_properties
	detail["has_more_properties"] = has_more_properties
	if has_more_properties:
		detail["next_max_properties"] = max_properties * 2

	return detail

func _count_project_resource_properties(resource: Resource, property_filter: String) -> int:
	var count: int = 0
	for property_info_variant in resource.get_property_list():
		var property_info: Dictionary = property_info_variant
		var property_name: String = str(property_info.get("name", ""))
		if property_name.is_empty():
			continue
		if not property_filter.is_empty() and not property_name.to_lower().contains(property_filter):
			continue
		count += 1
	return count

func _collect_project_resource_properties(resource: Resource, property_filter: String, include_property_values: bool, max_properties: int) -> Array:
	var properties: Array = []
	for property_info_variant in resource.get_property_list():
		if properties.size() >= max_properties:
			break
		var property_info: Dictionary = property_info_variant
		var property_name: String = str(property_info.get("name", ""))
		if property_name.is_empty():
			continue
		if not property_filter.is_empty() and not property_name.to_lower().contains(property_filter):
			continue
		var serialized: Dictionary = {
			"name": property_name,
			"type": int(property_info.get("type", TYPE_NIL)),
			"usage": int(property_info.get("usage", 0)),
			"hint": int(property_info.get("hint", PROPERTY_HINT_NONE)),
			"hint_string": str(property_info.get("hint_string", "")),
			"class_name": str(property_info.get("class_name", ""))
		}
		if include_property_values:
			serialized["value"] = _serialize_project_resource_value(resource.get(property_name))
		properties.append(serialized)
	properties.sort_custom(Callable(self, "_compare_named_entries"))
	return properties

func _run_python_project_test(test_path: String, absolute_test_path: String) -> Dictionary:
	var logs: Array = []
	var started_at_ms: int = Time.get_ticks_msec()
	var exit_code: int = OS.execute("python", [absolute_test_path], logs, true)
	var duration_ms: int = Time.get_ticks_msec() - started_at_ms
	var output: Array = []
	for line in logs:
		output.append(str(line))
	return {
		"status": "passed" if exit_code == OK else "failed",
		"framework": "python",
		"kind": "integration",
		"test_path": test_path,
		"exit_code": exit_code,
		"duration_ms": duration_ms,
		"command": ["python", absolute_test_path],
		"output": output
	}

func _run_gut_project_test(test_path: String) -> Dictionary:
	var gut_cmdln_path: String = "res://addons/gut/gut_cmdln.gd"
	if not FileAccess.file_exists(gut_cmdln_path):
		return {"error": "GUT is not installed at res://addons/gut/gut_cmdln.gd"}
	var executable_path: String = OS.get_executable_path()
	var project_path: String = ProjectSettings.globalize_path("res://")
	var args: Array[String] = [
		"--headless",
		"--path", project_path,
		"-s", gut_cmdln_path,
		"-gtest=" + test_path,
		"-gexit"
	]
	var logs: Array = []
	var started_at_ms: int = Time.get_ticks_msec()
	var exit_code: int = OS.execute(executable_path, args, logs, true)
	var duration_ms: int = Time.get_ticks_msec() - started_at_ms
	var output: Array = []
	for line in logs:
		output.append(str(line))
	return {
		"status": "passed" if exit_code == OK else "failed",
		"framework": "gut",
		"kind": "unit",
		"test_path": test_path,
		"exit_code": exit_code,
		"duration_ms": duration_ms,
		"command": [executable_path] + args,
		"output": output
	}

# ============================================================================
# inspect_csharp_project_support - 检查 C# / Mono 项目支持元数据
# ============================================================================

func _register_inspect_csharp_project_support(server_core: RefCounted) -> void:
	var tool_name: String = "inspect_csharp_project_support"
	var description: String = "Inspect C# / Mono project support files such as .csproj and .sln, including target frameworks, assembly metadata, and references."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {
				"type": "string",
				"description": "Directory to scan. Default is res://.",
				"default": "res://"
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {"type": "string"},
			"project_count": {"type": "integer"},
			"solution_count": {"type": "integer"},
			"projects": {"type": "array"},
			"solutions": {"type": "array"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_inspect_csharp_project_support"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_inspect_csharp_project_support(params: Dictionary) -> Dictionary:
	var search_path: String = str(params.get("search_path", "res://")).strip_edges()
	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	search_path = validation["sanitized"]

	var project_paths: Array[String] = []
	var solution_paths: Array[String] = []
	_collect_resources(search_path, [".csproj"], project_paths)
	_collect_resources(search_path, [".sln"], solution_paths)
	project_paths.sort()
	solution_paths.sort()

	var projects: Array = []
	for project_path in project_paths:
		projects.append(_inspect_csproj_file(project_path))

	var solutions: Array = []
	for solution_path in solution_paths:
		solutions.append(_inspect_solution_file(solution_path))

	return {
		"search_path": search_path,
		"project_count": projects.size(),
		"solution_count": solutions.size(),
		"projects": projects,
		"solutions": solutions
	}

# ============================================================================
# compare_render_screenshots - 比较渲染截图
# ============================================================================

func _register_compare_render_screenshots(server_core: RefCounted) -> void:
	var tool_name: String = "compare_render_screenshots"
	var description: String = "Compare two screenshot images and report pixel differences, RMSE, and threshold-based match status."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"baseline_path": {
				"type": "string",
				"description": "Baseline screenshot image path."
			},
			"candidate_path": {
				"type": "string",
				"description": "Candidate screenshot image path."
			},
			"max_diff_pixels": {
				"type": "integer",
				"description": "Maximum differing pixels allowed for a passing match. Default is 0.",
				"default": 0
			}
		},
		"required": ["baseline_path", "candidate_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"baseline_path": {"type": "string"},
			"candidate_path": {"type": "string"},
			"width": {"type": "integer"},
			"height": {"type": "integer"},
			"diff_pixel_count": {"type": "integer"},
			"diff_ratio": {"type": "number"},
			"rmse": {"type": "number"},
			"max_channel_delta": {"type": "number"},
			"matches": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_compare_render_screenshots"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_compare_render_screenshots(params: Dictionary) -> Dictionary:
	var baseline_path: String = str(params.get("baseline_path", "")).strip_edges()
	var candidate_path: String = str(params.get("candidate_path", "")).strip_edges()
	if baseline_path.is_empty():
		return {"error": "Missing required parameter: baseline_path"}
	if candidate_path.is_empty():
		return {"error": "Missing required parameter: candidate_path"}

	var baseline_validation: Dictionary = PathValidator.validate_file_path(baseline_path, [".png", ".jpg", ".jpeg", ".webp", ".bmp"])
	if not baseline_validation.get("valid", false):
		return {"error": baseline_validation.get("error", "Invalid baseline_path")}
	baseline_path = str(baseline_validation.get("sanitized", baseline_path))

	var candidate_validation: Dictionary = PathValidator.validate_file_path(candidate_path, [".png", ".jpg", ".jpeg", ".webp", ".bmp"])
	if not candidate_validation.get("valid", false):
		return {"error": candidate_validation.get("error", "Invalid candidate_path")}
	candidate_path = str(candidate_validation.get("sanitized", candidate_path))

	var baseline_image: Image = Image.load_from_file(ProjectSettings.globalize_path(baseline_path))
	var candidate_image: Image = Image.load_from_file(ProjectSettings.globalize_path(candidate_path))
	if baseline_image == null or baseline_image.is_empty():
		return {"error": "Failed to load baseline image: " + baseline_path}
	if candidate_image == null or candidate_image.is_empty():
		return {"error": "Failed to load candidate image: " + candidate_path}

	if baseline_image.get_width() != candidate_image.get_width() or baseline_image.get_height() != candidate_image.get_height():
		return {
			"baseline_path": baseline_path,
			"candidate_path": candidate_path,
			"width": baseline_image.get_width(),
			"height": baseline_image.get_height(),
			"candidate_width": candidate_image.get_width(),
			"candidate_height": candidate_image.get_height(),
			"matches": false,
			"error": "Image dimensions do not match"
		}

	var width: int = baseline_image.get_width()
	var height: int = baseline_image.get_height()
	var diff_pixel_count: int = 0
	var max_channel_delta: float = 0.0
	var squared_error_sum: float = 0.0

	for y in range(height):
		for x in range(width):
			var baseline_color: Color = baseline_image.get_pixel(x, y)
			var candidate_color: Color = candidate_image.get_pixel(x, y)
			var dr: float = absf(baseline_color.r - candidate_color.r)
			var dg: float = absf(baseline_color.g - candidate_color.g)
			var db: float = absf(baseline_color.b - candidate_color.b)
			var da: float = absf(baseline_color.a - candidate_color.a)
			var pixel_delta: float = maxf(maxf(dr, dg), maxf(db, da))
			if pixel_delta > 0.00001:
				diff_pixel_count += 1
			max_channel_delta = maxf(max_channel_delta, pixel_delta)
			squared_error_sum += dr * dr + dg * dg + db * db + da * da

	var total_pixels: int = width * height
	var total_channels: int = total_pixels * 4
	var rmse: float = sqrt(squared_error_sum / float(total_channels)) if total_channels > 0 else 0.0
	var diff_ratio: float = float(diff_pixel_count) / float(total_pixels) if total_pixels > 0 else 0.0
	var max_diff_pixels: int = max(0, int(params.get("max_diff_pixels", 0)))

	return {
		"baseline_path": baseline_path,
		"candidate_path": candidate_path,
		"width": width,
		"height": height,
		"diff_pixel_count": diff_pixel_count,
		"diff_ratio": diff_ratio,
		"rmse": rmse,
		"max_channel_delta": max_channel_delta,
		"matches": diff_pixel_count <= max_diff_pixels
	}

# ============================================================================
# inspect_tileset_resource - 检查 TileSet 资源
# ============================================================================

func _register_inspect_tileset_resource(server_core: RefCounted) -> void:
	var tool_name: String = "inspect_tileset_resource"
	var description: String = "Inspect a TileSet resource and summarize its sources, atlas tiles, and scene tiles."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "Path to a TileSet resource, such as 'res://tiles/terrain.tres'."
			},
			"include_tiles": {
				"type": "boolean",
				"description": "Whether to include per-tile entries for atlas and scene sources. Default is true."
			}
		},
		"required": ["resource_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {"type": "string"},
			"source_count": {"type": "integer"},
			"tile_size": {"type": "object"},
			"sources": {"type": "array"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_inspect_tileset_resource"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_inspect_tileset_resource(params: Dictionary) -> Dictionary:
	var resource_path: String = str(params.get("resource_path", "")).strip_edges()
	if resource_path.is_empty():
		return {"error": "Missing required parameter: resource_path"}

	var validation: Dictionary = PathValidator.validate_file_path(resource_path, [".tres", ".res"])
	if not validation.get("valid", false):
		return {"error": validation.get("error", "Invalid resource path")}
	resource_path = str(validation.get("sanitized", resource_path))

	if not FileAccess.file_exists(resource_path):
		return {"error": "File not found: " + resource_path}

	var resource: Resource = ResourceLoader.load(resource_path)
	if resource == null:
		return {"error": "Failed to load resource: " + resource_path}
	if not (resource is TileSet):
		return {"error": "Resource is not a TileSet: " + resource_path}

	var tile_set: TileSet = resource as TileSet
	var include_tiles: bool = bool(params.get("include_tiles", true))
	var sources: Array = []
	for index in range(tile_set.get_source_count()):
		var source_id: int = tile_set.get_source_id(index)
		var source: TileSetSource = tile_set.get_source(source_id)
		sources.append(_serialize_tileset_source(source_id, source, include_tiles))

	return {
		"resource_path": resource_path,
		"source_count": tile_set.get_source_count(),
		"tile_size": _serialize_vector2i(tile_set.tile_size),
		"sources": sources
	}

# ============================================================================
# list_project_resources - 列出项目资源
# ============================================================================

func _register_list_project_resources(server_core: RefCounted) -> void:
	var tool_name: String = "list_project_resources"
	var description: String = "List all resource files in the project (.tres, .res, .png, .ogg, etc.)."

	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {
				"type": "string",
				"description": "Optional subpath to search. Default is 'res://'.",
				"default": "res://"
			},
			"resource_types": {
				"type": "array",
				"items": {"type": "string"},
				"description": "Optional list of file extensions to filter (e.g. ['.tres', '.png']). Returns all if not provided."
			},
			"include_resource_details": {
				"type": "boolean",
				"description": "Whether to load each listed resource and include a bounded property summary. Default is false.",
				"default": false
			},
			"include_property_values": {
				"type": "boolean",
				"description": "When include_resource_details is true, whether to serialize property values in returned property entries. Default is false.",
				"default": false
			},
			"property_filter": {
				"type": "string",
				"description": "Optional case-insensitive substring filter applied to property names when include_resource_details is true."
			},
			"max_properties": {
				"type": "integer",
				"description": "Maximum matching properties to return per resource detail entry. Default is 40.",
				"default": 40
			}
		}
	}

	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resources": {
				"type": "array",
				"items": {"type": "string"}
			},
			"count": {"type": "integer"},
			"details_included": {"type": "boolean"},
			"include_property_values": {"type": "boolean"},
			"property_filter_applied": {"type": "string"},
			"max_properties_applied": {"type": "integer"},
			"resource_details": {"type": "array"}
		}
	}

	# annotations - readOnlyHint = true
	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_list_project_resources"),
						  output_schema, annotations,
						  "core", "Project")

func _tool_list_project_resources(params: Dictionary) -> Dictionary:
	# 参数提取
	var search_path: String = params.get("search_path", "res://")
	var resource_types: Array = params.get("resource_types", [])
	var include_resource_details: bool = bool(params.get("include_resource_details", false))
	var include_property_values: bool = bool(params.get("include_property_values", false))
	var property_filter: String = str(params.get("property_filter", "")).strip_edges().to_lower()
	var max_properties: int = max(1, int(params.get("max_properties", 40)))

	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}

	# 使用清理后的路径
	search_path = validation["sanitized"]

	# 常见资源扩展名
	var default_extensions: Array[String] = [
		".tres", ".res", ".otr", ".font", ".theme",
		".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp", ".hdr",
		".ogg", ".wav", ".mp3", ".oggstr",
		".obj", ".glb", ".gltf", ".mesh", ".fbx",
		".material", ".shader", ".gdshader",
		".tscn", ".gd", ".cfg", ".json",
		".ttf", ".otf", ".woff", ".woff2"
	]

	# 如果提供了resource_types，使用它；否则使用默认扩展名
	var extensions: Array[String] = []
	if resource_types.size() > 0:
		for ext in resource_types:
			var ext_str: String = str(ext)
			if not ext_str.begins_with("."):
				ext_str = "." + ext_str
			extensions.append(ext_str)
	else:
		extensions = default_extensions

	# 使用DirAccess递归查找资源文件
	var resources: Array[String] = []
	_collect_resources(search_path, extensions, resources)

	# 排序
	resources.sort()

	var result: Dictionary = {
		"resources": resources,
		"count": resources.size(),
		"details_included": include_resource_details,
		"include_property_values": include_property_values if include_resource_details else false,
		"property_filter_applied": property_filter,
		"max_properties_applied": max_properties,
		"resource_details": []
	}
	if include_resource_details:
		var resource_details: Array = []
		for resource_path in resources:
			resource_details.append(_build_project_resource_detail(resource_path, property_filter, include_property_values, max_properties))
		result["resource_details"] = resource_details

	return result

# ============================================================================
# inspect_project_resource - 检查单个项目资源
# ============================================================================

func _register_inspect_project_resource(server_core: RefCounted) -> void:
	var tool_name: String = "inspect_project_resource"
	var description: String = "Inspect a single project resource with truthful load errors and a bounded property summary."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "Resource path to inspect, such as 'res://resources/example.tres'."
			},
			"include_property_values": {
				"type": "boolean",
				"description": "Whether to serialize property values in returned property entries. Default is false.",
				"default": false
			},
			"property_filter": {
				"type": "string",
				"description": "Optional case-insensitive substring filter applied to property names."
			},
			"max_properties": {
				"type": "integer",
				"description": "Maximum matching properties to return. Default is 40.",
				"default": 40
			}
		},
		"required": ["resource_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {"type": "string"},
			"is_loadable": {"type": "boolean"},
			"class_name": {"type": "string"},
			"script_path": {"type": "string"},
			"property_filter_applied": {"type": "string"},
			"include_property_values": {"type": "boolean"},
			"property_count": {"type": "integer"},
			"returned_property_count": {"type": "integer"},
			"properties": {"type": "array"},
			"properties_truncated": {"type": "boolean"},
			"has_more_properties": {"type": "boolean"},
			"max_properties_applied": {"type": "integer"},
			"next_max_properties": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_inspect_project_resource"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_inspect_project_resource(params: Dictionary) -> Dictionary:
	var resource_path: String = str(params.get("resource_path", "")).strip_edges()
	if resource_path.is_empty():
		return {"error": "Missing required parameter: resource_path"}

	var validation: Dictionary = PathValidator.validate_path(resource_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	resource_path = validation["sanitized"]

	if not FileAccess.file_exists(resource_path):
		return {"error": "File not found: " + resource_path}

	var include_property_values: bool = bool(params.get("include_property_values", false))
	var property_filter: String = str(params.get("property_filter", "")).strip_edges().to_lower()
	var max_properties: int = max(1, int(params.get("max_properties", 40)))
	var detail: Dictionary = _build_project_resource_detail(resource_path, property_filter, include_property_values, max_properties)
	if not bool(detail.get("is_loadable", false)):
		return {"error": "Failed to load resource: " + resource_path}

	detail["property_filter_applied"] = property_filter
	detail["include_property_values"] = include_property_values
	return detail

# ============================================================================
# update_project_resource_properties - 更新单个项目资源属性并原地保存
# ============================================================================

func _register_update_project_resource_properties(server_core: RefCounted) -> void:
	var tool_name: String = "update_project_resource_properties"
	var description: String = "Update provided properties on one existing resource and save it in place."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "Existing resource path to update, such as 'res://resources/example.tres'."
			},
			"properties": {
				"type": "object",
				"description": "Property values to update before saving the resource in place."
			}
		},
		"required": ["resource_path", "properties"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"resource_path": {"type": "string"},
			"class_name": {"type": "string"},
			"updated_properties": {"type": "array"},
			"updated_property_count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_update_project_resource_properties"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_update_project_resource_properties(params: Dictionary) -> Dictionary:
	var resource_path: String = str(params.get("resource_path", "")).strip_edges()
	if resource_path.is_empty():
		return {"error": "Missing required parameter: resource_path"}

	var properties: Dictionary = params.get("properties", {})
	if properties.is_empty():
		return {"error": "Missing required parameter: properties"}

	var validation: Dictionary = PathValidator.validate_file_path(resource_path, [".tres", ".res"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	resource_path = validation["sanitized"]

	if not FileAccess.file_exists(resource_path):
		return {"error": "File not found: " + resource_path}

	var resource: Resource = ResourceLoader.load(resource_path)
	if not resource:
		return {"error": "Failed to load resource: " + resource_path}

	var property_info_by_name: Dictionary = {}
	for property_info_variant in resource.get_property_list():
		var property_info: Dictionary = property_info_variant
		var property_name: String = str(property_info.get("name", ""))
		if property_name.is_empty():
			continue
		property_info_by_name[property_name] = property_info

	var updated_properties: Array[String] = []
	for property_name in properties.keys():
		var property_name_text: String = str(property_name)
		if not property_info_by_name.has(property_name_text):
			return {"error": "Unknown resource property: " + property_name_text}
		var property_info: Dictionary = property_info_by_name[property_name_text]
		var coerced: Dictionary = _coerce_project_resource_value(properties[property_name], int(property_info.get("type", TYPE_NIL)))
		if not bool(coerced.get("ok", false)):
			return {"error": "Unsupported value for property '%s': %s" % [property_name_text, str(coerced.get("error", "unknown error"))]}
		resource.set(property_name_text, coerced.get("value"))
		updated_properties.append(property_name_text)

	var save_error: Error = ResourceSaver.save(resource, resource_path)
	if save_error != OK:
		return {"error": "Failed to save resource: " + error_string(save_error)}

	updated_properties.sort()
	return {
		"status": "success",
		"resource_path": resource_path,
		"class_name": resource.get_class(),
		"updated_properties": updated_properties,
		"updated_property_count": updated_properties.size()
	}

# ============================================================================
# duplicate_project_resource - 复制单个项目资源到新路径
# ============================================================================

func _register_duplicate_project_resource(server_core: RefCounted) -> void:
	var tool_name: String = "duplicate_project_resource"
	var description: String = "Duplicate one existing .tres/.res resource to a new path without mutating the source."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"source_path": {
				"type": "string",
				"description": "Existing .tres/.res resource path to duplicate."
			},
			"destination_path": {
				"type": "string",
				"description": "New .tres/.res resource path that will receive the duplicated resource."
			}
		},
		"required": ["source_path", "destination_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"source_path": {"type": "string"},
			"destination_path": {"type": "string"},
			"class_name": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_duplicate_project_resource"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_duplicate_project_resource(params: Dictionary) -> Dictionary:
	var source_path: String = str(params.get("source_path", "")).strip_edges()
	if source_path.is_empty():
		return {"error": "Missing required parameter: source_path"}
	var destination_path: String = str(params.get("destination_path", "")).strip_edges()
	if destination_path.is_empty():
		return {"error": "Missing required parameter: destination_path"}

	var source_validation: Dictionary = PathValidator.validate_file_path(source_path, [".tres", ".res"])
	if not source_validation["valid"]:
		return {"error": "Invalid source path: " + source_validation["error"]}
	source_path = source_validation["sanitized"]

	var destination_validation: Dictionary = PathValidator.validate_file_path(destination_path, [".tres", ".res"])
	if not destination_validation["valid"]:
		return {"error": "Invalid destination path: " + destination_validation["error"]}
	destination_path = destination_validation["sanitized"]

	if source_path == destination_path:
		return {"error": "Destination path must differ from source path"}
	if not FileAccess.file_exists(source_path):
		return {"error": "File not found: " + source_path}
	if FileAccess.file_exists(destination_path):
		return {"error": "File already exists: " + destination_path}

	var source_resource: Resource = ResourceLoader.load(source_path)
	if not source_resource:
		return {"error": "Failed to load resource: " + source_path}

	var destination_dir: String = destination_path.get_base_dir()
	if not destination_dir.is_empty():
		var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_dir))
		if make_dir_error != OK:
			return {"error": "Failed to create destination directory: " + destination_dir}

	var duplicated_resource: Resource = source_resource.duplicate(true)
	if not duplicated_resource:
		return {"error": "Failed to duplicate resource: " + source_path}

	var save_error: Error = ResourceSaver.save(duplicated_resource, destination_path)
	if save_error != OK:
		return {"error": "Failed to save duplicated resource: " + error_string(save_error)}

	return {
		"status": "success",
		"source_path": source_path,
		"destination_path": destination_path,
		"class_name": duplicated_resource.get_class()
	}

# ============================================================================
# delete_project_resource - 删除单个项目资源
# ============================================================================

func _register_delete_project_resource(server_core: RefCounted) -> void:
	var tool_name: String = "delete_project_resource"
	var description: String = "Delete one existing .tres/.res project resource file."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "Existing .tres/.res resource path to delete."
			}
		},
		"required": ["resource_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"resource_path": {"type": "string"},
			"removed": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_delete_project_resource"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_delete_project_resource(params: Dictionary) -> Dictionary:
	var resource_path: String = str(params.get("resource_path", "")).strip_edges()
	if resource_path.is_empty():
		return {"error": "Missing required parameter: resource_path"}

	var validation: Dictionary = PathValidator.validate_file_path(resource_path, [".tres", ".res"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	resource_path = validation["sanitized"]

	if not FileAccess.file_exists(resource_path):
		return {"error": "File not found: " + resource_path}

	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
	if remove_error != OK:
		return {"error": "Failed to delete resource: " + error_string(remove_error)}

	var editor_interface = _get_editor_interface()
	if editor_interface:
		var fs: EditorFileSystem = editor_interface.get_resource_filesystem()
		if fs:
			fs.update_file(resource_path)

	return {
		"status": "success",
		"resource_path": resource_path,
		"removed": true
	}

# ============================================================================
# move_project_resource - 移动或重命名单个项目资源
# ============================================================================

func _register_move_project_resource(server_core: RefCounted) -> void:
	var tool_name: String = "move_project_resource"
	var description: String = "Move or rename one existing .tres/.res resource to a new path."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"source_path": {
				"type": "string",
				"description": "Existing .tres/.res resource path to move."
			},
			"destination_path": {
				"type": "string",
				"description": "New .tres/.res resource path that will receive the moved resource."
			}
		},
		"required": ["source_path", "destination_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"source_path": {"type": "string"},
			"destination_path": {"type": "string"},
			"moved": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_move_project_resource"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_move_project_resource(params: Dictionary) -> Dictionary:
	var source_path: String = str(params.get("source_path", "")).strip_edges()
	if source_path.is_empty():
		return {"error": "Missing required parameter: source_path"}
	var destination_path: String = str(params.get("destination_path", "")).strip_edges()
	if destination_path.is_empty():
		return {"error": "Missing required parameter: destination_path"}

	var source_validation: Dictionary = PathValidator.validate_file_path(source_path, [".tres", ".res"])
	if not source_validation["valid"]:
		return {"error": "Invalid source path: " + source_validation["error"]}
	source_path = source_validation["sanitized"]

	var destination_validation: Dictionary = PathValidator.validate_file_path(destination_path, [".tres", ".res"])
	if not destination_validation["valid"]:
		return {"error": "Invalid destination path: " + destination_validation["error"]}
	destination_path = destination_validation["sanitized"]

	if source_path == destination_path:
		return {"error": "Destination path must differ from source path"}
	if not FileAccess.file_exists(source_path):
		return {"error": "File not found: " + source_path}
	if FileAccess.file_exists(destination_path):
		return {"error": "File already exists: " + destination_path}

	var destination_dir: String = destination_path.get_base_dir()
	if not destination_dir.is_empty():
		var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_dir))
		if make_dir_error != OK:
			return {"error": "Failed to create destination directory: " + destination_dir}

	var move_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(destination_path)
	)
	if move_error != OK:
		return {"error": "Failed to move resource: " + error_string(move_error)}

	var editor_interface = _get_editor_interface()
	if editor_interface:
		var fs: EditorFileSystem = editor_interface.get_resource_filesystem()
		if fs:
			fs.update_file(destination_path)

	return {
		"status": "success",
		"source_path": source_path,
		"destination_path": destination_path,
		"moved": true
	}

# 辅助函数：递归收集资源文件
func _collect_resources(directory_path: String, extensions: Array[String], result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(directory_path)

	if not dir:
		return

	# 列出所有文件和目录
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while not file_name.is_empty():
		# 跳过特殊目录
		if file_name != "." and file_name != "..":
			var full_path: String = directory_path
			if not full_path.ends_with("/"):
				full_path += "/"
			full_path += file_name

			if dir.current_is_dir():
				# 递归处理子目录
				_collect_resources(full_path, extensions, result)
			else:
				# 检查文件扩展名
				for ext in extensions:
					if file_name.ends_with(ext):
						result.append(full_path)
						break

		file_name = dir.get_next()

	dir.list_dir_end()

# ============================================================================
# create_resource - 创建资源
# ============================================================================

func _register_create_resource(server_core: RefCounted) -> void:
	var tool_name: String = "create_resource"
	var description: String = "Create a new Godot resource file (.tres). Supports common resource types."

	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "Path where the resource will be saved (e.g. 'res://resources/my_curve.tres')"
			},
			"resource_type": {
				"type": "string",
				"description": "Type of resource to create (e.g. 'Curve', 'Gradient', 'StyleBoxFlat', 'Animation')"
			},
			"properties": {
				"type": "object",
				"description": "Optional dictionary of property values to set on the resource"
			}
		},
		"required": ["resource_path", "resource_type"]
	}

	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"resource_path": {"type": "string"},
			"resource_type": {"type": "string"}
		}
	}

	# annotations
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_create_resource"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_create_resource(params: Dictionary) -> Dictionary:
	# 参数提取
	var resource_path: String = params.get("resource_path", "")
	var resource_type: String = params.get("resource_type", "")
	var properties: Dictionary = params.get("properties", {})

	# 参数验证
	if resource_path.is_empty():
		return {"error": "Missing required parameter: resource_path"}
	if resource_type.is_empty():
		return {"error": "Missing required parameter: resource_type"}

	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(resource_path, [".tres", ".res"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}

	# 使用清理后的路径
	resource_path = validation["sanitized"]

	# 验证资源类型
	if not ClassDB.class_exists(resource_type):
		return {"error": "Invalid resource type: " + resource_type}

	if not ClassDB.is_parent_class(resource_type, "Resource"):
		return {"error": "Type '%s' is not a Resource type" % resource_type}

	# 创建资源实例
	var resource: RefCounted = ClassDB.instantiate(resource_type)

	if not resource:
		return {"error": "Failed to create resource of type: " + resource_type}

	# 设置属性（如果有）
	for prop_name in properties:
		if prop_name in resource:
			resource.set(prop_name, properties[prop_name])

	# 保存资源
	var error: Error = ResourceSaver.save(resource, resource_path)

	if error != OK:
		return {"error": "Failed to save resource: " + error_string(error)}

	return {
		"status": "success",
		"resource_path": resource_path,
		"resource_type": resource_type
	}

# ============================================================================
# get_project_structure - 获取项目目录结构
# ============================================================================

func _register_get_project_structure(server_core: RefCounted) -> void:
	var tool_name: String = "get_project_structure"
	var description: String = "Get the project directory structure with file counts by extension. Returns directories and file type statistics."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"max_depth": {
				"type": "integer",
				"description": "Maximum directory depth to traverse. Default is 3.",
				"default": 3
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"directories": {"type": "array", "items": {"type": "string"}},
			"file_counts": {"type": "object"},
			"total_files": {"type": "integer"},
			"total_directories": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_project_structure"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_get_project_structure(params: Dictionary) -> Dictionary:
	var max_depth: int = params.get("max_depth", 3)
	var directories: Array = []
	var file_counts: Dictionary = {}

	_scan_directory("res://", directories, file_counts, 0, max_depth)

	var total_files: int = 0
	for ext in file_counts:
		total_files += file_counts[ext]

	return {
		"directories": directories,
		"file_counts": file_counts,
		"total_files": total_files,
		"total_directories": directories.size()
	}

func _scan_directory(path: String, directories: Array, file_counts: Dictionary, current_depth: int, max_depth: int) -> void:
	if current_depth > max_depth:
		return

	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return

	directories.append(path)

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = path + file_name
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_directory(full_path + "/", directories, file_counts, current_depth + 1, max_depth)
		else:
			var ext: String = file_name.get_extension().to_lower()
			if not ext.is_empty() and ext != "import" and ext != "uid":
				if not file_counts.has(ext):
					file_counts[ext] = 0
				file_counts[ext] += 1
		file_name = dir.get_next()
	dir.list_dir_end()

# ============================================================================
# reimport_resources - 重新导入指定资源
# ============================================================================

func _register_reimport_resources(server_core: RefCounted) -> void:
	var tool_name: String = "reimport_resources"
	var description: String = "Reimport existing project resources using Godot's EditorFileSystem import pipeline."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_paths": {
				"type": "array",
				"items": {"type": "string"},
				"description": "Resource source file paths to reimport, e.g. ['res://icon.png']"
			},
			"refresh_metadata": {
				"type": "boolean",
				"description": "Whether to refresh EditorFileSystem metadata with update_file() before reimport. Default is true.",
				"default": true
			}
		},
		"required": ["resource_paths"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"requested_count": {"type": "integer"},
			"reimported_count": {"type": "integer"},
			"resource_paths": {"type": "array"},
			"invalid_paths": {"type": "array"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_reimport_resources"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_reimport_resources(params: Dictionary) -> Dictionary:
	var raw_paths: Array = params.get("resource_paths", [])
	if raw_paths.is_empty():
		return {"error": "Missing required parameter: resource_paths"}

	var refresh_metadata: bool = params.get("refresh_metadata", true)
	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}

	var fs: EditorFileSystem = editor_interface.get_resource_filesystem()
	if not fs:
		return {"error": "Failed to get EditorFileSystem"}

	if fs.is_scanning():
		return {
			"status": "busy",
			"requested_count": raw_paths.size(),
			"reimported_count": 0,
			"resource_paths": [],
			"invalid_paths": [],
			"scan_progress": fs.get_scanning_progress()
		}

	var valid_paths: Array[String] = []
	var invalid_paths: Array[Dictionary] = []
	for raw_path in raw_paths:
		var resource_path: String = str(raw_path).strip_edges()
		var validation: Dictionary = PathValidator.validate_path(resource_path)
		if not validation["valid"]:
			invalid_paths.append({"path": resource_path, "error": validation["error"]})
			continue
		resource_path = validation["sanitized"]
		if not FileAccess.file_exists(resource_path):
			invalid_paths.append({"path": resource_path, "error": "File not found"})
			continue
		valid_paths.append(resource_path)

	if valid_paths.is_empty():
		return {
			"status": "no_valid_paths",
			"requested_count": raw_paths.size(),
			"reimported_count": 0,
			"resource_paths": [],
			"invalid_paths": invalid_paths
		}

	if refresh_metadata:
		for resource_path in valid_paths:
			fs.update_file(resource_path)

	var packed_paths: PackedStringArray = PackedStringArray()
	for resource_path in valid_paths:
		packed_paths.append(resource_path)
	fs.reimport_files(packed_paths)

	return {
		"status": "success",
		"requested_count": raw_paths.size(),
		"reimported_count": valid_paths.size(),
		"resource_paths": valid_paths,
		"invalid_paths": invalid_paths
	}

# ============================================================================
# get_import_metadata - 读取 .import 元数据
# ============================================================================

func _register_get_import_metadata(server_core: RefCounted) -> void:
	var tool_name: String = "get_import_metadata"
	var description: String = "Read Godot import metadata for a source asset, including importer settings and imported artifact paths."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "Source asset path such as 'res://icon.png'"
			}
		},
		"required": ["resource_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {"type": "string"},
			"import_config_path": {"type": "string"},
			"exists": {"type": "boolean"},
			"importer": {"type": "string"},
			"resource_type": {"type": "string"},
			"uid": {"type": "string"},
			"imported_path": {"type": "string"},
			"sections": {"type": "object"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_import_metadata"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_get_import_metadata(params: Dictionary) -> Dictionary:
	var resource_path: String = str(params.get("resource_path", "")).strip_edges()
	if resource_path.is_empty():
		return {"error": "Missing required parameter: resource_path"}

	var validation: Dictionary = PathValidator.validate_path(resource_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	resource_path = validation["sanitized"]

	var import_config_path: String = resource_path + ".import"
	if not FileAccess.file_exists(import_config_path):
		return {
			"resource_path": resource_path,
			"import_config_path": import_config_path,
			"exists": false
		}

	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(import_config_path)
	if load_error != OK:
		return {"error": "Failed to load import metadata: " + error_string(load_error)}

	var sections: Dictionary = {}
	for raw_section in config.get_sections():
		var section_name: String = str(raw_section)
		var section_values: Dictionary = {}
		for raw_key in config.get_section_keys(section_name):
			var key_name: String = str(raw_key)
			section_values[key_name] = config.get_value(section_name, key_name)
		sections[section_name] = section_values

	var remap: Dictionary = sections.get("remap", {})
	var deps: Dictionary = sections.get("deps", {})
	var params_section: Dictionary = sections.get("params", {})

	return {
		"resource_path": resource_path,
		"import_config_path": import_config_path,
		"exists": true,
		"importer": str(remap.get("importer", "")),
		"resource_type": str(remap.get("type", "")),
		"uid": str(remap.get("uid", "")),
		"imported_path": str(remap.get("path", "")),
		"dependencies": deps,
		"params": params_section,
		"sections": sections
	}

# ============================================================================
# get_resource_uid_info - 读取资源 UID 信息
# ============================================================================

func _register_get_resource_uid_info(server_core: RefCounted) -> void:
	var tool_name: String = "get_resource_uid_info"
	var description: String = "Inspect Godot ResourceUID mappings for a resource path or uid:// identifier."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "Resource path to inspect."
			},
			"uid": {
				"type": "string",
				"description": "Optional uid:// identifier to resolve."
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {"type": "string"},
			"uid": {"type": "string"},
			"uid_id": {"type": "string"},
			"editor_uid": {"type": "string"},
			"resolved_path": {"type": "string"},
			"exists": {"type": "boolean"},
			"has_uid_mapping": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_resource_uid_info"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_get_resource_uid_info(params: Dictionary) -> Dictionary:
	var resource_path: String = str(params.get("resource_path", "")).strip_edges()
	var uid_text: String = str(params.get("uid", "")).strip_edges()
	if resource_path.is_empty() and uid_text.is_empty():
		return {"error": "Provide resource_path or uid"}

	if not resource_path.is_empty():
		var validation: Dictionary = PathValidator.validate_path(resource_path)
		if not validation["valid"]:
			return {"error": "Invalid path: " + validation["error"]}
		resource_path = validation["sanitized"]
		if uid_text.is_empty():
			var mapped_uid: String = ResourceUID.path_to_uid(resource_path)
			if mapped_uid.begins_with("uid://"):
				uid_text = mapped_uid

	if not uid_text.is_empty() and not uid_text.begins_with("uid://"):
		return {"error": "uid must start with uid://"}

	var resolved_path: String = ""
	if not uid_text.is_empty():
		resolved_path = ResourceUID.uid_to_path(uid_text)
		if resource_path.is_empty():
			resource_path = resolved_path

	if not resource_path.is_empty() and uid_text.is_empty():
		var remapped_uid: String = ResourceUID.path_to_uid(resource_path)
		if remapped_uid.begins_with("uid://"):
			uid_text = remapped_uid
			resolved_path = ResourceUID.uid_to_path(uid_text)

	var effective_path: String = resource_path if not resource_path.is_empty() else resolved_path
	var exists: bool = not effective_path.is_empty() and FileAccess.file_exists(effective_path)
	var has_uid_mapping: bool = uid_text.begins_with("uid://")

	return {
		"resource_path": resource_path,
		"uid": uid_text,
		"uid_id": "",
		"resolved_path": resolved_path,
		"exists": exists,
		"has_uid_mapping": has_uid_mapping,
		"editor_uid": ""
	}

# ============================================================================
# fix_resource_uid - 生成或修复资源 UID
# ============================================================================

func _register_fix_resource_uid(server_core: RefCounted) -> void:
	var tool_name: String = "fix_resource_uid"
	var description: String = "Ensure a resource file has a persisted UID and refresh the editor filesystem mapping."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "Resource path to repair, e.g. 'res://resources/example.tres'"
			}
		},
		"required": ["resource_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"resource_path": {"type": "string"},
			"previous_uid": {"type": "string"},
			"uid": {"type": "string"},
			"uid_id": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_fix_resource_uid"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_fix_resource_uid(params: Dictionary) -> Dictionary:
	var resource_path: String = str(params.get("resource_path", "")).strip_edges()
	if resource_path.is_empty():
		return {"error": "Missing required parameter: resource_path"}

	var validation: Dictionary = PathValidator.validate_path(resource_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	resource_path = validation["sanitized"]

	if not FileAccess.file_exists(resource_path):
		return {"error": "File not found: " + resource_path}

	var previous_uid: String = ResourceUID.path_to_uid(resource_path)
	if not previous_uid.begins_with("uid://"):
		previous_uid = ""

	var uid_id: int = ResourceSaver.get_resource_id_for_path(resource_path, true)
	if uid_id == ResourceUID.INVALID_ID:
		return {"error": "Failed to generate resource UID for: " + resource_path}

	var set_error: Error = ResourceSaver.set_uid(resource_path, uid_id)
	if set_error != OK:
		return {"error": "Failed to persist resource UID: " + error_string(set_error)}

	var editor_interface = _get_editor_interface()
	if editor_interface:
		var fs: EditorFileSystem = editor_interface.get_resource_filesystem()
		if fs:
			fs.update_file(resource_path)

	var uid_text: String = ResourceUID.path_to_uid(resource_path)
	return {
		"status": "success",
		"resource_path": resource_path,
		"previous_uid": previous_uid,
		"uid": uid_text,
		"uid_id": str(uid_id)
	}

# ============================================================================
# get_resource_dependencies - 读取资源依赖
# ============================================================================

func _register_get_resource_dependencies(server_core: RefCounted) -> void:
	var tool_name: String = "get_resource_dependencies"
	var description: String = "List parsed resource dependencies using Godot's ResourceLoader dependency metadata."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {
				"type": "string",
				"description": "Resource path to inspect."
			}
		},
		"required": ["resource_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"resource_path": {"type": "string"},
			"dependency_count": {"type": "integer"},
			"dependencies": {"type": "array"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_resource_dependencies"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_get_resource_dependencies(params: Dictionary) -> Dictionary:
	var resource_path: String = str(params.get("resource_path", "")).strip_edges()
	if resource_path.is_empty():
		return {"error": "Missing required parameter: resource_path"}

	var validation: Dictionary = PathValidator.validate_path(resource_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	resource_path = validation["sanitized"]

	if not FileAccess.file_exists(resource_path):
		return {"error": "File not found: " + resource_path}

	var dependencies: Array = _parse_resource_dependencies(resource_path)
	return {
		"resource_path": resource_path,
		"dependency_count": dependencies.size(),
		"dependencies": dependencies
	}

# ============================================================================
# scan_missing_resource_dependencies - 扫描缺失依赖
# ============================================================================

func _register_scan_missing_resource_dependencies(server_core: RefCounted) -> void:
	var tool_name: String = "scan_missing_resource_dependencies"
	var description: String = "Scan project resources for broken or missing dependency references."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {
				"type": "string",
				"description": "Directory to scan. Default is res://.",
				"default": "res://"
			},
			"max_results": {
				"type": "integer",
				"description": "Maximum missing dependency issues to return. Default is 200.",
				"default": 200
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {"type": "string"},
			"scanned_resources": {"type": "integer"},
			"issue_count": {"type": "integer"},
			"issues": {"type": "array"},
			"truncated": {"type": "boolean"},
			"has_more": {"type": "boolean"},
			"max_results_applied": {"type": "integer"},
			"next_max_results": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_scan_missing_resource_dependencies"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_scan_missing_resource_dependencies(params: Dictionary) -> Dictionary:
	var search_path: String = str(params.get("search_path", "res://")).strip_edges()
	var max_results: int = max(1, int(params.get("max_results", 200)))

	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	search_path = validation["sanitized"]

	var dependency_extensions: Array[String] = [
		".tscn", ".scn", ".tres", ".res", ".gd", ".cs", ".gdshader", ".material"
	]
	var resources: Array[String] = []
	_collect_resources(search_path, dependency_extensions, resources)
	resources.sort()

	var sampled_issues: Array = _collect_missing_resource_dependency_issues(resources, max_results + 1)
	var truncated: bool = sampled_issues.size() > max_results
	var issues: Array = sampled_issues.slice(0, max_results)

	return _with_max_results_continuation({
		"search_path": search_path,
		"scanned_resources": resources.size(),
		"issue_count": issues.size(),
		"issues": issues
	}, max_results, truncated)

func _register_scan_cyclic_resource_dependencies(server_core: RefCounted) -> void:
	var tool_name: String = "scan_cyclic_resource_dependencies"
	var description: String = "Scan project resources for cyclic dependency chains based on parsed ResourceLoader dependency metadata."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {
				"type": "string",
				"description": "Directory to scan. Default is res://.",
				"default": "res://"
			},
			"max_results": {
				"type": "integer",
				"description": "Maximum cyclic dependency issues to return. Default is 100.",
				"default": 100
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {"type": "string"},
			"scanned_resources": {"type": "integer"},
			"issue_count": {"type": "integer"},
			"issues": {"type": "array"},
			"truncated": {"type": "boolean"},
			"has_more": {"type": "boolean"},
			"max_results_applied": {"type": "integer"},
			"next_max_results": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_scan_cyclic_resource_dependencies"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_scan_cyclic_resource_dependencies(params: Dictionary) -> Dictionary:
	var search_path: String = str(params.get("search_path", "res://")).strip_edges()
	var max_results: int = max(1, int(params.get("max_results", 100)))

	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	search_path = validation["sanitized"]

	var dependency_extensions: Array[String] = [
		".tscn", ".scn", ".tres", ".res", ".gd", ".cs", ".gdshader", ".material"
	]
	var resources: Array[String] = []
	_collect_resources(search_path, dependency_extensions, resources)
	resources.sort()

	var graph: Dictionary = {}
	for resource_path in resources:
		graph[resource_path] = _collect_existing_dependency_paths(resource_path)

	var sampled_issues: Array = _collect_cyclic_dependency_issues(resources, graph, max_results + 1)
	var truncated: bool = sampled_issues.size() > max_results
	var issues: Array = sampled_issues.slice(0, max_results)

	return _with_max_results_continuation({
		"search_path": search_path,
		"scanned_resources": resources.size(),
		"issue_count": issues.size(),
		"issues": issues
	}, max_results, truncated)

func _parse_resource_dependencies(resource_path: String) -> Array:
	var dependencies: Array = []
	for raw_dependency in ResourceLoader.get_dependencies(resource_path):
		var raw_text: String = str(raw_dependency)
		var entry: Dictionary = {
			"raw": raw_text,
			"uid": "",
			"fallback_path": "",
			"resolved_path": "",
			"exists": false,
			"missing": false
		}

		if raw_text.contains("::"):
			entry["uid"] = raw_text.get_slice("::", 0)
			entry["fallback_path"] = raw_text.get_slice("::", 2)
			var resolved_path: String = ""
			if str(entry["uid"]).begins_with("uid://"):
				resolved_path = ResourceUID.uid_to_path(str(entry["uid"]))
			if resolved_path.is_empty():
				resolved_path = str(entry["fallback_path"])
			entry["resolved_path"] = resolved_path
		else:
			entry["fallback_path"] = raw_text
			entry["resolved_path"] = raw_text

		var resolved_exists: bool = false
		var resolved_path_str: String = str(entry["resolved_path"])
		var fallback_path_str: String = str(entry["fallback_path"])
		if not resolved_path_str.is_empty():
			resolved_exists = FileAccess.file_exists(resolved_path_str)
		if not resolved_exists and not fallback_path_str.is_empty():
			resolved_exists = FileAccess.file_exists(fallback_path_str)

		entry["exists"] = resolved_exists
		entry["missing"] = not resolved_exists
		dependencies.append(entry)

	return dependencies

func _collect_existing_dependency_paths(resource_path: String) -> Array:
	var paths: Array = []
	for dependency in _parse_resource_dependencies(resource_path):
		if bool(dependency.get("missing", false)):
			continue
		var resolved_path: String = str(dependency.get("resolved_path", ""))
		var fallback_path: String = str(dependency.get("fallback_path", ""))
		var effective_path: String = resolved_path if not resolved_path.is_empty() else fallback_path
		if effective_path.is_empty():
			continue
		if not paths.has(effective_path):
			paths.append(effective_path)
	return paths

func _collect_cyclic_dependency_issues(resources: Array[String], graph: Dictionary, max_results: int) -> Array:
	var issues: Array = []
	var seen_cycles: Dictionary = {}
	for resource_path in resources:
		if issues.size() >= max_results:
			break
		var stack: Array = []
		var visiting: Dictionary = {}
		var cycle_paths: Array = []
		_find_cycles_from_resource(resource_path, graph, stack, visiting, seen_cycles, cycle_paths, max_results - issues.size())
		for cycle_path in cycle_paths:
			issues.append({
				"owner_path": resource_path,
				"cycle_path": cycle_path,
				"cycle_length": cycle_path.size() - 1
			})
			if issues.size() >= max_results:
				break
	return issues

func _find_cycles_from_resource(current_path: String, graph: Dictionary, stack: Array, visiting: Dictionary, seen_cycles: Dictionary, issues: Array, remaining_budget: int) -> void:
	if remaining_budget <= 0:
		return
	if bool(visiting.get(current_path, false)):
		var cycle_start: int = stack.find(current_path)
		if cycle_start >= 0:
			var cycle_path: Array = stack.slice(cycle_start)
			cycle_path.append(current_path)
			var cycle_key: String = _canonicalize_cycle_path(cycle_path)
			if not seen_cycles.has(cycle_key):
				seen_cycles[cycle_key] = true
				issues.append(cycle_path)
		return
	if stack.has(current_path):
		return

	visiting[current_path] = true
	stack.append(current_path)
	for dependency_path in graph.get(current_path, []):
		if not graph.has(dependency_path):
			continue
		_find_cycles_from_resource(dependency_path, graph, stack, visiting, seen_cycles, issues, remaining_budget - issues.size())
		if issues.size() >= remaining_budget:
			break
	stack.pop_back()
	visiting.erase(current_path)

func _canonicalize_cycle_path(cycle_path: Array) -> String:
	if cycle_path.size() <= 1:
		return JSON.stringify(cycle_path)
	var nodes: Array = cycle_path.slice(0, cycle_path.size() - 1)
	if nodes.is_empty():
		return JSON.stringify(cycle_path)
	var best_rotation: Array = []
	for start_index in range(nodes.size()):
		var rotated: Array = []
		for offset in range(nodes.size()):
			rotated.append(nodes[(start_index + offset) % nodes.size()])
		if best_rotation.is_empty() or JSON.stringify(rotated) < JSON.stringify(best_rotation):
			best_rotation = rotated
	best_rotation.append(best_rotation[0])
	return JSON.stringify(best_rotation)

# ============================================================================
# detect_broken_scripts - 批量检测脚本诊断
# ============================================================================

func _register_detect_broken_scripts(server_core: RefCounted) -> void:
	var tool_name: String = "detect_broken_scripts"
	var description: String = "Scan GDScript files for syntax errors and lightweight warnings."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {
				"type": "string",
				"description": "Directory to scan. Default is res://.",
				"default": "res://"
			},
			"include_warnings": {
				"type": "boolean",
				"description": "Whether to include lightweight warnings such as untyped var declarations. Default is true.",
				"default": true
			},
			"max_results": {
				"type": "integer",
				"description": "Maximum number of script issue entries to return. Default is 200.",
				"default": 200
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {"type": "string"},
			"scanned_scripts": {"type": "integer"},
			"broken_count": {"type": "integer"},
			"warning_count": {"type": "integer"},
			"issues": {"type": "array"},
			"truncated": {"type": "boolean"},
			"has_more": {"type": "boolean"},
			"max_results_applied": {"type": "integer"},
			"next_max_results": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_detect_broken_scripts"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_detect_broken_scripts(params: Dictionary) -> Dictionary:
	var search_path: String = str(params.get("search_path", "res://")).strip_edges()
	var include_warnings: bool = params.get("include_warnings", true)
	var max_results: int = max(1, int(params.get("max_results", 200)))

	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	search_path = validation["sanitized"]

	var scripts: Array[String] = []
	_collect_resources(search_path, [".gd"], scripts)
	scripts.sort()

	var sampled_issues: Array = _collect_broken_script_issues(scripts, include_warnings, max_results + 1)
	var truncated: bool = sampled_issues.size() > max_results
	var issues: Array = sampled_issues.slice(0, max_results)
	var severity_counts: Dictionary = _count_broken_script_severities(issues)

	return _with_max_results_continuation({
		"search_path": search_path,
		"scanned_scripts": scripts.size(),
		"broken_count": int(severity_counts.get("broken_count", 0)),
		"warning_count": int(severity_counts.get("warning_count", 0)),
		"issues": issues
	}, max_results, truncated)

# ============================================================================
# audit_project_health - 汇总项目健康诊断
# ============================================================================

func _register_audit_project_health(server_core: RefCounted) -> void:
	var tool_name: String = "audit_project_health"
	var description: String = "Run a lightweight project health audit covering broken scripts and missing resource dependencies."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {
				"type": "string",
				"description": "Directory to scan. Default is res://.",
				"default": "res://"
			},
			"include_warnings": {
				"type": "boolean",
				"description": "Whether to include lightweight script warnings. Default is true.",
				"default": true
			},
			"max_results": {
				"type": "integer",
				"description": "Maximum issue entries per category. Default is 200.",
				"default": 200
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"search_path": {"type": "string"},
			"summary": {"type": "object"},
			"broken_scripts": {"type": "array"},
			"missing_dependencies": {"type": "array"},
			"cyclic_dependencies": {"type": "array"},
			"truncated": {"type": "boolean"},
			"has_more": {"type": "boolean"},
			"max_results_applied": {"type": "integer"},
			"next_max_results": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_audit_project_health"),
						  output_schema, annotations,
						  "supplementary", "Project-Advanced")

func _tool_audit_project_health(params: Dictionary) -> Dictionary:
	var search_path: String = str(params.get("search_path", "res://")).strip_edges()
	var include_warnings: bool = params.get("include_warnings", true)
	var max_results: int = max(1, int(params.get("max_results", 200)))

	var broken_scripts_result: Dictionary = _tool_detect_broken_scripts({
		"search_path": search_path,
		"include_warnings": include_warnings,
		"max_results": max_results
	})
	if broken_scripts_result.has("error"):
		return broken_scripts_result

	var missing_dependencies_result: Dictionary = _tool_scan_missing_resource_dependencies({
		"search_path": search_path,
		"max_results": max_results
	})
	if missing_dependencies_result.has("error"):
		return missing_dependencies_result

	var cyclic_dependencies_result: Dictionary = _tool_scan_cyclic_resource_dependencies({
		"search_path": search_path,
		"max_results": max_results
	})
	if cyclic_dependencies_result.has("error"):
		return cyclic_dependencies_result

	var summary: Dictionary = {
		"scanned_scripts": int(broken_scripts_result.get("scanned_scripts", 0)),
		"broken_scripts": int(broken_scripts_result.get("broken_count", 0)),
		"script_warnings": int(broken_scripts_result.get("warning_count", 0)),
		"scanned_resources": int(missing_dependencies_result.get("scanned_resources", 0)),
		"missing_dependencies": int(missing_dependencies_result.get("issue_count", 0)),
		"cyclic_dependencies": int(cyclic_dependencies_result.get("issue_count", 0))
	}
	var hard_failures: int = summary["broken_scripts"] + summary["missing_dependencies"] + summary["cyclic_dependencies"]
	var status: String = "healthy"
	if hard_failures > 0:
		status = "failing"
	elif summary["script_warnings"] > 0:
		status = "warning"

	return _with_max_results_continuation({
		"status": status,
		"search_path": broken_scripts_result.get("search_path", search_path),
		"summary": summary,
		"broken_scripts": broken_scripts_result.get("issues", []),
		"missing_dependencies": missing_dependencies_result.get("issues", []),
		"cyclic_dependencies": cyclic_dependencies_result.get("issues", [])
	}, max_results, bool(broken_scripts_result.get("truncated", false)) or bool(missing_dependencies_result.get("truncated", false)) or bool(cyclic_dependencies_result.get("truncated", false)))

func _with_max_results_continuation(result: Dictionary, max_results: int, truncated: bool) -> Dictionary:
	result["truncated"] = truncated
	result["has_more"] = truncated
	result["max_results_applied"] = max_results
	if truncated:
		result["next_max_results"] = max_results * 2
	return result

func _collect_missing_resource_dependency_issues(resources: Array[String], max_results: int) -> Array:
	var issues: Array = []
	for resource_path in resources:
		if issues.size() >= max_results:
			break
		var dependencies: Array = _parse_resource_dependencies(resource_path)
		for dependency_variant in dependencies:
			if issues.size() >= max_results:
				break
			if not (dependency_variant is Dictionary):
				continue
			var dependency: Dictionary = dependency_variant
			if bool(dependency.get("missing", false)):
				issues.append({
					"owner_path": resource_path,
					"dependency": dependency
				})
	return issues

func _collect_broken_script_issues(scripts: Array[String], include_warnings: bool, max_results: int) -> Array:
	var issues: Array = []
	for script_path in scripts:
		if issues.size() >= max_results:
			break
		var diagnostics: Dictionary = _analyze_script_diagnostics(script_path, include_warnings)
		if diagnostics.has("error"):
			issues.append({
				"script_path": script_path,
				"severity": "error",
				"errors": [{"line": 0, "column": 0, "message": str(diagnostics["error"])}],
				"warnings": []
			})
			continue
		var has_errors: bool = int(diagnostics.get("error_count", 0)) > 0
		var has_warnings: bool = int(diagnostics.get("warning_count", 0)) > 0
		if has_errors or has_warnings:
			issues.append({
				"script_path": script_path,
				"severity": "error" if has_errors else "warning",
				"errors": diagnostics.get("errors", []),
				"warnings": diagnostics.get("warnings", [])
			})
	return issues

func _count_broken_script_severities(issues: Array) -> Dictionary:
	var broken_count: int = 0
	var warning_count: int = 0
	for issue_variant in issues:
		if not (issue_variant is Dictionary):
			continue
		var issue: Dictionary = issue_variant
		var severity: String = str(issue.get("severity", ""))
		if severity == "error":
			broken_count += 1
		if not Array(issue.get("warnings", [])).is_empty():
			warning_count += 1
	return {
		"broken_count": broken_count,
		"warning_count": warning_count
	}

func _analyze_script_diagnostics(script_path: String, include_warnings: bool) -> Dictionary:
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file"}
	var content: String = file.get_as_text()
	file.close()

	var validation_content: String = _strip_class_names(content)
	var test_script: GDScript = GDScript.new()
	test_script.source_code = validation_content
	var reload_error: Error = test_script.reload()

	var errors: Array = []
	var warnings: Array = []

	if reload_error != OK:
		var source_lines: PackedStringArray = content.split("\n")
		for i in range(source_lines.size()):
			var line: String = source_lines[i].strip_edges()
			if line.is_empty():
				continue
			if _is_likely_script_error_line(line):
				errors.append({
					"line": i + 1,
					"column": 0,
					"message": "Syntax error near: " + line
				})
				break
		if errors.is_empty():
			errors.append({
				"line": 0,
				"column": 0,
				"message": "Script has syntax errors"
			})

	if include_warnings and reload_error == OK:
		var source_lines_for_warning: PackedStringArray = content.split("\n")
		for i in range(source_lines_for_warning.size()):
			var warning_line: String = source_lines_for_warning[i].strip_edges()
			if warning_line.begins_with("var ") and not ":" in warning_line and not "=" in warning_line:
				warnings.append({
					"line": i + 1,
					"column": 0,
					"message": "Variable lacks type hint"
				})

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"error_count": errors.size(),
		"warning_count": warnings.size()
	}

func _strip_class_names(source: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	var result: PackedStringArray = []
	for line in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("class_name "):
			result.append("")
		else:
			result.append(line)
	return "\n".join(result)

func _is_likely_script_error_line(line: String) -> bool:
	var line_lower: String = line.to_lower()
	if line_lower.contains("unexpected") or line_lower.contains("expected") or line_lower.contains("indent"):
		return true
	if line.ends_with("(") or line.ends_with(",") or line.count("\"") % 2 == 1:
		return true
	return false

func _collect_project_autoloads_from_properties(properties: Array, values_by_name: Dictionary, orders_by_name: Dictionary) -> Array:
	var autoloads: Array = []
	for property_info in properties:
		var property_name: String = str(property_info.get("name", ""))
		if not property_name.begins_with("autoload/"):
			continue
		var raw_value: String = str(values_by_name.get(property_name, ""))
		var is_singleton: bool = raw_value.begins_with("*")
		var resolved_path: String = raw_value.substr(1) if is_singleton else raw_value
		autoloads.append({
			"name": property_name.get_slice("/", 1),
			"path": resolved_path.simplify_path(),
			"is_singleton": is_singleton,
			"order": int(orders_by_name.get(property_name, 0)),
			"setting_name": property_name,
			"raw_value": raw_value
		})
	autoloads.sort_custom(Callable(self, "_compare_autoload_entries"))
	return autoloads

func _normalize_global_class_entries(entries: Array) -> Array:
	var classes: Array = []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		classes.append({
			"name": str(entry.get("class", "")),
			"path": str(entry.get("path", "")),
			"base": str(entry.get("base", "")),
			"language": str(entry.get("language", "")),
			"is_tool": bool(entry.get("is_tool", false)),
			"is_abstract": bool(entry.get("is_abstract", false)),
			"icon": str(entry.get("icon", ""))
		})
	classes.sort_custom(Callable(self, "_compare_global_class_entries"))
	return classes

func _find_project_global_class_entry(target_class_name: String) -> Dictionary:
	if not ProjectSettings.has_method("get_global_class_list"):
		return {}
	for entry in ProjectSettings.get_global_class_list():
		if not (entry is Dictionary):
			continue
		if str(entry.get("class", "")) == target_class_name:
			return entry
	return {}

func _build_classdb_api_metadata(target_class_name: String, filter: String = "") -> Dictionary:
	return {
		"class_name": target_class_name,
		"source": "classdb",
		"base_class": ClassDB.get_parent_class(target_class_name),
		"api_type": ClassDB.class_get_api_type(target_class_name),
		"methods": _normalize_method_entries(ClassDB.class_get_method_list(target_class_name), filter),
		"properties": _normalize_property_entries(ClassDB.class_get_property_list(target_class_name), filter),
		"signals": _normalize_signal_entries(ClassDB.class_get_signal_list(target_class_name), filter),
		"constants": _normalize_constant_entries(target_class_name, filter)
	}

func _normalize_method_entries(entries: Array, filter: String = "") -> Array:
	var methods: Array = []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var method_name: String = str(entry.get("name", ""))
		if method_name.is_empty():
			continue
		if not filter.is_empty() and not method_name.to_lower().contains(filter):
			continue
		methods.append({
			"name": method_name,
			"flags": int(entry.get("flags", 0)),
			"id": int(entry.get("id", 0)),
			"return": _normalize_typed_value_info(entry.get("return", {})),
			"arguments": _normalize_typed_value_info_array(entry.get("args", [])),
			"default_argument_count": entry.get("default_args", []).size()
		})
	methods.sort_custom(Callable(self, "_compare_named_entries"))
	return methods

func _normalize_property_entries(entries: Array, filter: String = "") -> Array:
	var properties: Array = []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var property_name: String = str(entry.get("name", ""))
		if property_name.is_empty():
			continue
		if not filter.is_empty() and not property_name.to_lower().contains(filter):
			continue
		properties.append({
			"name": property_name,
			"type": int(entry.get("type", TYPE_NIL)),
			"class_name": str(entry.get("class_name", "")),
			"hint": int(entry.get("hint", PROPERTY_HINT_NONE)),
			"hint_string": str(entry.get("hint_string", "")),
			"usage": int(entry.get("usage", 0)),
			"setter": str(entry.get("setter", "")),
			"getter": str(entry.get("getter", ""))
		})
	properties.sort_custom(Callable(self, "_compare_named_entries"))
	return properties

func _normalize_signal_entries(entries: Array, filter: String = "") -> Array:
	var signals: Array = []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var signal_name: String = str(entry.get("name", ""))
		if signal_name.is_empty():
			continue
		if not filter.is_empty() and not signal_name.to_lower().contains(filter):
			continue
		signals.append({
			"name": signal_name,
			"flags": int(entry.get("flags", 0)),
			"id": int(entry.get("id", 0)),
			"arguments": _normalize_typed_value_info_array(entry.get("args", []))
		})
	signals.sort_custom(Callable(self, "_compare_named_entries"))
	return signals

func _normalize_constant_entries(target_class_name: String, filter: String = "") -> Array:
	var constants: Array = []
	for constant_name in ClassDB.class_get_integer_constant_list(target_class_name):
		var constant_name_text: String = str(constant_name)
		if not filter.is_empty() and not constant_name_text.to_lower().contains(filter):
			continue
		constants.append({
			"name": constant_name_text,
			"value": ClassDB.class_get_integer_constant(target_class_name, constant_name_text),
			"enum": str(ClassDB.class_get_integer_constant_enum(target_class_name, constant_name_text))
		})
	constants.sort_custom(Callable(self, "_compare_named_entries"))
	return constants

func _normalize_typed_value_info_array(entries: Array) -> Array:
	var normalized: Array = []
	for entry in entries:
		normalized.append(_normalize_typed_value_info(entry))
	return normalized

func _is_valid_plugin_config_path(plugin_path: String) -> bool:
	return plugin_path.begins_with("res://addons/") and plugin_path.ends_with("/plugin.cfg")

func _get_plugin_name_from_path(plugin_path: String) -> String:
	return plugin_path.get_base_dir().get_file()

func _get_feature_profile_path(config_dir: String, profile_name: String) -> String:
	return config_dir.path_join("feature_profiles").path_join(profile_name + ".profile")

func _load_plugin_config_metadata(plugin_path: String) -> Dictionary:
	var config := ConfigFile.new()
	var load_result: Error = config.load(plugin_path)
	if load_result != OK:
		return {"error": "Failed to read plugin config: " + plugin_path}
	return {
		"display_name": str(config.get_value("plugin", "name", "")),
		"description": str(config.get_value("plugin", "description", "")),
		"author": str(config.get_value("plugin", "author", "")),
		"version": str(config.get_value("plugin", "version", "")),
		"script": str(config.get_value("plugin", "script", ""))
	}

func _compare_feature_profile_entries(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("name", "")) < str(right.get("name", ""))

func _collect_project_plugins() -> Array:
	var plugins: Array = []
	var addons_dir: DirAccess = DirAccess.open("res://addons")
	if addons_dir == null:
		return plugins
	addons_dir.list_dir_begin()
	var entry_name: String = addons_dir.get_next()
	while not entry_name.is_empty():
		if addons_dir.current_is_dir():
			var plugin_path: String = "res://addons/%s/plugin.cfg" % entry_name
			if FileAccess.file_exists(plugin_path):
				plugins.append({
					"name": entry_name,
					"plugin_path": plugin_path,
					"enabled": false
				})
		entry_name = addons_dir.get_next()
	addons_dir.list_dir_end()
	plugins.sort_custom(Callable(self, "_compare_feature_profile_entries"))
	return plugins

func _normalize_typed_value_info(entry: Variant) -> Dictionary:
	if not (entry is Dictionary):
		return {}
	return {
		"name": str(entry.get("name", "")),
		"type": int(entry.get("type", TYPE_NIL)),
		"class_name": str(entry.get("class_name", "")),
		"hint": int(entry.get("hint", PROPERTY_HINT_NONE)),
		"hint_string": str(entry.get("hint_string", "")),
		"usage": int(entry.get("usage", 0))
	}

func _collect_project_input_actions(action_name_filter: String = "") -> Array:
	var actions: Array = []
	for property_info in ProjectSettings.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if not property_name.begins_with("input/"):
			continue
		var action_name: String = property_name.get_slice("/", 1)
		if not action_name_filter.is_empty() and action_name != action_name_filter:
			continue
		var raw_value: Variant = ProjectSettings.get_setting(property_name, {})
		if not (raw_value is Dictionary):
			continue
		var stored_events: Array = raw_value.get("events", [])
		var events: Array = []
		for stored_event in stored_events:
			if stored_event is InputEvent:
				events.append(_serialize_project_input_event(stored_event))
		actions.append({
			"action_name": action_name,
			"deadzone": float(raw_value.get("deadzone", 0.5)),
			"events": events,
			"event_count": events.size(),
			"setting_name": property_name
		})
	actions.sort_custom(Callable(self, "_sort_project_input_actions"))
	return actions

func _build_project_input_event(payload: Dictionary) -> InputEvent:
	var event_type: String = str(payload.get("type", "")).to_lower()
	match event_type:
		"action":
			var action_name: String = str(payload.get("action_name", ""))
			if action_name.is_empty():
				return null
			var action_event := InputEventAction.new()
			action_event.action = StringName(action_name)
			action_event.pressed = bool(payload.get("pressed", true))
			action_event.strength = float(payload.get("strength", 1.0 if action_event.pressed else 0.0))
			return action_event
		"key":
			var keycode: int = int(payload.get("keycode", 0))
			if keycode == 0:
				return null
			var key_event := InputEventKey.new()
			key_event.keycode = keycode
			key_event.physical_keycode = int(payload.get("physical_keycode", 0))
			key_event.unicode = int(payload.get("unicode", 0))
			key_event.pressed = bool(payload.get("pressed", true))
			key_event.echo = bool(payload.get("echo", false))
			_apply_project_input_modifiers(key_event, payload)
			return key_event
		"mouse_button":
			var button_index: int = int(payload.get("button_index", 0))
			if button_index == 0:
				return null
			var mouse_button_event := InputEventMouseButton.new()
			mouse_button_event.button_index = button_index
			mouse_button_event.pressed = bool(payload.get("pressed", true))
			mouse_button_event.double_click = bool(payload.get("double_click", false))
			mouse_button_event.factor = float(payload.get("factor", 1.0))
			mouse_button_event.button_mask = int(payload.get("button_mask", 0))
			mouse_button_event.position = _dict_to_project_vector2(payload.get("position", {}))
			mouse_button_event.global_position = _dict_to_project_vector2(payload.get("global_position", payload.get("position", {})))
			_apply_project_input_modifiers(mouse_button_event, payload)
			return mouse_button_event
		"mouse_motion":
			var mouse_motion_event := InputEventMouseMotion.new()
			mouse_motion_event.position = _dict_to_project_vector2(payload.get("position", {}))
			mouse_motion_event.global_position = _dict_to_project_vector2(payload.get("global_position", payload.get("position", {})))
			mouse_motion_event.relative = _dict_to_project_vector2(payload.get("relative", {}))
			mouse_motion_event.velocity = _dict_to_project_vector2(payload.get("velocity", {}))
			mouse_motion_event.button_mask = int(payload.get("button_mask", 0))
			mouse_motion_event.pressure = float(payload.get("pressure", 0.0))
			mouse_motion_event.pen_inverted = bool(payload.get("pen_inverted", false))
			_apply_project_input_modifiers(mouse_motion_event, payload)
			return mouse_motion_event
		_:
			return null

func _apply_project_input_modifiers(event: InputEventWithModifiers, payload: Dictionary) -> void:
	event.alt_pressed = bool(payload.get("alt_pressed", false))
	event.shift_pressed = bool(payload.get("shift_pressed", false))
	event.ctrl_pressed = bool(payload.get("ctrl_pressed", false))
	event.meta_pressed = bool(payload.get("meta_pressed", false))
	event.command_or_control_autoremap = bool(payload.get("command_or_control_autoremap", false))

func _dict_to_project_vector2(value: Variant) -> Vector2:
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO

func _serialize_project_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventAction:
		return {
			"type": "action",
			"action_name": String(event.action),
			"pressed": event.pressed,
			"strength": event.strength
		}
	if event is InputEventKey:
		return {
			"type": "key",
			"keycode": event.keycode,
			"physical_keycode": event.physical_keycode,
			"unicode": event.unicode,
			"pressed": event.pressed,
			"echo": event.echo
		}
	if event is InputEventMouseButton:
		return {
			"type": "mouse_button",
			"button_index": event.button_index,
			"pressed": event.pressed,
			"double_click": event.double_click,
			"position": {"x": event.position.x, "y": event.position.y}
		}
	if event is InputEventMouseMotion:
		return {
			"type": "mouse_motion",
			"position": {"x": event.position.x, "y": event.position.y},
			"relative": {"x": event.relative.x, "y": event.relative.y},
			"velocity": {"x": event.velocity.x, "y": event.velocity.y}
		}
	return {"type": "unknown", "class": event.get_class()}

func _inspect_csproj_file(project_path: String) -> Dictionary:
	var parser := XMLParser.new()
	var open_error: Error = parser.open(project_path)
	if open_error != OK:
		return {"path": project_path, "error": "Failed to open csproj: " + str(open_error)}

	var result: Dictionary = {
		"path": project_path,
		"sdk": "",
		"target_frameworks": [],
		"assembly_name": "",
		"root_namespace": "",
		"nullable": "",
		"lang_version": "",
		"package_references": [],
		"project_references": []
	}
	var current_text_field: String = ""

	while true:
		var read_error: Error = parser.read()
		if read_error == ERR_FILE_EOF:
			break
		if read_error != OK:
			result["error"] = "Failed to parse csproj: " + str(read_error)
			break

		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node_name: String = parser.get_node_name()
				match node_name:
					"Project":
						result["sdk"] = parser.get_named_attribute_value_safe("Sdk")
					"TargetFramework", "TargetFrameworks", "AssemblyName", "RootNamespace", "Nullable", "LangVersion":
						current_text_field = node_name
					"PackageReference":
						result["package_references"].append({
							"include": parser.get_named_attribute_value_safe("Include"),
							"version": parser.get_named_attribute_value_safe("Version"),
							"condition": parser.get_named_attribute_value_safe("Condition")
						})
					"ProjectReference":
						result["project_references"].append({
							"include": parser.get_named_attribute_value_safe("Include"),
							"name": parser.get_named_attribute_value_safe("Name")
						})
			XMLParser.NODE_TEXT:
				if current_text_field.is_empty():
					continue
				var text_value: String = parser.get_node_data().strip_edges()
				if text_value.is_empty():
					continue
				match current_text_field:
					"TargetFramework":
						result["target_frameworks"] = [text_value]
					"TargetFrameworks":
						result["target_frameworks"] = _split_semicolon_values(text_value)
					"AssemblyName":
						result["assembly_name"] = text_value
					"RootNamespace":
						result["root_namespace"] = text_value
					"Nullable":
						result["nullable"] = text_value
					"LangVersion":
						result["lang_version"] = text_value
			XMLParser.NODE_ELEMENT_END:
				current_text_field = ""

	return result

func _inspect_solution_file(solution_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(solution_path, FileAccess.READ)
	if not file:
		return {"path": solution_path, "error": "Failed to open solution file"}

	var entries: Array = []
	while not file.eof_reached():
		var raw_line: String = file.get_line()
		var line: String = raw_line.strip_edges()
		if not line.begins_with("Project("):
			continue
		var marker_index: int = line.find(" = ")
		if marker_index == -1:
			continue
		var tail: String = line.substr(marker_index + 3)
		var segments: PackedStringArray = tail.split(",")
		if segments.size() < 2:
			continue
		entries.append({
			"name": segments[0].strip_edges().trim_prefix("\"").trim_suffix("\""),
			"path": segments[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
		})
	file.close()

	return {
		"path": solution_path,
		"project_count": entries.size(),
		"projects": entries
	}

func _split_semicolon_values(value: String) -> Array:
	var values: Array = []
	for segment in value.split(";"):
		var trimmed: String = segment.strip_edges()
		if not trimmed.is_empty():
			values.append(trimmed)
	return values

func _serialize_tileset_source(source_id: int, source: TileSetSource, include_tiles: bool) -> Dictionary:
	var source_entry: Dictionary = {
		"source_id": source_id,
		"class_name": source.get_class(),
		"tile_count": source.get_tiles_count()
	}

	if source is TileSetAtlasSource:
		var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
		var texture: Texture2D = atlas_source.texture
		source_entry["source_type"] = "atlas"
		source_entry["texture_path"] = texture.resource_path if texture else ""
		source_entry["texture_size"] = _serialize_vector2(texture.get_size()) if texture else {}
		source_entry["margins"] = _serialize_vector2i(atlas_source.margins)
		source_entry["separation"] = _serialize_vector2i(atlas_source.separation)
		source_entry["texture_region_size"] = _serialize_vector2i(atlas_source.texture_region_size)
		source_entry["atlas_grid_size"] = _serialize_vector2i(atlas_source.get_atlas_grid_size())
		source_entry["uses_texture_padding"] = atlas_source.use_texture_padding
		if include_tiles:
			var atlas_tiles: Array = []
			for tile_index in range(atlas_source.get_tiles_count()):
				var atlas_coords: Vector2i = atlas_source.get_tile_id(tile_index)
				var alternatives: Array = []
				for alt_index in range(atlas_source.get_alternative_tiles_count(atlas_coords)):
					alternatives.append(atlas_source.get_alternative_tile_id(atlas_coords, alt_index))
				atlas_tiles.append({
					"atlas_coords": _serialize_vector2i(atlas_coords),
					"size_in_atlas": _serialize_vector2i(atlas_source.get_tile_size_in_atlas(atlas_coords)),
					"texture_region": _serialize_rect2i(atlas_source.get_tile_texture_region(atlas_coords)),
					"alternative_ids": alternatives,
					"alternative_count": alternatives.size()
				})
			source_entry["tiles"] = atlas_tiles
	elif source is TileSetScenesCollectionSource:
		var scenes_source: TileSetScenesCollectionSource = source as TileSetScenesCollectionSource
		source_entry["source_type"] = "scenes_collection"
		source_entry["scene_tile_count"] = scenes_source.get_scene_tiles_count()
		if include_tiles:
			var scene_tiles: Array = []
			for tile_index in range(scenes_source.get_scene_tiles_count()):
				var scene_tile_id: int = scenes_source.get_scene_tile_id(tile_index)
				var packed_scene: PackedScene = scenes_source.get_scene_tile_scene(scene_tile_id)
				scene_tiles.append({
					"scene_tile_id": scene_tile_id,
					"scene_path": packed_scene.resource_path if packed_scene else ""
				})
			source_entry["scene_tiles"] = scene_tiles
	else:
		source_entry["source_type"] = "unknown"

	return source_entry

func _serialize_vector2i(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _serialize_vector2(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _serialize_rect2i(value: Rect2i) -> Dictionary:
	return {
		"position": _serialize_vector2i(value.position),
		"size": _serialize_vector2i(value.size)
	}

func _serialize_project_resource_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR2I:
			return _serialize_vector2i(value)
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR3I:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR4:
			return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_VECTOR4I:
			return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_RECT2:
			return {
				"position": _serialize_project_resource_value(value.position),
				"size": _serialize_project_resource_value(value.size)
			}
		TYPE_RECT2I:
			return _serialize_rect2i(value)
		TYPE_ARRAY:
			var array_result: Array = []
			for item in value:
				array_result.append(_serialize_project_resource_value(item))
			return array_result
		TYPE_DICTIONARY:
			var dict_result: Dictionary = {}
			for key in value.keys():
				dict_result[str(key)] = _serialize_project_resource_value(value[key])
			return dict_result
		TYPE_OBJECT:
			if value is Resource:
				return {
					"class_name": value.get_class(),
					"resource_path": String((value as Resource).resource_path)
				}
			return {
				"class_name": value.get_class(),
				"instance_id": value.get_instance_id()
			}
		_:
			return String(value)

func _validate_project_setting_name(setting_name: String) -> Dictionary:
	if setting_name.is_empty():
		return {"ok": false, "error": "Invalid setting_name: value must not be empty"}
	if not setting_name.contains("/"):
		return {"ok": false, "error": "Invalid setting_name: expected slash-delimited project setting key"}
	if setting_name.begins_with("/") or setting_name.ends_with("/"):
		return {"ok": false, "error": "Invalid setting_name: leading or trailing slashes are not allowed"}
	if setting_name.contains(".."):
		return {"ok": false, "error": "Invalid setting_name: parent traversal segments are not allowed"}
	for segment in setting_name.split("/"):
		if String(segment).strip_edges().is_empty():
			return {"ok": false, "error": "Invalid setting_name: empty path segments are not allowed"}
	if ProjectSettings.has_setting(setting_name):
		return {"ok": true}
	if setting_name.begins_with("mcp/"):
		return {"ok": true}
	return {"ok": false, "error": "Invalid setting_name: only existing project settings or custom mcp/* keys are supported"}

func _coerce_project_setting_value(raw_value: Variant, expected_type: int, setting_exists: bool) -> Dictionary:
	if not setting_exists:
		var raw_type: int = typeof(raw_value)
		if raw_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
			return {"ok": true, "value": raw_value}
		if raw_value is String or raw_value is StringName:
			return {"ok": true, "value": String(raw_value)}
		return {"ok": false, "error": "new custom settings only support boolean, integer, float, or string values"}

	match expected_type:
		TYPE_BOOL:
			if raw_value is bool:
				return {"ok": true, "value": raw_value}
			return {"ok": false, "error": "expected boolean"}
		TYPE_INT:
			if raw_value is int:
				return {"ok": true, "value": int(raw_value)}
			if raw_value is float:
				return {"ok": true, "value": int(raw_value)}
			return {"ok": false, "error": "expected integer-compatible value"}
		TYPE_FLOAT:
			if raw_value is int or raw_value is float:
				return {"ok": true, "value": float(raw_value)}
			return {"ok": false, "error": "expected numeric value"}
		TYPE_STRING:
			if raw_value is String or raw_value is StringName:
				return {"ok": true, "value": String(raw_value)}
			return {"ok": false, "error": "expected string"}
		TYPE_STRING_NAME:
			if raw_value is String or raw_value is StringName:
				return {"ok": true, "value": StringName(str(raw_value))}
			return {"ok": false, "error": "expected string"}
		_:
			return {"ok": false, "error": "unsupported project setting type " + type_string(expected_type)}

func _coerce_project_resource_value(raw_value: Variant, expected_type: int) -> Dictionary:
	match expected_type:
		TYPE_NIL:
			return {"ok": true, "value": null}
		TYPE_BOOL:
			if raw_value is bool:
				return {"ok": true, "value": raw_value}
			return {"ok": false, "error": "expected boolean"}
		TYPE_INT:
			if raw_value is int:
				return {"ok": true, "value": int(raw_value)}
			if raw_value is float:
				return {"ok": true, "value": int(raw_value)}
			return {"ok": false, "error": "expected integer-compatible value"}
		TYPE_FLOAT:
			if raw_value is int or raw_value is float:
				return {"ok": true, "value": float(raw_value)}
			return {"ok": false, "error": "expected numeric value"}
		TYPE_STRING:
			if raw_value is String or raw_value is StringName:
				return {"ok": true, "value": String(raw_value)}
			return {"ok": false, "error": "expected string"}
		TYPE_STRING_NAME:
			if raw_value is String or raw_value is StringName:
				return {"ok": true, "value": StringName(str(raw_value))}
			return {"ok": false, "error": "expected string"}
		TYPE_COLOR:
			if raw_value is Dictionary:
				var color_dict: Dictionary = raw_value
				if not (color_dict.has("r") and color_dict.has("g") and color_dict.has("b")):
					return {"ok": false, "error": "color dictionaries must include r, g, and b"}
				return {
					"ok": true,
					"value": Color(
						float(color_dict.get("r", 0.0)),
						float(color_dict.get("g", 0.0)),
						float(color_dict.get("b", 0.0)),
						float(color_dict.get("a", 1.0))
					)
				}
			return {"ok": false, "error": "expected color dictionary"}
		TYPE_VECTOR2:
			return _coerce_project_resource_vector2(raw_value, false)
		TYPE_VECTOR2I:
			return _coerce_project_resource_vector2(raw_value, true)
		TYPE_VECTOR3:
			return _coerce_project_resource_vector3(raw_value, false)
		TYPE_VECTOR3I:
			return _coerce_project_resource_vector3(raw_value, true)
		TYPE_VECTOR4:
			return _coerce_project_resource_vector4(raw_value, false)
		TYPE_VECTOR4I:
			return _coerce_project_resource_vector4(raw_value, true)
		TYPE_RECT2:
			return _coerce_project_resource_rect2(raw_value, false)
		TYPE_RECT2I:
			return _coerce_project_resource_rect2(raw_value, true)
		TYPE_ARRAY:
			if raw_value is Array:
				return {"ok": true, "value": raw_value}
			return {"ok": false, "error": "expected array"}
		TYPE_DICTIONARY:
			if raw_value is Dictionary:
				return {"ok": true, "value": raw_value}
			return {"ok": false, "error": "expected dictionary"}
		_:
			return {"ok": false, "error": "unsupported property type " + str(expected_type)}

func _coerce_project_resource_vector2(raw_value: Variant, integer_components: bool) -> Dictionary:
	if not (raw_value is Dictionary):
		return {"ok": false, "error": "expected dictionary with x and y"}
	var value_dict: Dictionary = raw_value
	if not (value_dict.has("x") and value_dict.has("y")):
		return {"ok": false, "error": "vector dictionaries must include x and y"}
	if integer_components:
		return {"ok": true, "value": Vector2i(int(value_dict.get("x", 0)), int(value_dict.get("y", 0)))}
	return {"ok": true, "value": Vector2(float(value_dict.get("x", 0.0)), float(value_dict.get("y", 0.0)))}

func _coerce_project_resource_vector3(raw_value: Variant, integer_components: bool) -> Dictionary:
	if not (raw_value is Dictionary):
		return {"ok": false, "error": "expected dictionary with x, y, and z"}
	var value_dict: Dictionary = raw_value
	if not (value_dict.has("x") and value_dict.has("y") and value_dict.has("z")):
		return {"ok": false, "error": "vector dictionaries must include x, y, and z"}
	if integer_components:
		return {"ok": true, "value": Vector3i(int(value_dict.get("x", 0)), int(value_dict.get("y", 0)), int(value_dict.get("z", 0)))}
	return {"ok": true, "value": Vector3(float(value_dict.get("x", 0.0)), float(value_dict.get("y", 0.0)), float(value_dict.get("z", 0.0)))}

func _coerce_project_resource_vector4(raw_value: Variant, integer_components: bool) -> Dictionary:
	if not (raw_value is Dictionary):
		return {"ok": false, "error": "expected dictionary with x, y, z, and w"}
	var value_dict: Dictionary = raw_value
	if not (value_dict.has("x") and value_dict.has("y") and value_dict.has("z") and value_dict.has("w")):
		return {"ok": false, "error": "vector dictionaries must include x, y, z, and w"}
	if integer_components:
		return {"ok": true, "value": Vector4i(int(value_dict.get("x", 0)), int(value_dict.get("y", 0)), int(value_dict.get("z", 0)), int(value_dict.get("w", 0)))}
	return {"ok": true, "value": Vector4(float(value_dict.get("x", 0.0)), float(value_dict.get("y", 0.0)), float(value_dict.get("z", 0.0)), float(value_dict.get("w", 0.0)))}

func _coerce_project_resource_rect2(raw_value: Variant, integer_components: bool) -> Dictionary:
	if not (raw_value is Dictionary):
		return {"ok": false, "error": "expected dictionary with position and size"}
	var value_dict: Dictionary = raw_value
	if not (value_dict.has("position") and value_dict.has("size")):
		return {"ok": false, "error": "rect dictionaries must include position and size"}
	var position_result: Dictionary = _coerce_project_resource_vector2(value_dict.get("position"), integer_components)
	if not bool(position_result.get("ok", false)):
		return position_result
	var size_result: Dictionary = _coerce_project_resource_vector2(value_dict.get("size"), integer_components)
	if not bool(size_result.get("ok", false)):
		return size_result
	if integer_components:
		return {"ok": true, "value": Rect2i(position_result.get("value"), size_result.get("value"))}
	return {"ok": true, "value": Rect2(position_result.get("value"), size_result.get("value"))}

func _compare_autoload_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = int(left.get("order", 0))
	var right_order: int = int(right.get("order", 0))
	if left_order == right_order:
		return str(left.get("name", "")) < str(right.get("name", ""))
	return left_order < right_order

func _compare_global_class_entries(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("name", "")) < str(right.get("name", ""))

func _compare_named_entries(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("name", "")) < str(right.get("name", ""))

func _sort_project_input_actions(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("action_name", "")) < str(right.get("action_name", ""))
