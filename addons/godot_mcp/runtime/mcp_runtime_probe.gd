class_name MCPRuntimeProbe
extends Node

const CAPTURE_PREFIX: StringName = &"mcp"

func _ready() -> void:
	if EngineDebugger.is_active():
		if EngineDebugger.has_capture(CAPTURE_PREFIX):
			EngineDebugger.unregister_message_capture(CAPTURE_PREFIX)
		EngineDebugger.register_message_capture(CAPTURE_PREFIX, Callable(self, "_capture_mcp_message"))
		EngineDebugger.send_message("mcp:probe_ready", [_get_runtime_info()])

func _exit_tree() -> void:
	if EngineDebugger.is_active() and EngineDebugger.has_capture(CAPTURE_PREFIX):
		EngineDebugger.unregister_message_capture(CAPTURE_PREFIX)

func _capture_mcp_message(message: String, data: Array) -> bool:
	match message:
		"ping":
			EngineDebugger.send_message("mcp:pong", [_get_runtime_info()])
			return true
		"get_runtime_info":
			EngineDebugger.send_message("mcp:runtime_info", [_get_runtime_info()])
			return true
		"get_scene_tree":
			var max_depth: int = 6
			if not data.is_empty() and data[0] is int:
				max_depth = data[0]
			var root: Node = get_tree().current_scene
			if not root:
				root = get_tree().root
			EngineDebugger.send_message("mcp:scene_tree", [_serialize_node(root, 0, max_depth)])
			return true
		"inspect_node":
			if data.is_empty():
				EngineDebugger.send_message("mcp:error", [{"message": "inspect_node requires a NodePath string"}])
				return true
			var node: Node = _resolve_target_node(str(data[0]))
			if not node:
				EngineDebugger.send_message("mcp:error", [{"message": "Node not found: " + str(data[0])}])
				return true
			EngineDebugger.send_message("mcp:node", [_serialize_node(node, 0, 1, true)])
			return true
		"set_node_property":
			return _handle_set_node_property(data)
		"call_node_method":
			return _handle_call_node_method(data)
		"evaluate_expression":
			return _handle_evaluate_expression(data)
		"get_runtime_screenshot":
			return _handle_get_runtime_screenshot(data)
		"debug_break":
			EngineDebugger.debug(true, false)
			return true
		_:
			return false

func _get_runtime_info() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"physics_frames": Engine.get_physics_frames(),
		"process_frames": Engine.get_process_frames(),
		"debugger_active": EngineDebugger.is_active(),
		"current_scene": str(get_tree().current_scene.get_path()) if get_tree().current_scene else "",
		"node_count": _count_nodes(get_tree().root)
	}

func _serialize_node(node: Node, depth: int, max_depth: int, include_properties: bool = false) -> Dictionary:
	var result: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"child_count": node.get_child_count()
	}
	if include_properties:
		result["properties"] = _serialize_properties(node)
	if max_depth >= 0 and depth >= max_depth:
		return result
	var children: Array[Dictionary] = []
	for child in node.get_children():
		children.append(_serialize_node(child, depth + 1, max_depth))
	result["children"] = children
	return result

