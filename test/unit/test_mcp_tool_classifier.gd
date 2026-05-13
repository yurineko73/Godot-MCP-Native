extends "res://addons/gut/test.gd"

var _classifier = null

func before_each():
	_classifier = load("res://addons/godot_mcp/native_mcp/mcp_tool_classifier.gd").new()

func after_each():
	_classifier = null

func test_classifier_initializes():
	assert_ne(_classifier, null, "Classifier should initialize")

func test_all_205_tools_registered():
	var all_tools: Array = _classifier.get_all_tools()
	assert_eq(all_tools.size(), 205, "Should have exactly 205 tools registered")

func test_core_tools_count_within_limit():
	var core_tools: Array = _classifier.get_core_tools()
	assert_eq(core_tools.size(), 46, "Should have exactly 46 core tools")

func test_supplementary_tools_count():
	var supp_tools: Array = _classifier.get_supplementary_tools()
	assert_eq(supp_tools.size(), 159, "Should have 159 supplementary tools")

func test_get_tool_category_create_node():
	var cat: String = _classifier.get_tool_category("create_node")
	assert_eq(cat, "core", "create_node should be core")

func test_get_tool_category_execute_editor_script():
	var cat: String = _classifier.get_tool_category("execute_editor_script")
	assert_eq(cat, "supplementary", "execute_editor_script should be supplementary")

func test_get_tool_category_unknown():
	var cat: String = _classifier.get_tool_category("non_existent_tool")
	assert_eq(cat, "core", "Unknown tool should default to core")

func test_get_tool_group_create_node():
	var group: String = _classifier.get_tool_group("create_node")
	assert_eq(group, "Node-Write", "create_node should be in Node-Write group")

func test_get_tool_group_read_script():
	var group: String = _classifier.get_tool_group("read_script")
	assert_eq(group, "Script", "read_script should be in Script group")

func test_get_tool_group_reload_project():
	var group: String = _classifier.get_tool_group("reload_project")
	assert_eq(group, "Editor-Advanced", "reload_project should be in Editor-Advanced group")

func test_get_tool_group_unknown():
	var group: String = _classifier.get_tool_group("non_existent_tool")
	assert_eq(group, "", "Unknown tool should return empty group")

func test_get_all_groups_contains_core_groups():
	var groups: Array = _classifier.get_all_groups()
	assert_true("Node-Read" in groups, "Should contain Node-Read group")
	assert_true("Node-Write" in groups, "Should contain Node-Write group")
	assert_true("Script" in groups, "Should contain Script group")
	assert_true("Scene" in groups, "Should contain Scene group")
	assert_true("Editor" in groups, "Should contain Editor group")

func test_get_all_groups_contains_supplementary_groups():
	var groups: Array = _classifier.get_all_groups()
	assert_true("Editor-Advanced" in groups, "Should contain Editor-Advanced group")
	assert_true("Debug-Advanced" in groups, "Should contain Debug-Advanced group")
	assert_true("Node-Advanced" in groups, "Should contain Node-Advanced group")
	assert_true("Scene-Advanced" in groups, "Should contain Scene-Advanced group")
	assert_true("Script-Advanced" in groups, "Should contain Script-Advanced group")
	assert_true("Project-Advanced" in groups, "Should contain Project-Advanced group")

func test_get_group_tools_node_write():
	var tools: Array = _classifier.get_group_tools("Node-Write")
	assert_true(tools.size() >= 10, "Node-Write should have 10+ tools")
	assert_true("create_node" in tools, "Node-Write should contain create_node")
	assert_true("delete_node" in tools, "Node-Write should contain delete_node")
	assert_true("update_node_property" in tools, "Node-Write should contain update_node_property")

func test_get_group_tools_script():
	var tools: Array = _classifier.get_group_tools("Script")
	assert_true(tools.size() >= 9, "Script should have 9 tools")
	assert_true("read_script" in tools, "Script should contain read_script")
	assert_true("create_script" in tools, "Script should contain create_script")
	assert_true("modify_script" in tools, "Script should contain modify_script")

func test_is_core_tool():
	assert_true(_classifier.is_core_tool("create_node"), "create_node should be core")
	assert_false(_classifier.is_core_tool("execute_editor_script"), "execute_editor_script should not be core")

