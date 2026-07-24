extends "res://addons/gut/test.gd"

var _limiter := CliResultLimiter.new()

func test_list_limit_returns_cursor() -> void:
	var result: Dictionary = _limiter.apply([1, 2, 3], {"limit": 2})
	assert_eq(result["data"], [1, 2])
	assert_true(result["truncated"])
	assert_eq(result["next_cursor"], "2")

func test_field_projection_keeps_requested_fields() -> void:
	var result: Dictionary = _limiter.apply([{"name": "A", "type": "Node", "extra": 1}], {"fields": "name,type"})
	assert_eq(result["data"], [{"name": "A", "type": "Node"}])

func test_oversized_output_returns_structured_error() -> void:
	var result: Dictionary = _limiter.apply({"text": "x".repeat(4096)}, {"max_bytes": 1024})
	assert_true(result.has("error"))
	assert_eq(result["error"]["code"], "OUTPUT_TOO_LARGE")