func _serialize_properties(node: Node) -> Dictionary:
	var properties: Dictionary = {}
	for property in node.get_property_list():
		var name: String = property.get("name", "")
		var usage: int = property.get("usage", 0)
		if name.begins_with("_") \
				or (usage & PROPERTY_USAGE_CATEGORY) != 0 \
				or (usage & PROPERTY_USAGE_GROUP) != 0 \
				or (usage & PROPERTY_USAGE_SUBGROUP) != 0:
			continue
		var value: Variant = node.get(name)
		match typeof(value):
			TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
				properties[name] = value
			TYPE_VECTOR2:
				properties[name] = {"x": value.x, "y": value.y}
			TYPE_VECTOR3:
				properties[name] = {"x": value.x, "y": value.y, "z": value.z}
			TYPE_COLOR:
				properties[name] = {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
			_:
				properties[name] = _serialize_value(value)
	return properties

func _handle_set_node_property(data: Array) -> bool:
	if data.size() < 3:
		EngineDebugger.send_message("mcp:error", [{"message": "set_node_property requires node_path, property_name, property_value"}])
		return true
	var node: Node = _resolve_target_node(str(data[0]))
	if not node:
		EngineDebugger.send_message("mcp:error", [{"message": "Node not found: " + str(data[0])}])
		return true
	var property_name: String = str(data[1])
	if not property_name in node:
		EngineDebugger.send_message("mcp:error", [{"message": "Property not found on node: " + property_name}])
		return true
	var old_value: Variant = node.get(property_name)
	var converted_value: Variant = _convert_value_for_property(node, property_name, data[2])
	node.set(property_name, converted_value)
	EngineDebugger.send_message("mcp:node_property_updated", [{
		"node_path": str(node.get_path()),
		"property_name": property_name,
		"old_value": _serialize_value(old_value),
		"new_value": _serialize_value(node.get(property_name))
	}])
	return true

func _handle_call_node_method(data: Array) -> bool:
	if data.size() < 2:
		EngineDebugger.send_message("mcp:error", [{"message": "call_node_method requires node_path and method_name"}])
		return true
	var node: Node = _resolve_target_node(str(data[0]))
	if not node:
		EngineDebugger.send_message("mcp:error", [{"message": "Node not found: " + str(data[0])}])
		return true
	var method_name: String = str(data[1])
	if not node.has_method(method_name):
		EngineDebugger.send_message("mcp:error", [{"message": "Method not found on node: " + method_name}])
		return true
	var arguments: Array = []
	if data.size() >= 3 and data[2] is Array:
		arguments = data[2]
	var result: Variant = node.callv(method_name, arguments)
	EngineDebugger.send_message("mcp:node_method_result", [{
		"node_path": str(node.get_path()),
		"method_name": method_name,
		"arguments": _serialize_value(arguments),
		"result": _serialize_value(result)
	}])
	return true

func _handle_evaluate_expression(data: Array) -> bool:
	if data.is_empty():
		EngineDebugger.send_message("mcp:error", [{"message": "evaluate_expression requires an expression string"}])
		return true
	var expression_text: String = str(data[0])
	var node_path: String = ""
	if data.size() >= 2:
		node_path = str(data[1])
	var base_instance: Object = _resolve_target_node(node_path)
	if not base_instance:
		base_instance = get_tree().current_scene if get_tree().current_scene else self
	var expression: Expression = Expression.new()
	var parse_error: int = expression.parse(expression_text, [])
	if parse_error != OK:
		EngineDebugger.send_message("mcp:error", [{
			"message": "Expression parse failed",
			"code": parse_error,
			"expression": expression_text
		}])
		return true
	var result: Variant = expression.execute([], base_instance, false)
	if expression.has_execute_failed():
		EngineDebugger.send_message("mcp:error", [{
			"message": "Expression execution failed",
			"expression": expression_text
		}])
		return true
	EngineDebugger.send_message("mcp:expression_result", [{
		"expression": expression_text,
		"node_path": str(base_instance.get_path()) if base_instance is Node else "",
		"value": _serialize_value(result)
	}])
	return true

func _handle_get_runtime_screenshot(data: Array) -> bool:
	var save_path: String = "user://mcp_runtime_capture.png"
	if not data.is_empty() and data[0] is String and not String(data[0]).is_empty():
		save_path = String(data[0])
	var format: String = "png"
	if data.size() >= 2 and data[1] is String and not String(data[1]).is_empty():
		format = String(data[1]).to_lower()
	var result: Dictionary = capture_runtime_screenshot(save_path, format)
	if result.has("error"):
		EngineDebugger.send_message("mcp:error", [result])
		return true
	EngineDebugger.send_message("mcp:runtime_screenshot", [result])
	return true

func capture_runtime_screenshot(save_path: String = "user://mcp_runtime_capture.png", format: String = "png") -> Dictionary:
	if not ["png", "jpg"].has(format):
		return {"error": "Unsupported screenshot format: " + format}

	var viewport: Viewport = get_viewport()
	if not viewport:
		return {"error": "Runtime viewport is not available"}
	var texture: Texture2D = viewport.get_texture()
	if not texture:
		return {"error": "Failed to get runtime viewport texture"}
	var image: Image = texture.get_image()
	if not image or image.is_empty():
		return {"error": "Failed to capture runtime viewport image"}

	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	var save_dir: String = absolute_path.get_base_dir()
	if not save_dir.is_empty() and not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	var err: Error = OK
	if format == "jpg":
		err = image.save_jpg(absolute_path, 0.9)
	else:
		err = image.save_png(absolute_path)
	if err != OK:
		return {"error": "Failed to save runtime screenshot: error " + str(err)}

	return {
		"save_path": save_path,
		"format": format,
		"width": image.get_width(),
		"height": image.get_height(),
		"size": str(image.get_width()) + "x" + str(image.get_height()),
		"current_scene": str(get_tree().current_scene.get_path()) if get_tree().current_scene else ""
	}

func _resolve_target_node(node_path: String) -> Node:
	if node_path.is_empty() or node_path == ".":
		return get_tree().current_scene if get_tree().current_scene else get_tree().root
	if node_path == "/root":
		return get_tree().root
	return get_node_or_null(NodePath(node_path))

func _convert_value_for_property(node: Node, property_name: String, value: Variant) -> Variant:
	if value is String:
		var parsed: Variant = JSON.parse_string(value)
		if parsed != null:
			value = parsed

	var property_type: int = TYPE_NIL
	for property_info in node.get_property_list():
		if property_info.get("name", "") == property_name:
			property_type = int(property_info.get("type", TYPE_NIL))
			break

	match property_type:
		TYPE_VECTOR2:
			if value is Dictionary:
				return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
		TYPE_VECTOR3:
			if value is Dictionary:
				return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
		TYPE_COLOR:
			if value is Dictionary:
				return Color(float(value.get("r", 0.0)), float(value.get("g", 0.0)), float(value.get("b", 0.0)), float(value.get("a", 1.0)))
		TYPE_BOOL:
			if value is String:
				return value.to_lower() == "true"
		TYPE_INT:
			if value is String:
				return int(value)
		TYPE_FLOAT:
			if value is String:
				return float(value)

	return value

func _serialize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_serialize_value(item))
			return result
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key in value:
				result[str(key)] = _serialize_value(value[key])
			return result
		_:
			return str(value)

func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
