# script_tools_native.gd - Script Tools原生实现（简化版）
# 根据godot-dev-guide添加完整的类型提示

@tool
class_name ScriptToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null

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

# ============================================================================
# 工具注册
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	_register_list_project_scripts(server_core)
	_register_read_script(server_core)
	_register_create_script(server_core)
	_register_modify_script(server_core)
	_register_analyze_script(server_core)
	_register_get_current_script(server_core)
	_register_open_script_at_line(server_core)
	_register_attach_script(server_core)
	_register_validate_script(server_core)
	_register_search_in_files(server_core)

# ============================================================================
# list_project_scripts - 列出所有脚本
# ============================================================================

func _register_list_project_scripts(server_core: RefCounted) -> void:
	var tool_name: String = "list_project_scripts"
	var description: String = "List all GDScript files (.gd) in the project. Returns paths relative to res://."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {
				"type": "string",
				"description": "Optional subpath to search (e.g. 'res://scripts/'). Default is 'res://'.",
				"default": "res://"
			}
		}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"scripts": {
				"type": "array",
				"items": {"type": "string"}
			},
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
						  Callable(self, "_tool_list_project_scripts"),
						  output_schema, annotations)

func _tool_list_project_scripts(params: Dictionary) -> Dictionary:
	# 参数提取
	var search_path: String = params.get("search_path", "res://")
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	search_path = validation["sanitized"]
	
	# 使用DirAccess递归查找所有.gd文件
	var scripts: Array = []
	_collect_scripts(search_path, scripts)
	
	# 排序
	scripts.sort()
	
	return {
		"scripts": scripts,
		"count": scripts.size()
	}

# 辅助函数：递归收集脚本文件
func _collect_scripts(directory_path: String, result: Array) -> void:
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
				_collect_scripts(full_path, result)
			elif file_name.ends_with(".gd"):
				# 添加脚本文件
				result.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

# ============================================================================
# read_script - 读取脚本内容
# ============================================================================

func _register_read_script(server_core: RefCounted) -> void:
	var tool_name: String = "read_script"
	var description: String = "Read the content of a GDScript file (.gd). Returns the complete script source code."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path to the script file (e.g. 'res://scripts/player.gd')"
			}
		},
		"required": ["script_path"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {"type": "string"},
			"content": {"type": "string"},
			"line_count": {"type": "integer"}
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
						  Callable(self, "_tool_read_script"),
						  output_schema, annotations)

func _tool_read_script(params: Dictionary) -> Dictionary:
	# 参数提取
	var script_path: String = params.get("script_path", "")
	
	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	script_path = validation["sanitized"]
	
	# 验证文件是否存在
	
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	
	if not file:
		return {"error": "Failed to open file: " + script_path}
	
	# 读取内容
	var content: String = file.get_as_text()
	file.close()

	var line_count: int = content.split("\n").size()
	
	return {
		"script_path": script_path,
		"content": content,
		"line_count": line_count
	}

# ============================================================================
# create_script - 创建新脚本
# ============================================================================

func _register_create_script(server_core: RefCounted) -> void:
	var tool_name: String = "create_script"
	var description: String = "Create a new GDScript file with optional template. GDScript files are complete programs, not resource files."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path where the script will be saved (e.g. 'res://scripts/player.gd')"
			},
			"content": {
				"type": "string",
				"description": "Optional initial content for the script. If not provided, creates an empty script."
			},
			"template": {
				"type": "string",
				"description": "Optional template to use: 'empty', 'node', 'characterbody2d', 'characterbody3d', 'area2d', 'area3d'. Default is 'empty'."
			},
			"attach_to_node": {
				"type": "string",
				"description": "Optional node path to attach the script to after creation (e.g. '/root/MainScene/Player')."
			}
		},
		"required": ["script_path"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"script_path": {"type": "string"},
			"line_count": {"type": "integer"}
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
						  Callable(self, "_tool_create_script"),
						  output_schema, annotations)

