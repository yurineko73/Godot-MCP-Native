# mcp_server_native.gd - 闂傚倸鍊搁崐椋庣矆娓氣偓楠炲鏁撻悩顐熷亾閿曞倸鐐婃い鎺嗗亾缂佹劖顨婇弻鐔煎箲閹伴潧娈梺鍝勵儎缁舵岸寮婚悢铏圭＜婵妫欓弳鍖梻鍌氬€搁崐椋庣矆娓氣偓楠炴牠顢曢敂钘変罕闂佺硶鍓濋悷褔鎯岄幘缁樺€垫繛鎴烆伆閹达箑鐭楅煫鍥ㄧ⊕閻撶喖鏌￠崘銊モ偓鍝ユ暜閸洘鈷掗柛灞诲€曢悘锕傛煛鐏炵偓绀冪紒缁樼箚缁犳盯寮撮悩铏啅缂傚倸鍊峰ù鍥╀焊椤忓牜鏁嬬憸鏂匡耿娓氣偓濮婅櫣绱掑鍡欏姼濠电偛鎳忓ú鐔奉嚕閹间礁绀嬫い鏍ㄧ☉閳ь剛鏁诲濠氬醇閻旀亽鈧帡鏌ｈ箛娑楁喚闁?# 闂傚倸鍊搁崐椋庣矆娓氣偓楠炴牠顢曢妶鍥╃厠闂佺粯鍨堕弸鑽ょ礊閺嵮岀唵閻犺櫣灏ㄩ崝鐔兼煛閸℃劕鈧洟鍩ユ径鎰睄闁稿本绋戦崝妾噊t-dev-guide婵犵數濮烽弫鎼佸磻閻愬樊鐒芥繛鍡樻尭鐟欙箓鎮楅敐搴℃灍闁哄拋浜铏规嫚閺屻儺鈧鏌ｈ箛鏂垮摵闁诡噯绻濋弫鎾绘偐閸欏鈧剟鎮楅獮鍨姎婵炶绲介埢浠嬵敂閸喓鍘靛銈嗙墪濡鈧凹鍠氱划鏃囥亹閹烘挴鎷绘繛杈剧到閹诧繝宕悙瀛樺弿濠电姴瀚敮娑㈡煙娓氬灝濮傛鐐达耿椤㈡瑩鎸婃径澶嬪亝濠碉紕鍋戦崐鏍暜閹烘柡鍋撳鐓庡⒋鐎殿喖鎲＄粭鐔煎焵椤掑嫬绠栨俊銈呮噺椤ュ牊绻涢幋鐐垫噧闁哄棗鐗撳鐑樺濞嗘垹袣婵炲瓨绮犻崜娑樜ｉ幇鏉跨婵°倕锕ラ弲婵嬫⒑闂堟侗妯堥柛鐘崇墪閳绘捇顢橀姀鈾€鎷洪柣鐘叉搐瀵爼骞戦敐澶嬬厱闊洦妫戦懓鍧楁煟濞戝崬娅嶆鐐搭焽閹风娀鎳犻鍌涙緫濠碉紕鍋戦崐鏍涙担鍓叉禆闁靛ě鍐ㄧ亰闂佹眹鍨归幉锟犲煕閹达附鐓曟繛鎴烇公閸旂喖鏌ｉ鐑囪含闁哄矉缍侀崺鍕礃瑜嶉弸鍧竝ort闂傚倸鍊搁崐椋庣矆娓氣偓楠炲鏁撻悩鍐蹭画闂佹寧娲栭崐褰掑疾濠靛鐓忛煫鍥ь儏閳ь剚娲熷?

@tool
extends EditorPlugin

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

# ============================================================================
# 闂傚倸鍊搁崐鎼佸磹閻戣姤鍊块柨鏇楀亾妞ゎ厼鐏濊灒闁兼祴鏅濋悡瀣⒑閸撴彃浜濇繛鍙夛耿瀹曟垿顢旈崼鐔哄幈闂佹枼鏅涢崯浼村煡婢舵劖鐓熸い鎾跺櫏濞堟洟鏌熸笟鍨妞ゎ亜鍟伴幏鐘荤叓椤撶儐妫滈梻鍌氬€风欢姘焽閼姐倕绶ら柟顖嗗本瀵屾繛瀵稿Т椤戝懘寮告担琛″亾楠炲灝鍔氭い锔诲灦閺屽宕堕浣哄幗闂佸搫鍊圭€笛囧箚閸喆浜滈柕澶涚畱閻忓瓨鎱ㄦ繝鍐┿仢闁诡喚鍏橀幃褔宕奸敐鍥舵敤闂傚倷娴囧銊╂嚄閸洖绠扮紒铏瑰妵t-dev-guide婵犵數濮烽弫鎼佸磻閻樿绠垫い蹇撴缁€濠囨煃瑜滈崜姘辨崲濞戞瑥绶為悗锝庡亞椤︿即鎮楀▓鍨珮闁稿锕ㄥΛ銏狀渻閵堝倹娅呮い搴″煢ort闂?# ============================================================================

@export var auto_start: bool = false:
	set(value):
		auto_start = value
		notify_property_list_changed()

@export var vibe_coding_mode: bool = true:
	set(value):
		vibe_coding_mode = value
		notify_property_list_changed()

@export var transport_mode: String = "http":
	set(value):
		if value == "stdio" or value == "http":
			transport_mode = value
			if _native_server:
				var type: int = MCPServerCore.TransportType.TRANSPORT_STDIO if value == "stdio" \
					else MCPServerCore.TransportType.TRANSPORT_HTTP
				_native_server.set_transport_type(type)
			notify_property_list_changed()
		else:
			_log_error("Invalid transport mode: " + value + ". Valid values are 'stdio' or 'http'")

@export var http_port: int = 9080:
	set(value):
		if value < 1024 or value > 65535:
			_log_error("Invalid port: " + str(value) + ". Please use a port between 1024 and 65535.")
			return
		http_port = value
		if _native_server and _native_server.has_method("set_http_port"):
			_native_server.set_http_port(value)
		notify_property_list_changed()

@export var auth_enabled: bool = false:
	set(value):
		auth_enabled = value
		notify_property_list_changed()

@export var auth_token: String = "":
	set(value):
		if value.length() < 16 and not value.is_empty():
			_log_warn("Auth token is too short. Please use at least 16 characters for security.")
		auth_token = value
		notify_property_list_changed()

