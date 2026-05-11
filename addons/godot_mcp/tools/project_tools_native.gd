# project_tools_native.gd - Project Tools原生实现

@tool
class_name ProjectToolsNative
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
	_register_get_project_info(server_core)
	_register_get_project_settings(server_core)
	_register_list_project_autoloads(server_core)
	_register_list_project_global_classes(server_core)
	_register_list_project_resources(server_core)
	_register_create_resource(server_core)
	_register_get_project_structure(server_core)
	_register_reimport_resources(server_core)
	_register_get_import_metadata(server_core)
	_register_get_resource_uid_info(server_core)
	_register_fix_resource_uid(server_core)
	_register_get_resource_dependencies(server_core)
	_register_scan_missing_resource_dependencies(server_core)
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
						  output_schema, annotations)

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
						  output_schema, annotations)

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
						  output_schema, annotations)

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
						  output_schema, annotations)

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
						  Callable(self, "_tool_list_project_resources"),
						  output_schema, annotations)

func _tool_list_project_resources(params: Dictionary) -> Dictionary:
	# 参数提取
	var search_path: String = params.get("search_path", "res://")
	var resource_types: Array = params.get("resource_types", [])
	
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
	
	return {
		"resources": resources,
		"count": resources.size()
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
						  output_schema, annotations)

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
						  output_schema, annotations)

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
						  output_schema, annotations)

func _tool_reimport_resources(params: Dictionary) -> Dictionary:
	var raw_paths: Array = params.get("resource_paths", [])
	if raw_paths.is_empty():
		return {"error": "Missing required parameter: resource_paths"}

	var refresh_metadata: bool = params.get("refresh_metadata", true)
	var editor_interface: EditorInterface = _get_editor_interface()
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
						  output_schema, annotations)

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
						  output_schema, annotations)

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
						  output_schema, annotations)

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

	var editor_interface: EditorInterface = _get_editor_interface()
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
						  output_schema, annotations)

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
			"issues": {"type": "array"}
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
						  output_schema, annotations)

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

	var issues: Array = []
	for resource_path in resources:
		var dependencies: Array = _parse_resource_dependencies(resource_path)
		for dependency in dependencies:
			if bool(dependency.get("missing", false)):
				issues.append({
					"owner_path": resource_path,
					"dependency": dependency
				})
				if issues.size() >= max_results:
					return {
						"search_path": search_path,
						"scanned_resources": resources.size(),
						"issue_count": issues.size(),
						"issues": issues,
						"truncated": true
					}

	return {
		"search_path": search_path,
		"scanned_resources": resources.size(),
		"issue_count": issues.size(),
		"issues": issues,
		"truncated": false
	}

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
			"issues": {"type": "array"}
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
						  output_schema, annotations)

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

	var issues: Array = []
	var broken_count: int = 0
	var warning_count: int = 0

	for script_path in scripts:
		var diagnostics: Dictionary = _analyze_script_diagnostics(script_path, include_warnings)
		if diagnostics.has("error"):
			issues.append({
				"script_path": script_path,
				"severity": "error",
				"errors": [{"line": 0, "column": 0, "message": str(diagnostics["error"])}],
				"warnings": []
			})
			broken_count += 1
		else:
			var has_errors: bool = int(diagnostics.get("error_count", 0)) > 0
			var has_warnings: bool = int(diagnostics.get("warning_count", 0)) > 0
			if has_errors or has_warnings:
				issues.append({
					"script_path": script_path,
					"severity": "error" if has_errors else "warning",
					"errors": diagnostics.get("errors", []),
					"warnings": diagnostics.get("warnings", [])
				})
				if has_errors:
					broken_count += 1
				if has_warnings:
					warning_count += 1

		if issues.size() >= max_results:
			break

	return {
		"search_path": search_path,
		"scanned_scripts": scripts.size(),
		"broken_count": broken_count,
		"warning_count": warning_count,
		"issues": issues,
		"truncated": issues.size() >= max_results and scripts.size() > issues.size()
	}

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
			"missing_dependencies": {"type": "array"}
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
						  output_schema, annotations)

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

	var summary: Dictionary = {
		"scanned_scripts": int(broken_scripts_result.get("scanned_scripts", 0)),
		"broken_scripts": int(broken_scripts_result.get("broken_count", 0)),
		"script_warnings": int(broken_scripts_result.get("warning_count", 0)),
		"scanned_resources": int(missing_dependencies_result.get("scanned_resources", 0)),
		"missing_dependencies": int(missing_dependencies_result.get("issue_count", 0))
	}
	var hard_failures: int = summary["broken_scripts"] + summary["missing_dependencies"]
	var status: String = "healthy"
	if hard_failures > 0:
		status = "failing"
	elif summary["script_warnings"] > 0:
		status = "warning"

	return {
		"status": status,
		"search_path": broken_scripts_result.get("search_path", search_path),
		"summary": summary,
		"broken_scripts": broken_scripts_result.get("issues", []),
		"missing_dependencies": missing_dependencies_result.get("issues", []),
		"truncated": bool(broken_scripts_result.get("truncated", false)) or bool(missing_dependencies_result.get("truncated", false))
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

func _compare_autoload_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = int(left.get("order", 0))
	var right_order: int = int(right.get("order", 0))
	if left_order == right_order:
		return str(left.get("name", "")) < str(right.get("name", ""))
	return left_order < right_order

func _compare_global_class_entries(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("name", "")) < str(right.get("name", ""))