func _tool_create_script(params: Dictionary) -> Dictionary:
	var script_path: String = params.get("script_path", "")
	var content: String = params.get("content", "")
	var template: String = params.get("template", "empty")
	var attach_to_node: String = params.get("attach_to_node", "")

	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}

	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}

	script_path = validation["sanitized"]

	if FileAccess.file_exists(script_path):
		return {"error": "File already exists: " + script_path}

	if content.is_empty():
		content = _get_script_template(template)

	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		return {"error": "Failed to create file: " + script_path}

	file.store_string(content)
	file.close()

	var line_count: int = content.split("\n").size()
	var result: Dictionary = {
		"status": "success",
		"script_path": script_path,
		"line_count": line_count
	}

	if not attach_to_node.is_empty():
		var editor_interface: EditorInterface = _get_editor_interface()
		if editor_interface:
			var node: Node = _resolve_node_path(editor_interface, attach_to_node)
			if node:
				var script_res: Script = load(script_path)
				if script_res:
					node.set_script(script_res)
					result["attached_to"] = attach_to_node
					editor_interface.get_resource_filesystem().scan()
				else:
					result["attach_warning"] = "Script created but failed to load for attachment"
			else:
				result["attach_warning"] = "Node not found: " + attach_to_node
		else:
			result["attach_warning"] = "Editor interface not available for script attachment"

	return result

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

# 辅助函数：获取脚本模板
func _get_script_template(template_name: String) -> String:
	if template_name == "node":
		return """@tool
extends Node

# Called when the node enters the scene tree
func _ready() -> void:
	pass

# Called every frame
func _process(delta: float) -> void:
	pass
"""
	elif template_name == "characterbody2d":
		return """@tool
extends CharacterBody2D

func _physics_process(delta: float) -> void:
	move_and_slide()
"""
	elif template_name == "characterbody3d":
		return """@tool
extends CharacterBody3D

func _physics_process(delta: float) -> void:
	move_and_slide()
"""
	else:
		return ""

# ============================================================================
# modify_script - 修改脚本内容
# ============================================================================

func _register_modify_script(server_core: RefCounted) -> void:
	var tool_name: String = "modify_script"
	var description: String = "Modify the content of an existing GDScript file. Can replace entire content or specific lines."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path to the script file to modify (e.g. 'res://scripts/player.gd')"
			},
			"content": {
				"type": "string",
				"description": "New content for the script (full replacement)"
			},
			"line_number": {
				"type": "integer",
				"description": "Optional line number to replace (1-indexed). If provided with 'content', replaces that line only."
			}
		},
		"required": ["script_path", "content"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"script_path": {"type": "string"},
			"line_count": {"type": "integer"}
		}
	}
	
	# annotations - destructiveHint = true
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,  # 会覆盖文件
		"idempotentHint": false,
		"openWorldHint": false
	}
	
	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_modify_script"),
						  output_schema, annotations)

func _tool_modify_script(params: Dictionary) -> Dictionary:
	# 参数提取
	var script_path: String = params.get("script_path", "")
	var new_content: String = params.get("content", "")
	var line_number: int = params.get("line_number", 0)
	
	# 参数验证
	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}
	if new_content.is_empty():
		return {"error": "Missing required parameter: content"}
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	script_path = validation["sanitized"]
	
	# 验证文件是否存在
	if not FileAccess.file_exists(script_path):
		return {"error": "File not found: " + script_path}
	
	# 读取现有内容
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file for reading: " + script_path}
	
	var existing_lines: Array = []
	while not file.eof_reached():
		existing_lines.append(file.get_line())
	file.close()
	
	# 修改内容
	var final_content: String
	
	if line_number > 0 and line_number <= existing_lines.size():
		# 替换特定行
		existing_lines[line_number - 1] = new_content
		final_content = "\n".join(existing_lines)
	else:
		# 全量替换
		final_content = new_content
	
	# 写入文件
	file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		return {"error": "Failed to open file for writing: " + script_path}
	
	file.store_string(final_content)
	file.close()
	
	# 计算行数
	var line_count: int = final_content.split("\n").size()
	
	return {
		"status": "success",
		"script_path": script_path,
		"line_count": line_count
	}