@export_range(0, 3, 1) var log_level: int = 2:  # 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG (婵犵數濮甸鏍窗濡ゅ啯鏆滄俊銈呭暟閻瑩鏌熼悜妯镐粶闁逞屽墾缁犳挸鐣锋總绋课ㄦい鏃囧Г濞?=INFO闂傚倸鍊搁崐鐑芥倿閿旈敮鍋撶粭娑樻噽閻瑩鏌熺€电浠ч梻鍕閺岋繝宕橀妸銉㈠亾婵犳碍鍎楁慨妯垮煐閻撶娀鏌涘┑鍕姕闁哄棌鏅滈妵鍕煛閸屾粌寮ㄥΔ鐘靛仦閻楁洝褰佸銈嗗坊閸嬫捇鏌ｈ箛锝呮珝闁哄本娲熷畷濂告偄缁嬪灝鏀梻?
	set(value):
		log_level = value
		if _native_server:
			_native_server.set_log_level(value)
		notify_property_list_changed()

@export var security_level: int = 1:  # 0=PERMISSIVE, 1=STRICT
	set(value):
		security_level = value
		if _native_server:
			_native_server.set_security_level(value)
		notify_property_list_changed()

@export var rate_limit: int = 100:
	set(value):
		rate_limit = value
		if _native_server:
			_native_server.set_rate_limit(value)
		notify_property_list_changed()

@export var sse_enabled: bool = true:
	set(value):
		sse_enabled = value
		notify_property_list_changed()

@export var allow_remote: bool = false:
	set(value):
		allow_remote = value
		notify_property_list_changed()

@export var cors_origin: String = "*":
	set(value):
		cors_origin = value
		notify_property_list_changed()

# ============================================================================
# 闂傚倸鍊搁崐椋庣矆娓氣偓楠炲鏁撻悩鑼槷闂佸搫娲㈤崹鍦不閻樿櫕鍙忔俊鐐额嚙娴滈箖鎮楃憴鍕婵炶尙鍠栭悰顔碱潨閳ь剟銆佸▎鎾村殐闁冲搫鍟獮鈧繝鐢靛У椤旀牠宕板Δ鍛︽繛鎴欏灩绾惧鏌熼崜褏甯涢柣鎾存礋閺屻劌鈹戦崱姗嗘！闂侀潧娲︾换鍫ュ蓟閳╁啯濯撮柛婵勫剾瑜忛埀顒冾潐濞叉粓宕㈣閳ワ箓濡搁埡浣侯槰闂佹寧绻傚Λ娑㈠焵椤掆偓閵堢顫忕紒妯诲閻熸瑥瀚ㄦ禒褍鈹戦悙闈涘付婵炲皷鈧磭鏆︽繝闈涙閺嗗棝鏌涢弴銊ュ濞寸姷鍘ч—鍐Χ閸℃鐟ㄩ柣搴㈠嚬閸撶喎顕ｉ崨濠勭懝闁逞屽墴楠炲啫螖閸涱厼鐎銈嗗姂閸婃牠骞夊▎蹇ｆ富闁靛牆楠告禍鍓х磼閻樿櫕宕岀€殿喛顕ч埥澶愬閻樻牑鏅犻弻鏇熷緞濡儤鐏堥梺鍛婃崌娴滃爼骞冨畡閭︾叆闁割偒鍋呭▓銉╂⒑閻撳骸鏆卞褍閰ｅ畷?- 闂傚倸鍊搁崐椋庣矆娓氣偓楠炴牠顢曢妶鍥╃厠闂佺粯鍨堕弸鑽ょ礊閺嵮岀唵閻犺櫣灏ㄩ崝鐔兼煛閸℃劕鈧洟鍩ユ径鎰睄闁稿本绋戦崝妾噊t-dev-guide闂?# ============================================================================

var _native_server: RefCounted = null
var _main_panel: Control = null
var _editor_interface: EditorInterface = null
var _mcp_server_mode: bool = false
var _tool_instances: Dictionary = {}
var _debugger_bridge: MCPDebuggerBridge = null

const TOOL_SCRIPT_PATHS: Dictionary = {
	"NodeToolsNative": "res://addons/godot_mcp/tools/node_tools_native.gd",
	"ScriptToolsNative": "res://addons/godot_mcp/tools/script_tools_native.gd",
	"SceneToolsNative": "res://addons/godot_mcp/tools/scene_tools_native.gd",
	"EditorToolsNative": "res://addons/godot_mcp/tools/editor_tools_native.gd",
	"DebugToolsNative": "res://addons/godot_mcp/tools/debug_tools_native.gd",
	"ProjectToolsNative": "res://addons/godot_mcp/tools/project_tools_native.gd"
}

# ============================================================================
# 闂傚倸鍊搁崐鐑芥倿閿曞倹鍎戠憸鐗堝笒閸ㄥ倸鈹戦悩瀹犲缂佹劖顨婇獮鏍庨鈧俊鑲╃磼閻橀潧鈻堥柡灞诲姂閹垽宕崟鎴欏灮閳ь剛鎳撻幉锛勬崲閸儱钃熼柡鍥╁枔缁♀偓闂婎偄娲︾粙鎺楊敁瀹ュ鈷戠紒顖涙礃濞呭懘鏌涙繝鍌涘仴鐎殿喖顭烽弫鎾绘偐閼碱剨绱叉繝鐢靛Т閻忔岸宕濋弽顐ょ闁割偁鍨荤壕?
# ============================================================================

