class_name McpTransportBase
extends RefCounted

# Базовый класс транспортного слоя - единый интерфейс для всех видов транспорта
# Соответствует стандартам разработки Godot 4.x и протоколу MCP

# ==============================================================================
# Определение сигналов (для межпоточного взаимодействия и потокобезопасности)
# ==============================================================================

## Срабатывает при получении сообщения
## @param message: Dictionary - сообщение JSON-RPC
## @param context: Variant - контекст транспорта (stdio: null, HTTP: StreamPeerTCP)
signal message_received(message: Dictionary, context: Variant)

## Срабатывает при возникновении ошибки
## @param error: String - описание ошибки
signal server_error(error: String)

## Срабатывает при успешном запуске сервера
signal server_started()

## Срабатывает при остановке сервера
signal server_stopped()


# ==============================================================================
# Виртуальные методы (должны быть реализованы в наследниках)
# ==============================================================================

## Запуск транспортного слоя
## @returns: bool - true при успешном запуске, иначе false
func start() -> bool:
	push_error("McpTransportBase.start() must be overridden")
	return false

## Остановка транспортного слоя
func stop() -> void:
	push_error("McpTransportBase.stop() must be overridden")

## Проверка, работает ли транспортный слой
## @returns: bool - true, если работает; иначе false
func is_running() -> bool:
	push_error("McpTransportBase.is_running() must be overridden")
	return false


# ==============================================================================
# Дополнительные методы (могут быть переопределены в наследниках)
# ==============================================================================

## Установить порт (используется в режиме HTTP)
## @param port: int - порт прослушивания
func set_port(port: int) -> void:
	push_error("McpTransportBase.set_port() is not implemented")

## Установить менеджер аутентификации (режим HTTP)
## @param manager: RefCounted - экземпляр менеджера аутентификации
func set_auth_manager(manager: RefCounted) -> void:
	push_error("McpTransportBase.set_auth_manager() is not implemented")

## Отправить ответ (требуется для некоторых транспортов)
## @param response: Dictionary - ответ JSON-RPC
## @param context: Variant - контекст транспорта
func send_response(response: Dictionary, context: Variant) -> void:
	push_error("McpTransportBase.send_response() is not implemented")