# ============================================================================
# analyze_script - 分析脚本结构（完整版）
# ============================================================================

func _register_analyze_script(server_core: RefCounted) -> void:
	var tool_name: String = "analyze_script"
	var description: String = "Analyze the structure of a GDScript file. Returns functions, signals, properties, and more."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path to the script file to analyze (e.g. 'res://scripts/player.gd')"
			}
		},
		"required": ["script_path"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {"type": "string"},
			"has_class_name": {"type": "boolean"},
			"extends_from": {"type": "string"},
			"functions": {"type": "array", "items": {"type": "string"}},
			"signals": {"type": "array", "items": {"type": "string"}},
			"properties": {"type": "array", "items": {"type": "string"}},
			"line_count": {"type": "integer"}
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
						  Callable(self, "_tool_analyze_script"),
						  output_schema, annotations)

func _tool_analyze_script(params: Dictionary) -> Dictionary:
	# 参数提取
	var script_path: String = params.get("script_path", "")
	
	# 参数验证
	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	script_path = validation["sanitized"]
	
	# 验证文件是否存在
	var line_count: int = 0
	var has_class_name: bool = false
	var extends_from: String = ""
	var functions: Array = []
	var signals: Array = []
	var properties: Array = []
	
	# 读取文件内容
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file: " + script_path}
	
	while not file.eof_reached():
		var line: String = file.get_line()
		line_count += 1
		
		# 简单解析
		var trimmed: String = line.strip_edges()
		
		if trimmed.begins_with("class_name "):
			has_class_name = true
		elif trimmed.begins_with("extends ") and extends_from.is_empty():
			extends_from = trimmed.split(" ")[1]
		elif trimmed.begins_with("func "):
			# 提取函数名
			var func_name: String = trimmed.replace("func ", "").split("(")[0]
			functions.append(func_name)
		elif trimmed.begins_with("signal "):
			var signal_name: String = trimmed.replace("signal ", "").split("(")[0]
			signals.append(signal_name)
		elif trimmed.begins_with("var ") and not trimmed.begins_with("var _"):
			var var_part: String = trimmed.replace("var ", "").split(":")[0].split("=")[0].strip_edges()
			if not var_part.is_empty():
				properties.append(var_part)
	
	file.close()
	
	return {
		"script_path": script_path,
		"has_class_name": has_class_name,
		"extends_from": extends_from,
		"language": "gdscript" if script_path.ends_with(".gd") else "csharp" if script_path.ends_with(".cs") else "unknown",
		"functions": functions,
		"signals": signals,
		"properties": properties,
		"line_count": line_count
	}

# ============================================================================
# get_current_script - 获取当前正在编辑的脚本
# ============================================================================

func _register_get_current_script(server_core: RefCounted) -> void:
	var tool_name: String = "get_current_script"
	var description: String = "Get the script currently being edited in the Godot script editor. Returns the script path and content."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_found": {"type": "boolean"},
			"script_path": {"type": "string"},
			"content": {"type": "string"},
			"line_count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_current_script"),
						  output_schema, annotations)

func _tool_get_current_script(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"script_found": false, "message": "Editor interface not available"}

	var script_editor: ScriptEditor = editor_interface.get_script_editor()
	if not script_editor:
		return {"script_found": false, "message": "Script editor not available"}

	var current_script: Script = script_editor.get_current_script()
	if not current_script:
		return {"script_found": false, "message": "No script is currently being edited in the script editor"}

	var script_path: String = current_script.resource_path
	if script_path.is_empty():
		return {"script_found": false, "message": "Current script has no file path (may be a built-in script)"}

	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"script_found": false, "message": "Failed to open script file: " + script_path}

	var content: String = file.get_as_text()
	file.close()

	var line_count: int = content.split("\n").size()

	return {
		"script_found": true,
		"script_path": script_path,
		"content": content,
		"line_count": line_count
	}