func _enter_tree() -> void:
	_log_info("Godot Native MCP Plugin entering tree...")

	Engine.set_meta("GodotMCPPlugin", self)

	_editor_interface = get_editor_interface()
	if not _editor_interface:
		_log_error("Failed to get EditorInterface")
		return

	_native_server = _instantiate_script("res://addons/godot_mcp/native_mcp/mcp_server_core.gd")

	if not _native_server:
		_log_error("Failed to create MCP Server Core instance")
		return

	_debugger_bridge = load("res://addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd").new()
	if not _debugger_bridge:
		_log_error("Failed to create debugger bridge instance")
		return
	add_debugger_plugin(_debugger_bridge)

	# 闂傚倸鍊峰ù鍥х暦閸偅鍙忕€规洖娲ㄩ惌鍡椕归敐鍫綈婵炲懐濮撮湁闁绘ê妯婇崕鎰版煕鐎ｅ吀閭柡灞剧洴閸╁嫰宕楅悪鈧禍顏堛€佸鑸电劶鐎广儱妫涢崢钘夆攽閳藉棗鐏￠悗绗涘浂鏁傞柣妯兼暩绾句粙鏌涢锝囩闁绘挸銈搁弻鈥崇暆鐎ｎ剛鐦堥悗瑙勬礃鐢帡鈥﹂妸鈺佺妞ゆ劧绲块弳姘辩磽?
	var type: int = MCPServerCore.TransportType.TRANSPORT_STDIO if transport_mode == "stdio" \
			else MCPServerCore.TransportType.TRANSPORT_HTTP
	_native_server.set_transport_type(type)
	_log_info("Transport type set to: " + transport_mode)

	# 闂傚倸鍊峰ù鍥х暦閸偅鍙忕€规洖娲ㄩ惌鍡椕归敐鍫綈婵炲懐濮撮湁闁绘ê妯婇崕鎰版煕?HTTP 缂傚倸鍊搁崐鎼佸磹閻戣姤鍊块柨鏇楀亾閾荤偤鐓崶銊р槈闁搞劌鍊块弻鐔风暋閹峰矈娼舵繛?
	_native_server.set_http_port(http_port)
	_log_info("HTTP port set to: " + str(http_port))

	# Configure auth for HTTP transport when enabled.
	if auth_enabled and transport_mode == "http":
		var auth_manager: McpAuthManager = McpAuthManager.new()
		auth_manager.set_token(auth_token)
		auth_manager.set_enabled(true)
		_native_server.set_auth_manager(auth_manager)
		_log_info("Auth manager created and enabled")
	# Configure HTTP-specific options.
	if transport_mode == "http":
		if _native_server.has_method("set_sse_enabled"):
			_native_server.set_sse_enabled(sse_enabled)
			_log_info("SSE enabled: " + str(sse_enabled))
		if _native_server.has_method("set_remote_config"):
			_native_server.set_remote_config(allow_remote, cors_origin)
			_log_info("Remote config: allow_remote=" + str(allow_remote) + ", cors=" + cors_origin)

	# Configure general server options.
	_native_server.set_log_level(log_level)
	_native_server.set_security_level(security_level)
	_native_server.set_rate_limit(rate_limit)
	# Connect server lifecycle and tool execution signals.
	_native_server.server_started.connect(_on_server_started)
	_native_server.server_stopped.connect(_on_server_stopped)
	_native_server.message_received.connect(_on_message_received)
	_native_server.response_sent.connect(_on_response_sent)
	_native_server.tool_execution_started.connect(_on_tool_started)
	_native_server.tool_execution_completed.connect(_on_tool_completed)
	_native_server.tool_execution_failed.connect(_on_tool_failed)
	_native_server.log_message.connect(_on_log_message)
	# Register all tools and resources after server setup.
	_register_all_tools()
	_register_all_resources()

	# 闂傚倸鍊搁崐椋庢濮橆剦鐒藉┑鐘崇閸ゅ牏鎲搁悧鍫濈瑨闁汇倝绠栭弻锝夘敇閻樻彃骞嬪┑顔硷攻濡炶棄鐣烽妸锔剧瘈闁稿本绮庨幊鏍磽閸屾瑧顦︽い鎴濇瀹曞綊宕烽鐕佹綗闂佽宕橀褏绮绘繝姘仯闁搞儺浜滈惃鐑樸亜閿旇寮柟顔筋殜閻涱噣宕归鐓庮潛闂備胶鎳撻崯鍧楁煀閿濆鏅查柣鎰劋閺呮彃顭跨捄鐚村姛濡ょ姴娲铏圭磼濡搫顫戦梺绯曟櫆閻楃姾妫㈡繝銏ｅ煐閸旀牠鎮￠弴銏＄厵閻庢稒蓱閻撱儱顭胯鐏忔瑧妲愰幒鏂炬勃闁芥ê顦抽崺鐐烘⒑鐎圭媭娼愰柛銊ョ仢閻ｇ兘宕￠悙鈺傜€婚梺褰掑亰閸樺ジ寮稿☉銏♀拻闁稿本鐟ч崝宥夋煟椤忓嫮绉虹€规洘绻傞悾婵嬪焵椤掑嫬鐒垫い鎺嶇閸ゎ剟鏌涢幘瀛樼殤闁逞屽墴濞佳囧Χ閹间胶宓侀柛銉墮缁狙囨偣娓氼垳鍘涙俊宸灠閳规垿鏁嶉崟顐＄捕濡炪倖鍨甸幊蹇涖€冮妷鈺佷紶闁靛／鍕珮闂傚倸鍊搁崐宄懊归崶顒夋晪闁哄稁鍘肩粈鍌涚箾閹寸偟顣叉い鎰矙閺屾洟宕煎┑鍥ь槱濡炪値鍋呭ú妯兼崲濞戙垹骞㈡俊顖濇娴犳悂姊虹粙璺ㄧ缂侇喖绉规俊鐢稿礋椤栨氨鐫勯梺鎼炲劀閸愨晛鍔掔紓鍌氬€烽懗鑸垫叏妞嬪海鐭堢紒鈧Δ鍛拻闁稿本鐟чˇ锕傛煙绾板崬浜為柍褜鍓氶崙褰掑礈濮樿泛鐤鹃柤鍝ユ暩椤╃兘鎮楅敐搴樺亾椤撱劑妾柟渚垮妼椤粓宕卞Δ鈧埛鎺戔攽閻愮儤锛熼柛妤佸▕瀵濡搁妷銏℃杸闂佺硶鍓濋…鍥囬柆宥嗏拺闂侇偆鍋涢懟顖涙櫠椤栫偞鐓ラ柡鍥悘鍙夘殽閻愬弶顥㈢€规洘锕㈤、娆撴嚃閳哄﹥效濠碉紕鍋戦崐鏍礉瑜忓濠冪鐎ｎ亞顦繝鐢靛У绾板秹鍩涢幋鐐电闁肩⒈鍓涚敮娑樷攽閻愬弶鍠橀柡灞剧洴瀵剟宕归鍛Ψ闂備線鈧稓鈹掗柛鏃€鍨块悰顕€寮介妸锕€顎撻梺鍛婄缚閸庢娊寮抽悩娴嬫斀闁绘劕鐡ㄧ亸浼存煠瑜版帞鐣洪柡浣稿暣閺佸倿宕滆閻?
	if _native_server.has_method("load_tool_states"):
		_native_server.load_tool_states()
		_log_info("Loaded saved tool states before UI creation")

	# 闂傚倸鍊搁崐椋庣矆娓氣偓楠炲鏁嶉崟顒佹濠德板€曢崯浼存儗濞嗘挻鐓欓悗鐢殿焾鍟哥紒鎯у綖缁瑩寮婚悢璁胯櫣绱掑Ο缁橆唶闂傚倸鍊搁崐鎼佸磹閹间礁纾归柟闂寸劍閸嬪鏌涢弴銊ョ仩闁搞劌鍊块弻娑樷攽閸℃浼岄梺?
	_create_main_screen_panel()

	_mcp_server_mode = "--mcp-server" in OS.get_cmdline_user_args()

	if _mcp_server_mode:
		_log_info("MCP server mode detected via --mcp-server argument")
		_start_native_server()
	elif auto_start:
		_log_info("Auto-start enabled, starting MCP server")
		_start_native_server()
	else:
		_log_info("MCP server not auto-started. Use Start button or --mcp-server flag.")

	_log_info("Godot Native MCP Plugin initialized")

func _exit_tree() -> void:
	_log_info("Godot Native MCP Plugin exiting tree...")

	if _native_server and _native_server.is_running():
		_native_server.stop()

	if _main_panel:
		EditorInterface.get_editor_main_screen().remove_child(_main_panel)
		_main_panel.queue_free()
		_main_panel = null

	if _debugger_bridge:
		remove_debugger_plugin(_debugger_bridge)
		_debugger_bridge = null

	_native_server = null

	_log_info("Godot Native MCP Plugin shutdown complete")

