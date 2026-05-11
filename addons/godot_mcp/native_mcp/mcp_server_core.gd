# mcp_server_core.gd - основная реализация MCP-сервера
# Объединяет транспортный слой, обработку протокола, регистрацию инструментов и управление ресурсами
# Добавлены полные подсказки типов (по godot-dev-guide)
# Добавлена поддержка outputSchema и annotations (по mcp-builder)

class_name MCPServerCore
extends RefCounted

# ============================================================================
# Перечисление типов транспорта
# ============================================================================

enum TransportType {
	TRANSPORT_STDIO,    # транспорт stdio (по умолчанию)
	TRANSPORT_HTTP      # транспорт HTTP
}

# ============================================================================
# Определение сигналов (развязка через сигналы по godot-dev-guide)
# ============================================================================

signal server_started
signal server_stopped
signal message_received(message: Dictionary)
signal response_sent(response: Dictionary)
signal tool_execution_started(tool_name: String, params: Dictionary)
signal tool_execution_completed(tool_name: String, result: Dictionary)
signal tool_execution_failed(tool_name: String, error: String)
signal resource_requested(resource_uri: String, params: Dictionary)
signal resource_loaded(resource_uri: String, content: Dictionary)
signal log_message(level: String, message: String)

# ============================================================================
# Константы
# ============================================================================

const JSONRPC_VERSION: String = "2.0"
const PROTOCOL_VERSION: String = "2025-11-25"

# ============================================================================
# Переменные состояния (полные подсказки типов по godot-dev-guide)
# ============================================================================

var _active: bool = false
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()

# Переменные, связанные с транспортом (добавлено - поддержка нескольких транспортов)
var _transport_type: TransportType = TransportType.TRANSPORT_STDIO
var _transport: McpTransportBase = null  # Экземпляр транспортного слоя (тип базового класса)
var _auth_manager: McpAuthManager = null  # Менеджер аутентификации (для режима HTTP)
var _http_port: int = 9080  # Порт прослушивания HTTP

# Очереди сообщений (типизированные массивы по godot-dev-guide)
var _message_queue: Array[Dictionary] = []
var _response_queue: Array[Dictionary] = []

# Реестр инструментов и ресурсов
var _tools: Dictionary = {}  # String -> MCPTool
var _resources: Dictionary = {}  # String -> MCPResource
var _prompts: Dictionary = {}  # String -> MCPPrompt

# Конфигурация
var _log_level: int = MCPTypes.LogLevel.INFO
var _security_level: int = MCPTypes.SecurityLevel.STRICT
var _rate_limit: int = 100  # Не более 100 запросов за 60 секунд

# Отслеживание лимита запросов
var _request_count: Dictionary = {}  # String (client_id) -> int
var _request_timestamps: Dictionary = {}  # String (client_id) -> Array[int]

# Кэш
var _scene_structure_cache: Dictionary = {}  # String -> Dictionary
var _cache_timestamp: Dictionary = {}  # String -> int

# Экземпляр JSONRPC (если нужен встроенный обработчик Godot, можно раскомментировать)
# var _jsonrpc: JSONRPC = JSONRPC.new()

# ============================================================================
# Методы интерфейса транспортного слоя (добавлено - поддержка разных транспортов)
# ============================================================================

## Установить тип транспорта (вызывать до старта сервера)
## @param type: TransportType - перечисление типов транспорта
func set_transport_type(type: TransportType) -> void:
	if _active:
		_log_error("Cannot change transport type while server is running")
		return
	_transport_type = type
	_log_info("Transport type set to: " + str(_transport_type))

## Установить менеджер аутентификации (режим HTTP)
## @param manager: McpAuthManager - экземпляр менеджера аутентификации
func set_auth_manager(manager: McpAuthManager) -> void:
	_auth_manager = manager
	_log_info("Auth manager set")

## Установить HTTP-порт (режим HTTP, вызывать до старта сервера)
## @param port: int - номер порта прослушивания
func set_http_port(port: int) -> void:
	if _transport and _transport.has_method("set_port"):
		_transport.set_port(port)
	_http_port = port
	_log_info("HTTP port set to: " + str(port))

