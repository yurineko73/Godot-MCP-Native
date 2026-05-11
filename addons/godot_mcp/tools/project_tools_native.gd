# project_tools_native.gd - нативная реализация инструментов проекта

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
# Регистрация инструментов
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	_register_get_project_info(server_core)
	_register_get_project_settings(server_core)
	_register_list_project_resources(server_core)
	_register_create_resource(server_core)
	_register_get_project_structure(server_core)

# ============================================================================
# get_project_info - получение информации о проекте
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
	
	# Регистрация инструмента
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
# get_project_settings - получение настроек проекта
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
	
	# Регистрация инструмента
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
# list_project_resources - список ресурсов проекта
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
	
	# Регистрация инструмента
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_list_project_resources"),
						  output_schema, annotations)

func _tool_list_project_resources(params: Dictionary) -> Dictionary:
	# Извлечение параметров
	var search_path: String = params.get("search_path", "res://")
	var resource_types: Array = params.get("resource_types", [])
	
	# Проверка безопасности пути через PathValidator
	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# Использование очищенного пути
	search_path = validation["sanitized"]
	
	# Стандартные расширения ресурсов
	var default_extensions: Array[String] = [
		".tres", ".res", ".otr", ".font", ".theme",
		".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp", ".hdr",
		".ogg", ".wav", ".mp3", ".oggstr",
		".obj", ".glb", ".gltf", ".mesh", ".fbx",
		".material", ".shader", ".gdshader",
		".tscn", ".gd", ".cfg", ".json",
		".ttf", ".otf", ".woff", ".woff2"
	]
	
	# Если передан resource_types, используем его, иначе - список по умолчанию
	var extensions: Array[String] = []
	if resource_types.size() > 0:
		for ext in resource_types:
			var ext_str: String = str(ext)
			if not ext_str.begins_with("."):
				ext_str = "." + ext_str
			extensions.append(ext_str)
	else:
		extensions = default_extensions
	
	# Рекурсивный поиск файлов ресурсов через DirAccess
	var resources: Array[String] = []
	_collect_resources(search_path, extensions, resources)
	
	# Сортировка
	resources.sort()
	
	return {
		"resources": resources,
		"count": resources.size()
	}

# Вспомогательная функция: рекурсивный сбор файлов ресурсов
func _collect_resources(directory_path: String, extensions: Array[String], result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(directory_path)
	
	if not dir:
		return
	
	# Перебор всех файлов и каталогов
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while not file_name.is_empty():
		# Пропуск специальных каталогов
		if file_name != "." and file_name != "..":
			var full_path: String = directory_path
			if not full_path.ends_with("/"):
				full_path += "/"
			full_path += file_name
			
			if dir.current_is_dir():
				# Рекурсивная обработка подкаталогов
				_collect_resources(full_path, extensions, result)
			else:
				# Проверка расширения файла
				for ext in extensions:
					if file_name.ends_with(ext):
						result.append(full_path)
						break
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

# ============================================================================
# create_resource - создание ресурса
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
	
	# Регистрация инструмента
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_create_resource"),
						  output_schema, annotations)

func _tool_create_resource(params: Dictionary) -> Dictionary:
	# Извлечение параметров
	var resource_path: String = params.get("resource_path", "")
	var resource_type: String = params.get("resource_type", "")
	var properties: Dictionary = params.get("properties", {})
	
	# Проверка параметров
	if resource_path.is_empty():
		return {"error": "Missing required parameter: resource_path"}
	if resource_type.is_empty():
		return {"error": "Missing required parameter: resource_type"}
	
	# Проверка безопасности пути через PathValidator
	var validation: Dictionary = PathValidator.validate_file_path(resource_path, [".tres", ".res"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# Использование очищенного пути
	resource_path = validation["sanitized"]
	
	# Проверка типа ресурса
	if not ClassDB.class_exists(resource_type):
		return {"error": "Invalid resource type: " + resource_type}
	
	if not ClassDB.is_parent_class(resource_type, "Resource"):
		return {"error": "Type '%s' is not a Resource type" % resource_type}
	
	# Создание экземпляра ресурса
	var resource: RefCounted = ClassDB.instantiate(resource_type)
	
	if not resource:
		return {"error": "Failed to create resource of type: " + resource_type}
	
	# Установка свойств (если переданы)
	for prop_name in properties:
		if prop_name in resource:
			resource.set(prop_name, properties[prop_name])
	
	# Сохранение ресурса
	var error: Error = ResourceSaver.save(resource, resource_path)
	
	if error != OK:
		return {"error": "Failed to save resource: " + error_string(error)}
	
	return {
		"status": "success",
		"resource_path": resource_path,
		"resource_type": resource_type
	}

# ============================================================================
# get_project_structure - получение структуры каталогов проекта
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