# ============================================================================
# 闂傚倸鍊搁崐椋庣矆娴ｉ潻鑰块弶鍫氭櫅閸ㄦ繃銇勯弽銊х煁闁哄棙绮岄埞鎴︽偐閹绘巻鍋撻悽绋垮嚑閹兼番鍔嶉悡蹇涚叓閸パ屽剰闁逞屽墯閻楃娀骞冮敓鐘茬劦妞ゆ帒瀚崐鍨殽閻愯尙浠㈤柛鏃€纰嶇换娑氫沪閸屾艾顫囬悗娈垮枟閹倸鐣烽幒妤佸€烽悗鐢殿焾瀵櫕绻濋悽闈涗沪闁搞劌鐖奸垾锕傚炊閵婏附鐝峰┑鐐村灟閸ㄦ椽鎮￠悢闀愮箚闁靛牆瀚崝宥夋倶韫囥儵妾い銊ｅ劦閹瑩寮堕幋鐘辩礉闂備浇顕栭崰鏇犲垝濞嗘挸绠栭柣鎰靛墰閳瑰秵銇勯敂鑺ヮ€?dev-guide婵犵數濮烽弫鎼佸磻閻愬樊鐒芥繛鍡樻尭鐟欙箓鎮楅敐搴℃灍闁哄拋浜铏规嫚閺屻儺鈧鏌ｈ箛鏂垮摵闁诡噯绻濋弫鎾绘偐閸欏鈧?# ============================================================================

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if _main_panel:
		_main_panel.visible = visible

func _get_plugin_name() -> String:
	return "MCP"

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/godot_mcp/icon.svg")

func get_native_server() -> RefCounted:
	return _native_server

func get_tool_instance(module_name: String) -> RefCounted:
	return _tool_instances.get(module_name, null)

func get_debugger_bridge() -> MCPDebuggerBridge:
	return _debugger_bridge

func _has_settings() -> bool:
	return true

func _get_property_list() -> Array:
	var properties: Array = []

	properties.append({
		"name": "MCP Transport Settings",
		"type": TYPE_NIL,
		"hint_string": "MCP Transport Settings",
		"usage": PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		"name": "transport_mode",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "stdio,http",
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "http_port",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1024,65535,1",
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "auth_enabled",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "auth_token",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_PASSWORD,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "sse_enabled",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "allow_remote",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "cors_origin",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "MCP Settings",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		"name": "auto_start",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "vibe_coding_mode",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "log_level",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "ERROR,WARN,INFO,DEBUG",
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "security_level",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "PERMISSIVE,STRICT",
		"usage": PROPERTY_USAGE_DEFAULT
	})

	properties.append({
		"name": "rate_limit",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "10,1000,10",
		"usage": PROPERTY_USAGE_DEFAULT
	})

	return properties

# ============================================================================
# 闂傚倸鍊搁崐鐑芥嚄閸洍鈧箓宕煎婵堟嚀椤繄鎹勯搹璇℃Ф婵犵數鍋涘Λ娆撳箰閹间焦鍎楁俊銈勯檷娴滄粓鏌嶉妷銊︾彧鐞氭
# ============================================================================

func start_server() -> bool:
	return _start_native_server()

func stop_server() -> void:
	_stop_native_server()

func is_server_running() -> bool:
	if _native_server:
		return _native_server.is_running()
	return false

func get_server_status() -> Dictionary:
	if not _native_server:
		return {"status": "not_initialized"}

	return {
		"status": "running" if _native_server.is_running() else "stopped",
		"log_level": log_level,
		"security_level": security_level,
		"rate_limit": rate_limit,
		"tools_count": _get_tools_count(),
		"resources_count": _get_resources_count()
	}

# ============================================================================
# 缂傚倸鍊搁崐鎼佸磹妞嬪海鐭嗗〒姘ｅ亾閽樻繃銇勯弴妤€浜鹃梺璇″枤閸嬨倝寮崘顔肩劦妞ゆ帒瀚弲婵嬫煏韫囥儳纾块柣鐔风秺閺屽秷顧侀柛鎾寸懇椤㈡岸鏁愭径妯绘櫌闂佺鏈粙鎴﹀几閸岀偞鈷戦柛娑橈攻婢跺嫰鏌涘Ο铏圭Ш闁糕斁鍋?- 闂傚倸鍊搁崐椋庣矆娓氣偓楠炴牠顢曢敂钘変罕闂佺硶鍓濋悷褔鎯岄幘缁樺€垫繛鎴烆伆閹达箑鐭楅煫鍥ㄧ⊕閻撶喖鏌￠崘銊モ偓鍝ユ暜閸洘鈷掗柛灞诲€曢悘锕傛煛鐏炵偓绀冪紒缁樼椤︽煡鏌ゅú璇茬仸妤犵偛鍟粭鐔煎焵椤掆偓椤?# ============================================================================

func _start_native_server() -> bool:
	if not _native_server:
		_log_error("MCP Server instance not available")
		return false

	if _native_server.is_running():
		_log_warn("MCP Server already running")
		return false

	_log_info("Starting native MCP server...")
	var success: bool = _native_server.start()

	if success:
		_log_info("Native MCP Server started - transport: " + transport_mode)
	else:
		_log_error("Failed to start MCP Server")

	return success

func _stop_native_server() -> void:
	if not _native_server:
		return

	if not _native_server.is_running():
		_log_warn("MCP Server not running")
		return

	_log_info("Stopping native MCP server...")
	_native_server.stop()
	_log_info("Native MCP Server stopped")

func _get_tools_count() -> int:
	if not _native_server:
		return 0
	return _native_server.get_tools_count() if _native_server.has_method("get_tools_count") else 0

func _get_resources_count() -> int:
	if not _native_server:
		return 0
	return _native_server.get_resources_count() if _native_server.has_method("get_resources_count") else 0

