# mcp_resource_manager.gd
# MCP Resource Manager - отвечает за регистрацию и чтение MCP-ресурсов
# Версия: 1.0
# Автор: AI Assistant
# Дата: 2026-05-01

class_name MCPResourceManager
extends RefCounted

# Сигналы
signal resource_registered(uri: String, name: String)
signal resource_read(uri: String, result: Dictionary)

# Константы
const JSONRPC_VERSION := "2.0"

# Реестр ресурсов: uri -> {name, mimeType, load_callable}
var _resources: Dictionary = {}

# Колбэк логирования
var _log_callback: Callable = Callable()

## Установить колбэк логирования
func set_log_callback(callback: Callable) -> void:
	_log_callback = callback

# ===========================================
# Регистрация ресурсов
# ===========================================

## Зарегистрировать ресурс
func register_resource(uri: String, name: String, mime_type: String, load_callable: Callable) -> void:
	if _resources.has(uri):
		if _log_callback.is_valid():
			_log_callback.call("WARN", "Ресурс уже существует, будет перезаписан: " + uri)

	_resources[uri] = {
		"name": name,
		"mimeType": mime_type,
		"load": load_callable
	}

	resource_registered.emit(uri, name)
	if _log_callback.is_valid():
		_log_callback.call("INFO", "Ресурс зарегистрирован: " + uri + " (" + name + ")")

## Удалить регистрацию ресурса
func unregister_resource(uri: String) -> bool:
	if _resources.has(uri):
		_resources.erase(uri)
		if _log_callback.is_valid():
			_log_callback.call("INFO", "Ресурс удалён из реестра: " + uri)
		return true
	return false

## Получить список ресурсов
func list_resources() -> Array:
	var resource_list: Array = []

	for uri in _resources.keys():
		var resource_info: Dictionary = _resources[uri]
		resource_list.append({
			"uri": uri,
			"name": resource_info["name"],
			"mimeType": resource_info["mimeType"]
		})

	return resource_list

# ===========================================
# Чтение ресурсов
# ===========================================

## Прочитать ресурс
func read_resource(uri: String, params: Dictionary = {}) -> Dictionary:
	if not _resources.has(uri):
		return _error_response(null, -32602, "Resource not found: " + uri)

	var resource_info: Dictionary = _resources[uri]
	var load_callable: Callable = resource_info.get("load", Callable())

	if not load_callable.is_valid():
		return _error_response(null, -32603, "Resource load function not available")

	var result: Dictionary = load_callable.call(params)

	if result.has("error"):
		return _error_response(null, -32603, result.get("error"))

	return result

# ===========================================
# Вспомогательные функции ответа JSON-RPC
# ===========================================

## Успешный ответ
static func _success_response(id: Variant, result: Variant) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": id,
		"result": result
	}

## Ответ с ошибкой
static func _error_response(id: Variant, code: int, message: String) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": id,
		"error": {
			"code": code,
			"message": message
		}
	}

# ===========================================
# Отладочные функции
# ===========================================

## Получить количество зарегистрированных ресурсов
func get_resource_count() -> int:
	return _resources.size()

## Вывести все зарегистрированные ресурсы
func print_resources() -> void:
	if not _log_callback.is_valid():
		return
	_log_callback.call("INFO", "Зарегистрированные ресурсы:")
	for uri in _resources.keys():
		var info: Dictionary = _resources[uri]
		_log_callback.call("INFO", "  - " + uri + " (" + info["name"] + ")")
	_log_callback.call("INFO", "  Всего: " + str(_resources.size()) + " ресурсов")
