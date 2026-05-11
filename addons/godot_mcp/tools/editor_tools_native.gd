# editor_tools_native.gd - нативная реализация Editor Tools
# Добавлены полные подсказки типов по godot-dev-guide

@tool
class_name EditorToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null
var _editor_operation_in_progress: bool = false

func initialize(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface

func _get_editor_interface() -> EditorInterface:
	if _editor_interface:
		return _editor_interface
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_editor_interface"):
			return plugin.get_editor_interface()
	return null

func _get_user_scene_root() -> Node:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return null
	
	var scene_root: Node = editor_interface.get_edited_scene_root()
	if scene_root and not scene_root.name.begins_with("@") and scene_root.get_class() != "PanelContainer":
		return scene_root
	
	var open_scenes: Array = editor_interface.get_open_scenes()
	for scene in open_scenes:
		if scene and not scene.name.begins_with("@") and scene.get_class() != "PanelContainer":
			return scene
	
	return scene_root

static func _make_friendly_path(node: Node, scene_root: Node) -> String:
	if not scene_root:
		return str(node.get_path())
	if node == scene_root:
		return "/root/" + scene_root.name
	var node_path: String = str(node.get_path())
	var root_path: String = str(scene_root.get_path())
	if node_path.begins_with(root_path + "/"):
		return "/root/" + scene_root.name + node_path.substr(root_path.length())
	return node_path

# ============================================================================
# Регистрация инструментов
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	_register_get_editor_state(server_core)
	_register_run_project(server_core)
	_register_stop_project(server_core)
	_register_get_selected_nodes(server_core)
	_register_set_editor_setting(server_core)
	_register_get_editor_screenshot(server_core)
	_register_get_signals(server_core)
	_register_reload_project(server_core)

# ============================================================================
# get_editor_state - получение состояния редактора
# ============================================================================

func _register_get_editor_state(server_core: RefCounted) -> void:
	var tool_name: String = "get_editor_state"
	var description: String = "Get the current state of the Godot editor, including active scene and selection info."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"active_scene": {"type": "string"},
			"selected_nodes": {
				"type": "array",
				"items": {"type": "object"}
			},
			"editor_mode": {"type": "string"},
			"selected_count": {"type": "integer"}
		}
	}
	
	# annotations - readOnlyHint = true
	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}
	
	# Регистрация инструмента
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_editor_state"),
						  output_schema, annotations)

func _tool_get_editor_state(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var scene_root: Node = _get_user_scene_root()
	var active_scene: String = scene_root.name if scene_root else ""
	
	var selected_nodes: Array = []
	var selection: EditorSelection = editor_interface.get_selection()
	if selection:
		var selected: Array[Node] = selection.get_selected_nodes()
		for node in selected:
			var node_info: Dictionary = {
				"path": _make_friendly_path(node, scene_root),
				"type": node.get_class()
			}
			var node_script: Variant = node.get_script()
			if node_script and node_script is Script:
				node_info["script_path"] = node_script.resource_path
			selected_nodes.append(node_info)
	
	var editor_mode: String = "editor"
	if editor_interface.is_playing_scene():
		editor_mode = "playing"
	
	return {
		"active_scene": active_scene,
		"selected_nodes": selected_nodes,
		"editor_mode": editor_mode,
		"selected_count": selected_nodes.size()
	}

# ============================================================================
# run_project - запуск проекта
# ============================================================================

func _register_run_project(server_core: RefCounted) -> void:
	var tool_name: String = "run_project"
	var description: String = "Run the current project or a specific scene. Launches the game in play mode."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "Optional path to a specific scene to run. If not provided, runs the main scene."
			}
		}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"mode": {"type": "string"}
		}
	}
	
	# annotations
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}
	
	# Регистрация инструмента
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_run_project"),
						  output_schema, annotations)

func _tool_run_project(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	if editor_interface.is_playing_scene():
		return {"error": "Project is already running. Stop it first with stop_project."}
	
	var scene_path: String = params.get("scene_path", "")
	
	if not scene_path.is_empty():
		if not FileAccess.file_exists(scene_path):
			return {"error": "Scene file not found: " + scene_path}
		editor_interface.play_custom_scene(scene_path)
	else:
		editor_interface.play_current_scene()
	
	return {
		"status": "success",
		"mode": "playing"
	}

# ============================================================================
# stop_project - остановка запуска
# ============================================================================

func _register_stop_project(server_core: RefCounted) -> void:
	var tool_name: String = "stop_project"
	var description: String = "Stop the currently running project and return to editor mode."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"mode": {"type": "string"}
		}
	}
	
	# annotations
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}
	
	# Регистрация инструмента
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_stop_project"),
						  output_schema, annotations)