# ============================================================================
# 缂傚倸鍊搁崐鎼佸磹妞嬪海鐭嗗〒姘ｅ亾閽樻繃銇勯弴妤€浜鹃梺璇″枤閸嬨倝寮崘顔肩劦妞ゆ帒瀚弲婵嬫煏韫囥儳纾块柣鐔风秺閺屽秷顧侀柛鎾寸懇椤㈡岸鏁愭径妯绘櫌闂佺鏈粙鎴﹀几閸岀偞鈷戦柛娑橈攻婢跺嫰鏌涘Ο铏圭Ш闁糕斁鍋?- 闂傚倷娴囬褍顫濋敃鍌︾稏濠㈣埖鍔曠粻鏍煕椤愶絾绀€缁炬儳娼″娲敆閳ь剛绮旈幘顔藉剹婵°倕鎳忛悡鏇熴亜椤撶喎鐏ラ柡瀣崌閺岋紕鈧綆鍋嗘晶鐢告煛鐏炵偓绀冪紒缁樼洴瀹曞綊顢欓悡搴經闂傚倷绀侀幖顐﹀磹閻㈢纾婚柟鍓х帛閳锋帒霉閿濆洦鍤€妞ゆ洘绮庣槐鎺斺偓锝庡亜閻忔挳鏌熼銊ュ缁♀偓闂佹悶鍎崝灞剧闁秵鈷戦柛锔诲弨濡炬悂鏌涢悩宕囧⒈缂侇喖顭峰濠氬Ψ閿旀儳骞楅梻渚€娼х换鍫ュ垂婵犳凹鏁勫ǎ?builder婵犵數濮烽弫鎼佸磻閻愬樊鐒芥繛鍡樻尭鐟欙箓鎮楅敐搴℃灍闁哄拋浜铏规嫚閺屻儺鈧鏌ｈ箛鏂垮摵闁诡噯绻濋弫鎾绘偐閸欏鈧?# ============================================================================

func _register_all_tools() -> void:
	_log_info("Registering all MCP tools...")

	if not _native_server:
		_log_error("MCP Server instance not available")
		return

	for module_name in TOOL_SCRIPT_PATHS.keys():
		var instance: Variant = _instantiate_script(str(TOOL_SCRIPT_PATHS[module_name]))
		if not instance:
			_log_error("Failed to instantiate tool module: " + str(module_name))
			continue
		_register_tool_module(str(module_name), instance)

	var total_tools: int = _native_server.get_tools_count()
	_log_info("All MCP tools registered successfully. Total: " + str(total_tools))

func _register_tool_module(module_name: String, instance: RefCounted) -> void:
	if not instance:
		return

	_tool_instances[module_name] = instance
	var tools_before: int = _native_server.get_tools_count() if _native_server and _native_server.has_method("get_tools_count") else -1
	_log_info("Registering tool module: %s (before=%d)" % [module_name, tools_before])

	if instance.has_method("initialize"):
		instance.initialize(_editor_interface)

	if instance.has_method("register_tools"):
		instance.register_tools(_native_server)
	var tools_after: int = _native_server.get_tools_count() if _native_server and _native_server.has_method("get_tools_count") else -1
	_log_info("Registered tool module: %s (after=%d, added=%d)" % [module_name, tools_after, tools_after - tools_before])

func _instantiate_script(script_path: String) -> Variant:
	var script: Script = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not script:
		_log_error("Failed to load script: " + script_path)
		return null
	return script.new()

# ============================================================================
# 缂傚倸鍊搁崐鎼佸磹妞嬪海鐭嗗〒姘ｅ亾閽樻繃銇勯弴妤€浜鹃梺璇″枤閸嬨倝寮崘顔肩劦妞ゆ帒瀚弲婵嬫煏韫囥儳纾块柣鐔风秺閺屽秷顧侀柛鎾寸懇椤㈡岸鏁愭径妯绘櫌闂佺鏈粙鎴﹀几閸岀偞鈷戦柛娑橈攻婢跺嫰鏌涘Ο铏圭Ш闁糕斁鍋?- 闂傚倸鍊峰ù鍥х暦閸偅鍙忕€广儱顦粈鍐┿亜椤撶喎鐏ｉ柣銉簽缁辨捇宕掑▎鎴ｇ獥闂佺粯鎸搁悧鎾崇暦娴兼潙鍐€妞ゆ挾鍋熼崢娲⒑閸濆嫬鏆欓柣妤€妫欓崕顐︽⒒娓氣偓濞佳囁囬銏犵？闁哄被鍎辩痪褔鏌熼梻瀵稿妽闁抽攱鍨块弻鐔虹矙閹稿孩宕抽梺瀹犳椤︾敻寮婚敐鍛傛棃鍩€椤掑嫭鏅濇い蹇撶墕缁犳牜鎲搁弮鍫㈠祦婵せ鍋撴い銏＄懇閹虫牠鍩℃繝鍌涙毉闂傚倸鍊烽悞锕傛儑瑜版帒鍨傞柤濮愬€楃粻鏃€銇?builder婵犵數濮烽弫鎼佸磻閻愬樊鐒芥繛鍡樻尭鐟欙箓鎮楅敐搴℃灍闁哄拋浜铏规嫚閺屻儺鈧鏌ｈ箛鏂垮摵闁诡噯绻濋弫鎾绘偐閸欏鈧?# ============================================================================

func _register_all_resources() -> void:
	_log_info("Registering all MCP resources...")

	if not _native_server:
		_log_error("MCP Server instance not available")
		return

	# 濠电姷鏁告慨鐑藉极閹间礁纾绘繛鎴旀嚍閸ヮ剦鏁囬柕蹇曞Х椤︻噣鎮楅崗澶婁壕闂佸憡娲﹂崑澶愬春閻愬绠鹃悗鐢殿焾瀛濆銈嗗灥閹虫﹢鐛幋锕€閱囬柡鍥╁枔閸樹粙姊洪悷閭﹀殶闁稿﹥鐗犻獮瀣晜閽樺鎴锋俊鐐€栭悧婊堝磻閻愬搫纾婚柨婵嗘处閸犳劗鈧箍鍎卞ú鐘诲磻閹炬剚娼╅柣鎾抽缁犲姊?
	_register_scene_resources()

	# 濠电姷鏁告慨鐑藉极閹间礁纾绘繛鎴旀嚍閸ヮ剦鏁囬柕蹇曞Х椤︻噣鎮楅崗澶婁壕闂佸憡娲﹂崑澶愬春閻愬绠鹃悗鐢殿焾瀛濆銈嗗灥濡繂鐣烽悽绋跨倞闁靛绠戝鍨攽椤旂瓔娈旀俊顐ｎ殜閻涱喖螖閸涱喚鍘甸梺缁樺灦閸ㄦ繈骞夋ィ鍐╃厵妞ゆ梻铏庨弨鐗堛亜閿旂晫鍙€闁诡喗顨呴～婵嬫偂鎼达紕顔掗梻?
	_register_script_resources()

	# 濠电姷鏁告慨鐑藉极閹间礁纾绘繛鎴旀嚍閸ヮ剦鏁囬柕蹇曞Х椤︻噣鎮楅崗澶婁壕闂佸憡娲﹂崑澶愬春閻愮儤鈷戦柛蹇涙？閼割亪鏌涙惔顔肩仭缂佸倸绉撮…銊╁醇閻斿搫骞堥梻浣瑰濡線顢氳閻涱喖螖閸愵亞锛滈梺褰掑亰閸欏骸鈻撳鍫熺厵妞ゆ梻铏庨弨鐗堛亜閿旂晫鍙€闁诡喗顨呴～婵嬫偂鎼达紕顔掗梻?
	_register_project_resources()

	_register_editor_resources()

	_log_info("All MCP resources registered successfully")