func set_sse_enabled(enabled: bool) -> void:
	if _transport and _transport.has_method("set_sse_enabled"):
		_transport.set_sse_enabled(enabled)
	_log_info("SSE enabled: " + str(enabled))

func set_remote_config(allow_remote: bool, cors_origin: String) -> void:
	if _transport and _transport.has_method("set_remote_config"):
		_transport.set_remote_config(allow_remote, cors_origin)
	_log_info("Remote config - allow: " + str(allow_remote) + ", CORS: " + cors_origin)

## Инициализировать транспортный слой (создаёт экземпляр по _transport_type)
## @returns: bool - true при успешной инициализации, иначе false
func _init_transport() -> bool:
	match _transport_type:
		TransportType.TRANSPORT_STDIO:
			_transport = McpStdioServer.new()
			if _transport.has_method("set_log_callback"):
				_transport.set_log_callback(_log_transport_message)
			_log_info("Initialized stdio transport")
		
		TransportType.TRANSPORT_HTTP:
			_transport = McpHttpServer.new()
			_transport.set_port(_http_port)
			if _auth_manager:
				_transport.set_auth_manager(_auth_manager)
			if _transport.has_method("set_log_callback"):
				_transport.set_log_callback(_log_transport_message)
			_log_info("Initialized HTTP transport on port " + str(_http_port))
		
		_:
			_log_error("Unknown transport type: " + str(_transport_type))
			return false
	
	# Подключение сигналов (для потокобезопасности)
	_transport.message_received.connect(_on_transport_message_received)
	_transport.server_error.connect(_on_transport_error)
	_transport.server_started.connect(_on_transport_started)
	_transport.server_stopped.connect(_on_transport_stopped)
	
	_log_info("Transport layer initialized: " + str(_transport_type))
	return true

## Обработка сообщения от транспортного слоя (потокобезопасно: выполняется в главном потоке)
## @param message: Dictionary - сообщение JSON-RPC
## @param context: Variant - транспортный контекст (stdio: null, HTTP: StreamPeerTCP)
func _on_transport_message_received(message: Dictionary, context: Variant) -> void:
	# Проверка формата сообщения
	if not message.has("jsonrpc"):
		_send_error(null, MCPTypes.ERROR_INVALID_REQUEST, 
				   "Missing 'jsonrpc' field. Please ensure the message is a valid JSON-RPC 2.0 message.")
		return
	
	if message["jsonrpc"] != JSONRPC_VERSION:
		_send_error(message.get("id"), MCPTypes.ERROR_INVALID_REQUEST, 
				   "Invalid JSON-RPC version. Expected '2.0', got: " + str(message["jsonrpc"]))
		return
	
	# Логирование полученного сообщения
	message_received.emit(message)
	_log_debug("Received message: " + JSON.stringify(message))
	
	# Обработка запроса
	var response: Dictionary = {}
	
	if message.has("method"):
		# Это запрос или уведомление
		response = _handle_request(message)
	else:
		# Это ответ (обычно не требует обработки)
		_log_warn("Received unexpected response message: " + JSON.stringify(message))
		return
	
	# Отправка ответа (если есть)
	if response:
		_send_response(response, context)

## Обработка ошибки транспортного слоя
## @param error: String - описание ошибки
func _on_transport_error(error: String) -> void:
	_log_error("Transport error: " + error)

## Обработка запуска транспортного слоя
func _on_transport_started() -> void:
	_log_info("Transport layer started")
	server_started.emit()

## Обработка остановки транспортного слоя
func _on_transport_stopped() -> void:
	_log_info("Transport layer stopped")
	server_stopped.emit()


# ============================================================================
# Методы жизненного цикла
# ============================================================================

