class_name McpHttpServer
extends McpTransportBase

const MAX_REQUEST_SIZE: int = 1024 * 1024
const REQUEST_TIMEOUT: float = 30.0

var _tcp_server: TCPServer = null
var _port: int = 9080
var _active: bool = false
var _thread: Thread = null
var _connections: Array[StreamPeerTCP] = []
var _sse_connections: Dictionary = {}
var _sessions: Dictionary = {}
var _auth_manager: McpAuthManager = null
var _allow_remote: bool = false
var _cors_origin: String = "*"
var _sse_enabled: bool = true
var _log_callback: Callable = Callable()
var _cli_api_handler: CliApiHandler = null

func set_port(port: int) -> void:
	if _active:
		push_error("Cannot change port while server is running")
		return
	_port = port

func set_log_callback(callback: Callable) -> void:
	_log_callback = callback

func set_auth_manager(manager: RefCounted) -> void:
	_auth_manager = manager as McpAuthManager

func set_sse_enabled(enabled: bool) -> void:
	_sse_enabled = enabled

func set_remote_config(allow_remote: bool, cors_origin: String = "*") -> void:
	_allow_remote = allow_remote
	_cors_origin = cors_origin
	_log("INFO", "Remote access config: allow_remote=" + str(allow_remote) + ", cors=" + cors_origin)

func start() -> bool:
	if _active:
		return false
	_tcp_server = TCPServer.new()
	var error: Error = _tcp_server.listen(_port)
	if error != OK:
		var message: String = "Failed to listen on port " + str(_port) + ": " + str(error)
		server_error.emit(message)
		_log("ERROR", message)
		_tcp_server = null
		return false
	_active = true
	_thread = Thread.new()
	_thread.start(_http_server_loop)
	server_started.emit()
	_log("INFO", "Server started on port " + str(_port))
	return true

func stop() -> void:
	_active = false
	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
	_thread = null
	for peer in _connections:
		if peer and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
	_connections.clear()
	_sse_connections.clear()
	_sessions.clear()
	server_stopped.emit()
	_log("INFO", "Server stopped")

func is_running() -> bool:
	return _active and _tcp_server != null and _tcp_server.is_listening()

func _http_server_loop() -> void:
	var last_keepalive: int = Time.get_ticks_msec()
	_log("INFO", "Server loop started")
	while _active:
		if _tcp_server == null:
			break
		if _tcp_server.is_connection_available():
			var peer: StreamPeerTCP = _tcp_server.take_connection()
			if peer:
				_connections.append(peer)
		var disconnected: Array[StreamPeerTCP] = []
		for peer in _connections.duplicate():
			if not _active:
				break
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				disconnected.append(peer)
				continue
			if peer.get_available_bytes() > 0:
				_handle_http_request(peer)
		for peer in disconnected:
			_connections.erase(peer)
			_sse_connections.erase(peer)
		if Time.get_ticks_msec() - last_keepalive > 30000:
			_send_sse_keepalive()
			last_keepalive = Time.get_ticks_msec()
		OS.delay_msec(2)
	_log("INFO", "Server loop stopped")

func _handle_http_request(peer: StreamPeerTCP) -> void:
	var raw_request: String = ""
	var started_at: int = Time.get_ticks_msec()
	var content_length: int = -1
	while true:
		var available: int = peer.get_available_bytes()
		if available > 0:
			raw_request += peer.get_utf8_string(available)
		if raw_request.to_utf8_buffer().size() > MAX_REQUEST_SIZE:
			_send_http_error(peer, 413, "Request too large")
			return
		if Time.get_ticks_msec() - started_at > int(REQUEST_TIMEOUT * 1000.0):
			_send_http_error(peer, 408, "Request timeout")
			return
		var header_end: int = raw_request.find("\r\n\r\n")
		if header_end < 0:
			OS.delay_msec(1)
			continue
		if content_length < 0:
			content_length = _extract_content_length(raw_request.left(header_end))
		var body_size: int = raw_request.substr(header_end + 4).to_utf8_buffer().size()
		if content_length < 0 or body_size >= content_length:
			break
		OS.delay_msec(1)
	if raw_request.is_empty():
		return
	var parsed: Dictionary = _parse_http_request(raw_request)
	if parsed.is_empty():
		_send_http_error(peer, 400, "Invalid HTTP request")
		return
	if _auth_manager and not _auth_manager.validate_request(parsed["headers"]):
		_send_http_error(peer, 401, "Unauthorized")
		return
	var path: String = str(parsed["path"])
	if path.begins_with("/cli/v1"):
		if not _allow_remote and not _is_loopback(peer):
			_send_cli_error(peer, 403, "REMOTE_CLI_DISABLED", "CLI API accepts loopback requests only")
			return
		call_deferred("_handle_cli_request_on_main", peer, parsed)
		return
	match str(parsed["method"]):
		"POST":
			_handle_post_request(peer, parsed)
		"GET":
			_handle_get_request(peer, parsed)
		"OPTIONS":
			_handle_options_request(peer)
		_:
			_send_http_error(peer, 405, "Method not allowed")

