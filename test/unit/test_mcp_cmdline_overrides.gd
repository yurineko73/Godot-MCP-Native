extends "res://addons/gut/test.gd"

# Tests for MCPServerNative.parse_mcp_overrides — the pure/static command-line
# override parser used by _apply_cmdline_overrides to support parallel MCP
# instances (--mcp-port / --mcp-transport). The script is loaded (not
# instantiated, since it extends EditorPlugin) and its static method is invoked
# through the loaded GDScript resource.

var _plugin_script = null


func before_each():
	_plugin_script = load("res://addons/godot_mcp/mcp_server_native.gd")


func after_each():
	_plugin_script = null


func test_script_loads_and_exposes_parser():
	assert_not_null(_plugin_script, "Plugin script should load")
	assert_true(
		_plugin_script.has_method("parse_mcp_overrides"), "Plugin should expose parse_mcp_overrides"
	)


func test_parse_valid_port():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(
		PackedStringArray(["--mcp-server", "--mcp-port=19100"])
	)
	assert_eq(r["http_port"], 19100, "valid port should be parsed")
	assert_eq(r["transport_mode"], "", "no transport override means empty string")


func test_parse_port_below_range_ignored():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(PackedStringArray(["--mcp-port=80"]))
	assert_eq(r["http_port"], -1, "port below 1024 must be ignored")


func test_parse_port_above_range_ignored():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(PackedStringArray(["--mcp-port=99999"]))
	assert_eq(r["http_port"], -1, "port above 65535 must be ignored")


func test_parse_non_numeric_port_ignored():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(PackedStringArray(["--mcp-port=abc"]))
	assert_eq(r["http_port"], -1, "non-numeric port must be ignored (to_int -> 0, out of range)")


func test_parse_valid_transport():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(
		PackedStringArray(["--mcp-transport=stdio"])
	)
	assert_eq(r["transport_mode"], "stdio", "valid transport should be parsed")
	assert_eq(r["http_port"], -1, "no port override means -1")


func test_parse_http_transport():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(
		PackedStringArray(["--mcp-transport=http"])
	)
	assert_eq(r["transport_mode"], "http", "http transport should be accepted")


func test_parse_invalid_transport_ignored():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(
		PackedStringArray(["--mcp-transport=ftp"])
	)
	assert_eq(r["transport_mode"], "", "unknown transport must be ignored")


func test_parse_multiple_overrides():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(
		PackedStringArray(["--mcp-port=19080", "--mcp-transport=stdio"])
	)
	assert_eq(r["http_port"], 19080, "port override should be parsed")
	assert_eq(r["transport_mode"], "stdio", "transport override should be parsed")


func test_parse_no_args():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(PackedStringArray([]))
	assert_eq(r["http_port"], -1, "no args -> no port override")
	assert_eq(r["transport_mode"], "", "no args -> no transport override")


func test_parse_unrelated_args_ignored():
	var r: Dictionary = _plugin_script.parse_mcp_overrides(
		PackedStringArray(["--mcp-server", "--editor", "--some-other-flag=1"])
	)
	assert_eq(r["http_port"], -1, "unrelated args must not set a port")
	assert_eq(r["transport_mode"], "", "unrelated args must not set a transport")