# ============================================================================
# open_script_at_line - 打开脚本并定位到指定行/列
# ============================================================================

func _register_open_script_at_line(server_core: RefCounted) -> void:
	var tool_name: String = "open_script_at_line"
	var description: String = "Open a script in the Godot script editor and move the caret to a specific line and column."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path to the script file (e.g. 'res://scripts/player.gd')."
			},
			"line": {
				"type": "integer",
				"description": "1-based line number to focus.",
				"default": 1
			},
			"column": {
				"type": "integer",
				"description": "0-based column to focus.",
				"default": 0
			},
			"grab_focus": {
				"type": "boolean",
				"description": "Whether the editor should grab focus. Default is true.",
				"default": true
			}
		},
		"required": ["script_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"script_path": {"type": "string"},
			"line": {"type": "integer"},
			"column": {"type": "integer"},
			"caret_line": {"type": "integer"},
			"caret_column": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_open_script_at_line"),
						  output_schema, annotations)

func _tool_open_script_at_line(params: Dictionary) -> Dictionary:
	var script_path: String = str(params.get("script_path", "")).strip_edges()
	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}

	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd", ".cs"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	script_path = validation["sanitized"]

	if not FileAccess.file_exists(script_path):
		return {"error": "Script file not found: " + script_path}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}

	var script_resource: Script = load(script_path)
	if not script_resource:
		return {"error": "Failed to load script: " + script_path}

	var line: int = max(1, int(params.get("line", 1)))
	var column: int = max(0, int(params.get("column", 0)))
	var grab_focus: bool = params.get("grab_focus", true)

	editor_interface.edit_script(script_resource, line - 1, column, grab_focus)

	var caret_line: int = line - 1
	var caret_column: int = column
	var script_editor: ScriptEditor = editor_interface.get_script_editor()
	if script_editor:
		var current_editor: ScriptEditorBase = script_editor.get_current_editor()
		if current_editor:
			var base_editor: Control = current_editor.get_base_editor()
			if base_editor:
				if base_editor.has_method("set_caret_line"):
					base_editor.call("set_caret_line", line - 1, true, true, -1, 0)
				if base_editor.has_method("set_caret_column"):
					base_editor.call("set_caret_column", column, true, 0)
				if base_editor.has_method("get_caret_line") and base_editor.has_method("get_caret_column"):
					caret_line = int(base_editor.call("get_caret_line"))
					caret_column = int(base_editor.call("get_caret_column"))

	return {
		"status": "success",
		"script_path": script_path,
		"line": line,
		"column": column,
		"caret_line": caret_line + 1,
		"caret_column": caret_column
	}

# ============================================================================
# attach_script - 将脚本附加到节点
# ============================================================================

func _register_attach_script(server_core: RefCounted) -> void:
	var tool_name: String = "attach_script"
	var description: String = "Attach an existing GDScript file to a node in the scene tree."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node to attach the script to (e.g. '/root/MainScene/Player')"
			},
			"script_path": {
				"type": "string",
				"description": "Path to the script file (e.g. 'res://scripts/player.gd')"
			}
		},
		"required": ["node_path", "script_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"node_path": {"type": "string"},
			"script_path": {"type": "string"},
			"previous_script": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
		Callable(self, "_tool_attach_script"),
		output_schema, annotations)

