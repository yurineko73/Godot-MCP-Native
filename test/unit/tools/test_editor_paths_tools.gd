extends "res://addons/gut/test.gd"

var _editor_tools: RefCounted = null

func before_each() -> void:
	_editor_tools = load("res://addons/godot_mcp/tools/editor_tools_native.gd").new()

func after_each() -> void:
	_editor_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_get_editor_paths_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_paths(server_core)
	var tool = server_core.get_tool("get_editor_paths")
	assert_not_null(tool, "get_editor_paths should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "config_dir", "Editor paths output should expose config_dir")
	assert_has(properties, "data_dir", "Editor paths output should expose data_dir")
	assert_has(properties, "cache_dir", "Editor paths output should expose cache_dir")
	assert_has(properties, "project_settings_dir", "Editor paths output should expose project_settings_dir")
	assert_has(properties, "export_templates_dir", "Editor paths output should expose export_templates_dir")
	assert_has(properties, "self_contained", "Editor paths output should expose self_contained")
	assert_has(properties, "self_contained_file", "Editor paths output should expose self_contained_file")

func test_get_editor_paths_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_paths({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor paths read should fail cleanly without editor interface")

func test_get_editor_shell_state_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_shell_state(server_core)
	var tool = server_core.get_tool("get_editor_shell_state")
	assert_not_null(tool, "get_editor_shell_state should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "main_screen_name", "Editor shell output should expose main_screen_name")
	assert_has(properties, "main_screen_type", "Editor shell output should expose main_screen_type")
	assert_has(properties, "editor_scale", "Editor shell output should expose editor_scale")
	assert_has(properties, "multi_window_enabled", "Editor shell output should expose multi_window_enabled")

func test_get_editor_shell_state_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_shell_state({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor shell read should fail cleanly without editor interface")

func test_get_editor_language_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_language(server_core)
	var tool = server_core.get_tool("get_editor_language")
	assert_not_null(tool, "get_editor_language should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "editor_language", "Editor language output should expose editor_language")

func test_get_editor_language_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_language({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor language read should fail cleanly without editor interface")

func test_get_editor_play_state_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_play_state(server_core)
	var tool = server_core.get_tool("get_editor_play_state")
	assert_not_null(tool, "get_editor_play_state should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "is_playing_scene", "Editor play state output should expose is_playing_scene")
	assert_has(properties, "playing_scene", "Editor play state output should expose playing_scene")

func test_get_editor_play_state_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_play_state({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor play-state read should fail cleanly without editor interface")

func test_get_editor_3d_snap_state_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_3d_snap_state(server_core)
	var tool = server_core.get_tool("get_editor_3d_snap_state")
	assert_not_null(tool, "get_editor_3d_snap_state should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "snap_enabled", "Editor 3D snap output should expose snap_enabled")
	assert_has(properties, "translate_snap", "Editor 3D snap output should expose translate_snap")
	assert_has(properties, "rotate_snap", "Editor 3D snap output should expose rotate_snap")
	assert_has(properties, "scale_snap", "Editor 3D snap output should expose scale_snap")

func test_get_editor_3d_snap_state_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_3d_snap_state({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor 3D snap-state read should fail cleanly without editor interface")

func test_get_editor_subsystem_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_subsystem_availability(server_core)
	var tool = server_core.get_tool("get_editor_subsystem_availability")
	assert_not_null(tool, "get_editor_subsystem_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "command_palette_available", "Editor subsystem output should expose command_palette_available")
	assert_has(properties, "toaster_available", "Editor subsystem output should expose toaster_available")
	assert_has(properties, "resource_filesystem_available", "Editor subsystem output should expose resource_filesystem_available")
	assert_has(properties, "script_editor_available", "Editor subsystem output should expose script_editor_available")

func test_get_editor_subsystem_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_subsystem_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor subsystem read should fail cleanly without editor interface")

func test_get_editor_previewer_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_previewer_availability(server_core)
	var tool = server_core.get_tool("get_editor_previewer_availability")
	assert_not_null(tool, "get_editor_previewer_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "resource_previewer_available", "Editor previewer output should expose resource_previewer_available")
	assert_has(properties, "resource_previewer_type", "Editor previewer output should expose resource_previewer_type")

func test_get_editor_previewer_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_previewer_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor previewer read should fail cleanly without editor interface")

func test_get_editor_undo_redo_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_undo_redo_availability(server_core)
	var tool = server_core.get_tool("get_editor_undo_redo_availability")
	assert_not_null(tool, "get_editor_undo_redo_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "undo_redo_available", "Editor undo/redo output should expose undo_redo_available")
	assert_has(properties, "undo_redo_type", "Editor undo/redo output should expose undo_redo_type")

func test_get_editor_undo_redo_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_undo_redo_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor undo/redo read should fail cleanly without editor interface")

func test_get_editor_viewport_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_viewport_availability(server_core)
	var tool = server_core.get_tool("get_editor_viewport_availability")
	assert_not_null(tool, "get_editor_viewport_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "viewport_2d_available", "Editor viewport output should expose viewport_2d_available")
	assert_has(properties, "viewport_2d_type", "Editor viewport output should expose viewport_2d_type")
	assert_has(properties, "viewport_3d_available", "Editor viewport output should expose viewport_3d_available")
	assert_has(properties, "viewport_3d_type", "Editor viewport output should expose viewport_3d_type")

func test_get_editor_viewport_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_viewport_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor viewport read should fail cleanly without editor interface")

func test_get_editor_base_control_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_base_control_availability(server_core)
	var tool = server_core.get_tool("get_editor_base_control_availability")
	assert_not_null(tool, "get_editor_base_control_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "base_control_available", "Editor base control output should expose base_control_available")
	assert_has(properties, "base_control_type", "Editor base control output should expose base_control_type")

func test_get_editor_base_control_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_base_control_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor base control read should fail cleanly without editor interface")

func test_get_editor_file_system_dock_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_file_system_dock_availability(server_core)
	var tool = server_core.get_tool("get_editor_file_system_dock_availability")
	assert_not_null(tool, "get_editor_file_system_dock_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "file_system_dock_available", "Editor file system dock output should expose file_system_dock_available")
	assert_has(properties, "file_system_dock_type", "Editor file system dock output should expose file_system_dock_type")

func test_get_editor_file_system_dock_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_file_system_dock_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor file system dock read should fail cleanly without editor interface")

func test_get_editor_inspector_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_inspector_availability(server_core)
	var tool = server_core.get_tool("get_editor_inspector_availability")
	assert_not_null(tool, "get_editor_inspector_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "inspector_available", "Editor inspector output should expose inspector_available")
	assert_has(properties, "inspector_type", "Editor inspector output should expose inspector_type")

func test_get_editor_inspector_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_inspector_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor inspector read should fail cleanly without editor interface")

func test_get_editor_current_location_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_current_location(server_core)
	var tool = server_core.get_tool("get_editor_current_location")
	assert_not_null(tool, "get_editor_current_location should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "current_path", "Editor current location output should expose current_path")
	assert_has(properties, "current_directory", "Editor current location output should expose current_directory")

func test_get_editor_current_location_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_current_location({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor current location read should fail cleanly without editor interface")

func test_get_editor_selected_paths_summary_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_selected_paths_summary(server_core)
	var tool = server_core.get_tool("get_editor_selected_paths_summary")
	assert_not_null(tool, "get_editor_selected_paths_summary should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "selected_paths", "Editor selected paths output should expose selected_paths")
	assert_has(properties, "selected_count", "Editor selected paths output should expose selected_count")

func test_get_editor_selected_paths_summary_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_selected_paths_summary({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor selected paths read should fail cleanly without editor interface")

func test_get_editor_selection_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_selection_availability(server_core)
	var tool = server_core.get_tool("get_editor_selection_availability")
	assert_not_null(tool, "get_editor_selection_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "selection_available", "Editor selection output should expose selection_available")
	assert_has(properties, "selection_type", "Editor selection output should expose selection_type")

func test_get_editor_selection_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_selection_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor selection read should fail cleanly without editor interface")

func test_get_editor_command_palette_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_command_palette_availability(server_core)
	var tool = server_core.get_tool("get_editor_command_palette_availability")
	assert_not_null(tool, "get_editor_command_palette_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "command_palette_available", "Editor command palette output should expose command_palette_available")
	assert_has(properties, "command_palette_type", "Editor command palette output should expose command_palette_type")

func test_get_editor_command_palette_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_command_palette_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor command palette read should fail cleanly without editor interface")

func test_get_editor_toaster_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_toaster_availability(server_core)
	var tool = server_core.get_tool("get_editor_toaster_availability")
	assert_not_null(tool, "get_editor_toaster_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "toaster_available", "Editor toaster output should expose toaster_available")
	assert_has(properties, "toaster_type", "Editor toaster output should expose toaster_type")

func test_get_editor_toaster_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_toaster_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor toaster read should fail cleanly without editor interface")

func test_get_editor_resource_filesystem_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_resource_filesystem_availability(server_core)
	var tool = server_core.get_tool("get_editor_resource_filesystem_availability")
	assert_not_null(tool, "get_editor_resource_filesystem_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "resource_filesystem_available", "Editor resource filesystem output should expose resource_filesystem_available")
	assert_has(properties, "resource_filesystem_type", "Editor resource filesystem output should expose resource_filesystem_type")

func test_get_editor_resource_filesystem_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_resource_filesystem_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor resource filesystem read should fail cleanly without editor interface")

func test_get_editor_script_editor_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_script_editor_availability(server_core)
	var tool = server_core.get_tool("get_editor_script_editor_availability")
	assert_not_null(tool, "get_editor_script_editor_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "script_editor_available", "Editor script editor output should expose script_editor_available")
	assert_has(properties, "script_editor_type", "Editor script editor output should expose script_editor_type")

func test_get_editor_script_editor_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_script_editor_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor script editor read should fail cleanly without editor interface")

func test_get_editor_open_script_summary_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_open_script_summary(server_core)
	var tool = server_core.get_tool("get_editor_open_script_summary")
	assert_not_null(tool, "get_editor_open_script_summary should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "script_open", "Editor open script summary should expose script_open")
	assert_has(properties, "script_path", "Editor open script summary should expose script_path")
	assert_has(properties, "current_script_type", "Editor open script summary should expose current_script_type")
	assert_has(properties, "current_editor_type", "Editor open script summary should expose current_editor_type")
	assert_has(properties, "current_editor_breakpoints", "Editor open script summary should expose current_editor_breakpoints")
	assert_has(properties, "current_editor_breakpoint_count", "Editor open script summary should expose current_editor_breakpoint_count")
	assert_has(properties, "open_script_paths", "Editor open script summary should expose open_script_paths")
	assert_has(properties, "open_script_types", "Editor open script summary should expose open_script_types")
	assert_has(properties, "open_script_count", "Editor open script summary should expose open_script_count")
	assert_has(properties, "open_script_editor_types", "Editor open script summary should expose open_script_editor_types")
	assert_has(properties, "open_script_editor_count", "Editor open script summary should expose open_script_editor_count")
	assert_has(properties, "breakpoints", "Editor open script summary should expose breakpoints")
	assert_has(properties, "breakpoint_count", "Editor open script summary should expose breakpoint_count")

func test_get_editor_open_script_summary_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_open_script_summary({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor open script summary should fail cleanly without editor interface")

func test_get_editor_open_scene_summary_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_open_scene_summary(server_core)
	var tool = server_core.get_tool("get_editor_open_scene_summary")
	assert_not_null(tool, "get_editor_open_scene_summary should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "scene_open", "Editor open scene summary should expose scene_open")
	assert_has(properties, "scene_path", "Editor open scene summary should expose scene_path")

func test_get_editor_open_scene_summary_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_open_scene_summary({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor open scene summary should fail cleanly without editor interface")

func test_get_editor_open_scenes_summary_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_open_scenes_summary(server_core)
	var tool = server_core.get_tool("get_editor_open_scenes_summary")
	assert_not_null(tool, "get_editor_open_scenes_summary should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "open_scene_paths", "Editor open scenes summary should expose open_scene_paths")
	assert_has(properties, "active_scene_path", "Editor open scenes summary should expose active_scene_path")
	assert_has(properties, "open_scene_count", "Editor open scenes summary should expose open_scene_count")

func test_get_editor_open_scenes_summary_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_open_scenes_summary({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor open scenes summary should fail cleanly without editor interface")

func test_get_editor_open_scene_roots_summary_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_open_scene_roots_summary(server_core)
	var tool = server_core.get_tool("get_editor_open_scene_roots_summary")
	assert_not_null(tool, "get_editor_open_scene_roots_summary should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "open_scene_roots", "Editor open scene roots summary should expose open_scene_roots")
	assert_has(properties, "open_scene_root_count", "Editor open scene roots summary should expose open_scene_root_count")

func test_get_editor_open_scene_roots_summary_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_open_scene_roots_summary({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor open scene roots summary should fail cleanly without editor interface")

func test_get_editor_settings_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_settings_availability(server_core)
	var tool = server_core.get_tool("get_editor_settings_availability")
	assert_not_null(tool, "get_editor_settings_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "editor_settings_available", "Editor settings output should expose editor_settings_available")
	assert_has(properties, "editor_settings_type", "Editor settings output should expose editor_settings_type")

func test_get_editor_settings_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_settings_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor settings availability should fail cleanly without editor interface")

func test_get_editor_theme_availability_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_theme_availability(server_core)
	var tool = server_core.get_tool("get_editor_theme_availability")
	assert_not_null(tool, "get_editor_theme_availability should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "editor_theme_available", "Editor theme output should expose editor_theme_available")
	assert_has(properties, "editor_theme_type", "Editor theme output should expose editor_theme_type")

func test_get_editor_theme_availability_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_theme_availability({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor theme availability should fail cleanly without editor interface")

func test_get_editor_current_feature_profile_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_current_feature_profile(server_core)
	var tool = server_core.get_tool("get_editor_current_feature_profile")
	assert_not_null(tool, "get_editor_current_feature_profile should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "current_feature_profile", "Editor feature profile output should expose current_feature_profile")
	assert_has(properties, "uses_default_profile", "Editor feature profile output should expose uses_default_profile")

func test_get_editor_current_feature_profile_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_current_feature_profile({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor feature profile read should fail cleanly without editor interface")

func test_get_editor_plugin_enabled_state_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_plugin_enabled_state(server_core)
	var tool = server_core.get_tool("get_editor_plugin_enabled_state")
	assert_not_null(tool, "get_editor_plugin_enabled_state should register successfully")
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(properties, "plugin_name", "Editor plugin enabled-state output should expose plugin_name")
	assert_has(properties, "enabled", "Editor plugin enabled-state output should expose enabled")

func test_get_editor_plugin_enabled_state_requires_plugin_name() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_plugin_enabled_state({})
	assert_eq(result.get("error", ""), "Missing required parameter: plugin_name", "Editor plugin enabled-state read should require plugin_name")

func test_get_editor_plugin_enabled_state_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_plugin_enabled_state({"plugin_name": "godot_mcp"})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor plugin enabled-state read should fail cleanly without editor interface")

func test_get_editor_current_scene_dirty_state_registers_read_surface() -> void:
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

	_editor_tools._register_get_editor_current_scene_dirty_state(server_core)
	var tool = server_core.get_tool("get_editor_current_scene_dirty_state")
	assert_not_null(tool, "get_editor_current_scene_dirty_state should register successfully")
	var input_properties: Dictionary = tool.input_schema.get("properties", {})
	var properties: Dictionary = tool.output_schema.get("properties", {})
	assert_has(input_properties, "set_dirty", "Editor current scene dirty-state helper should expose optional set_dirty input")
	assert_has(properties, "scene_open", "Editor current scene dirty-state output should expose scene_open")
	assert_has(properties, "scene_path", "Editor current scene dirty-state output should expose scene_path")
	assert_has(properties, "scene_dirty", "Editor current scene dirty-state output should expose scene_dirty")
	assert_eq(tool.annotations.get("readOnlyHint"), false, "Editor current scene dirty-state helper should no longer advertise readOnlyHint when optional set_dirty is available")

func test_get_editor_current_scene_dirty_state_reports_missing_editor_interface() -> void:
	var result: Dictionary = _editor_tools._tool_get_editor_current_scene_dirty_state({})
	assert_eq(result.get("error", ""), "Editor interface not available", "Editor current scene dirty-state read should fail cleanly without editor interface")