func test_is_supplementary_tool():
	assert_true(_classifier.is_supplementary_tool("execute_editor_script"), "execute_editor_script should be supplementary")
	assert_true(_classifier.is_supplementary_tool("reload_project"), "reload_project should be supplementary")
	assert_true(_classifier.is_supplementary_tool("execute_script"), "execute_script should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_performance_metrics"), "get_performance_metrics should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_debugger_sessions"), "get_debugger_sessions should be supplementary")
	assert_true(_classifier.is_supplementary_tool("set_debugger_breakpoint"), "set_debugger_breakpoint should be supplementary")
	assert_true(_classifier.is_supplementary_tool("send_debugger_message"), "send_debugger_message should be supplementary")
	assert_true(_classifier.is_supplementary_tool("toggle_debugger_profiler"), "toggle_debugger_profiler should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_debugger_messages"), "get_debugger_messages should be supplementary")
	assert_true(_classifier.is_supplementary_tool("add_debugger_capture_prefix"), "add_debugger_capture_prefix should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_debug_stack_frames"), "get_debug_stack_frames should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_debug_stack_variables"), "get_debug_stack_variables should be supplementary")
	assert_true(_classifier.is_supplementary_tool("install_runtime_probe"), "install_runtime_probe should be supplementary")
	assert_true(_classifier.is_supplementary_tool("remove_runtime_probe"), "remove_runtime_probe should be supplementary")
	assert_true(_classifier.is_supplementary_tool("request_debug_break"), "request_debug_break should be supplementary")
	assert_true(_classifier.is_supplementary_tool("send_debug_command"), "send_debug_command should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_info"), "get_runtime_info should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_scene_tree"), "get_runtime_scene_tree should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_runtime_node"), "inspect_runtime_node should be supplementary")
	assert_true(_classifier.is_supplementary_tool("update_runtime_node_property"), "update_runtime_node_property should be supplementary")
	assert_true(_classifier.is_supplementary_tool("call_runtime_node_method"), "call_runtime_node_method should be supplementary")
	assert_true(_classifier.is_supplementary_tool("evaluate_runtime_expression"), "evaluate_runtime_expression should be supplementary")
	assert_true(_classifier.is_supplementary_tool("await_runtime_condition"), "await_runtime_condition should be supplementary")
	assert_true(_classifier.is_supplementary_tool("assert_runtime_condition"), "assert_runtime_condition should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_debug_threads"), "get_debug_threads should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_debug_state_events"), "get_debug_state_events should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_debug_output"), "get_debug_output should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_debug_scopes"), "get_debug_scopes should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_debug_variables"), "get_debug_variables should be supplementary")
	assert_true(_classifier.is_supplementary_tool("expand_debug_variable"), "expand_debug_variable should be supplementary")
	assert_true(_classifier.is_supplementary_tool("evaluate_debug_expression"), "evaluate_debug_expression should be supplementary")
	assert_true(_classifier.is_supplementary_tool("debug_step_into"), "debug_step_into should be supplementary")
	assert_true(_classifier.is_supplementary_tool("debug_step_over"), "debug_step_over should be supplementary")
	assert_true(_classifier.is_supplementary_tool("debug_step_out"), "debug_step_out should be supplementary")
	assert_true(_classifier.is_supplementary_tool("debug_continue"), "debug_continue should be supplementary")
	assert_true(_classifier.is_supplementary_tool("debug_step_into_and_wait"), "debug_step_into_and_wait should be supplementary")
	assert_true(_classifier.is_supplementary_tool("debug_step_over_and_wait"), "debug_step_over_and_wait should be supplementary")
	assert_true(_classifier.is_supplementary_tool("debug_step_out_and_wait"), "debug_step_out_and_wait should be supplementary")
	assert_true(_classifier.is_supplementary_tool("debug_continue_and_wait"), "debug_continue_and_wait should be supplementary")
	assert_true(_classifier.is_supplementary_tool("await_debugger_state"), "await_debugger_state should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_performance_snapshot"), "get_runtime_performance_snapshot should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_memory_trend"), "get_runtime_memory_trend should be supplementary")
	assert_true(_classifier.is_supplementary_tool("create_runtime_node"), "create_runtime_node should be supplementary")
	assert_true(_classifier.is_supplementary_tool("delete_runtime_node"), "delete_runtime_node should be supplementary")
	assert_true(_classifier.is_supplementary_tool("simulate_runtime_input_event"), "simulate_runtime_input_event should be supplementary")
	assert_true(_classifier.is_supplementary_tool("simulate_runtime_input_action"), "simulate_runtime_input_action should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_runtime_input_actions"), "list_runtime_input_actions should be supplementary")
	assert_true(_classifier.is_supplementary_tool("upsert_runtime_input_action"), "upsert_runtime_input_action should be supplementary")
	assert_true(_classifier.is_supplementary_tool("remove_runtime_input_action"), "remove_runtime_input_action should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_runtime_animations"), "list_runtime_animations should be supplementary")
	assert_true(_classifier.is_supplementary_tool("play_runtime_animation"), "play_runtime_animation should be supplementary")
	assert_true(_classifier.is_supplementary_tool("stop_runtime_animation"), "stop_runtime_animation should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_animation_state"), "get_runtime_animation_state should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_animation_tree_state"), "get_runtime_animation_tree_state should be supplementary")
	assert_true(_classifier.is_supplementary_tool("set_runtime_animation_tree_active"), "set_runtime_animation_tree_active should be supplementary")
	assert_true(_classifier.is_supplementary_tool("travel_runtime_animation_tree"), "travel_runtime_animation_tree should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_material_state"), "get_runtime_material_state should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_theme_item"), "get_runtime_theme_item should be supplementary")
	assert_true(_classifier.is_supplementary_tool("set_runtime_theme_override"), "set_runtime_theme_override should be supplementary")
	assert_true(_classifier.is_supplementary_tool("clear_runtime_theme_override"), "clear_runtime_theme_override should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_shader_parameters"), "get_runtime_shader_parameters should be supplementary")
	assert_true(_classifier.is_supplementary_tool("set_runtime_shader_parameter"), "set_runtime_shader_parameter should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_runtime_tilemap_layers"), "list_runtime_tilemap_layers should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_tilemap_cell"), "get_runtime_tilemap_cell should be supplementary")
	assert_true(_classifier.is_supplementary_tool("set_runtime_tilemap_cell"), "set_runtime_tilemap_cell should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_runtime_audio_buses"), "list_runtime_audio_buses should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_audio_bus"), "get_runtime_audio_bus should be supplementary")
	assert_true(_classifier.is_supplementary_tool("update_runtime_audio_bus"), "update_runtime_audio_bus should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_runtime_screenshot"), "get_runtime_screenshot should be supplementary")
	assert_true(_classifier.is_supplementary_tool("select_node"), "select_node should be supplementary")
	assert_true(_classifier.is_supplementary_tool("select_file"), "select_file should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_file_system_navigation"), "get_file_system_navigation should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_paths"), "get_editor_paths should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_shell_state"), "get_editor_shell_state should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_language"), "get_editor_language should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_play_state"), "get_editor_play_state should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_3d_snap_state"), "get_editor_3d_snap_state should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_subsystem_availability"), "get_editor_subsystem_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_previewer_availability"), "get_editor_previewer_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_undo_redo_availability"), "get_editor_undo_redo_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_viewport_availability"), "get_editor_viewport_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_base_control_availability"), "get_editor_base_control_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_file_system_dock_availability"), "get_editor_file_system_dock_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_inspector_availability"), "get_editor_inspector_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_current_location"), "get_editor_current_location should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_selected_paths_summary"), "get_editor_selected_paths_summary should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_selection_availability"), "get_editor_selection_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_command_palette_availability"), "get_editor_command_palette_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_toaster_availability"), "get_editor_toaster_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_resource_filesystem_availability"), "get_editor_resource_filesystem_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_script_editor_availability"), "get_editor_script_editor_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_open_script_summary"), "get_editor_open_script_summary should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_open_scene_summary"), "get_editor_open_scene_summary should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_open_scenes_summary"), "get_editor_open_scenes_summary should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_open_scene_roots_summary"), "get_editor_open_scene_roots_summary should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_settings_availability"), "get_editor_settings_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_theme_availability"), "get_editor_theme_availability should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_current_feature_profile"), "get_editor_current_feature_profile should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_plugin_enabled_state"), "get_editor_plugin_enabled_state should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_editor_current_scene_dirty_state"), "get_editor_current_scene_dirty_state should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_inspector_properties"), "get_inspector_properties should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_export_presets"), "list_export_presets should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_export_templates"), "inspect_export_templates should be supplementary")
	assert_true(_classifier.is_supplementary_tool("validate_export_preset"), "validate_export_preset should be supplementary")
	assert_true(_classifier.is_supplementary_tool("run_export"), "run_export should be supplementary")
	assert_true(_classifier.is_supplementary_tool("batch_update_node_properties"), "batch_update_node_properties should be supplementary")
	assert_true(_classifier.is_supplementary_tool("batch_scene_node_edits"), "batch_scene_node_edits should be supplementary")
	assert_true(_classifier.is_supplementary_tool("audit_scene_node_persistence"), "audit_scene_node_persistence should be supplementary")
	assert_true(_classifier.is_supplementary_tool("audit_scene_inheritance"), "audit_scene_inheritance should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_open_scenes"), "list_open_scenes should be supplementary")
	assert_true(_classifier.is_supplementary_tool("close_scene_tab"), "close_scene_tab should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_project_script_symbols"), "list_project_script_symbols should be supplementary")
	assert_true(_classifier.is_supplementary_tool("find_script_symbol_definition"), "find_script_symbol_definition should be supplementary")
	assert_true(_classifier.is_supplementary_tool("find_script_symbol_references"), "find_script_symbol_references should be supplementary")
	assert_true(_classifier.is_supplementary_tool("rename_script_symbol"), "rename_script_symbol should be supplementary")
	assert_true(_classifier.is_supplementary_tool("open_script_at_line"), "open_script_at_line should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_project_tests"), "list_project_tests should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_project_test_runners"), "list_project_test_runners should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_project_test"), "inspect_project_test should be supplementary")
	assert_true(_classifier.is_supplementary_tool("run_project_test"), "run_project_test should be supplementary")
	assert_true(_classifier.is_supplementary_tool("run_project_tests"), "run_project_tests should be supplementary")
	assert_true(_classifier.is_supplementary_tool("set_project_setting"), "set_project_setting should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_project_setting"), "inspect_project_setting should be supplementary")
	assert_true(_classifier.is_supplementary_tool("clear_project_setting"), "clear_project_setting should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_project_input_actions"), "list_project_input_actions should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_project_input_action"), "inspect_project_input_action should be supplementary")
	assert_true(_classifier.is_supplementary_tool("upsert_project_input_action"), "upsert_project_input_action should be supplementary")
	assert_true(_classifier.is_supplementary_tool("remove_project_input_action"), "remove_project_input_action should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_project_autoloads"), "list_project_autoloads should be supplementary")
	assert_true(_classifier.is_supplementary_tool("upsert_project_autoload"), "upsert_project_autoload should be supplementary")
	assert_true(_classifier.is_supplementary_tool("remove_project_autoload"), "remove_project_autoload should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_project_autoload"), "inspect_project_autoload should be supplementary")
	assert_true(_classifier.is_supplementary_tool("set_project_plugin_enabled"), "set_project_plugin_enabled should be supplementary")
	assert_true(_classifier.is_supplementary_tool("set_project_feature_profile"), "set_project_feature_profile should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_project_feature_profile"), "inspect_project_feature_profile should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_project_feature_profiles"), "list_project_feature_profiles should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_project_plugins"), "list_project_plugins should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_project_plugin"), "inspect_project_plugin should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_project_configuration_summary"), "get_project_configuration_summary should be supplementary")
	assert_true(_classifier.is_supplementary_tool("list_project_global_classes"), "list_project_global_classes should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_project_global_class"), "inspect_project_global_class should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_class_api_metadata"), "get_class_api_metadata should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_csharp_project_support"), "inspect_csharp_project_support should be supplementary")
	assert_true(_classifier.is_supplementary_tool("compare_render_screenshots"), "compare_render_screenshots should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_tileset_resource"), "inspect_tileset_resource should be supplementary")
	assert_true(_classifier.is_supplementary_tool("inspect_project_resource"), "inspect_project_resource should be supplementary")
	assert_true(_classifier.is_supplementary_tool("update_project_resource_properties"), "update_project_resource_properties should be supplementary")
	assert_true(_classifier.is_supplementary_tool("duplicate_project_resource"), "duplicate_project_resource should be supplementary")
	assert_true(_classifier.is_supplementary_tool("delete_project_resource"), "delete_project_resource should be supplementary")
	assert_true(_classifier.is_supplementary_tool("move_project_resource"), "move_project_resource should be supplementary")
	assert_true(_classifier.is_supplementary_tool("reimport_resources"), "reimport_resources should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_import_metadata"), "get_import_metadata should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_resource_uid_info"), "get_resource_uid_info should be supplementary")
	assert_true(_classifier.is_supplementary_tool("fix_resource_uid"), "fix_resource_uid should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_resource_dependencies"), "get_resource_dependencies should be supplementary")
	assert_true(_classifier.is_supplementary_tool("scan_missing_resource_dependencies"), "scan_missing_resource_dependencies should be supplementary")
	assert_true(_classifier.is_supplementary_tool("scan_cyclic_resource_dependencies"), "scan_cyclic_resource_dependencies should be supplementary")
	assert_true(_classifier.is_supplementary_tool("detect_broken_scripts"), "detect_broken_scripts should be supplementary")
	assert_true(_classifier.is_supplementary_tool("audit_project_health"), "audit_project_health should be supplementary")

func test_get_core_max_count():
	assert_eq(_classifier.get_core_max_count(), 46, "Core max count should be 46")

func test_get_all_categories():
	var cats: Array = _classifier.get_all_categories()
	assert_true("core" in cats, "Should contain core category")
	assert_true("supplementary" in cats, "Should contain supplementary category")

func test_classifier_no_duplicate_groups():
	var groups: Array = _classifier.get_all_groups()
	var unique: Array = []
	for g in groups:
		if not g in unique:
			unique.append(g)
	assert_eq(groups.size(), unique.size(), "Groups should not contain duplicates")

func test_classifier_no_duplicate_tools():
	var tools: Array = _classifier.get_all_tools()
	var unique: Array = []
	for t in tools:
		if not t in unique:
			unique.append(t)
	assert_eq(tools.size(), unique.size(), "Tools should not contain duplicates")