func _tool_attach_script(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var script_path: String = params.get("script_path", "")

	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}

	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
	if not validation["valid"]:
		return {"error": "Invalid script path: " + validation["error"]}
	script_path = validation["sanitized"]

	if not FileAccess.file_exists(script_path):
		return {"error": "Script file not found: " + script_path}

	var target_node: Node = _resolve_node_path(editor_interface, node_path)
	if not target_node:
		return {"error": "Node not found: " + node_path}

	var previous_script: String = ""
	var old_script: Variant = target_node.get_script()
	if old_script and old_script is Script:
		previous_script = old_script.resource_path

	var script_res: Script = load(script_path)
	if not script_res:
		return {"error": "Failed to load script: " + script_path}

	target_node.set_script(script_res)
	editor_interface.get_resource_filesystem().scan()

	return {
		"status": "success",
		"node_path": node_path,
		"script_path": script_path,
		"previous_script": previous_script
	}

# ============================================================================
# validate_script - 验证 GDScript 语法
# ============================================================================

func _register_validate_script(server_core: RefCounted) -> void:
	var tool_name: String = "validate_script"
	var description: String = "Validate GDScript syntax without executing it. Checks for errors and warnings."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path to the script file to validate (e.g. 'res://scripts/player.gd')"
			},
			"content": {
				"type": "string",
				"description": "Optional script content to validate directly (instead of reading from file)"
			},
			"check_warnings": {
				"type": "boolean",
				"description": "Whether to check for warnings. Default is true."
			}
		},
		"required": []
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"valid": {"type": "boolean"},
			"errors": {"type": "array"},
			"warnings": {"type": "array"},
			"error_count": {"type": "integer"},
			"warning_count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
		Callable(self, "_tool_validate_script"),
		output_schema, annotations)

func _tool_validate_script(params: Dictionary) -> Dictionary:
	var script_path: String = params.get("script_path", "")
	var content: String = params.get("content", "")
	var check_warnings: bool = params.get("check_warnings", true)

	if script_path.is_empty() and content.is_empty():
		return {"error": "Must provide either script_path or content"}

	if content.is_empty():
		var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
		if not validation["valid"]:
			return {"error": "Invalid path: " + validation["error"]}
		script_path = validation["sanitized"]

		if not FileAccess.file_exists(script_path):
			return {"error": "Script file not found: " + script_path}

		var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		if not file:
			return {"error": "Failed to open file: " + script_path}
		content = file.get_as_text()
		file.close()

	var validation_content: String = _strip_class_names(content)
	var test_script: GDScript = GDScript.new()
	test_script.source_code = validation_content
	var reload_err: Error = test_script.reload()

	var errors: Array = []
	var warnings: Array = []

	if reload_err != OK:
		var error_msg: String = test_script.get_meta("_error_text", "") if test_script.has_meta("_error_text") else ""
		if error_msg.is_empty():
			var err_lines: PackedStringArray = content.split("\n")
			for i in range(err_lines.size()):
				var line: String = err_lines[i].strip_edges()
				if line.is_empty():
					continue
				if _is_syntax_error_line(line):
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

	if check_warnings and reload_err == OK:
		var source_lines: PackedStringArray = content.split("\n")
		for i in range(source_lines.size()):
			var line: String = source_lines[i].strip_edges()
			if line.begins_with("var ") and not ":" in line and not "=" in line:
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

func _is_syntax_error_line(line: String) -> bool:
	var error_keywords: Array = ["unexpected", "expected", "indent", "mismatched"]
	var line_lower: String = line.to_lower()
	for keyword in error_keywords:
		if keyword in line_lower:
			return true
	return false

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

# ============================================================================
# search_in_files - 在项目文件中搜索内容
# ============================================================================