func _extract_content_length(header_section: String) -> int:
	for line in header_section.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			return line.substr(line.find(":") + 1).strip_edges().to_int()
	return -1

func _parse_http_request(raw: String) -> Dictionary:
	var header_end: int = raw.find("\r\n\r\n")
	if header_end < 0:
		return {}
	var header_lines: PackedStringArray = raw.left(header_end).split("\r\n")
	if header_lines.is_empty():
		return {}
	var request_line: PackedStringArray = header_lines[0].split(" ", false)
	if request_line.size() < 2:
		return {}
	var headers: Dictionary = {}
	for index in range(1, header_lines.size()):
		var separator: int = header_lines[index].find(":")
		if separator <= 0:
			continue
		headers[header_lines[index].left(separator).to_lower()] = header_lines[index].substr(separator + 1).strip_edges()
	return {
		"method": request_line[0],
		"path": request_line[1],
		"version": request_line[2] if request_line.size() > 2 else "HTTP/1.1",
		"headers": headers,
		"body": raw.substr(header_end + 4),
	}

func _handle_post_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
	if parsed["path"] != "/mcp" and parsed["path"] != "/":
		_send_http_error(peer, 404, "Not found. Use /mcp for MCP requests")
		return
	var body: String = str(parsed["body"])
	var content_type: String = str(parsed["headers"].get("content-type", ""))
	if body.is_empty():
		_send_http_error(peer, 400, "Empty request body")
		return
	if not content_type.contains("application/json"):
		_send_http_error(peer, 415, "Content-Type must be application/json")
		return
	var json := JSON.new()
	if json.parse(body) != OK or not (json.get_data() is Dictionary):
		_send_http_error(peer, 400, "Invalid JSON")
		return
	var message: Dictionary = json.get_data()
	var is_notification: bool = not message.has("id")
	call_deferred("_emit_message_received", message, peer)
	if is_notification:
		_send_http_accepted(peer)

func _handle_get_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
	if parsed["headers"].get("accept", "") == "text/event-stream":
		if not _sse_enabled:
			_send_http_error(peer, 404, "SSE is disabled")
			return
		_handle_sse_request(peer)
		return
	_send_http_response(peer, {
		"name": "Godot MCP Native",
		"version": "1.0.7",
		"transport": "http",
		"protocol": "MCP",
		"endpoints": {
			"mcp": "/mcp",
			"sse": "/mcp",
			"cli": "/cli/v1",
		},
	})

func _handle_options_request(peer: StreamPeerTCP) -> void:
	var response: String = "HTTP/1.1 204 No Content\r\n"
	response += "Access-Control-Allow-Origin: " + _cors_origin + "\r\n"
	response += "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type, Authorization, X-GDMCP-API-Version\r\n"
	response += "Access-Control-Max-Age: 86400\r\n\r\n"
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()

func _handle_cli_request_on_main(peer: StreamPeerTCP, parsed: Dictionary) -> void:
	if _cli_api_handler == null:
		var plugin: Object = null
		if Engine.has_meta("GodotMCPPlugin"):
			plugin = Engine.get_meta("GodotMCPPlugin")
		var server_core: RefCounted = null
		if plugin != null:
			server_core = plugin.get("_native_server") as RefCounted
		_cli_api_handler = CliApiHandler.new()
		_cli_api_handler.configure(server_core, plugin, _auth_manager != null)
	var response: Dictionary = await _cli_api_handler.handle_request(
		str(parsed["method"]),
		str(parsed["path"]),
		parsed["headers"],
		str(parsed["body"])
	)
	_send_cli_response(peer, response)

func _handle_sse_request(peer: StreamPeerTCP) -> void:
	var session_id: String = _generate_session_id()
	var header: String = "HTTP/1.1 200 OK\r\n"
	header += "Content-Type: text/event-stream\r\n"
	header += "Cache-Control: no-cache\r\n"
	header += "Connection: keep-alive\r\n"
	header += "Access-Control-Allow-Origin: " + _cors_origin + "\r\n\r\n"
	peer.put_data(header.to_utf8_buffer())
	_send_sse_event(peer, "connected", {"session_id": session_id})
	_sse_connections[peer] = session_id
	_sessions[session_id] = {"peer": peer, "created_at": Time.get_time_dict_from_system()}

