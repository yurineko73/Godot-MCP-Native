# resource_tools_native.gd
# 璧勬簮宸ュ叿 - 瀹炵幇 MCP 璧勬簮璇诲彇鍔熻兘
# 鐗堟湰: 1.0
# 浣滆€? AI Assistant
# 鏃ユ湡: 2026-05-01

@tool
class_name ResourceToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null
var _base_control: Control = null
var _log_callback: Callable = Callable()
var _server_core: RefCounted = null

func set_log_callback(callback: Callable) -> void:
	_log_callback = callback

func initialize(editor_interface: EditorInterface, base_control: Control) -> void:
	_editor_interface = editor_interface
	_base_control = base_control
	if _log_callback.is_valid():
		_log_callback.call("INFO", "鍒濆鍖栧畬鎴?)

static func _build_runtime_state_snapshot() -> Dictionary:
	var result: Dictionary = {
		"available": false,
		"status": "no_active_sessions",
		"session_count": 0,
		"active_session_count": 0,
		"snapshot_source": "runtime_probe",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		result["status"] = "plugin_unavailable"
		return result

	var debug_tools: RefCounted = plugin.get_tool_instance("DebugToolsNative")
	if not debug_tools:
		result["status"] = "debug_tools_unavailable"
		return result

	if debug_tools.has_method("_tool_get_debugger_sessions"):
		var sessions_result: Variant = debug_tools._tool_get_debugger_sessions({})
		if sessions_result is Dictionary:
			var sessions: Array = sessions_result.get("sessions", [])
			var active_session_count: int = 0
			for session in sessions:
				if bool(session.get("active", false)):
					active_session_count += 1
			result["session_count"] = int(sessions_result.get("count", sessions.size()))
			result["active_session_count"] = active_session_count
			if sessions.size() > 0:
				result["sessions"] = sessions

	if not debug_tools.has_method("_tool_get_runtime_info"):
		result["status"] = "runtime_info_unavailable"
		return result

	var runtime_result: Variant = debug_tools._tool_get_runtime_info({"timeout_ms": 1500})
	if runtime_result is Dictionary:
		var runtime_status: String = str(runtime_result.get("status", ""))
		if runtime_status == "success" or runtime_status == "stale":
			result["available"] = true
			for key in runtime_result.keys():
				result[key] = runtime_result[key]
			return result
		if not runtime_status.is_empty():
			result["status"] = runtime_status
		if runtime_result.has("refresh_result"):
			result["refresh_result"] = runtime_result.get("refresh_result")

	return result

static func _build_editor_script_summary_snapshot() -> Dictionary:
	var result: Dictionary = {
		"script_open": false,
		"script_path": "",
		"current_script_type": "",
		"current_editor_type": "",
		"current_editor_breakpoints": [],
		"current_editor_breakpoint_count": 0,
		"open_script_paths": [],
		"open_script_types": [],
		"open_script_count": 0,
		"open_script_editor_types": [],
		"open_script_editor_count": 0,
		"breakpoints": [],
		"breakpoint_count": 0,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_open_script_summary"):
		return result

	var summary_result: Variant = editor_tools._tool_get_editor_open_script_summary({})
	if summary_result is Dictionary and not summary_result.has("error"):
		for key in summary_result.keys():
			result[key] = summary_result[key]

	return result

static func _build_editor_paths_snapshot() -> Dictionary:
	var result: Dictionary = {
		"config_dir": "",
		"data_dir": "",
		"cache_dir": "",
		"project_settings_dir": "",
		"export_templates_dir": "",
		"self_contained": false,
		"self_contained_file": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_paths"):
		return result

	var paths_result: Variant = editor_tools._tool_get_editor_paths({})
	if paths_result is Dictionary and not paths_result.has("error"):
		for key in paths_result.keys():
			result[key] = paths_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_shell_state_snapshot() -> Dictionary:
	var result: Dictionary = {
		"main_screen_name": "",
		"main_screen_type": "",
		"editor_scale": 1.0,
		"multi_window_enabled": false,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_shell_state"):
		return result

	var shell_result: Variant = editor_tools._tool_get_editor_shell_state({})
	if shell_result is Dictionary and not shell_result.has("error"):
		for key in shell_result.keys():
			result[key] = shell_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_language_snapshot() -> Dictionary:
	var result: Dictionary = {
		"editor_language": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_language"):
		return result

	var language_result: Variant = editor_tools._tool_get_editor_language({})
	if language_result is Dictionary and not language_result.has("error"):
		for key in language_result.keys():
			result[key] = language_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_current_location_snapshot() -> Dictionary:
	var result: Dictionary = {
		"current_path": "",
		"current_directory": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_current_location"):
		return result

	var location_result: Variant = editor_tools._tool_get_editor_current_location({})
	if location_result is Dictionary and not location_result.has("error"):
		for key in location_result.keys():
			result[key] = location_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_current_feature_profile_snapshot() -> Dictionary:
	var result: Dictionary = {
		"current_feature_profile": "",
		"uses_default_profile": true,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_current_feature_profile"):
		return result

	var feature_profile_result: Variant = editor_tools._tool_get_editor_current_feature_profile({})
	if feature_profile_result is Dictionary and not feature_profile_result.has("error"):
		for key in feature_profile_result.keys():
			result[key] = feature_profile_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_selected_paths_snapshot() -> Dictionary:
	var result: Dictionary = {
		"selected_paths": [],
		"selected_count": 0,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_selected_paths_summary"):
		return result

	var selected_paths_result: Variant = editor_tools._tool_get_editor_selected_paths_summary({})
	if selected_paths_result is Dictionary and not selected_paths_result.has("error"):
		for key in selected_paths_result.keys():
			result[key] = selected_paths_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_play_state_snapshot() -> Dictionary:
	var result: Dictionary = {
		"is_playing_scene": false,
		"playing_scene": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_play_state"):
		return result

	var play_state_result: Variant = editor_tools._tool_get_editor_play_state({})
	if play_state_result is Dictionary and not play_state_result.has("error"):
		for key in play_state_result.keys():
			result[key] = play_state_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_3d_snap_state_snapshot() -> Dictionary:
	var result: Dictionary = {
		"snap_enabled": false,
		"translate_snap": 0.0,
		"rotate_snap": 0.0,
		"scale_snap": 0.0,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_3d_snap_state"):
		return result

	var snap_state_result: Variant = editor_tools._tool_get_editor_3d_snap_state({})
	if snap_state_result is Dictionary and not snap_state_result.has("error"):
		for key in snap_state_result.keys():
			result[key] = snap_state_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_subsystem_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"command_palette_available": false,
		"command_palette_type": "",
		"toaster_available": false,
		"toaster_type": "",
		"resource_filesystem_available": false,
		"resource_filesystem_type": "",
		"script_editor_available": false,
		"script_editor_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_subsystem_availability"):
		return result

	var subsystem_result: Variant = editor_tools._tool_get_editor_subsystem_availability({})
	if subsystem_result is Dictionary and not subsystem_result.has("error"):
		for key in subsystem_result.keys():
			result[key] = subsystem_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_previewer_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"resource_previewer_available": false,
		"resource_previewer_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_previewer_availability"):
		return result

	var previewer_result: Variant = editor_tools._tool_get_editor_previewer_availability({})
	if previewer_result is Dictionary and not previewer_result.has("error"):
		for key in previewer_result.keys():
			result[key] = previewer_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_undo_redo_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"undo_redo_available": false,
		"undo_redo_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_undo_redo_availability"):
		return result

	var undo_redo_result: Variant = editor_tools._tool_get_editor_undo_redo_availability({})
	if undo_redo_result is Dictionary and not undo_redo_result.has("error"):
		for key in undo_redo_result.keys():
			result[key] = undo_redo_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_base_control_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"base_control_available": false,
		"base_control_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_base_control_availability"):
		return result

	var base_control_result: Variant = editor_tools._tool_get_editor_base_control_availability({})
	if base_control_result is Dictionary and not base_control_result.has("error"):
		for key in base_control_result.keys():
			result[key] = base_control_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_file_system_dock_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"file_system_dock_available": false,
		"file_system_dock_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_file_system_dock_availability"):
		return result

	var dock_result: Variant = editor_tools._tool_get_editor_file_system_dock_availability({})
	if dock_result is Dictionary and not dock_result.has("error"):
		for key in dock_result.keys():
			result[key] = dock_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_inspector_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"inspector_available": false,
		"inspector_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_inspector_availability"):
		return result

	var inspector_result: Variant = editor_tools._tool_get_editor_inspector_availability({})
	if inspector_result is Dictionary and not inspector_result.has("error"):
		for key in inspector_result.keys():
			result[key] = inspector_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_viewport_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"viewport_2d_available": false,
		"viewport_2d_type": "",
		"viewport_3d_available": false,
		"viewport_3d_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_viewport_availability"):
		return result

	var viewport_result: Variant = editor_tools._tool_get_editor_viewport_availability({})
	if viewport_result is Dictionary and not viewport_result.has("error"):
		for key in viewport_result.keys():
			result[key] = viewport_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_selection_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"selection_available": false,
		"selection_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_selection_availability"):
		return result

	var selection_result: Variant = editor_tools._tool_get_editor_selection_availability({})
	if selection_result is Dictionary and not selection_result.has("error"):
		for key in selection_result.keys():
			result[key] = selection_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_command_palette_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"command_palette_available": false,
		"command_palette_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_command_palette_availability"):
		return result

	var command_palette_result: Variant = editor_tools._tool_get_editor_command_palette_availability({})
	if command_palette_result is Dictionary and not command_palette_result.has("error"):
		for key in command_palette_result.keys():
			result[key] = command_palette_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_toaster_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"toaster_available": false,
		"toaster_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_toaster_availability"):
		return result

	var toaster_result: Variant = editor_tools._tool_get_editor_toaster_availability({})
	if toaster_result is Dictionary and not toaster_result.has("error"):
		for key in toaster_result.keys():
			result[key] = toaster_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_resource_filesystem_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"resource_filesystem_available": false,
		"resource_filesystem_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_resource_filesystem_availability"):
		return result

	var resource_filesystem_result: Variant = editor_tools._tool_get_editor_resource_filesystem_availability({})
	if resource_filesystem_result is Dictionary and not resource_filesystem_result.has("error"):
		for key in resource_filesystem_result.keys():
			result[key] = resource_filesystem_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_script_editor_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"script_editor_available": false,
		"script_editor_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_script_editor_availability"):
		return result

	var script_editor_result: Variant = editor_tools._tool_get_editor_script_editor_availability({})
	if script_editor_result is Dictionary and not script_editor_result.has("error"):
		for key in script_editor_result.keys():
			result[key] = script_editor_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_settings_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"editor_settings_available": false,
		"editor_settings_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_settings_availability"):
		return result

	var editor_settings_result: Variant = editor_tools._tool_get_editor_settings_availability({})
	if editor_settings_result is Dictionary and not editor_settings_result.has("error"):
		for key in editor_settings_result.keys():
			result[key] = editor_settings_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_theme_availability_snapshot() -> Dictionary:
	var result: Dictionary = {
		"editor_theme_available": false,
		"editor_theme_type": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_theme_availability"):
		return result

	var editor_theme_result: Variant = editor_tools._tool_get_editor_theme_availability({})
	if editor_theme_result is Dictionary and not editor_theme_result.has("error"):
		for key in editor_theme_result.keys():
			result[key] = editor_theme_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_current_scene_dirty_state_snapshot() -> Dictionary:
	var result: Dictionary = {
		"scene_open": false,
		"scene_path": "",
		"scene_dirty": false,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_current_scene_dirty_state"):
		return result

	var dirty_state_result: Variant = editor_tools._tool_get_editor_current_scene_dirty_state({})
	if dirty_state_result is Dictionary and not dirty_state_result.has("error"):
		for key in dirty_state_result.keys():
			result[key] = dirty_state_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_open_scene_summary_snapshot() -> Dictionary:
	var result: Dictionary = {
		"scene_open": false,
		"scene_path": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_open_scene_summary"):
		return result

	var open_scene_result: Variant = editor_tools._tool_get_editor_open_scene_summary({})
	if open_scene_result is Dictionary and not open_scene_result.has("error"):
		for key in open_scene_result.keys():
			result[key] = open_scene_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_open_scenes_summary_snapshot() -> Dictionary:
	var result: Dictionary = {
		"open_scene_paths": [],
		"active_scene_path": "",
		"open_scene_count": 0,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_open_scenes_summary"):
		return result

	var open_scenes_result: Variant = editor_tools._tool_get_editor_open_scenes_summary({})
	if open_scenes_result is Dictionary and not open_scenes_result.has("error"):
		for key in open_scenes_result.keys():
			result[key] = open_scenes_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_editor_open_scene_roots_summary_snapshot() -> Dictionary:
	var result: Dictionary = {
		"open_scene_roots": [],
		"open_scene_root_count": 0,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var editor_tools: RefCounted = plugin.get_tool_instance("EditorToolsNative")
	if not editor_tools or not editor_tools.has_method("_tool_get_editor_open_scene_roots_summary"):
		return result

	var open_scene_roots_result: Variant = editor_tools._tool_get_editor_open_scene_roots_summary({})
	if open_scene_roots_result is Dictionary and not open_scene_roots_result.has("error"):
		for key in open_scene_roots_result.keys():
			result[key] = open_scene_roots_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_project_configuration_summary_snapshot() -> Dictionary:
	var result: Dictionary = {
		"max_items_applied": 10,
		"plugin_count": 0,
		"enabled_plugin_count": 0,
		"plugins": [],
		"plugins_truncated": false,
		"autoload_count": 0,
		"autoloads": [],
		"autoloads_truncated": false,
		"feature_profile_count": 0,
		"current_feature_profile": "",
		"feature_profiles": [],
		"feature_profiles_truncated": false,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var project_tools: RefCounted = plugin.get_tool_instance("ProjectToolsNative")
	if not project_tools or not project_tools.has_method("_tool_get_project_configuration_summary"):
		return result

	var summary_result: Variant = project_tools._tool_get_project_configuration_summary({
		"max_items": 10
	})
	if summary_result is Dictionary and not summary_result.has("error"):
		for key in summary_result.keys():
			result[key] = summary_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_project_info_snapshot() -> Dictionary:
	var result: Dictionary = {
		"name": "",
		"version": "",
		"description": "",
		"main_scene": "",
		"project_path": "",
		"godot_version": "",
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var project_tools: RefCounted = plugin.get_tool_instance("ProjectToolsNative")
	if not project_tools or not project_tools.has_method("_tool_get_project_info"):
		return result

	var info_result: Variant = project_tools._tool_get_project_info({})
	if info_result is Dictionary and not info_result.has("error"):
		result["name"] = str(info_result.get("project_name", ""))
		result["version"] = str(info_result.get("project_version", ""))
		result["description"] = str(info_result.get("project_description", ""))
		result["main_scene"] = str(info_result.get("main_scene", ""))
		result["project_path"] = str(info_result.get("project_path", ""))
		result["godot_version"] = str(info_result.get("godot_version", ""))
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_project_settings_snapshot() -> Dictionary:
	var result: Dictionary = {
		"settings": {},
		"count": 0,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var project_tools: RefCounted = plugin.get_tool_instance("ProjectToolsNative")
	if not project_tools or not project_tools.has_method("_tool_get_project_settings"):
		return result

	var combined_settings: Dictionary = {}
	for prefix in ["application/", "display/", "rendering/"]:
		var settings_result: Variant = project_tools._tool_get_project_settings({"filter": prefix})
		if settings_result is Dictionary and not settings_result.has("error"):
			var settings_chunk: Variant = settings_result.get("settings", {})
			if settings_chunk is Dictionary:
				for key in settings_chunk.keys():
					combined_settings[key] = settings_chunk[key]

	result["settings"] = combined_settings
	result["count"] = combined_settings.size()
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_project_global_classes_snapshot() -> Dictionary:
	var result: Dictionary = {
		"count": 0,
		"classes": [],
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var project_tools: Variant = plugin.get_tool_instance("ProjectToolsNative")
	if not project_tools or not project_tools.has_method("_tool_list_project_global_classes"):
		return result

	var tool_result: Dictionary = project_tools._tool_list_project_global_classes({})
	result["count"] = tool_result.get("count", 0)
	result["classes"] = tool_result.get("classes", [])
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_project_plugins_snapshot() -> Dictionary:
	var result: Dictionary = {
		"count": 0,
		"plugins": [],
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var project_tools: RefCounted = plugin.get_tool_instance("ProjectToolsNative")
	if not project_tools or not project_tools.has_method("_tool_list_project_plugins"):
		return result

	var plugins_result: Variant = project_tools._tool_list_project_plugins({})
	if plugins_result is Dictionary and not plugins_result.has("error"):
		for key in plugins_result.keys():
			result[key] = plugins_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_project_feature_profiles_snapshot() -> Dictionary:
	var result: Dictionary = {
		"count": 0,
		"current_profile": "",
		"profiles": [],
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var project_tools: RefCounted = plugin.get_tool_instance("ProjectToolsNative")
	if not project_tools or not project_tools.has_method("_tool_list_project_feature_profiles"):
		return result

	var profiles_result: Variant = project_tools._tool_list_project_feature_profiles({})
	if profiles_result is Dictionary and not profiles_result.has("error"):
		for key in profiles_result.keys():
			result[key] = profiles_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_project_autoloads_snapshot() -> Dictionary:
	var result: Dictionary = {
		"autoloads": [],
		"count": 0,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var project_tools: RefCounted = plugin.get_tool_instance("ProjectToolsNative")
	if not project_tools or not project_tools.has_method("_tool_list_project_autoloads"):
		return result

	var autoloads_result: Variant = project_tools._tool_list_project_autoloads({})
	if autoloads_result is Dictionary and not autoloads_result.has("error"):
		for key in autoloads_result.keys():
			result[key] = autoloads_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_project_tests_snapshot() -> Dictionary:
	var result: Dictionary = {
		"count": 0,
		"search_path": "res://test",
		"tests": [],
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var project_tools: Variant = plugin.get_tool_instance("ProjectToolsNative")
	if not project_tools or not project_tools.has_method("_tool_list_project_tests"):
		return result

	var tool_result: Dictionary = project_tools._tool_list_project_tests({"search_path": "res://test/"})
	result["count"] = tool_result.get("count", 0)
	result["search_path"] = tool_result.get("search_path", "res://test/")
	result["tests"] = tool_result.get("tests", [])
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

static func _build_project_test_runners_snapshot() -> Dictionary:
	var result: Dictionary = {
		"count": 0,
		"runners": [],
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var project_tools: RefCounted = plugin.get_tool_instance("ProjectToolsNative")
	if not project_tools or not project_tools.has_method("_tool_list_project_test_runners"):
		return result

	var runners_result: Variant = project_tools._tool_list_project_test_runners({})
	if runners_result is Dictionary and not runners_result.has("error"):
		for key in runners_result.keys():
			result[key] = runners_result[key]
	result["timestamp"] = Time.get_unix_time_from_system()
	return result

# ===========================================
# 璧勬簮璇诲彇鍔熻兘
# ===========================================

## 璇诲彇鍦烘櫙鍒楄〃璧勬簮
func _resource_scene_list(params: Dictionary) -> Dictionary:
	var scenes: Array = []
	var dir = DirAccess.open("res://")

	if not dir:
		return {"contents": [{"uri": "godot://scene/list", "mimeType": "application/json", "text": "{}"}]}

	_find_files_recursive(dir, ".tscn", scenes)

	return {
		"contents": [{
			"uri": "godot://scene/list",
			"mimeType": "application/json",
			"text": JSON.stringify({
				"scenes": scenes,
				"count": scenes.size(),
				"timestamp": Time.get_unix_time_from_system()
			}, "\t", true)
		}]
	}

## 璇诲彇褰撳墠鍦烘櫙璧勬簮
func _resource_scene_current(params: Dictionary) -> Dictionary:
	if not _editor_interface:
		return {"contents": [{"uri": "godot://scene/current", "mimeType": "application/json", "text": "{}"}]}

	var scene_root: Node = _editor_interface.get_edited_scene_root()
	if not scene_root:
		return {"contents": [{"uri": "godot://scene/current", "mimeType": "application/json", "text": "{}"}]}

	var scene_info: Dictionary = {
		"name": scene_root.name,
		"path": scene_root.scene_file_path,
		"type": scene_root.get_class(),
		"node_count": _count_nodes(scene_root),
		"children": _get_node_tree(scene_root, 2)
	}

	return {
		"contents": [{
			"uri": "godot://scene/current",
			"mimeType": "application/json",
			"text": JSON.stringify(scene_info, "\t", true)
		}]
	}

func _resource_scene_open(params: Dictionary) -> Dictionary:
	if not _editor_interface:
		return {"contents": [{"uri": "godot://scene/open", "mimeType": "application/json", "text": "{}"}]}

	var open_scene_paths: PackedStringArray = _editor_interface.get_open_scenes()
	var open_scene_roots: Array = _editor_interface.get_open_scene_roots()
	var active_root: Node = _editor_interface.get_edited_scene_root()
	var active_scene_path: String = active_root.scene_file_path if active_root else ""
	var open_scenes: Array = []

	for i in range(open_scene_paths.size()):
		var scene_path: String = str(open_scene_paths[i])
		var root_name: String = ""
		var root_type: String = ""
		if i < open_scene_roots.size():
			var root_node: Node = open_scene_roots[i]
			if root_node:
				root_name = str(root_node.name)
				root_type = str(root_node.get_class())
		open_scenes.append({
			"scene_path": scene_path,
			"root_name": root_name,
			"root_type": root_type,
			"is_active": scene_path == active_scene_path
		})

	return {
		"contents": [{
			"uri": "godot://scene/open",
			"mimeType": "application/json",
			"text": JSON.stringify({
				"open_scenes": open_scenes,
				"count": open_scenes.size(),
				"active_scene_path": active_scene_path,
				"timestamp": Time.get_unix_time_from_system()
			}, "\t", true)
		}]
	}

func _resource_tools_catalog(params: Dictionary) -> Dictionary:
	var tools: Array = []
	if _server_core and _server_core.has_method("get_registered_tools"):
		tools = _server_core.get_registered_tools()

	return {
		"contents": [{
			"uri": "godot://tools/catalog",
			"mimeType": "application/json",
			"text": JSON.stringify({
				"tools": tools,
				"count": tools.size(),
				"timestamp": Time.get_unix_time_from_system()
			}, "\t", true)
		}]
	}

## 璇诲彇鑴氭湰鍒楄〃璧勬簮
func _resource_script_list(params: Dictionary) -> Dictionary:
	var scripts: Array = []
	var dir = DirAccess.open("res://")

	if not dir:
		return {"contents": [{"uri": "godot://script/list", "mimeType": "application/json", "text": "{}"}]}

	_find_files_recursive(dir, ".gd", scripts)

	return {
		"contents": [{
			"uri": "godot://script/list",
			"mimeType": "application/json",
			"text": JSON.stringify({
				"scripts": scripts,
				"count": scripts.size(),
				"timestamp": Time.get_unix_time_from_system()
			}, "\t", true)
		}]
	}

## 璇诲彇褰撳墠鑴氭湰璧勬簮
func _resource_script_current(params: Dictionary) -> Dictionary:
	if not _editor_interface:
		return {"contents": [{"uri": "godot://script/current", "mimeType": "application/json", "text": "{}"}]}

	var script_editor = _editor_interface.get_script_editor()
	if not script_editor:
		return {"contents": [{"uri": "godot://script/current", "mimeType": "application/json", "text": "{}"}]}

	var current_script = script_editor.get_current_script()
	if not current_script:
		return {"contents": [{"uri": "godot://script/current", "mimeType": "application/json", "text": "{}"}]}

	var script_path: String = current_script.resource_path
	if not FileAccess.file_exists(script_path):
		return {"contents": [{"uri": "godot://script/current", "mimeType": "application/json", "text": "{}"}]}

	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"contents": [{"uri": "godot://script/current", "mimeType": "application/json", "text": "{}"}]}

	var script_content: String = file.get_as_text()
	file.close()

	var line_count: int = 0
	if not script_content.is_empty():
		line_count = script_content.split("\n").size()

	var script_info: Dictionary = {
		"path": script_path,
		"name": current_script.get_class(),
		"content": script_content,
		"line_count": line_count,
		"timestamp": Time.get_unix_time_from_system()
	}

	return {
		"contents": [{
			"uri": "godot://script/current",
			"mimeType": "application/json",
			"text": JSON.stringify(script_info, "\t", true)
		}]
	}

func _resource_editor_script_summary(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_script_summary_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/script_summary",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

## 璇诲彇椤圭洰淇℃伅璧勬簮
func _resource_editor_paths(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_paths_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/paths",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_shell_state(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_shell_state_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/shell_state",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_language(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_language_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/language",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_current_location(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_current_location_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/current_location",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_current_feature_profile(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_current_feature_profile_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/current_feature_profile",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_selected_paths(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_selected_paths_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/selected_paths",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_play_state(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_play_state_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/play_state",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_3d_snap_state(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_3d_snap_state_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/3d_snap_state",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_subsystem_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_subsystem_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/subsystem_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_previewer_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_previewer_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/previewer_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_undo_redo_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_undo_redo_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/undo_redo_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_base_control_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_base_control_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/base_control_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_file_system_dock_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_file_system_dock_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/file_system_dock_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_inspector_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_inspector_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/inspector_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_viewport_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_viewport_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/viewport_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_selection_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_selection_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/selection_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_command_palette_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_command_palette_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/command_palette_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_toaster_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_toaster_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/toaster_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_resource_filesystem_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_resource_filesystem_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/resource_filesystem_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_script_editor_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_script_editor_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/script_editor_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_settings_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_settings_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/settings_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_theme_availability(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_theme_availability_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/theme_availability",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_current_scene_dirty_state(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_current_scene_dirty_state_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/current_scene_dirty_state",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_open_scene_summary(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_open_scene_summary_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/open_scene_summary",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_open_scenes_summary(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_open_scenes_summary_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/open_scenes_summary",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_open_scene_roots_summary(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_open_scene_roots_summary_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/open_scene_roots_summary",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_project_info(params: Dictionary) -> Dictionary:
	var project_info: Dictionary = _build_project_info_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/info",
			"mimeType": "application/json",
			"text": JSON.stringify(project_info, "\t", true)
		}]
	}

## 璇诲彇椤圭洰璁剧疆璧勬簮
func _resource_project_settings(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_project_settings_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/settings",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_project_class_metadata(params: Dictionary) -> Dictionary:
	var classes: Array = _normalize_project_global_class_entries(ProjectSettings.get_global_class_list() if ProjectSettings.has_method("get_global_class_list") else [])

	return {
		"contents": [{
			"uri": "godot://project/class_metadata",
			"mimeType": "application/json",
			"text": JSON.stringify({
				"classes": classes,
				"count": classes.size(),
				"timestamp": Time.get_unix_time_from_system()
			}, "\t", true)
		}]
	}

func _resource_project_global_classes(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_project_global_classes_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/global_classes",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_project_configuration_summary(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_project_configuration_summary_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/configuration_summary",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_project_plugins(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_project_plugins_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/plugins",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_project_feature_profiles(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_project_feature_profiles_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/feature_profiles",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_project_autoloads(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_project_autoloads_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/autoloads",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_project_tests(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_project_tests_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/tests",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_project_test_runners(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_project_test_runners_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/test_runners",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_project_dependency_snapshot(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_project_dependency_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/dependency_snapshot",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_editor_logs(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_editor_logs_snapshot()

	return {
		"contents": [{
			"uri": "godot://editor/logs",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

func _resource_runtime_state(params: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_runtime_state_snapshot()

	return {
		"contents": [{
			"uri": "godot://runtime/state",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

## 璇诲彇缂栬緫鍣ㄧ姸鎬佽祫婧?
func _resource_editor_state(params: Dictionary) -> Dictionary:
	if not _editor_interface:
		return {"contents": [{"uri": "godot://editor/state", "mimeType": "application/json", "text": "{}"}]}

	var editor_state: Dictionary = {
		"current_scene": "",
		"selected_nodes": [],
		"timestamp": Time.get_unix_time_from_system()
	}

	var scene_root: Node = _editor_interface.get_edited_scene_root()
	if scene_root:
		editor_state["current_scene"] = scene_root.scene_file_path

	var selection: EditorSelection = _editor_interface.get_selection()
	if selection:
		var selected_nodes: Array = selection.get_selected_nodes()
		for node in selected_nodes:
			editor_state["selected_nodes"].append(node.get_path())

	return {
		"contents": [{
			"uri": "godot://editor/state",
			"mimeType": "application/json",
			"text": JSON.stringify(editor_state, "\t", true)
		}]
	}

# ===========================================
# 杈呭姪鍑芥暟
# ===========================================

## 閫掑綊鏌ユ壘鏂囦欢
static func _find_files_recursive(dir: DirAccess, extension: String, result: Array, base_path: String = "res://") -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		var full_path: String = base_path + file_name

		if dir.current_is_dir():
			var sub_dir: DirAccess = DirAccess.open(full_path + "/")
			if sub_dir:
				_find_files_recursive(sub_dir, extension, result, full_path + "/")
		elif file_name.ends_with(extension):
			result.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

static func _find_files_recursive_with_extensions(dir: DirAccess, extensions: Array[String], result: Array, base_path: String = "res://") -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		var full_path: String = base_path + file_name

		if dir.current_is_dir():
			var sub_dir: DirAccess = DirAccess.open(full_path + "/")
			if sub_dir:
				_find_files_recursive_with_extensions(sub_dir, extensions, result, full_path + "/")
		else:
			for extension in extensions:
				if file_name.ends_with(extension):
					result.append(full_path)
					break

		file_name = dir.get_next()

	dir.list_dir_end()

## 璁＄畻鑺傜偣鏁伴噺
static func _count_nodes(node: Node) -> int:
	var count: int = 1

	for child in node.get_children():
		count += _count_nodes(child)

	return count

## 鑾峰彇鑺傜偣鏍戠粨鏋?
static func _get_node_tree(node: Node, max_depth: int, current_depth: int = 0) -> Array:
	if current_depth >= max_depth:
		return []

	var result: Array = []

	for child in node.get_children():
		var child_info: Dictionary = {
			"name": child.name,
			"type": child.get_class(),
			"children": _get_node_tree(child, max_depth, current_depth + 1)
		}
		result.append(child_info)

	return result

## 鑾峰彇Godot鐗堟湰
static func _get_godot_version() -> Dictionary:
	return {
		"version": Engine.get_version_info()["string"],
		"major": Engine.get_version_info()["major"],
		"minor": Engine.get_version_info()["minor"],
		"patch": Engine.get_version_info()["patch"]
	}

static func _normalize_project_global_class_entries(entries: Array) -> Array:
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
	classes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return classes

static func _build_project_dependency_snapshot() -> Dictionary:
	var dependency_extensions: Array[String] = [
		".tscn", ".scn", ".tres", ".res", ".gd", ".cs", ".gdshader", ".material"
	]
	var resources: Array = []
	var dir: DirAccess = DirAccess.open("res://")
	if dir:
		_find_files_recursive_with_extensions(dir, dependency_extensions, resources)

	resources.sort()

	var dependency_resources: Array = []
	var missing_dependency_resources: int = 0
	var missing_dependency_entries: int = 0

	for resource_path_variant in resources:
		var resource_path: String = str(resource_path_variant)
		var dependency_entries: Array = _summarize_resource_dependencies(resource_path)
		if dependency_entries.is_empty():
			continue

		var dependency_paths: Array = []
		var missing_paths: Array = []
		for dependency_entry in dependency_entries:
			var resolved_path: String = str(dependency_entry.get("resolved_path", ""))
			var fallback_path: String = str(dependency_entry.get("fallback_path", ""))
			var effective_path: String = resolved_path if not resolved_path.is_empty() else fallback_path
			dependency_paths.append(effective_path)
			if bool(dependency_entry.get("missing", false)):
				missing_paths.append(effective_path)

		if not missing_paths.is_empty():
			missing_dependency_resources += 1
			missing_dependency_entries += missing_paths.size()

		dependency_resources.append({
			"resource_path": resource_path,
			"dependency_count": dependency_paths.size(),
			"missing_dependency_count": missing_paths.size(),
			"dependency_paths": dependency_paths,
			"missing_dependency_paths": missing_paths
		})

	return {
		"resources": dependency_resources,
		"count": dependency_resources.size(),
		"scanned_resources": resources.size(),
		"missing_dependency_resources": missing_dependency_resources,
		"missing_dependency_entries": missing_dependency_entries,
		"timestamp": Time.get_unix_time_from_system()
	}

static func _summarize_resource_dependencies(resource_path: String) -> Array:
	var dependencies: Array = []
	for raw_dependency in ResourceLoader.get_dependencies(resource_path):
		var raw_text: String = str(raw_dependency)
		var entry: Dictionary = {
			"resolved_path": "",
			"fallback_path": "",
			"missing": false
		}

		if raw_text.contains("::"):
			entry["fallback_path"] = raw_text.get_slice("::", 2)
			var resolved_path: String = ""
			var uid_text: String = raw_text.get_slice("::", 0)
			if uid_text.begins_with("uid://"):
				resolved_path = ResourceUID.uid_to_path(uid_text)
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

		entry["missing"] = not resolved_exists
		dependencies.append(entry)

	return dependencies

static func _build_editor_logs_snapshot() -> Dictionary:
	var result: Dictionary = {
		"logs": [],
		"count": 0,
		"total_available": 0,
		"truncated": false,
		"has_more": false,
		"source": "mcp",
		"order": "desc",
		"snapshot_limit": 100,
		"timestamp": Time.get_unix_time_from_system()
	}

	var plugin: Variant = Engine.get_meta("GodotMCPPlugin") if Engine.has_meta("GodotMCPPlugin") else null
	if not plugin or not plugin.has_method("get_tool_instance"):
		return result

	var debug_tools: RefCounted = plugin.get_tool_instance("DebugToolsNative")
	if not debug_tools or not debug_tools.has_method("_tool_get_editor_logs"):
		return result

	var log_result: Variant = debug_tools._tool_get_editor_logs({
		"source": "mcp",
		"count": 100,
		"offset": 0,
		"order": "desc"
	})
	if log_result is Dictionary:
		for key in log_result.keys():
			result[key] = log_result[key]
	return result

# ===========================================
# 璧勬簮娉ㄥ唽
# ===========================================

## 娉ㄥ唽鎵€鏈夎祫婧愬埌MCPServerCore
func register_resources(server_core: RefCounted) -> void:
	if not server_core:
		if _log_callback.is_valid():
			_log_callback.call("ERROR", "server_core 涓虹┖")
		return
	_server_core = server_core

	server_core.register_resource(
		"godot://scene/list",
		"Godot Scene List",
		"application/json",
		Callable(self, "_resource_scene_list"),
		"List all scene files in the project"
	)

	server_core.register_resource(
		"godot://scene/current",
		"Current Godot Scene",
		"application/json",
		Callable(self, "_resource_scene_current"),
		"Get the currently edited scene info"
	)

	server_core.register_resource(
		"godot://scene/open",
		"Open Godot Scenes",
		"application/json",
		Callable(self, "_resource_scene_open"),
		"Get the currently open scene tabs in the editor"
	)

	server_core.register_resource(
		"godot://tools/catalog",
		"Godot Tool Catalog",
		"application/json",
		Callable(self, "_resource_tools_catalog"),
		"Get the live registered MCP tool catalog"
	)

	server_core.register_resource(
		"godot://script/list",
		"Godot Script List",
		"application/json",
		Callable(self, "_resource_script_list"),
		"List all GDScript files in the project"
	)

	server_core.register_resource(
		"godot://script/current",
		"Current Godot Script",
		"application/json",
		Callable(self, "_resource_script_current"),
		"Get the currently edited script info"
	)

	server_core.register_resource(
		"godot://editor/script_summary",
		"Editor Script Summary",
		"application/json",
		Callable(self, "_resource_editor_script_summary"),
		"Get the current open-script/editor summary snapshot"
	)

	server_core.register_resource(
		"godot://editor/paths",
		"Editor Paths",
		"application/json",
		Callable(self, "_resource_editor_paths"),
		"Get the current editor paths snapshot"
	)

	server_core.register_resource(
		"godot://editor/shell_state",
		"Editor Shell State",
		"application/json",
		Callable(self, "_resource_editor_shell_state"),
		"Get the current editor shell-state snapshot"
	)

	server_core.register_resource(
		"godot://editor/language",
		"Editor Language",
		"application/json",
		Callable(self, "_resource_editor_language"),
		"Get the current editor language snapshot"
	)

	server_core.register_resource(
		"godot://editor/current_location",
		"Editor Current Location",
		"application/json",
		Callable(self, "_resource_editor_current_location"),
		"Get the current editor path and directory snapshot"
	)

	server_core.register_resource(
		"godot://editor/current_feature_profile",
		"Editor Current Feature Profile",
		"application/json",
		Callable(self, "_resource_editor_current_feature_profile"),
		"Get the current editor feature-profile snapshot"
	)

	server_core.register_resource(
		"godot://editor/selected_paths",
		"Editor Selected Paths",
		"application/json",
		Callable(self, "_resource_editor_selected_paths"),
		"Get the current editor selected-path snapshot"
	)

	server_core.register_resource(
		"godot://editor/play_state",
		"Editor Play State",
		"application/json",
		Callable(self, "_resource_editor_play_state"),
		"Get the current editor play-state snapshot"
	)

	server_core.register_resource(
		"godot://editor/3d_snap_state",
		"Editor 3D Snap State",
		"application/json",
		Callable(self, "_resource_editor_3d_snap_state"),
		"Get the current editor 3D snap-state snapshot"
	)

	server_core.register_resource(
		"godot://editor/subsystem_availability",
		"Editor Subsystem Availability",
		"application/json",
		Callable(self, "_resource_editor_subsystem_availability"),
		"Get the current editor subsystem availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/previewer_availability",
		"Editor Previewer Availability",
		"application/json",
		Callable(self, "_resource_editor_previewer_availability"),
		"Get the current editor resource-previewer availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/undo_redo_availability",
		"Editor Undo Redo Availability",
		"application/json",
		Callable(self, "_resource_editor_undo_redo_availability"),
		"Get the current editor undo-redo availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/base_control_availability",
		"Editor Base Control Availability",
		"application/json",
		Callable(self, "_resource_editor_base_control_availability"),
		"Get the current editor base-control availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/file_system_dock_availability",
		"Editor File System Dock Availability",
		"application/json",
		Callable(self, "_resource_editor_file_system_dock_availability"),
		"Get the current editor file-system-dock availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/inspector_availability",
		"Editor Inspector Availability",
		"application/json",
		Callable(self, "_resource_editor_inspector_availability"),
		"Get the current editor inspector availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/viewport_availability",
		"Editor Viewport Availability",
		"application/json",
		Callable(self, "_resource_editor_viewport_availability"),
		"Get the current editor viewport availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/selection_availability",
		"Editor Selection Availability",
		"application/json",
		Callable(self, "_resource_editor_selection_availability"),
		"Get the current editor selection-object availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/command_palette_availability",
		"Editor Command Palette Availability",
		"application/json",
		Callable(self, "_resource_editor_command_palette_availability"),
		"Get the current editor command-palette availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/toaster_availability",
		"Editor Toaster Availability",
		"application/json",
		Callable(self, "_resource_editor_toaster_availability"),
		"Get the current editor toaster availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/resource_filesystem_availability",
		"Editor Resource Filesystem Availability",
		"application/json",
		Callable(self, "_resource_editor_resource_filesystem_availability"),
		"Get the current editor resource-filesystem availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/script_editor_availability",
		"Editor Script Editor Availability",
		"application/json",
		Callable(self, "_resource_editor_script_editor_availability"),
		"Get the current editor script-editor availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/settings_availability",
		"Editor Settings Availability",
		"application/json",
		Callable(self, "_resource_editor_settings_availability"),
		"Get the current editor settings availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/theme_availability",
		"Editor Theme Availability",
		"application/json",
		Callable(self, "_resource_editor_theme_availability"),
		"Get the current editor theme availability snapshot"
	)

	server_core.register_resource(
		"godot://editor/current_scene_dirty_state",
		"Editor Current Scene Dirty State",
		"application/json",
		Callable(self, "_resource_editor_current_scene_dirty_state"),
		"Get the current active scene dirty-state snapshot"
	)

	server_core.register_resource(
		"godot://editor/open_scene_summary",
		"Editor Open Scene Summary",
		"application/json",
		Callable(self, "_resource_editor_open_scene_summary"),
		"Get the current open-scene summary snapshot"
	)

	server_core.register_resource(
		"godot://editor/open_scenes_summary",
		"Editor Open Scenes Summary",
		"application/json",
		Callable(self, "_resource_editor_open_scenes_summary"),
		"Get the current open-scenes summary snapshot"
	)

	server_core.register_resource(
		"godot://editor/open_scene_roots_summary",
		"Editor Open Scene Roots Summary",
		"application/json",
		Callable(self, "_resource_editor_open_scene_roots_summary"),
		"Get the current open-scene-roots summary snapshot"
	)

	server_core.register_resource(
		"godot://project/info",
		"Godot Project Info",
		"application/json",
		Callable(self, "_resource_project_info"),
		"Get project information"
	)

	server_core.register_resource(
		"godot://project/settings",
		"Godot Project Settings",
		"application/json",
		Callable(self, "_resource_project_settings"),
		"Get project settings"
	)

	server_core.register_resource(
		"godot://project/class_metadata",
		"Project Class Metadata",
		"application/json",
		Callable(self, "_resource_project_class_metadata"),
		"Get normalized project global class metadata"
	)

	server_core.register_resource(
		"godot://project/global_classes",
		"Project Global Classes",
		"application/json",
		Callable(self, "_resource_project_global_classes"),
		"Get the installed project global class inventory"
	)

	server_core.register_resource(
		"godot://project/configuration_summary",
		"Project Configuration Summary",
		"application/json",
		Callable(self, "_resource_project_configuration_summary"),
		"Get a bounded snapshot of installed plugins, autoloads, and feature profiles"
	)

	server_core.register_resource(
		"godot://project/plugins",
		"Project Plugins",
		"application/json",
		Callable(self, "_resource_project_plugins"),
		"Get the installed project plugin inventory and enabled states"
	)

	server_core.register_resource(
		"godot://project/feature_profiles",
		"Project Feature Profiles",
		"application/json",
		Callable(self, "_resource_project_feature_profiles"),
		"Get the installed project feature-profile inventory and current active profile"
	)

	server_core.register_resource(
		"godot://project/autoloads",
		"Project Autoloads",
		"application/json",
		Callable(self, "_resource_project_autoloads"),
		"Get the installed project autoload inventory"
	)

	server_core.register_resource(
		"godot://project/tests",
		"Project Tests",
		"application/json",
		Callable(self, "_resource_project_tests"),
		"Get the discovered project test inventory"
	)

	server_core.register_resource(
		"godot://project/test_runners",
		"Project Test Runners",
		"application/json",
		Callable(self, "_resource_project_test_runners"),
		"Get current runner availability for supported project test frameworks"
	)

	server_core.register_resource(
		"godot://project/dependency_snapshot",
		"Project Dependency Snapshot",
		"application/json",
		Callable(self, "_resource_project_dependency_snapshot"),
		"Get a stable snapshot of parsed project resource dependencies"
	)

	server_core.register_resource(
		"godot://editor/logs",
		"Editor Logs",
		"application/json",
		Callable(self, "_resource_editor_logs"),
		"Get a bounded snapshot of recent MCP/editor log entries"
	)

	server_core.register_resource(
		"godot://runtime/state",
		"Runtime State",
		"application/json",
		Callable(self, "_resource_runtime_state"),
		"Get a bounded runtime-state snapshot or explicit no-session truth"
	)

	server_core.register_resource(
		"godot://editor/state",
		"Godot Editor State",
		"application/json",
		Callable(self, "_resource_editor_state"),
		"Get current editor state"
	)

	if _log_callback.is_valid():
		_log_callback.call("INFO", "宸叉敞鍐?26 涓祫婧?)