func _register_search_in_files(server_core: RefCounted) -> void:
	var tool_name: String = "search_in_files"
	var description: String = "Search for text patterns in project files. Supports literal text and regex matching."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"pattern": {
				"type": "string",
				"description": "Search pattern (text or regex)"
			},
			"search_path": {
				"type": "string",
				"description": "Directory to search in. Default is 'res://'."
			},
			"file_extensions": {
				"type": "array",
				"items": {"type": "string"},
				"description": "File extensions to include (e.g. ['.gd', '.tscn']). Default is ['.gd']."
			},
			"use_regex": {
				"type": "boolean",
				"description": "Whether to use regex matching. Default is false (literal match)."
			},
			"case_sensitive": {
				"type": "boolean",
				"description": "Whether the search is case-sensitive. Default is true."
			},
			"max_results": {
				"type": "integer",
				"description": "Maximum number of results to return. Default is 50."
			}
		},
		"required": ["pattern"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"pattern": {"type": "string"},
			"results": {"type": "array"},
			"total_matches": {"type": "integer"},
			"files_searched": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
		Callable(self, "_tool_search_in_files"),
		output_schema, annotations)

func _tool_search_in_files(params: Dictionary) -> Dictionary:
	var pattern: String = params.get("pattern", "")
	var search_path: String = params.get("search_path", "res://")
	var file_extensions: Array = params.get("file_extensions", [".gd"])
	var use_regex: bool = params.get("use_regex", false)
	var case_sensitive: bool = params.get("case_sensitive", true)
	var max_results: int = params.get("max_results", 50)

	if pattern.is_empty():
		return {"error": "Missing required parameter: pattern"}

	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	search_path = validation["sanitized"]

	var regex: RegEx = null
	if use_regex:
		regex = RegEx.new()
		var compile_err: int = regex.compile(pattern)
		if compile_err != OK:
			return {"error": "Invalid regex pattern: " + pattern}

	var state: Dictionary = {
		"results": [],
		"files_searched": 0,
		"total_matches": 0,
		"max_results": max_results
	}

	_search_recursive(search_path, pattern, file_extensions, use_regex,
		case_sensitive, regex, state)

	return {
		"pattern": pattern,
		"results": state["results"],
		"total_matches": state["total_matches"],
		"files_searched": state["files_searched"]
	}

func _search_recursive(
	dir_path: String, pattern: String, extensions: Array,
	use_regex: bool, case_sensitive: bool, regex: RegEx, state: Dictionary
) -> void:
	if state["total_matches"] >= state["max_results"]:
		return

	var dir: DirAccess = DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while not file_name.is_empty():
		if state["total_matches"] >= state["max_results"]:
			break

		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path: String = dir_path.path_join(file_name)

		if dir.current_is_dir():
			_search_recursive(full_path, pattern, extensions, use_regex,
				case_sensitive, regex, state)
		else:
			var ext_match: bool = extensions.is_empty()
			for ext in extensions:
				if file_name.ends_with(ext):
					ext_match = true
					break

			if ext_match:
				state["files_searched"] = int(state["files_searched"]) + 1
				_search_file(full_path, pattern, use_regex, case_sensitive, regex, state)

		file_name = dir.get_next()

	dir.list_dir_end()

func _search_file(
	file_path: String, pattern: String, use_regex: bool,
	case_sensitive: bool, regex: RegEx, state: Dictionary
) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var line_number: int = 0
	var file_matches: Array = []

	while not file.eof_reached() and state["total_matches"] < state["max_results"]:
		var line: String = file.get_line()
		line_number += 1

		var found: bool = false
		var match_text: String = ""

		if use_regex and regex:
			var match_result: RegExMatch = regex.search(line)
			if match_result:
				found = true
				match_text = match_result.get_string()
		else:
			var search_line: String = line if case_sensitive else line.to_lower()
			var search_pattern: String = pattern if case_sensitive else pattern.to_lower()
			var pos: int = search_line.find(search_pattern)
			if pos >= 0:
				found = true
				match_text = line.strip_edges()

		if found:
			file_matches.append({
				"line": line_number,
				"text": match_text
			})
			state["total_matches"] = int(state["total_matches"]) + 1

	file.close()

	if not file_matches.is_empty():
		state["results"].append({
			"file": file_path,
			"matches": file_matches,
			"match_count": file_matches.size()
		})