func _tool_stop_project(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	if not editor_interface.is_playing_scene():
		return {"error": "Project is not currently running."}
	
	editor_interface.stop_playing_scene()
	
	return {
		"status": "success",
		"mode": "editor"
	}

# ============================================================================
# get_selected_nodes - получение выбранных узлов
# ============================================================================

func _register_get_selected_nodes(server_core: RefCounted) -> void:
	var tool_name: String = "get_selected_nodes"
	var description: String = "Get the list of currently selected nodes in the editor."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"selected_nodes": {
				"type": "array",
				"items": {"type": "object"}
			},
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
						  Callable(self, "_tool_get_selected_nodes"),
						  output_schema, annotations)

func _tool_get_selected_nodes(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var selected_nodes: Array = []
	var selection: EditorSelection = editor_interface.get_selection()
	var scene_root: Node = _get_user_scene_root()
	
	if selection:
		var selected: Array[Node] = selection.get_selected_nodes()
		for node in selected:
			var node_info: Dictionary = {
				"path": _make_friendly_path(node, scene_root),
				"type": node.get_class()
			}
			var node_script: Variant = node.get_script()
			if node_script and node_script is Script:
				node_info["script_path"] = node_script.resource_path
			selected_nodes.append(node_info)
	
	if selected_nodes.is_empty():
		var edited_scene: Node = editor_interface.get_edited_scene_root()
		if edited_scene:
			selected_nodes.append({
				"path": _make_friendly_path(edited_scene, scene_root),
				"type": edited_scene.get_class()
			})
	
	return {
		"selected_nodes": selected_nodes,
		"count": selected_nodes.size()
	}

# ============================================================================
# set_editor_setting - установка параметра редактора
# ============================================================================

func _register_set_editor_setting(server_core: RefCounted) -> void:
	var tool_name: String = "set_editor_setting"
	var description: String = "Set an editor setting value. Requires editor restart for some settings to take effect."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"setting_name": {
				"type": "string",
				"description": "Name of the setting (e.g. 'interface/theme/accent_color')"
			},
			"setting_value": {
				"description": "New value for the setting"
			}
		},
		"required": ["setting_name", "setting_value"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"setting_name": {"type": "string"},
			"old_value": {"type": "string"},
			"new_value": {"type": "string"}
		}
	}
	
	# annotations
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}
	
	# Регистрация инструмента
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_set_editor_setting"),
						  output_schema, annotations)

func _tool_set_editor_setting(params: Dictionary) -> Dictionary:
	var setting_name: String = params.get("setting_name", "")
	var setting_value: Variant = params.get("setting_value", null)
	
	if setting_name.is_empty():
		return {"error": "Missing required parameter: setting_name"}
	if setting_value == null:
		return {"error": "Missing required parameter: setting_value"}
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var editor_settings: EditorSettings = editor_interface.get_editor_settings()
	if not editor_settings:
		return {"error": "Failed to get EditorSettings"}
	
	var old_value: Variant = null
	if editor_settings.has_setting(setting_name):
		old_value = editor_settings.get_setting(setting_name)
	editor_settings.set_setting(setting_name, setting_value)
	if editor_settings.has_method("save"):
		editor_settings.save()
	
	return {
		"status": "success",
		"setting_name": setting_name,
		"old_value": str(old_value) if old_value != null else "null",
		"new_value": str(setting_value)
	}

# ============================================================================
# get_editor_screenshot - снимок окна редактора
# ============================================================================

func _register_get_editor_screenshot(server_core: RefCounted) -> void:
	var tool_name: String = "get_editor_screenshot"
	var description: String = "Capture a screenshot of the editor viewport and save it to a file."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"viewport_type": {
				"type": "string",
				"description": "Viewport type: '3d' or '2d'. Default is '3d'.",
				"enum": ["3d", "2d"]
			},
			"viewport_index": {
				"type": "integer",
				"description": "3D viewport index (0-3). Default is 0."
			},
			"save_path": {
				"type": "string",
				"description": "Path to save the screenshot (e.g. 'res://screenshots/editor.png')."
			},
			"format": {
				"type": "string",
				"description": "Image format: 'png' or 'jpg'. Default is 'png'.",
				"enum": ["png", "jpg"]
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"save_path": {"type": "string"},
			"size": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
		Callable(self, "_tool_get_editor_screenshot"),
		output_schema, annotations)