func _register_scene_resources() -> void:
	# godot://scene/list
	_native_server.register_resource(
		"godot://scene/list",
		"Godot Scene List",
		"application/json",
		Callable(self, "_resource_scene_list"),
		"List of all .tscn scene files in the project"
	)

	# godot://scene/current
	_native_server.register_resource(
		"godot://scene/current",
		"Current Scene",
		"application/json",
		Callable(self, "_resource_scene_current"),
		"Structure of the currently open scene in the editor"
	)

	# godot://scene/open
	_native_server.register_resource(
		"godot://scene/open",
		"Open Godot Scenes",
		"application/json",
		Callable(self, "_resource_scene_open"),
		"Get the currently open scene tabs in the editor"
	)

	# godot://tools/catalog
	_native_server.register_resource(
		"godot://tools/catalog",
		"Godot Tool Catalog",
		"application/json",
		Callable(self, "_resource_tools_catalog"),
		"Get the live registered MCP tool catalog"
	)

func _register_script_resources() -> void:
	# godot://script/list
	_native_server.register_resource(
		"godot://script/list",
		"Godot Script List",
		"application/json",
		Callable(self, "_resource_script_list"),
		"List of all .gd script files in the project"
	)

	# godot://script/current
	_native_server.register_resource(
		"godot://script/current",
		"Current Script",
		"text/plain",
		Callable(self, "_resource_script_current"),
		"Content of the currently open script in the editor"
	)

	_native_server.register_resource(
		"godot://editor/script_summary",
		"Editor Script Summary",
		"application/json",
		Callable(self, "_resource_editor_script_summary"),
		"Get the current open-script/editor summary snapshot"
	)

	_native_server.register_resource(
		"godot://editor/paths",
		"Editor Paths",
		"application/json",
		Callable(self, "_resource_editor_paths"),
		"Get the current editor paths snapshot"
	)

	_native_server.register_resource(
		"godot://editor/shell_state",
		"Editor Shell State",
		"application/json",
		Callable(self, "_resource_editor_shell_state"),
		"Get the current editor shell-state snapshot"
	)

	_native_server.register_resource(
		"godot://editor/language",
		"Editor Language",
		"application/json",
		Callable(self, "_resource_editor_language"),
		"Get the current editor language snapshot"
	)

	_native_server.register_resource(
		"godot://editor/current_location",
		"Editor Current Location",
		"application/json",
		Callable(self, "_resource_editor_current_location"),
		"Get the current editor path and directory snapshot"
	)

	_native_server.register_resource(
		"godot://editor/current_feature_profile",
		"Editor Current Feature Profile",
		"application/json",
		Callable(self, "_resource_editor_current_feature_profile"),
		"Get the current editor feature-profile snapshot"
	)

	_native_server.register_resource(
		"godot://editor/selected_paths",
		"Editor Selected Paths",
		"application/json",
		Callable(self, "_resource_editor_selected_paths"),
		"Get the current editor selected-path snapshot"
	)

	_native_server.register_resource(
		"godot://editor/play_state",
		"Editor Play State",
		"application/json",
		Callable(self, "_resource_editor_play_state"),
		"Get the current editor play-state snapshot"
	)

	_native_server.register_resource(
		"godot://editor/3d_snap_state",
		"Editor 3D Snap State",
		"application/json",
		Callable(self, "_resource_editor_3d_snap_state"),
		"Get the current editor 3D snap-state snapshot"
	)

	_native_server.register_resource(
		"godot://editor/subsystem_availability",
		"Editor Subsystem Availability",
		"application/json",
		Callable(self, "_resource_editor_subsystem_availability"),
		"Get the current editor subsystem availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/previewer_availability",
		"Editor Previewer Availability",
		"application/json",
		Callable(self, "_resource_editor_previewer_availability"),
		"Get the current editor resource-previewer availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/undo_redo_availability",
		"Editor Undo Redo Availability",
		"application/json",
		Callable(self, "_resource_editor_undo_redo_availability"),
		"Get the current editor undo-redo availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/base_control_availability",
		"Editor Base Control Availability",
		"application/json",
		Callable(self, "_resource_editor_base_control_availability"),
		"Get the current editor base-control availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/file_system_dock_availability",
		"Editor File System Dock Availability",
		"application/json",
		Callable(self, "_resource_editor_file_system_dock_availability"),
		"Get the current editor file-system-dock availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/inspector_availability",
		"Editor Inspector Availability",
		"application/json",
		Callable(self, "_resource_editor_inspector_availability"),
		"Get the current editor inspector availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/viewport_availability",
		"Editor Viewport Availability",
		"application/json",
		Callable(self, "_resource_editor_viewport_availability"),
		"Get the current editor viewport availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/selection_availability",
		"Editor Selection Availability",
		"application/json",
		Callable(self, "_resource_editor_selection_availability"),
		"Get the current editor selection-object availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/command_palette_availability",
		"Editor Command Palette Availability",
		"application/json",
		Callable(self, "_resource_editor_command_palette_availability"),
		"Get the current editor command-palette availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/toaster_availability",
		"Editor Toaster Availability",
		"application/json",
		Callable(self, "_resource_editor_toaster_availability"),
		"Get the current editor toaster availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/resource_filesystem_availability",
		"Editor Resource Filesystem Availability",
		"application/json",
		Callable(self, "_resource_editor_resource_filesystem_availability"),
		"Get the current editor resource-filesystem availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/script_editor_availability",
		"Editor Script Editor Availability",
		"application/json",
		Callable(self, "_resource_editor_script_editor_availability"),
		"Get the current editor script-editor availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/settings_availability",
		"Editor Settings Availability",
		"application/json",
		Callable(self, "_resource_editor_settings_availability"),
		"Get the current editor settings availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/theme_availability",
		"Editor Theme Availability",
		"application/json",
		Callable(self, "_resource_editor_theme_availability"),
		"Get the current editor theme availability snapshot"
	)

	_native_server.register_resource(
		"godot://editor/current_scene_dirty_state",
		"Editor Current Scene Dirty State",
		"application/json",
		Callable(self, "_resource_editor_current_scene_dirty_state"),
		"Get the current active scene dirty-state snapshot"
	)

	_native_server.register_resource(
		"godot://editor/open_scene_summary",
		"Editor Open Scene Summary",
		"application/json",
		Callable(self, "_resource_editor_open_scene_summary"),
		"Get the current open-scene summary snapshot"
	)

	_native_server.register_resource(
		"godot://editor/open_scenes_summary",
		"Editor Open Scenes Summary",
		"application/json",
		Callable(self, "_resource_editor_open_scenes_summary"),
		"Get the current open-scenes summary snapshot"
	)

	_native_server.register_resource(
		"godot://editor/open_scene_roots_summary",
		"Editor Open Scene Roots Summary",
		"application/json",
		Callable(self, "_resource_editor_open_scene_roots_summary"),
		"Get the current open-scene-roots summary snapshot"
	)

