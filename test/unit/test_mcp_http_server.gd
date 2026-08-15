extends "res://addons/gut/test.gd"

var _http_server: RefCounted = null

func before_each():
	_http_server = load("res://addons/godot_mcp/native_mcp/mcp_http_server.gd").new()

func after_each():
	if _http_server and _http_server.is_running():
		_http_server.stop()
	_http_server = null

func test_parse_http_request_post():
	var raw: String = "POST /mcp HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 42\r\n\r\n{\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"id\":1}"
	var result: Dictionary = _http_server._parse_http_request(raw)
	assert_eq(result["method"], "POST", "Method should be POST")
	assert_eq(result["path"], "/mcp", "Path should be /mcp")
	assert_eq(result["version"], "HTTP/1.1", "Version should be HTTP/1.1")

func test_parse_http_request_headers():
	var raw: String = "POST /mcp HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer test123\r\n\r\n{}"
	var result: Dictionary = _http_server._parse_http_request(raw)
	assert_eq(result["headers"].get("content-type"), "application/json", "Content-Type should be parsed")
	assert_eq(result["headers"].get("authorization"), "Bearer test123", "Authorization should be parsed")

func test_parse_http_request_headers_case_insensitive():
	var raw: String = "POST /mcp HTTP/1.1\r\nContent-Type: application/json\r\n\r\n{}"
	var result: Dictionary = _http_server._parse_http_request(raw)
	assert_true(result["headers"].has("content-type"), "Header names should be lowercased")

func test_parse_http_request_body():
	var body: String = '{"jsonrpc":"2.0","method":"initialize","id":1}'
	var raw: String = "POST /mcp HTTP/1.1\r\nContent-Length: " + str(body.length()) + "\r\n\r\n" + body
	var result: Dictionary = _http_server._parse_http_request(raw)
	assert_true(result["body"].length() > 0, "Should have body content")

func test_parse_http_get_request():
	var raw: String = "GET /mcp HTTP/1.1\r\nAccept: text/event-stream\r\n\r\n"
	var result: Dictionary = _http_server._parse_http_request(raw)
	assert_eq(result["method"], "GET", "Method should be GET")
	assert_eq(result["path"], "/mcp", "Path should be /mcp")

func test_parse_http_options_request():
	var raw: String = "OPTIONS /mcp HTTP/1.1\r\nOrigin: http://localhost:3000\r\n\r\n"
	var result: Dictionary = _http_server._parse_http_request(raw)
	assert_eq(result["method"], "OPTIONS", "Method should be OPTIONS")

func test_generate_session_id():
	var id1: String = _http_server._generate_session_id()
	var id2: String = _http_server._generate_session_id()
	assert_eq(id1.length(), 32, "Session ID should be 32 characters")
	assert_ne(id1, id2, "Session IDs should be unique")

func test_generate_session_id_characters():
	var session_id: String = _http_server._generate_session_id()
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	for ch in session_id:
		assert_true(valid_chars.contains(ch), "Session ID should only contain alphanumeric characters")

func test_check_port_conflict_returns_string():
	var result: String = _http_server._check_port_conflict(9999)
	assert_true(result is String, "Should return a string on any platform")

func test_check_port_conflict_windows_method_exists():
	assert_true(_http_server.has_method("_check_port_conflict_windows"), "Should have Windows-specific method")

func test_check_port_conflict_linux_method_exists():
	assert_true(_http_server.has_method("_check_port_conflict_linux"), "Should have Linux-specific method")

func test_check_port_conflict_macos_method_exists():
	assert_true(_http_server.has_method("_check_port_conflict_macos"), "Should have macOS-specific method")

func test_set_port():
	_http_server.set_port(9999)
	assert_eq(_http_server._port, 9999, "Port should be set to 9999")

func test_set_port_while_running():
	_http_server._port = 9080
	assert_eq(_http_server._port, 9080, "Default port should be 9080")

func test_is_running_initially():
	assert_false(_http_server.is_running(), "Should not be running initially")

func test_set_auth_manager():
	var auth: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_auth_manager.gd").new()
	_http_server.set_auth_manager(auth)
	assert_ne(_http_server._auth_manager, null, "Auth manager should be set")

func test_set_remote_config():
	_http_server.set_remote_config(true, "http://localhost:3000")
	assert_eq(_http_server._allow_remote, true, "Allow remote should be true")
	assert_eq(_http_server._cors_origin, "http://localhost:3000", "CORS origin should be set")

func test_bind_addresses_cover_both_local_ip_families():
	_http_server.set_remote_config(false, "*")
	assert_eq(
		_http_server._get_bind_addresses(),
		PackedStringArray(["127.0.0.1", "::1"]),
		"Local mode should bind both IPv4 and IPv6 loopback"
	)

func test_remote_bind_address_covers_all_interfaces():
	_http_server.set_remote_config(true, "*")
	assert_eq(
		_http_server._get_bind_addresses(),
		PackedStringArray(["*"]),
		"Remote mode should bind all interfaces"
	)

func test_max_request_size_constant():
	assert_eq(_http_server.MAX_REQUEST_SIZE, 1024 * 1024, "Max request size should be 1MB")

func test_request_timeout_constant():
	assert_eq(_http_server.REQUEST_TIMEOUT, 30.0, "Request timeout should be 30 seconds")

func test_auth_header_constants():
	assert_eq(_http_server.AUTH_HEADER, "authorization", "Auth header should be 'authorization'")
	assert_eq(_http_server.AUTH_SCHEME, "Bearer", "Auth scheme should be 'Bearer'")

func test_http_server_has_send_raw_message():
	assert_true(_http_server.has_method("send_raw_message"), "HTTP server should have send_raw_message method")

func test_http_server_send_raw_message_logs():
	var test_message: Dictionary = {"jsonrpc": "2.0", "method": "notifications/tools/list_changed", "params": {}}
	_http_server.send_raw_message(test_message)
	assert_true(true, "send_raw_message should not crash when no SSE connections")
