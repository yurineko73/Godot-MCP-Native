class_name CliResultLimiter
extends RefCounted

const DEFAULT_MAX_BYTES: int = 65536
const MAX_MAX_BYTES: int = 4 * 1024 * 1024

func apply(value: Variant, options: Dictionary = {}) -> Dictionary:
	var fields: PackedStringArray = _parse_fields(options.get("fields", PackedStringArray()))
	var limit: int = maxi(int(options.get("limit", 0)), 0)
	var cursor: int = maxi(int(str(options.get("cursor", "0"))), 0)
	var depth: int = int(options.get("depth", -1))
	var max_bytes: int = clampi(int(options.get("max_bytes", DEFAULT_MAX_BYTES)), 1024, MAX_MAX_BYTES)
	var transformed: Variant = _limit_depth(value, depth) if depth >= 0 else value
	transformed = _project_fields(transformed, fields) if not fields.is_empty() else transformed
	var next_cursor: String = ""
	if transformed is Array and limit > 0:
		var array: Array = transformed
		var end: int = mini(cursor + limit, array.size())
		transformed = array.slice(cursor, end)
		if end < array.size():
			next_cursor = str(end)
	var serialized: String = JSON.stringify(transformed)
	if serialized.to_utf8_buffer().size() <= max_bytes:
		return {
			"data": transformed,
			"truncated": not next_cursor.is_empty(),
			"next_cursor": next_cursor,
		}
	return {
		"data": null,
		"truncated": true,
		"next_cursor": next_cursor,
		"error": {
			"code": "OUTPUT_TOO_LARGE",
			"message": "Output exceeds max_bytes; use fields, limit, depth, or an output file",
			"size_bytes": serialized.to_utf8_buffer().size(),
			"max_bytes": max_bytes,
		},
	}

func _parse_fields(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	if value is Array:
		return PackedStringArray(value)
	if value is String and not value.is_empty():
		return value.split(",", false)
	return PackedStringArray()

func _project_fields(value: Variant, fields: PackedStringArray) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var projected: Dictionary = {}
		for field in fields:
			if source.has(field):
				projected[field] = source[field]
		return projected
	if value is Array:
		var projected_array: Array = []
		for item in value:
			projected_array.append(_project_fields(item, fields))
		return projected_array
	return value

func _limit_depth(value: Variant, remaining_depth: int) -> Variant:
	if remaining_depth < 0:
		return value
	if remaining_depth == 0:
		if value is Dictionary or value is Array:
			return {"truncated": true}
		return value
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = _limit_depth(value[key], remaining_depth - 1)
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_limit_depth(item, remaining_depth - 1))
		return result
	return value
