extends "res://addons/gut/test.gd"

var _limiter := CliResultLimiter.new()

func test_list_limit_returns_cursor() -> void:
	var result: Dictionary = _limiter.apply([1, 2, 3], {"limit": 2})
	assert_eq(result["data"], [1, 2])
	assert_true(result["truncated"])
	assert_eq(result["next_cursor"], "2")

func test_nested_resource_limit_returns_cursor() -> void:
	var result: Dictionary = _limiter.apply({"resources": ["a", "b", "c"], "count": 3}, {"limit": 2})
	assert_eq(result["data"]["resources"], ["a", "b"])
	assert_eq(result["data"]["count"], 2)
	assert_eq(result["next_cursor"], "2")

func test_field_projection_keeps_requested_tree_fields_recursively() -> void:
	var value: Dictionary = {
		"scene_path": "res://main.tscn",
		"root": {
			"name": "Main",
			"type": "Node2D",
			"path": "/root/Main",
			"children": [{"name": "Player", "type": "CharacterBody2D", "path": "/root/Main/Player"}],
		},
	}
	var result: Dictionary = _limiter.apply(value, {"fields": "path,type"})
	assert_eq(result["data"]["root"]["path"], "/root/Main")
	assert_eq(result["data"]["root"]["type"], "Node2D")
	assert_eq(result["data"]["root"]["children"][0]["path"], "/root/Main/Player")
	assert_false(result["data"]["root"].has("name"))

func test_oversized_output_returns_structured_error() -> void:
	var result: Dictionary = _limiter.apply({"text": "x".repeat(4096)}, {"max_bytes": 1024})
	assert_true(result.has("error"))
	assert_eq(result["error"]["code"], "OUTPUT_TOO_LARGE")
