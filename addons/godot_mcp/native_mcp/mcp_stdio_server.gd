class_name McpStdioServer
extends McpTransportBase

# Реализация транспорта stdio - выделено из mcp_server_core.gd
# Отвечает за передачу JSON-RPC сообщений через stdin/stdout
# Наследуется от McpTransportBase и реализует единый интерфейс транспорта

# ==============================================================================
# Переменные состояния (с подсказками типов по godot-dev-guide)
# ==============================================================================

## Флаг активности
var _active: bool = false

## Поток прослушивания stdin
var _thread: Thread = null

## Мьютекс (для потокобезопасного доступа к очереди сообщений)
var _mutex: Mutex = Mutex.new()

## Очередь сообщений (сообщения, ожидающие обработки)
var _message_queue: Array[Dictionary] = []

## Очередь ответов (ответы, ожидающие отправки)
var _response_queue: Array[Dictionary] = []

## Колбэк логирования
var _log_callback: Callable = Callable()

## Установить функцию обратного вызова для логирования
func set_log_callback(callback: Callable) -> void:
	_log_callback = callback


# ==============================================================================
# Реализация интерфейса McpTransportBase
# ==============================================================================

## Запустить транспортный слой stdio
## @returns: bool - true при успешном запуске, иначе false
func start() -> bool:
	_active = true
	
	# Обеспечивает своевременный flush stdout
	ProjectSettings.set_setting("application/run/flush_stdout_on_print", true)
	
	_thread = Thread.new()
	_thread.start(_stdin_listen_loop)
	
	server_started.emit()
	if _log_callback.is_valid():
		_log_callback.call("INFO", "Server started")
	
	return true

## Остановить транспортный слой stdio
func stop() -> void:
	if not _active:
		return
	
	_active = false
	
	# Ожидание завершения потока
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
	
	# Очистка очередей
	_mutex.lock()
	_message_queue.clear()
	_response_queue.clear()
	_mutex.unlock()
	
	server_stopped.emit()
	if _log_callback.is_valid():
		_log_callback.call("INFO", "Server stopped")

## Проверить, работает ли транспортный слой
## @returns: bool - true, если работает; иначе false
func is_running() -> bool:
	return _active


# ==============================================================================
# Основная логика stdio-транспорта (вынесено и оптимизировано из mcp_server_core.gd)
# ==============================================================================

## Цикл прослушивания stdin (работает в отдельном потоке)
func _stdin_listen_loop() -> void:
	if _log_callback.is_valid():
		_log_callback.call("DEBUG", "Listen loop started")
	
	while _active:
		# Чтение данных из stdin
		var input: String = OS.read_string_from_stdin()
		
		if not input.is_empty():
			# Разбор сообщения
			_parse_and_queue_message(input)
		
		# Не допускает излишней нагрузки на CPU
		OS.delay_msec(10)
	
	if _log_callback.is_valid():
		_log_callback.call("DEBUG", "Listen loop stopped")

## Разобрать вход и добавить сообщение в очередь
## @param raw_input: String - исходная строка, прочитанная из stdin
func _parse_and_queue_message(raw_input: String) -> void:
	var lines: PackedStringArray = raw_input.split("\n")
	
	for line in lines:
		if line.is_empty():
			continue
		
		var json: JSON = JSON.new()
		var parse_result: Error = json.parse(line)
		
		if parse_result != OK:
			if _log_callback.is_valid():
				_log_callback.call("ERROR", "JSON parse error: " + json.get_error_message())
			call_deferred("_emit_error", null, MCPTypes.ERROR_PARSE_ERROR, "Failed to parse JSON input", line)
			continue
		
		var message: Dictionary = json.get_data()
		
		# Потокобезопасность: очередь сообщений защищена мьютексом
		_mutex.lock()
		_message_queue.append(message)
		_mutex.unlock()
		
		# Обработка сообщения в главном потоке (для потокобезопасности)
		call_deferred("_process_next_message")
	
	# Обработка очереди ответов
	call_deferred("_process_response_queue")

## Обработать следующее сообщение
func _process_next_message() -> void:
	_mutex.lock()
	
	if _message_queue.is_empty():
		_mutex.unlock()
		return
	
	var message: Dictionary = _message_queue.pop_front()
	
	_mutex.unlock()
	
	# Отправка сигнала на уровень ядра для обработки
	message_received.emit(message, null)  # context = null (для stdio не нужен)

## Обработка очереди ответов (режим stdio: прямой вывод в stdout)
func _process_response_queue() -> void:
	_mutex.lock()
	
	if _response_queue.is_empty():
		_mutex.unlock()
		return
	
	var response: Dictionary = _response_queue.pop_front()
	
	_mutex.unlock()
	
	# Отправка в stdout
	_send_response(response)

## Отправка ответа (режим stdio: вывод в stdout)
## @param response: Dictionary - ответ JSON-RPC
func _send_response(response: Dictionary) -> void:
	var json_string: String = JSON.stringify(response)
	
	if _log_callback.is_valid():
		_log_callback.call("DEBUG", "Sending response: " + json_string)
	
	# Вывод в stdout
	print(json_string)

## Отправка ответа об ошибке
## @param id: Variant - ID запроса
## @param code: int - код ошибки
## @param message: String - сообщение об ошибке
## @param data: Variant - дополнительные данные (опционально)
func _send_error(id: Variant, code: int, message: String, data: Variant = null) -> void:
	var error_response: Dictionary = MCPTypes.create_error_response(id, code, message, data)
	_send_response(error_response)

## Добавить ответ в очередь (для внешнего вызова)
## @param response: Dictionary - ответ JSON-RPC
func queue_response(response: Dictionary) -> void:
	_mutex.lock()
	_response_queue.append(response)
	_mutex.unlock()
	
	call_deferred("_process_response_queue")

## Отправка сигнала ошибки в главном потоке (потокобезопасно)
func _emit_error(id: Variant, code: int, message: String, data: Variant = null) -> void:
	server_error.emit("JSON parse error: " + message)