func start() -> bool:
	if _active:
		_log_warn("Server already running")
		return false
	
	_log_info("Starting MCP Server (transport: " + str(_transport_type) + ")...")
	
	# Инициализация транспортного слоя
	if not _init_transport():
		_log_error("Failed to initialize transport layer")
		return false
	
	# Запуск транспортного слоя
	var success: bool = _transport.start()
	
	if not success:
		_log_error("Failed to start transport layer")
		return false
	
	_active = true
	_log_info("MCP Server started successfully (transport: " + str(_transport_type) + ")")
	
	return true

func stop() -> void:
	if not _active:
		return
	
	_log_info("Stopping MCP Server...")
	
	# Остановка транспортного слоя
	if _transport:
		_transport.stop()
		_transport = null
	
	_active = false
	_log_info("MCP Server stopped")

func is_running() -> bool:
	if _transport:
		return _transport.is_running()
	return false

# ============================================================================
# Обработка запросов (оптимизация по mcp-builder)
# ============================================================================

func _handle_request(message: Dictionary) -> Dictionary:
	var method: String = message.get("method", "")
	var id: Variant = message.get("id", null)
	var params: Dictionary = message.get("params", {})
	
	# Проверка лимита запросов
	if not _check_rate_limit("default"):
		return MCPTypes.create_error_response(id, MCPTypes.ERROR_INTERNAL_ERROR, "Rate limit exceeded")
	
	match method:
		MCPTypes.METHOD_INITIALIZE:
			return _handle_initialize(message)
		
		MCPTypes.METHOD_NOTIFICATIONS_INITIALIZED:
			return _handle_initialized_notification(message)
		
		MCPTypes.METHOD_TOOLS_LIST:
			return _handle_tools_list(message)
		
		MCPTypes.METHOD_TOOLS_CALL:
			return _handle_tool_call(message)
		
		MCPTypes.METHOD_RESOURCES_LIST:
			return _handle_resources_list(message)
		
		MCPTypes.METHOD_RESOURCES_READ:
			return _handle_resource_read(message)
		
		MCPTypes.METHOD_RESOURCES_SUBSCRIBE:
			return _handle_resource_subscribe(message)
		
		MCPTypes.METHOD_PROMPTS_LIST:
			return _handle_prompts_list(message)
		
		MCPTypes.METHOD_PROMPTS_GET:
			return _handle_prompt_get(message)
		
		_:
			_log_warn("Method not found: " + method)
			return MCPTypes.create_error_response(id, MCPTypes.ERROR_METHOD_NOT_FOUND, "Method not found: " + method)

# ============================================================================
# Реализация методов MCP-протокола (полная версия по mcp-builder)
# ============================================================================