func _tool_get_editor_screenshot(params: Dictionary) -> Dictionary:
	var viewport_type: String = params.get("viewport_type", "3d")
	var viewport_index: int = params.get("viewport_index", 0)
	var save_path: String = params.get("save_path", "res://screenshot_editor.png")
	var format: String = params.get("format", "png")

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}

	var path_validation: Dictionary = PathValidator.validate_path(save_path)
	if not path_validation["valid"]:
		return {"error": "Invalid save path: " + path_validation["error"]}
	save_path = path_validation["sanitized"]

	var viewport: SubViewport = null
	if viewport_type == "3d":
		viewport = editor_interface.get_editor_viewport_3d(viewport_index)
	else:
		viewport = editor_interface.get_editor_viewport_2d()

	if not viewport:
		return {"error": "Failed to get editor viewport"}

	var texture: ViewportTexture = viewport.get_texture()
	if not texture:
		return {"error": "Failed to get viewport texture"}

	var image: Image = texture.get_image()
	if not image:
		return {"error": "Failed to capture viewport image"}

	var save_dir: String = save_path.get_base_dir()
	if not save_dir.is_empty() and not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	var err: Error = OK
	if format == "jpg":
		err = image.save_jpg(save_path, 0.9)
	else:
		err = image.save_png(save_path)

	if err != OK:
		return {"error": "Failed to save screenshot: error " + str(err)}

	return {
		"status": "success",
		"save_path": save_path,
		"size": str(image.get_width()) + "x" + str(image.get_height())
	}

# ============================================================================
# get_signals - получение всех сигналов узла и соединений
# ============================================================================

func _register_get_signals(server_core: RefCounted) -> void:
	var tool_name: String = "get_signals"
	var description: String = "Get all signals and their connections for a node."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node (e.g. '/root/MainScene/Player')"
			},
			"include_connections": {
				"type": "boolean",
				"description": "Whether to include connection details. Default is true."
			}
		},
		"required": ["node_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"signals": {"type": "array"},
			"signal_count": {"type": "integer"},
			"connection_count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
		Callable(self, "_tool_get_signals"),
		output_schema, annotations)

func _tool_get_signals(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var include_connections: bool = params.get("include_connections", true)

	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}

	var target_node: Node = _resolve_node_path(editor_interface, node_path)
	if not target_node:
		return {"error": "Node not found: " + node_path}

	var signal_list: Array = target_node.get_signal_list()
	var signals: Array = []
	var total_connections: int = 0

	for sig in signal_list:
		var signal_info: Dictionary = {
			"name": sig.get("name", ""),
			"arguments": sig.get("args", []).size()
		}

		if include_connections:
			var connections: Array = target_node.get_signal_connection_list(sig.get("name", ""))
			var connection_list: Array = []
			for conn in connections:
				connection_list.append({
					"callable": str(conn.get("callable", "")),
					"flags": conn.get("flags", 0)
				})
				total_connections += 1
			signal_info["connections"] = connection_list
			signal_info["connection_count"] = connection_list.size()

		signals.append(signal_info)

	return {
		"node_path": node_path,
		"signals": signals,
		"signal_count": signals.size(),
		"connection_count": total_connections
	}

func _resolve_node_path(editor_interface: EditorInterface, path: String) -> Node:
	var edited_scene: Node = editor_interface.get_edited_scene_root()
	if not edited_scene:
		return null
	if path == str(edited_scene.get_path()) or path == "/root/" + edited_scene.name:
		return edited_scene
	if path.begins_with("/root/" + edited_scene.name + "/"):
		var relative: String = path.substr(("/root/" + edited_scene.name + "/").length())
		return edited_scene.get_node_or_null(relative)
	return edited_scene.get_node_or_null(path)

# ============================================================================
# reload_project - повторное сканирование файловой системы и перезагрузка скриптов
# ============================================================================

func _register_reload_project(server_core: RefCounted) -> void:
	var tool_name: String = "reload_project"
	var description: String = "Rescan the project filesystem and reload scripts. Useful after external file changes."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"full_scan": {
				"type": "boolean",
				"description": "Whether to perform a full scan (true) or source-only scan (false). Default is false."
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"scan_type": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
		Callable(self, "_tool_reload_project"),
		output_schema, annotations)

func _tool_reload_project(params: Dictionary) -> Dictionary:
	var full_scan: bool = params.get("full_scan", false)

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}

	var fs: EditorFileSystem = editor_interface.get_resource_filesystem()
	if not fs:
		return {"error": "Failed to get EditorFileSystem"}

	if fs.is_scanning():
		return {
			"status": "already_scanning",
			"progress": fs.get_scanning_progress(),
			"message": "Filesystem scan is already in progress"
		}

	if full_scan:
		fs.scan()
		return {"status": "success", "scan_type": "full"}
	else:
		fs.scan_sources()
		return {"status": "success", "scan_type": "sources_only"}