func send_raw_message(message: Dictionary) -> void:
	for peer in _sse_connections.keys():
		_send_sse_event(peer, "message", message)

func _send_sse_event(peer: StreamPeerTCP, event: String, data: Dictionary) -> void:
	var payload: String = "event: " + event + "\r\n"
	payload += "data: " + JSON.stringify(data) + "\r\n\r\n"
	if peer.put_data(payload.to_utf8_buffer()) != OK:
		_close_sse_connection(peer)

func _send_sse_keepalive() -> void:
	for peer in _sse_connections.keys().duplicate():
		if peer.put_data(": keepalive\r\n\r\n".to_utf8_buffer()) != OK:
			_close_sse_connection(peer)

func _close_sse_connection(peer: StreamPeerTCP) -> void:
	if _sse_connections.has(peer):
		var session_id: String = str(_sse_connections[peer])
		_sse_connections.erase(peer)
		_sessions.erase(session_id)
	peer.disconnect_from_host()

func _generate_session_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chars: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result: String = ""
	for index in range(32):
		result += chars[rng.randi_range(0, chars.length() - 1)]
	return result

func _emit_message_received(message: Dictionary, peer: StreamPeerTCP) -> void:
	message_received.emit(message, peer as Variant)

func send_response(response: Dictionary, context: Variant) -> void:
	var peer: StreamPeerTCP = context as StreamPeerTCP
	if peer == null:
		_log("ERROR", "Cannot send response: invalid peer context")
		return
	_send_http_response(peer, response)

func _send_http_response(peer: StreamPeerTCP, data: Dictionary) -> void:
	_send_json_response(peer, 200, data)

func _send_cli_response(peer: StreamPeerTCP, response: Dictionary) -> void:
	_send_json_response(peer, int(response.get("status", 500)), response.get("body", {}), str(response.get("content_type", "application/json; charset=utf-8")))

func _send_cli_error(peer: StreamPeerTCP, status: int, code: String, message: String) -> void:
	_send_json_response(peer, status, {
		"schema_version": 1,
		"api_version": 1,
		"ok": false,
		"data": null,
		"error": {"code": code, "message": message, "retryable": false},
		"meta": {"truncated": false, "next_cursor": null},
	})

func _send_json_response(peer: StreamPeerTCP, status: int, data: Dictionary, content_type: String = "application/json; charset=utf-8") -> void:
	var body: PackedByteArray = JSON.stringify(data).to_utf8_buffer()
	var header: String = "HTTP/1.1 " + str(status) + " " + _status_text(status) + "\r\n"
	header += "Content-Type: " + content_type + "\r\n"
	header += "Content-Length: " + str(body.size()) + "\r\n"
	header += "Access-Control-Allow-Origin: " + _cors_origin + "\r\n"
	header += "Connection: close\r\n\r\n"
	var error: Error = peer.put_data(header.to_utf8_buffer() + body)
	if error != OK:
		server_error.emit("Failed to send HTTP response: " + str(error))
	peer.disconnect_from_host()

func _send_http_accepted(peer: StreamPeerTCP) -> void:
	var response: String = "HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
	peer.put_data(response.to_utf8_buffer())
	peer.disconnect_from_host()

func _send_http_error(peer: StreamPeerTCP, status: int, message: String) -> void:
	var body: PackedByteArray = message.to_utf8_buffer()
	var header: String = "HTTP/1.1 " + str(status) + " " + _status_text(status) + "\r\n"
	header += "Content-Type: text/plain; charset=utf-8\r\n"
	header += "Content-Length: " + str(body.size()) + "\r\n"
	header += "Access-Control-Allow-Origin: " + _cors_origin + "\r\n"
	header += "Connection: close\r\n\r\n"
	peer.put_data(header.to_utf8_buffer() + body)
	peer.disconnect_from_host()
	_log("WARN", "HTTP error " + str(status) + ": " + message)

func _status_text(status: int) -> String:
	match status:
		200: return "OK"
		202: return "Accepted"
		204: return "No Content"
		400: return "Bad Request"
		401: return "Unauthorized"
		403: return "Forbidden"
		404: return "Not Found"
		405: return "Method Not Allowed"
		408: return "Request Timeout"
		409: return "Conflict"
		413: return "Payload Too Large"
		415: return "Unsupported Media Type"
		422: return "Unprocessable Content"
		500: return "Internal Server Error"
		_: return "Error"

func _is_loopback(peer: StreamPeerTCP) -> bool:
	var host: String = peer.get_connected_host()
	return host == "127.0.0.1" or host == "::1" or host == "0:0:0:0:0:0:0:1"

func _log(level: String, message: String) -> void:
	if _log_callback.is_valid():
		_log_callback.call(level, message)