func _handle_initialize(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var client_capabilities: Dictionary = params.get("capabilities", {})
	var client_protocol_version: String = params.get("protocolVersion", PROTOCOL_VERSION)
	
	_log_info("Initialize request from client. Protocol: " + client_protocol_version)
	_log_debug("Client capabilities: " + JSON.stringify(client_capabilities))
	
	var negotiated_version: String = _negotiate_protocol_version(client_protocol_version)
	
	var result: Dictionary = {
		"protocolVersion": negotiated_version,
		"capabilities": MCPTypes.create_capabilities(true, true, true, true),
		"serverInfo": {
			"name": "godot-native-mcp",
			"version": "2.0.0"
		}
	}
	
	var response: Dictionary = MCPTypes.create_response(id, result)
	_log_debug("Initialize response: " + JSON.stringify(response))
	
	return response

func _negotiate_protocol_version(client_version: String) -> String:
	var supported_versions: PackedStringArray = [
		"2025-11-25",
		"2025-06-18",
		"2025-03-26",
		"2024-11-05",
	]
	
	if client_version in supported_versions:
		return client_version
	
	for version in supported_versions:
		if version == PROTOCOL_VERSION:
			return version
	
	return supported_versions[0]

func _handle_initialized_notification(message: Dictionary) -> Dictionary:
	_log_info("Client initialized notification received")
	# Это уведомление, ответ не требуется
	return {}

func _handle_tools_list(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	
	# Формирование списка инструментов (по mcp-builder, включая annotations и outputSchema)
	var tools_list: Array[Dictionary] = []
	
	for tool_name in _tools:
		var tool: MCPTypes.MCPTool = _tools[tool_name]
		if tool and tool.is_valid() and tool.enabled:
			tools_list.append(tool.to_dict())
	
	var result: Dictionary = {"tools": tools_list}
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	_log_info("Tools list requested. Available tools: " + str(tools_list.size()) + " (registered: " + str(_tools.size()) + ")")
	
	_log_debug("Tools list response: " + JSON.stringify(response))
	
	return response

func _handle_tool_call(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var tool_name: String = params.get("name", "")
	var arguments: Dictionary = params.get("arguments", {})
	
	_log_info("Tool call: " + tool_name)
	_log_debug("Tool arguments: " + JSON.stringify(arguments))
	
	# Проверка существования инструмента
	if not _tools.has(tool_name):
		_log_error("Tool not found: " + tool_name)
		var error_result: Dictionary = {
			"content": [{
				"type": "text",
				"text": "Tool not found: " + tool_name
			}],
			"isError": true
		}
		return MCPTypes.create_response(id, error_result)
	
	var tool: MCPTypes.MCPTool = _tools[tool_name]
	
	if not tool.enabled:
		_log_error("Tool is disabled: " + tool_name)
		var error_result: Dictionary = {
			"content": [{
				"type": "text",
				"text": "Tool is disabled: " + tool_name
			}],
			"isError": true
		}
		return MCPTypes.create_response(id, error_result)
	
	# Отправка сигнала начала выполнения
	tool_execution_started.emit(tool_name, arguments)
	
	# Выполнение инструмента
	var result: Variant = null
	var error: String = ""
	
	if tool.callable.is_valid():
		# Вызов инструмента через Callable
		var status: Error = OK
		
		# Обработка ошибок выполнения
		if status == OK:
			result = tool.callable.call(arguments)
		else:
			error = "Tool execution failed with error: " + str(status)
	
	# Обработка результата выполнения
	if not error.is_empty():
		_log_error("Tool execution failed: " + tool_name + " - " + error)
		tool_execution_failed.emit(tool_name, error)
		var error_result: Dictionary = {
			"content": [{
				"type": "text",
				"text": error
			}],
			"isError": true
		}
		return MCPTypes.create_response(id, error_result)
	
	var has_error: bool = result is Dictionary and result.has("error")

	var response_result: Dictionary = {
		"content": [{
			"type": "text",
			"text": JSON.stringify(result)
		}],
		"isError": has_error
	}

	if not has_error and tool.output_schema.size() > 0:
		response_result["structuredContent"] = result
	
	var response: Dictionary = MCPTypes.create_response(id, response_result)
	
	_append_tool_log(tool_name, result, error)
	
	# Отправка сигнала завершения
	tool_execution_completed.emit(tool_name, result)
	_log_info("Tool execution completed: " + tool_name)
	
	return response

func _handle_resources_list(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	
	_log_info("Resources list requested. Available resources: " + str(_resources.size()))
	
	# Формирование списка ресурсов (по mcp-builder, включая description)
	var resources_list: Array[Dictionary] = []
	
	for uri in _resources:
		var resource: MCPTypes.MCPResource = _resources[uri]
		if resource and resource.is_valid():
			resources_list.append(resource.to_dict())
	
	var result: Dictionary = {"resources": resources_list}
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	_log_debug("Resources list response: " + JSON.stringify(response))
	
	return response

func _handle_resource_read(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var uri: String = params.get("uri", "")
	
	_log_info("Resource read: " + uri)
	
	# Проверка существования ресурса
	if not _resources.has(uri):
		_log_error("Resource not found: " + uri)
		return MCPTypes.create_error_response(id, MCPTypes.ERROR_RESOURCE_NOT_FOUND, "Resource not found: " + uri)
	
	var resource: MCPTypes.MCPResource = _resources[uri]
	
	resource_requested.emit(uri, params)
	
	var content: Dictionary = {}
	
	if resource.load_callable.is_valid():
		content = resource.load_callable.call(params)
	
	var result: Dictionary = {}
	
	if content.has("contents"):
		result = content
	else:
		result = {
			"contents": [{
				"uri": uri,
				"mimeType": resource.mime_type,
				"text": content.get("text", JSON.stringify(content))
			}]
		}
	
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	# Отправка сигнала загрузки ресурса
	resource_loaded.emit(uri, content)
	_log_info("Resource loaded: " + uri)
	
	return response

func _handle_resource_subscribe(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var uri: String = params.get("uri", "")
	
	_log_info("Resource subscribe: " + uri)
	
	# TODO: Реализовать логику подписки на ресурс
	var result: Dictionary = {"subscriptionId": MCPTypes.generate_id()}
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	return response

func _handle_prompts_list(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	
	_log_info("Prompts list requested")
	
	var prompts_list: Array[Dictionary] = []
	
	for prompt_name in _prompts:
		var prompt: MCPTypes.MCPPrompt = _prompts[prompt_name]
		if prompt and prompt.is_valid():
			prompts_list.append(prompt.to_dict())
	
	var result: Dictionary = {"prompts": prompts_list}
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	return response

func _handle_prompt_get(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var prompt_name: String = params.get("name", "")
	
	_log_info("Prompt get: " + prompt_name)
	
	# TODO: Реализовать логику получения prompt
	var result: Dictionary = {
		"description": "Prompt: " + prompt_name,
		"messages": []
	}
	
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	return response

# ============================================================================
# API регистрации инструментов (оптимизировано по mcp-builder)
# ============================================================================

func register_tool(name: String, description: String, 
				  input_schema: Dictionary, callable: Callable,
				  output_schema: Dictionary = {}, 
				  annotations: Dictionary = {}) -> void:
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = name
	tool.description = description
	tool.input_schema = input_schema
	tool.output_schema = output_schema
	tool.annotations = annotations
	tool.callable = callable
	
	if not tool.is_valid():
		var reason: String = "unknown"
		if name.is_empty():
			reason = "name is empty"
		elif description.is_empty():
			reason = "description is empty"
		elif not callable.is_valid():
			reason = "callable is invalid (method may not exist or object is freed)"
		_log_error("Invalid tool definition: " + name + " (reason: " + reason + ")")
		printerr("[MCP][DIAG] Tool '%s' rejected: callable.is_valid()=%s, callable=%s" % [name, str(callable.is_valid()), str(callable)])
		return
	
	_tools[name] = tool
	_log_info("Tool registered: " + name)

func unregister_tool(name: String) -> void:
	if _tools.has(name):
		_tools.erase(name)
		_log_info("Tool unregistered: " + name)

func get_tool(name: String) -> MCPTypes.MCPTool:
	return _tools.get(name, null)

func get_all_tools() -> Dictionary:
	return _tools.duplicate()

func get_tools_count() -> int:
	return _tools.size()

func get_resources_count() -> int:
	return _resources.size()

func get_registered_tools() -> Array:
	var tools_info: Array = []
	for tool_name in _tools:
		var tool: MCPTypes.MCPTool = _tools[tool_name]
		if tool and tool.is_valid():
			tools_info.append({
				"name": tool.name,
				"description": tool.description,
				"enabled": tool.enabled
			})
	return tools_info

func set_tool_enabled(tool_name: String, enabled: bool) -> void:
	if _tools.has(tool_name):
		_tools[tool_name].enabled = enabled
		if enabled:
			_log_info("Tool enabled: " + tool_name)
		else:
			_log_info("Tool disabled: " + tool_name)
	else:
		if enabled:
			_log_warn("Cannot enable unregistered tool: " + tool_name)

func has_tool(name: String) -> bool:
	return _tools.has(name)

# ============================================================================
# API регистрации ресурсов (оптимизировано по mcp-builder)
# ============================================================================

func register_resource(uri: String, name: String, 
					  mime_type: String, load_callable: Callable,
					  description: String = "") -> void:  # Добавлен параметр description
	# Создание объекта ресурса
	var resource: MCPTypes.MCPResource = MCPTypes.MCPResource.new()
	resource.uri = uri
	resource.name = name
	resource.description = description  # Добавлено по mcp-builder
	resource.mime_type = mime_type
	resource.load_callable = load_callable
	
	# Проверка определения ресурса
	if not resource.is_valid():
		_log_error("Invalid resource definition: " + uri)
		return
	
	_resources[uri] = resource
	_log_info("Resource registered: " + uri)

func unregister_resource(uri: String) -> void:
	if _resources.has(uri):
		_resources.erase(uri)
		_log_info("Resource unregistered: " + uri)

func get_resource(uri: String) -> MCPTypes.MCPResource:
	return _resources.get(uri, null)

func get_all_resources() -> Dictionary:
	return _resources.duplicate()

# ============================================================================
# API регистрации Prompt
# ============================================================================

func register_prompt(name: String, description: String, 
					 arguments: Array[Dictionary], 
					 get_callable: Callable) -> void:
	var prompt: MCPTypes.MCPPrompt = MCPTypes.MCPPrompt.new()
	prompt.name = name
	prompt.description = description
	prompt.arguments = arguments
	
	_prompts[name] = prompt
	_log_info("Prompt registered: " + name)

# ============================================================================
# Отправка ответов
# ============================================================================

func _send_response(response: Dictionary, context: Variant = null) -> void:
	var json_string: String = JSON.stringify(response)
	
	if _transport_type == TransportType.TRANSPORT_STDIO:
		print(json_string)
	elif _transport_type == TransportType.TRANSPORT_HTTP:
		_transport.send_response(response, context)
	
	response_sent.emit(response)

func _send_error(id: Variant, code: int, message: String, data: Variant = null) -> void:
	var error_response: Dictionary = MCPTypes.create_error_response(id, code, message, data)
	_send_response(error_response)

# ============================================================================
# Ограничение частоты запросов (best practices безопасности mcp-builder)
# ============================================================================

func _check_rate_limit(client_id: String) -> bool:
	var current_time: int = Time.get_unix_time_from_system()
	
	if not _request_timestamps.has(client_id):
		var new_timestamps: Array[int] = []
		_request_timestamps[client_id] = new_timestamps
		_request_count[client_id] = 0
	
	var timestamps: Array[int] = _request_timestamps[client_id]
	
	# Удаление записей старше 60 секунд
	while not timestamps.is_empty() and current_time - timestamps[0] > 60:
		timestamps.pop_front()
		_request_count[client_id] -= 1
	
	# Проверка превышения лимита
	if _request_count[client_id] >= _rate_limit:
		_log_warn("Rate limit exceeded for client: " + client_id)
		return false
	
	# Добавление новой записи
	timestamps.append(current_time)
	_request_count[client_id] += 1
	
	return true

# ============================================================================
# Механизм кэширования (добавлено по godot-dev-guide)
# ============================================================================

func get_cached_scene_structure(scene_path: String) -> Dictionary:
	var cache_key: String = scene_path
	var current_time: int = Time.get_unix_time_from_system()
	
	# Проверка актуальности кэша (TTL: 5 минут)
	if _scene_structure_cache.has(cache_key):
		var cache_time: int = _cache_timestamp.get(cache_key, 0)
		if current_time - cache_time < 300:  # 5 минут
			_log_debug("Cache hit: " + scene_path)
			return _scene_structure_cache[cache_key]
	
	# Кэш не найден или устарел
	_log_debug("Cache miss: " + scene_path)
	return {}

func set_cached_scene_structure(scene_path: String, structure: Dictionary) -> void:
	var cache_key: String = scene_path
	var current_time: int = Time.get_unix_time_from_system()
	
	_scene_structure_cache[cache_key] = structure
	_cache_timestamp[cache_key] = current_time
	
	_log_debug("Cache set: " + scene_path)

func clear_cache() -> void:
	_scene_structure_cache.clear()
	_cache_timestamp.clear()
	_log_info("Cache cleared")

# ============================================================================
# Методы конфигурации
# ============================================================================

func set_log_level(level: int) -> void:
	_log_level = level
	_log_info("Log level set to: " + str(level))

func set_security_level(level: int) -> void:
	_security_level = level
	_log_info("Security level set to: " + str(level))

func set_rate_limit(limit: int) -> void:
	_rate_limit = limit
	_log_info("Rate limit set to: " + str(limit) + " requests/minute")

# ============================================================================
# Методы логирования (оптимизировано по godot-dev-guide)
# ============================================================================

func _log_error(message: String) -> void:
	if _log_level >= MCPTypes.LogLevel.ERROR:
		call_deferred("emit_signal", "log_message", "ERROR", message)

func _log_warn(message: String) -> void:
	if _log_level >= MCPTypes.LogLevel.WARN:
		call_deferred("emit_signal", "log_message", "WARN", message)

func _log_info(message: String) -> void:
	if _log_level >= MCPTypes.LogLevel.INFO:
		call_deferred("emit_signal", "log_message", "INFO", message)

func _log_debug(message: String) -> void:
	if _log_level >= MCPTypes.LogLevel.DEBUG:
		call_deferred("emit_signal", "log_message", "DEBUG", message)

# ============================================================================
# Очистка
# ============================================================================

func cleanup() -> void:
	stop()

# ============================================================================
# Журнал вызовов инструментов (для пакетной валидации)
# ============================================================================

var _tool_log_path: String = "user://mcp_tool_verification_log.json"

func clear_tool_log() -> void:
	var file: FileAccess = FileAccess.open(_tool_log_path, FileAccess.WRITE)
	if file:
		file.store_string("[]")
		file.close()


# ============================================================================
# Проброс логов транспортного слоя
# ============================================================================

## Колбэк логов транспорта, заменяет printerr выводом через систему логов ядра
## @param level: String - уровень логирования (ERROR/WARN/INFO/DEBUG)
## @param message: String - сообщение лога
func _log_transport_message(level: String, message: String) -> void:
	match level:
		"ERROR":
			_log_error(message)
		"WARN":
			_log_warn(message)
		"INFO":
			_log_info(message)
		"DEBUG":
			_log_debug(message)
		_:
			_log_info(message)

func _append_tool_log(tool_name: String, result: Variant, error: String) -> void:
	var log_entry: Dictionary = {
		"tool": tool_name,
		"timestamp": Time.get_unix_time_from_system(),
		"error": error,
		"result_type": str(typeof(result))
	}
	if result is Dictionary:
		if result.has("error"):
			log_entry["status"] = "error"
			log_entry["error_detail"] = str(result["error"])
		elif result.has("status"):
			log_entry["status"] = str(result["status"])
		else:
			log_entry["status"] = "ok"
		var result_keys: Array = result.keys()
		log_entry["result_keys"] = result_keys
		for key in result_keys:
			var val: Variant = result[key]
			if val is Array:
				log_entry["result_" + key + "_count"] = val.size()
			elif val is Dictionary:
				log_entry["result_" + key + "_keys"] = val.keys()
			else:
				var val_str: String = str(val)
				if val_str.length() > 200:
					val_str = val_str.substr(0, 200)
				log_entry["result_" + key] = val_str
	else:
		log_entry["status"] = "ok"
		var preview: String = str(result)
		if preview.length() > 200:
			preview = preview.substr(0, 200)
		log_entry["result_preview"] = preview
	
	var existing: Array = []
	if FileAccess.file_exists(_tool_log_path):
		var file: FileAccess = FileAccess.open(_tool_log_path, FileAccess.READ)
		if file:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				existing = json.get_data()
			file.close()
	
	existing.append(log_entry)
	
	var file: FileAccess = FileAccess.open(_tool_log_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(existing, "\t"))
		file.close()
