class_name McpAuthManager
extends RefCounted

# Менеджер аутентификации для режима HTTP - token-based auth
# Соответствует best practices безопасности MCP и RFC 6750 (Bearer Token)

# ==============================================================================
# Параметры конфигурации
# ==============================================================================

## Токен аутентификации (должен быть >= 16 символов)
var _token: String = ""

## Включена ли аутентификация
var _enabled: bool = true


# ==============================================================================
# Константы
# ==============================================================================

## Имя HTTP-заголовка аутентификации
const HEADER_NAME: String = "authorization"

## Схема аутентификации Bearer
const SCHEME: String = "Bearer"


# ==============================================================================
# Публичные методы
# ==============================================================================

## Установить токен аутентификации
## @param token: String - токен аутентификации (должен быть >= 16 символов)
func set_token(token: String) -> void:
	if token.length() < 16:
		push_error("Auth token must be at least 16 characters long")
		return
	_token = token

## Включить/выключить аутентификацию
## @param enabled: bool - true включает, false выключает
func set_enabled(enabled: bool) -> void:
	_enabled = enabled

## Проверить заголовок аутентификации HTTP-запроса
## @param headers: Dictionary - словарь HTTP-заголовков запроса
## @returns: bool - true, если проверка пройдена; иначе false
func validate_request(headers: Dictionary) -> bool:
	# Если аутентификация выключена, проверка проходит сразу
	if not _enabled:
		return true
	
	# Проверка наличия заголовка Authorization
	if not headers.has(HEADER_NAME):
		return false  # Отсутствует заголовок аутентификации
	
	var auth_header: String = headers[HEADER_NAME]
	
	# Проверка формата: Bearer <token>
	if not auth_header.begins_with(SCHEME + " "):
		return false  # Неверный формат
	
	# Извлечение токена
	var token: String = auth_header.substr(SCHEME.length() + 1)
	
	var result: bool = true
	var max_len: int = maxi(token.length(), _token.length())
	
	for i in range(max_len):
		var token_char: String = token[i] if i < token.length() else ""
		var stored_char: String = _token[i] if i < _token.length() else ""
		if token_char != stored_char:
			result = false
	
	if token.length() != _token.length():
		result = false
	
	return result

## Вернуть заголовок WWW-Authenticate (для ответа 401)
## @returns: String - значение заголовка WWW-Authenticate
func get_www_authenticate_header() -> String:
	return SCHEME + ' realm="Godot MCP Native", error="invalid_token"'

## Сгенерировать случайный токен
## @param length: int - длина токена (по умолчанию 32)
## @returns: String - случайно сгенерированный токен
static func generate_token(length: int = 32) -> String:
	var chars: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
	var token: String = ""
	
	for i in range(length):
		var idx: int = randi() % chars.length()
		token += chars[idx]
	
	return token