func _register_project_resources() -> void:
	# godot://project/info
	_native_server.register_resource(
		"godot://project/info",
		"Project Info",
		"application/json",
		Callable(self, "_resource_project_info"),
		"Project name, version, and basic information"
	)

	# godot://project/settings
	_native_server.register_resource(
		"godot://project/settings",
		"Project Settings",
		"application/json",
		Callable(self, "_resource_project_settings"),
		"Project setting values and configuration"
	)

	# godot://project/class_metadata
	_native_server.register_resource(
		"godot://project/class_metadata",
		"Project Class Metadata",
		"application/json",
		Callable(self, "_resource_project_class_metadata"),
		"Get normalized project global class metadata"
	)

	_native_server.register_resource(
		"godot://project/global_classes",
		"Project Global Classes",
		"application/json",
		Callable(self, "_resource_project_global_classes"),
		"Get the installed project global class inventory"
	)

	_native_server.register_resource(
		"godot://project/configuration_summary",
		"Project Configuration Summary",
		"application/json",
		Callable(self, "_resource_project_configuration_summary"),
		"Get a bounded snapshot of installed plugins, autoloads, and feature profiles"
	)

	_native_server.register_resource(
		"godot://project/plugins",
		"Project Plugins",
		"application/json",
		Callable(self, "_resource_project_plugins"),
		"Get the installed project plugin inventory and enabled states"
	)

	_native_server.register_resource(
		"godot://project/feature_profiles",
		"Project Feature Profiles",
		"application/json",
		Callable(self, "_resource_project_feature_profiles"),
		"Get the installed project feature-profile inventory and current active profile"
	)

	_native_server.register_resource(
		"godot://project/autoloads",
		"Project Autoloads",
		"application/json",
		Callable(self, "_resource_project_autoloads"),
		"Get the installed project autoload inventory"
	)

	_native_server.register_resource(
		"godot://project/tests",
		"Project Tests",
		"application/json",
		Callable(self, "_resource_project_tests"),
		"Get the discovered project test inventory"
	)

	_native_server.register_resource(
		"godot://project/test_runners",
		"Project Test Runners",
		"application/json",
		Callable(self, "_resource_project_test_runners"),
		"Get current runner availability for supported project test frameworks"
	)

	_native_server.register_resource(
		"godot://project/dependency_snapshot",
		"Project Dependency Snapshot",
		"application/json",
		Callable(self, "_resource_project_dependency_snapshot"),
		"Get a stable snapshot of parsed project resource dependencies"
	)

func _register_editor_resources() -> void:
	_native_server.register_resource(
		"godot://editor/logs",
		"Editor Logs",
		"application/json",
		Callable(self, "_resource_editor_logs"),
		"Get a bounded snapshot of recent MCP/editor log entries"
	)

	_native_server.register_resource(
		"godot://runtime/state",
		"Runtime State",
		"application/json",
		Callable(self, "_resource_runtime_state"),
		"Get a bounded runtime-state snapshot or explicit no-session truth"
	)

	# godot://editor/state
	_native_server.register_resource(
		"godot://editor/state",
		"Editor State",
		"application/json",
		Callable(self, "_resource_editor_state"),
		"Current editor state and active tools"
	)

# ============================================================================
# 闂傚倸鍊峰ù鍥х暦閸偅鍙忕€广儱顦粈鍐┿亜椤撶喎鐏ｉ柣銉簽缁辨捇宕掑▎鎴ｇ獥闂佺粯鎸搁悧鎾崇暦閹惰姤鏅查柛娑卞灡濞堟儳鈹戦悩缁樻锭妞ゆ垵妫濆畷鎴﹀箛閻楀牏鍘介梺鐟邦嚟閸庢劙鎮炴禒瀣厪闁割偅绮屽畵鍡樻叏婵犲啯銇濈€规洦鍋婂畷鐔碱敃閻旇渹澹曟繛瀵稿Т椤戞垹绱為弽褜鐔嗛悹铏瑰劋濠€浼存煕韫囨梻鐭掗柡灞剧洴椤㈡洟鏁愰崱娆樻О闂備礁鎼幏瀣礈閻旂厧钃熸繛鎴欏焺閺佸啴鏌ㄥ┑鍡樺窛闁伙絽銈稿娲传閸曞灚啸缂備緡鍠楅悷銉╋綖韫囨梻绡€婵﹩鍓涢ˇ鏉款渻閵堝棗濮х紒鑼舵閳诲秹鏁愭径瀣ф嫼濠殿喚鎳撳ú銈夊焵椤掍焦绀堥柍褜鍓氶惌顕€宕￠幎鐣屽祦闁告劑鍔庨弳锕傛煕閵夛絽濡芥繛鍫熸緲椤啴濡堕崱妯煎弳婵犫拃鍌滅煓閽?
# ============================================================================

func _resource_scene_list(params: Dictionary) -> Dictionary:
	var scenes: Array = []
	var dir = DirAccess.open("res://")

	if not dir:
		return {"contents": [{"uri": "godot://scene/list", "mimeType": "application/json", "text": "[]"}]}

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
	if _native_server and _native_server.has_method("get_registered_tools"):
		tools = _native_server.get_registered_tools()

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

func _resource_script_list(params: Dictionary) -> Dictionary:
	var scripts: Array = []
	var dir = DirAccess.open("res://")

	if not dir:
		return {"contents": [{"uri": "godot://script/list", "mimeType": "application/json", "text": "[]"}]}

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

