# path_validator.gd
# Утилита валидации путей - защита от обхода директорий и невалидного доступа
# Версия: 1.0
# Автор: AI Assistant
# Дата: 2026-05-01

@tool
class_name PathValidator
extends RefCounted

# Сигналы
signal path_rejected(path: String, reason: String)
signal path_approved(path: String)

# Константы - разрешенные префиксы путей
const ALLOWED_PATHS := ["res://", "user://"]

# Константы - опасные шаблоны путей
const DANGEROUS_PATTERNS := [
	"~",            # Домашний каталог пользователя
	"\\\\",         # Windows-сетевой путь
	"C:\\",         # Абсолютный путь Windows
	"/etc/",        # Системный каталог Linux
	"/var/",        # Каталог данных Linux
	"/tmp/",        # Временный каталог
	"D:\\",        # Другие диски Windows
	"E:\\",
	"F:\\"
]

# Конфигурация
var _strict_mode: bool = true  # true=строгий режим, false=мягкий режим
var _allowed_extensions: Array[String] = []  # Разрешенные расширения файлов (пусто = без ограничений)

# Колбэк логирования
var _log_callback: Callable = Callable()

## Установить функцию логирования
func set_log_callback(callback: Callable) -> void:
	_log_callback = callback

# ===========================================
# Основные функции валидации пути
# ===========================================

## Проверяет, безопасен ли путь
## Возвращает: {valid: bool, error: String, sanitized: String}
static func validate_path(path: String, strict: bool = true) -> Dictionary:
	var result: Dictionary = {
		"valid": false,
		"error": "",
		"sanitized": ""
	}
	
	if path.is_empty():
		result["error"] = "Path is empty"
		return result
	
	var sanitized: String = _sanitize_path(path)
	result["sanitized"] = sanitized
	
	var is_allowed: bool = false
	for allowed in ALLOWED_PATHS:
		if sanitized.begins_with(allowed):
			is_allowed = true
			break
	
	if not is_allowed:
		result["error"] = "Path must start with res:// or user://"
		return result
	
	if strict:
		for pattern in DANGEROUS_PATTERNS:
			if sanitized.contains(pattern):
				result["error"] = "Path contains dangerous pattern: " + pattern
				return result
		var path_part: String = sanitized
		for prefix in ALLOWED_PATHS:
			if path_part.begins_with(prefix):
				path_part = path_part.substr(prefix.length())
				break
		if path_part.contains(".."):
			result["error"] = "Path contains directory traversal: .."
			return result
	
	result["valid"] = true
	result["sanitized"] = sanitized
	return result

## Проверяет путь к файлу (с проверкой расширения)
## Возвращает: {valid: bool, error: String, sanitized: String}
static func validate_file_path(path: String, allowed_extensions: Array = []) -> Dictionary:
	var result: Dictionary = validate_path(path)
	if not result["valid"]:
		return result
	
	if not allowed_extensions.is_empty():
		var has_valid_ext: bool = false
		var path_lower: String = result["sanitized"].to_lower()
		
		for ext in allowed_extensions:
			if path_lower.ends_with(ext.to_lower()):
				has_valid_ext = true
				break
		
		if not has_valid_ext:
			result["valid"] = false
			result["error"] = "File extension not allowed. Allowed: " + str(allowed_extensions)
			return result
	
	return result

## Проверяет путь к каталогу
## Возвращает: {valid: bool, error: String, sanitized: String}
static func validate_directory_path(path: String) -> Dictionary:
	var result: Dictionary = validate_path(path)
	if not result["valid"]:
		return result
	
	var sanitized: String = result["sanitized"]
	var path_without_prefix: String = sanitized
	for allowed in ALLOWED_PATHS:
		if path_without_prefix.begins_with(allowed):
			path_without_prefix = path_without_prefix.substr(allowed.length())
			break
	
	if not path_without_prefix.is_empty() and not path_without_prefix.ends_with("/"):
		sanitized += "/"
		result["sanitized"] = sanitized
	
	return result

# ===========================================
# Очистка пути
# ===========================================

## Очищает путь (удаляет опасные символы)
static func _sanitize_path(path: String) -> String:
	var sanitized: String = path
	
	var prefix: String = ""
	for allowed in ALLOWED_PATHS:
		if sanitized.begins_with(allowed):
			prefix = allowed
			sanitized = sanitized.substr(allowed.length())
			break
	
	sanitized = sanitized.replace("..", "")
	
	while sanitized.contains("//"):
		sanitized = sanitized.replace("//", "/")
	
	if sanitized.begins_with("/"):
		sanitized = sanitized.lstrip("/")
	
	if prefix.is_empty():
		if path.begins_with("/"):
			prefix = "res://"
		else:
			prefix = "res://"
	
	return prefix + sanitized

# ===========================================
# Пакетная валидация
# ===========================================

## Пакетно проверяет несколько путей
## Возвращает: {valid: Array, invalid: Array[Dictionary]}
static func validate_paths(paths: Array[String], strict: bool = true) -> Dictionary:
	var result: Dictionary = {
		"valid": [],
		"invalid": []
	}
	
	for path in paths:
		var validation: Dictionary = validate_path(path, strict)
		if validation["valid"]:
			result["valid"].append(validation["sanitized"])
		else:
			result["invalid"].append({
				"path": path,
				"error": validation["error"]
			})
	
	return result

# ===========================================
# Методы экземпляра (с поддержкой сигналов)
# ===========================================

## Метод экземпляра: проверка пути (эмитит сигнал)
## Возвращает: bool
func validate_path_with_signal(path: String) -> bool:
	var result: Dictionary = validate_path(path, _strict_mode)
	
	if result["valid"]:
		path_approved.emit(result["sanitized"])
		return true
	else:
		path_rejected.emit(path, result["error"])
		return false

## Установить строгий режим
func set_strict_mode(strict: bool) -> void:
	_strict_mode = strict
	if _log_callback.is_valid():
		_log_callback.call("INFO", "Strict mode: " + str(strict))

## Добавить разрешенное расширение
func add_allowed_extension(extension: String) -> void:
	if not _allowed_extensions.has(extension):
		_allowed_extensions.append(extension)
		if _log_callback.is_valid():
			_log_callback.call("INFO", "Added allowed extension: " + extension)

## Очистить список разрешенных расширений (без ограничений)
func clear_allowed_extensions() -> void:
	_allowed_extensions.clear()
	if _log_callback.is_valid():
		_log_callback.call("INFO", "Cleared allowed extensions (no restriction)")

# ===========================================
# Отладочные функции
# ===========================================

## Тест валидации путей (для отладки)
## Возвращает: Array[String] Текст с результатами проверки
static func test_validation() -> Array[String]:
	var output: Array[String] = []
	output.append("Testing path validation...")
	
	var test_paths: Array[String] = [
		"res://test.tscn",
		"user://save.dat",
		"../../../etc/passwd",
		"C:\\Windows\\System32",
		"res://../escape.tscn",
		"res://normal/path/script.gd"
	]
	
	for path in test_paths:
		var result: Dictionary = validate_path(path)
		output.append("  Path: " + path)
		output.append("    Valid: " + str(result["valid"]))
		if not result["valid"]:
			output.append("    Error: " + result["error"])
		else:
			output.append("    Sanitized: " + result["sanitized"])
		output.append("")
	
	return output
