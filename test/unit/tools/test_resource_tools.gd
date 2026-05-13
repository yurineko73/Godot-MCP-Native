extends "res://addons/gut/test.gd"

var _resource_tools: RefCounted = null

func before_each():
	_resource_tools = load("res://addons/godot_mcp/tools/resource_tools_native.gd").new()

func after_each():
	_resource_tools = null

func test_resource_scene_list_format():
	var result: Dictionary = _resource_tools._resource_scene_list({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"].size(), 1, "Should have one content item")
	assert_eq(result["contents"][0]["uri"], "godot://scene/list", "URI should be godot://scene/list")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")

func test_resource_scene_list_has_text():
	var result: Dictionary = _resource_tools._resource_scene_list({})
	var text: String = result["contents"][0]["text"]
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed != null, "Text should be valid JSON")
	assert_true(parsed is Dictionary, "Parsed text should be a Dictionary")
	assert_true(parsed.has("scenes"), "Should have scenes key")
	assert_true(parsed.has("count"), "Should have count key")
	assert_true(parsed.has("timestamp"), "Should have timestamp key")

func test_resource_script_list_format():
	var result: Dictionary = _resource_tools._resource_script_list({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://script/list", "URI should be godot://script/list")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")

func test_resource_script_list_has_text():
	var result: Dictionary = _resource_tools._resource_script_list({})
	var text: String = result["contents"][0]["text"]
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed != null, "Text should be valid JSON")
	assert_true(parsed.has("scripts"), "Should have scripts key")
	assert_true(parsed.has("count"), "Should have count key")

func test_resource_project_info_format():
	var result: Dictionary = _resource_tools._resource_project_info({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/info", "URI should be godot://project/info")
	var text: String = result["contents"][0]["text"]
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed != null, "Text should be valid JSON")
	assert_true(parsed.has("name"), "Should have name key")
	assert_true(parsed.has("version"), "Should have version key")
	assert_true(parsed.has("description"), "Should have description key")
	assert_true(parsed.has("main_scene"), "Should have main_scene key")
	assert_true(parsed.has("project_path"), "Should have project_path key")
	assert_true(parsed.has("godot_version"), "Should have godot_version key")
	assert_true(parsed.has("timestamp"), "Should have timestamp key")

func test_resource_project_settings_format():
	var result: Dictionary = _resource_tools._resource_project_settings({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/settings", "URI should be godot://project/settings")
	var text: String = result["contents"][0]["text"]
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed != null, "Text should be valid JSON")
	assert_true(parsed.has("settings"), "Should have settings key")
	assert_true(parsed.has("count"), "Should have count key")
	assert_true(parsed.has("timestamp"), "Should have timestamp key")

func test_resource_scene_current_no_editor():
	var result: Dictionary = _resource_tools._resource_scene_current({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://scene/current", "URI should be godot://scene/current")

func test_resource_scene_open_no_editor():
	var result: Dictionary = _resource_tools._resource_scene_open({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://scene/open", "URI should be godot://scene/open")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")

func test_resource_tools_catalog_no_server():
	var result: Dictionary = _resource_tools._resource_tools_catalog({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://tools/catalog", "URI should be godot://tools/catalog")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("tools"), "Should expose tools key")
	assert_true(parsed.has("count"), "Should expose count key")

func test_resource_project_class_metadata_format():
	var result: Dictionary = _resource_tools._resource_project_class_metadata({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/class_metadata", "URI should be godot://project/class_metadata")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("classes"), "Should expose classes key")
	assert_true(parsed.has("count"), "Should expose count key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_project_configuration_summary_format():
	var result: Dictionary = _resource_tools._resource_project_configuration_summary({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/configuration_summary", "URI should be godot://project/configuration_summary")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("max_items_applied"), "Should expose max_items_applied key")
	assert_true(parsed.has("plugin_count"), "Should expose plugin_count key")
	assert_true(parsed.has("enabled_plugin_count"), "Should expose enabled_plugin_count key")
	assert_true(parsed.has("plugins"), "Should expose plugins key")
	assert_true(parsed.has("plugins_truncated"), "Should expose plugins_truncated key")
	assert_true(parsed.has("autoload_count"), "Should expose autoload_count key")
	assert_true(parsed.has("autoloads"), "Should expose autoloads key")
	assert_true(parsed.has("autoloads_truncated"), "Should expose autoloads_truncated key")
	assert_true(parsed.has("feature_profile_count"), "Should expose feature_profile_count key")
	assert_true(parsed.has("current_feature_profile"), "Should expose current_feature_profile key")
	assert_true(parsed.has("feature_profiles"), "Should expose feature_profiles key")
	assert_true(parsed.has("feature_profiles_truncated"), "Should expose feature_profiles_truncated key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_project_plugins_format():
	var result: Dictionary = _resource_tools._resource_project_plugins({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/plugins", "URI should be godot://project/plugins")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("count"), "Should expose count key")
	assert_true(parsed.has("plugins"), "Should expose plugins key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_project_feature_profiles_format():
	var result: Dictionary = _resource_tools._resource_project_feature_profiles({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/feature_profiles", "URI should be godot://project/feature_profiles")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("count"), "Should expose count key")
	assert_true(parsed.has("current_profile"), "Should expose current_profile key")
	assert_true(parsed.has("profiles"), "Should expose profiles key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_project_autoloads_format():
	var result: Dictionary = _resource_tools._resource_project_autoloads({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/autoloads", "URI should be godot://project/autoloads")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("autoloads"), "Should expose autoloads key")
	assert_true(parsed.has("count"), "Should expose count key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_project_global_classes_format():
	var result: Dictionary = _resource_tools._resource_project_global_classes({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/global_classes", "URI should be godot://project/global_classes")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("classes"), "Should expose classes key")
	assert_true(parsed.has("count"), "Should expose count key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_project_tests_format():
	var result: Dictionary = _resource_tools._resource_project_tests({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/tests", "URI should be godot://project/tests")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("count"), "Should expose count key")
	assert_true(parsed.has("search_path"), "Should expose search_path key")
	assert_true(parsed.has("tests"), "Should expose tests key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_project_test_runners_format():
	var result: Dictionary = _resource_tools._resource_project_test_runners({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/test_runners", "URI should be godot://project/test_runners")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("count"), "Should expose count key")
	assert_true(parsed.has("runners"), "Should expose runners key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_project_dependency_snapshot_format():
	var result: Dictionary = _resource_tools._resource_project_dependency_snapshot({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/dependency_snapshot", "URI should be godot://project/dependency_snapshot")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("resources"), "Should expose resources key")
	assert_true(parsed.has("count"), "Should expose count key")
	assert_true(parsed.has("scanned_resources"), "Should expose scanned_resources key")
	assert_true(parsed.has("missing_dependency_resources"), "Should expose missing_dependency_resources key")
	assert_true(parsed.has("missing_dependency_entries"), "Should expose missing_dependency_entries key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_logs_format():
	var result: Dictionary = _resource_tools._resource_editor_logs({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/logs", "URI should be godot://editor/logs")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("logs"), "Should expose logs key")
	assert_true(parsed.has("count"), "Should expose count key")
	assert_true(parsed.has("total_available"), "Should expose total_available key")
	assert_true(parsed.has("truncated"), "Should expose truncated key")
	assert_true(parsed.has("has_more"), "Should expose has_more key")
	assert_true(parsed.has("source"), "Should expose source key")
	assert_true(parsed.has("order"), "Should expose order key")
	assert_true(parsed.has("snapshot_limit"), "Should expose snapshot_limit key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")
	assert_eq(parsed.get("source"), "mcp", "Editor log snapshot should use mcp source")
	assert_eq(parsed.get("order"), "desc", "Editor log snapshot should use desc order")

func test_resource_runtime_state_format():
	var result: Dictionary = _resource_tools._resource_runtime_state({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://runtime/state", "URI should be godot://runtime/state")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("available"), "Should expose available key")
	assert_true(parsed.has("status"), "Should expose status key")
	assert_true(parsed.has("session_count"), "Should expose session_count key")
	assert_true(parsed.has("active_session_count"), "Should expose active_session_count key")
	assert_true(parsed.has("snapshot_source"), "Should expose snapshot_source key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")
	assert_eq(parsed.get("snapshot_source"), "runtime_probe", "Runtime state snapshot should identify its source")

func test_resource_script_current_no_editor():
	var result: Dictionary = _resource_tools._resource_script_current({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://script/current", "URI should be godot://script/current")

func test_resource_editor_script_summary_format():
	var result: Dictionary = _resource_tools._resource_editor_script_summary({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/script_summary", "URI should be godot://editor/script_summary")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("script_open"), "Should expose script_open key")
	assert_true(parsed.has("script_path"), "Should expose script_path key")
	assert_true(parsed.has("current_script_type"), "Should expose current_script_type key")
	assert_true(parsed.has("current_editor_type"), "Should expose current_editor_type key")
	assert_true(parsed.has("open_script_paths"), "Should expose open_script_paths key")
	assert_true(parsed.has("open_script_count"), "Should expose open_script_count key")
	assert_true(parsed.has("open_script_editor_types"), "Should expose open_script_editor_types key")
	assert_true(parsed.has("breakpoints"), "Should expose breakpoints key")
	assert_true(parsed.has("breakpoint_count"), "Should expose breakpoint_count key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_paths_format():
	var result: Dictionary = _resource_tools._resource_editor_paths({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/paths", "URI should be godot://editor/paths")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("config_dir"), "Should expose config_dir key")
	assert_true(parsed.has("data_dir"), "Should expose data_dir key")
	assert_true(parsed.has("cache_dir"), "Should expose cache_dir key")
	assert_true(parsed.has("project_settings_dir"), "Should expose project_settings_dir key")
	assert_true(parsed.has("export_templates_dir"), "Should expose export_templates_dir key")
	assert_true(parsed.has("self_contained"), "Should expose self_contained key")
	assert_true(parsed.has("self_contained_file"), "Should expose self_contained_file key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_shell_state_format():
	var result: Dictionary = _resource_tools._resource_editor_shell_state({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/shell_state", "URI should be godot://editor/shell_state")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("main_screen_name"), "Should expose main_screen_name key")
	assert_true(parsed.has("main_screen_type"), "Should expose main_screen_type key")
	assert_true(parsed.has("editor_scale"), "Should expose editor_scale key")
	assert_true(parsed.has("multi_window_enabled"), "Should expose multi_window_enabled key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_language_format():
	var result: Dictionary = _resource_tools._resource_editor_language({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/language", "URI should be godot://editor/language")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("editor_language"), "Should expose editor_language key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_current_location_format():
	var result: Dictionary = _resource_tools._resource_editor_current_location({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/current_location", "URI should be godot://editor/current_location")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("current_path"), "Should expose current_path key")
	assert_true(parsed.has("current_directory"), "Should expose current_directory key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_current_feature_profile_format():
	var result: Dictionary = _resource_tools._resource_editor_current_feature_profile({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/current_feature_profile", "URI should be godot://editor/current_feature_profile")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("current_feature_profile"), "Should expose current_feature_profile key")
	assert_true(parsed.has("uses_default_profile"), "Should expose uses_default_profile key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_selected_paths_format():
	var result: Dictionary = _resource_tools._resource_editor_selected_paths({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/selected_paths", "URI should be godot://editor/selected_paths")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("selected_paths"), "Should expose selected_paths key")
	assert_true(parsed.has("selected_count"), "Should expose selected_count key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_play_state_format():
	var result: Dictionary = _resource_tools._resource_editor_play_state({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/play_state", "URI should be godot://editor/play_state")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("is_playing_scene"), "Should expose is_playing_scene key")
	assert_true(parsed.has("playing_scene"), "Should expose playing_scene key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_3d_snap_state_format():
	var result: Dictionary = _resource_tools._resource_editor_3d_snap_state({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/3d_snap_state", "URI should be godot://editor/3d_snap_state")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("snap_enabled"), "Should expose snap_enabled key")
	assert_true(parsed.has("translate_snap"), "Should expose translate_snap key")
	assert_true(parsed.has("rotate_snap"), "Should expose rotate_snap key")
	assert_true(parsed.has("scale_snap"), "Should expose scale_snap key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_subsystem_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_subsystem_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/subsystem_availability", "URI should be godot://editor/subsystem_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("command_palette_available"), "Should expose command_palette_available key")
	assert_true(parsed.has("command_palette_type"), "Should expose command_palette_type key")
	assert_true(parsed.has("toaster_available"), "Should expose toaster_available key")
	assert_true(parsed.has("toaster_type"), "Should expose toaster_type key")
	assert_true(parsed.has("resource_filesystem_available"), "Should expose resource_filesystem_available key")
	assert_true(parsed.has("resource_filesystem_type"), "Should expose resource_filesystem_type key")
	assert_true(parsed.has("script_editor_available"), "Should expose script_editor_available key")
	assert_true(parsed.has("script_editor_type"), "Should expose script_editor_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_previewer_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_previewer_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/previewer_availability", "URI should be godot://editor/previewer_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("resource_previewer_available"), "Should expose resource_previewer_available key")
	assert_true(parsed.has("resource_previewer_type"), "Should expose resource_previewer_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_undo_redo_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_undo_redo_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/undo_redo_availability", "URI should be godot://editor/undo_redo_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("undo_redo_available"), "Should expose undo_redo_available key")
	assert_true(parsed.has("undo_redo_type"), "Should expose undo_redo_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_base_control_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_base_control_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/base_control_availability", "URI should be godot://editor/base_control_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("base_control_available"), "Should expose base_control_available key")
	assert_true(parsed.has("base_control_type"), "Should expose base_control_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_file_system_dock_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_file_system_dock_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/file_system_dock_availability", "URI should be godot://editor/file_system_dock_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("file_system_dock_available"), "Should expose file_system_dock_available key")
	assert_true(parsed.has("file_system_dock_type"), "Should expose file_system_dock_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_inspector_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_inspector_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/inspector_availability", "URI should be godot://editor/inspector_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("inspector_available"), "Should expose inspector_available key")
	assert_true(parsed.has("inspector_type"), "Should expose inspector_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_viewport_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_viewport_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/viewport_availability", "URI should be godot://editor/viewport_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("viewport_2d_available"), "Should expose viewport_2d_available key")
	assert_true(parsed.has("viewport_2d_type"), "Should expose viewport_2d_type key")
	assert_true(parsed.has("viewport_3d_available"), "Should expose viewport_3d_available key")
	assert_true(parsed.has("viewport_3d_type"), "Should expose viewport_3d_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_selection_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_selection_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/selection_availability", "URI should be godot://editor/selection_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("selection_available"), "Should expose selection_available key")
	assert_true(parsed.has("selection_type"), "Should expose selection_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_command_palette_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_command_palette_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/command_palette_availability", "URI should be godot://editor/command_palette_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("command_palette_available"), "Should expose command_palette_available key")
	assert_true(parsed.has("command_palette_type"), "Should expose command_palette_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_toaster_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_toaster_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/toaster_availability", "URI should be godot://editor/toaster_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("toaster_available"), "Should expose toaster_available key")
	assert_true(parsed.has("toaster_type"), "Should expose toaster_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_resource_filesystem_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_resource_filesystem_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/resource_filesystem_availability", "URI should be godot://editor/resource_filesystem_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("resource_filesystem_available"), "Should expose resource_filesystem_available key")
	assert_true(parsed.has("resource_filesystem_type"), "Should expose resource_filesystem_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_script_editor_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_script_editor_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/script_editor_availability", "URI should be godot://editor/script_editor_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("script_editor_available"), "Should expose script_editor_available key")
	assert_true(parsed.has("script_editor_type"), "Should expose script_editor_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_settings_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_settings_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/settings_availability", "URI should be godot://editor/settings_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("editor_settings_available"), "Should expose editor_settings_available key")
	assert_true(parsed.has("editor_settings_type"), "Should expose editor_settings_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_theme_availability_format():
	var result: Dictionary = _resource_tools._resource_editor_theme_availability({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/theme_availability", "URI should be godot://editor/theme_availability")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("editor_theme_available"), "Should expose editor_theme_available key")
	assert_true(parsed.has("editor_theme_type"), "Should expose editor_theme_type key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_current_scene_dirty_state_format():
	var result: Dictionary = _resource_tools._resource_editor_current_scene_dirty_state({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/current_scene_dirty_state", "URI should be godot://editor/current_scene_dirty_state")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("scene_open"), "Should expose scene_open key")
	assert_true(parsed.has("scene_path"), "Should expose scene_path key")
	assert_true(parsed.has("scene_dirty"), "Should expose scene_dirty key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_open_scene_summary_format():
	var result: Dictionary = _resource_tools._resource_editor_open_scene_summary({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/open_scene_summary", "URI should be godot://editor/open_scene_summary")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("scene_open"), "Should expose scene_open key")
	assert_true(parsed.has("scene_path"), "Should expose scene_path key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_open_scenes_summary_format():
	var result: Dictionary = _resource_tools._resource_editor_open_scenes_summary({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/open_scenes_summary", "URI should be godot://editor/open_scenes_summary")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("open_scene_paths"), "Should expose open_scene_paths key")
	assert_true(parsed.has("active_scene_path"), "Should expose active_scene_path key")
	assert_true(parsed.has("open_scene_count"), "Should expose open_scene_count key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_open_scene_roots_summary_format():
	var result: Dictionary = _resource_tools._resource_editor_open_scene_roots_summary({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/open_scene_roots_summary", "URI should be godot://editor/open_scene_roots_summary")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")
	var parsed: Variant = JSON.parse_string(result["contents"][0]["text"])
	assert_true(parsed is Dictionary, "Text should be a Dictionary")
	assert_true(parsed.has("open_scene_roots"), "Should expose open_scene_roots key")
	assert_true(parsed.has("open_scene_root_count"), "Should expose open_scene_root_count key")
	assert_true(parsed.has("timestamp"), "Should expose timestamp key")

func test_resource_editor_state_no_editor():
	var result: Dictionary = _resource_tools._resource_editor_state({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/state", "URI should be godot://editor/state")

func test_count_nodes():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child1: Node = Node.new()
	child1.name = "Child1"
	var child2: Node = Node.new()
	child2.name = "Child2"
	root.add_child(child1)
	root.add_child(child2)
	var count: int = _resource_tools._count_nodes(root)
	assert_eq(count, 3, "Should count root + 2 children")

func test_count_nodes_nested():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child"
	var grandchild: Node = Node.new()
	grandchild.name = "GrandChild"
	root.add_child(child)
	child.add_child(grandchild)
	var count: int = _resource_tools._count_nodes(root)
	assert_eq(count, 3, "Should count root + child + grandchild")

func test_get_node_tree():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child1"
	root.add_child(child)
	var tree: Array = _resource_tools._get_node_tree(root, 1)
	assert_eq(tree.size(), 1, "Should have 1 child at depth 1")
	assert_eq(tree[0]["name"], "Child1", "Child name should be Child1")
	assert_eq(tree[0]["type"], "Node", "Child type should be Node")

func test_get_node_tree_max_depth():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child"
	root.add_child(child)
	var tree: Array = _resource_tools._get_node_tree(root, 0)
	assert_eq(tree.size(), 0, "Should have 0 children at depth 0 (max_depth=0)")

func test_get_godot_version():
	var version: Dictionary = _resource_tools._get_godot_version()
	assert_true(version.has("version"), "Should have version key")
	assert_true(version.has("major"), "Should have major key")
	assert_true(version.has("minor"), "Should have minor key")
	assert_true(version.has("patch"), "Should have patch key")
	assert_true(version["major"] >= 4, "Godot major version should be >= 4")

func test_register_resources():
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()
	_resource_tools.register_resources(server_core)
	assert_eq(server_core.get_resources_count(), 47, "Should register 47 resources")