func _resource_script_current(params: Dictionary) -> Dictionary:
	return {
		"contents": [{
			"uri": "godot://script/current",
			"mimeType": "text/plain",
			"text": "# Current script feature not yet implemented\n# Godot 4.x requires EditorPlugin or ScriptEditor to get current script"
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
	var snapshot: Dictionary = _build_project_info_snapshot()

	return {
		"contents": [{
			"uri": "godot://project/info",
			"mimeType": "application/json",
			"text": JSON.stringify(snapshot, "\t", true)
		}]
	}

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

	var selection = _editor_interface.get_selection()
	if selection:
		var selected_nodes: Array = selection.get_selected_nodes()
		for node in selected_nodes:
			editor_state["selected_nodes"].append(str(node.get_path()))

	return {
		"contents": [{
			"uri": "godot://editor/state",
			"mimeType": "application/json",
			"text": JSON.stringify(editor_state, "\t", true)
		}]
	}

# ============================================================================
# 闂傚倸鍊峰ù鍥х暦閸偅鍙忕€广儱顦粈鍐┿亜椤撶喎鐏ｉ柣銉簽缁辨捇宕掑▎鎴ｇ獥闂佺粯鎸搁悧鎾崇暦閹惰姤鏅查柛娑卞灡濞堟儳鈹戦悩缁樻锭妞ゆ垵妫濆畷鎴﹀箛閻楀牏鍘介梺鐟邦嚟閸庢劙鎮炴禒瀣厪闁割偅绮屽畵鍡涙煛鐏炵澧茬€垫澘瀚换婵嬪礋椤愵偅姣囬梻鍌欒兌閹虫捇宕捄銊㈠亾濞戞帗娅婃鐐茬墦婵℃悂鍩℃繝鍐╂珕闂備礁澹婇崑鍛崲閸曨垁鍥煛閸涱喒鎷洪梺绋跨箻濡潡鎳滈鍫熺厱閹兼番鍨圭徊濠氭煃?
# ============================================================================

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

static func _count_nodes(node: Node) -> int:
	var count: int = 1  # 闂傚倷娴囧畷鐢稿窗閹邦喖鍨濋幖娣灪濞呯姵淇婇妶鍛櫣缂佺姳鍗抽弻娑樷槈濮楀牊鏁惧┑鐐叉噽婵炩偓闁哄矉绲借灒闁兼祴鏅涚粭锟犳⒑閹肩偛鈧洜绮旇ぐ鎺戣摕婵炴垶鐭▽顏堟煕閹炬鎳愰崢鎰攽?

	for child in node.get_children():
		count += _count_nodes(child)

	return count

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

# ============================================================================
# UI闂傚倸鍊搁崐鎼佸磹閹间礁纾归柟闂寸劍閸嬪鏌涢弴銊ョ仩闁搞劌鍊块弻娑樷攽閸℃浼岄梺缁樻煥濡瑩骞堥妸銉富閻犲洩寮撴竟鏇㈡煟鎼淬値娼愭繛鍙夛耿閹虫繃銈ｉ崘銊у弨婵犮垼娉涜癌闁绘柨鍚嬮崵鍐煃鏉炴壆璐版俊?
# ============================================================================

func _create_main_screen_panel() -> void:
	_log_info("Creating main screen panel...")

	var panel_scene: PackedScene = load("res://addons/godot_mcp/ui/mcp_panel_native.tscn")
	if not panel_scene:
		_log_error("Failed to load MCP panel scene")
		return

	_main_panel = panel_scene.instantiate()
	if not _main_panel:
		_log_error("Failed to instantiate MCP panel")
		return

	EditorInterface.get_editor_main_screen().add_child(_main_panel)
	_make_visible(false)

	if _main_panel.has_method("set_plugin"):
		_main_panel.set_plugin(self)
		_log_info("Plugin reference set to panel")

	if _native_server and _main_panel.has_method("set_server_core"):
		_main_panel.set_server_core(_native_server)
		_log_info("Server core reference set to panel")

	_log_info("Main screen panel created successfully")

# ============================================================================
# 婵犵數濮烽弫鎼佸磿閹寸姴绶ら柦妯侯棦濞差亝鍋愰悹鍥皺閸旓箑顪冮妶鍡楀潑闁稿鎹囬弻娑㈡偄缁嬫鍤嬬紓浣虹帛閻╊垰鐣烽崼鏇ㄦ晢濞达絽鎼獮鍫ユ⒒娓氣偓濞佳囨晬韫囨稑绀冪憸宥夊箺鐎ｎ喗鈷?
# ============================================================================

func _on_server_started() -> void:
	_log_info("MCP Server started")
	if _main_panel and _main_panel.has_method("refresh"):
		if Thread.is_main_thread():
			_main_panel.refresh()
		else:
			_main_panel.call_deferred("refresh")

func _on_server_stopped() -> void:
	_log_info("MCP Server stopped")
	if _main_panel and _main_panel.has_method("refresh"):
		if Thread.is_main_thread():
			_main_panel.refresh()
		else:
			_main_panel.call_deferred("refresh")

func _on_message_received(message: Dictionary) -> void:
	_log_debug("Message received: " + JSON.stringify(message))
	if _main_panel and _main_panel.has_method("update_log"):
		_main_panel.update_log("[RECV] " + JSON.stringify(message))

func _on_response_sent(response: Dictionary) -> void:
	_log_debug("Response sent: " + JSON.stringify(response))
	if _main_panel and _main_panel.has_method("update_log"):
		_main_panel.update_log("[SENT] " + JSON.stringify(response))

func _on_tool_started(tool_name: String, params: Dictionary) -> void:
	_log_info("Tool started: " + tool_name)

func _on_tool_completed(tool_name: String, result: Dictionary) -> void:
	_log_info("Tool completed: " + tool_name)

func _on_tool_failed(tool_name: String, error: String) -> void:
	_log_error("Tool failed: " + tool_name + " - " + error)

func _on_log_message(level: String, message: String) -> void:
	if _main_panel and _main_panel.has_method("update_log"):
		_main_panel.update_log("[" + level + "] " + message)

# ============================================================================
# 闂傚倸鍊搁崐椋庣矆娓氣偓楠炴牠顢曢敃鈧悿顕€鏌曟繛鐐珔缁炬儳娼″鍫曞醇濮橆厽鐝曢悗瑙勬礃閻擄繝寮婚敓鐘茬闁靛ě鍐炬毇婵犵妲呴崑鍛存晝閵忋倕绠栫€瑰嫭澹嬮弸搴ㄧ叓閸ャ劍鎯勫ù灏栧亾闂傚倷绶氬褍螞濡ゅ懏鏅濇い蹇撶墕閽冪喖鏌曟繛鍨姉婵℃彃鐗婃穱濠囶敍濠婂啫浠樺銈冨€愰崑鎾绘⒒閸屾瑨鍏岀紒顕呭灦閵嗗啴宕卞☉妯碱唶闂佺懓澧庨弲顐㈢暤娓氣偓閺岀喐娼忔ィ鍐╊€嶉梺绋款儍閸旀垿寮婚敐澶嬫櫜闁告洦鍨伴崝鏉榯-dev-guide婵犵數濮烽弫鎼佸磻閻愬樊鐒芥繛鍡樻尭鐟欙箓鎮楅敐搴℃灍闁哄拋浜铏规嫚閺屻儺鈧鏌ｈ箛鏂垮摵闁诡噯绻濋弫鎾绘偐閸欏鈧?# ============================================================================

func _log_error(message: String) -> void:
	if log_level >= 0 and _native_server:
		_native_server._log_error(message)

func _log_warn(message: String) -> void:
	if log_level >= 1 and _native_server:
		_native_server._log_warn(message)

func _log_info(message: String) -> void:
	if log_level >= 2 and _native_server:
		_native_server._log_info(message)

func _log_debug(message: String) -> void:
	if log_level >= 3 and _native_server:
		_native_server._log_debug(message)

# ============================================================================
# 濠电姷鏁告慨鐑藉极閹间礁纾婚柣鎰惈缁犱即鏌熼梻瀵割槮缂佺姷濞€閺岀喖鎮ч崼鐔哄嚒缂?
# ============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _native_server and _native_server.is_running():
			_native_server.stop()
		_native_server = null
