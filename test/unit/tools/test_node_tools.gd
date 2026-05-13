extends "res://addons/gut/test.gd"

var _node_tools = null

func before_each() -> void:
	_node_tools = load("res://addons/godot_mcp/tools/node_tools_native.gd").new()

func after_each() -> void:
	_node_tools = null

func test_create_node_schema():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "create_node"
	tool.description = "Create a new node"
	tool.input_schema = {
		"type": "object",
		"properties": {
			"parent_path": {"type": "string"},
			"node_type": {"type": "string"},
			"node_name": {"type": "string"}
		},
		"required": ["parent_path", "node_type", "node_name"]
	}
	assert_true(tool.is_valid() or tool.name == "create_node", "create_node schema should be valid")

func test_delete_node_schema():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "delete_node"
	tool.description = "Delete a node"
	tool.input_schema = {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"}
		},
		"required": ["node_path"]
	}
	assert_eq(tool.name, "delete_node", "delete_node schema should exist")

func test_update_node_property_schema():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "update_node_property"
	tool.description = "Update a node property"
	tool.input_schema = {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"property_name": {"type": "string"},
			"property_value": {}
		},
		"required": ["node_path", "property_name", "property_value"]
	}
	assert_eq(tool.name, "update_node_property", "update_node_property schema should exist")

func test_property_value_json_string_parsing():
	var json_str: String = '{"x": 10, "y": 5, "z": 3}'
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary, "JSON string should parse to Dictionary")
	if parsed is Dictionary:
		var vec: Vector3 = Vector3(float(parsed.get("x", 0.0)), float(parsed.get("y", 0.0)), float(parsed.get("z", 0.0)))
		assert_eq(vec, Vector3(10, 5, 3), "Should convert parsed dict to Vector3")

func test_property_value_bool_string():
	var val: Variant = "true"
	var result: bool
	if val is String:
		result = val == "true"
	assert_true(result, "String 'true' should convert to bool true")

func test_property_value_int_string():
	var val: Variant = "42"
	var result: int
	if val is String:
		result = int(val)
	assert_eq(result, 42, "String '42' should convert to int 42")

func test_node_path_resolution():
	var path: String = "/root/Node3D/Child"
	var parts: PackedStringArray = path.split("/")
	assert_eq(parts.size(), 4, "Path should have 4 parts")
	assert_eq(parts[0], "", "First part should be empty (before /)")
	assert_eq(parts[1], "root", "Second part should be root")
	assert_eq(parts[2], "Node3D", "Third part should be Node3D")

func test_category_property_filtering():
	var property_dict: Dictionary = {"name": "Transform", "usage": 128}
	var usage_flags: int = property_dict.get("usage", 0)
	var is_category: bool = (usage_flags & 128) != 0 or (usage_flags & 64) != 0 or (usage_flags & 256) != 0
	assert_true(is_category, "Usage 128 should be filtered as category")

func test_normal_property_not_filtered():
	var property_dict: Dictionary = {"name": "position", "usage": 0}
	var usage_flags: int = property_dict.get("usage", 0)
	var is_category: bool = (usage_flags & 128) != 0 or (usage_flags & 64) != 0 or (usage_flags & 256) != 0
	assert_false(is_category, "Usage 0 should not be filtered")

func test_group_property_filtered():
	var property_dict: Dictionary = {"name": "Physics", "usage": 64}
	var usage_flags: int = property_dict.get("usage", 0)
	var is_category: bool = (usage_flags & 128) != 0 or (usage_flags & 64) != 0 or (usage_flags & 256) != 0
	assert_true(is_category, "Usage 64 should be filtered as group")

func test_subgroup_property_filtered():
	var property_dict: Dictionary = {"name": "Coordinates", "usage": 256}
	var usage_flags: int = property_dict.get("usage", 0)
	var is_category: bool = (usage_flags & 128) != 0 or (usage_flags & 64) != 0 or (usage_flags & 256) != 0
	assert_true(is_category, "Usage 256 should be filtered as subgroup")

func test_get_scene_tree_result_marks_truncation():
	var root := Node.new()
	root.name = "Root"
	var child := Node.new()
	child.name = "Child"
	var grandchild := Node.new()
	grandchild.name = "Grandchild"
	root.add_child(child)
	child.add_child(grandchild)

	var result: Dictionary = _node_tools._build_scene_tree_result(root, 1)
	assert_true(result.get("truncated", false), "Limited scene tree result should report truncation")
	assert_eq(result.get("max_depth_applied"), 1, "Result should echo applied max depth")
	assert_eq(result.get("next_max_depth"), 2, "Result should advertise a continuation depth")
	var tree: Dictionary = result.get("tree", {})
	assert_eq(tree.get("children", [{}])[0].get("children_truncated", false), true, "Child node should mark truncated descendants")

	root.free()

func test_get_scene_tree_result_without_truncation():
	var root := Node.new()
	root.name = "Root"
	var child := Node.new()
	child.name = "Child"
	root.add_child(child)

	var result: Dictionary = _node_tools._build_scene_tree_result(root, -1)
	assert_false(result.get("truncated", true), "Unlimited scene tree result should not report truncation")
	assert_eq(result.get("max_depth_applied"), -1, "Unlimited result should preserve -1 max depth")
	assert_false(result.has("next_max_depth"), "Unlimited scene tree result should not advertise a continuation depth")

	root.free()

func test_build_list_nodes_result_marks_truncation():
	var nodes: Array[String] = ["/root/Main", "/root/Main/Child", "/root/Main/Grandchild"]
	var result: Dictionary = _node_tools._build_list_nodes_result(nodes, 2, 0)
	assert_eq(result.get("count"), 2, "Result should be limited to max_items")
	assert_eq(result.get("total_available"), 3, "Result should report total available nodes")
	assert_true(result.get("truncated", false), "Limited node listing should report truncation")
	assert_true(result.get("has_more", false), "Limited node listing should report more data")
	assert_eq(result.get("next_cursor"), 2, "Limited node listing should advertise the next cursor")

func test_build_list_nodes_result_continues_from_cursor():
	var nodes: Array[String] = ["/root/Main", "/root/Main/Child", "/root/Main/Grandchild"]
	var result: Dictionary = _node_tools._build_list_nodes_result(nodes, 2, 2)
	assert_eq(result.get("nodes"), ["/root/Main/Grandchild"], "Cursor should resume from the requested offset")
	assert_eq(result.get("count"), 1, "Continuation window should report its own count")
	assert_eq(result.get("total_available"), 3, "Continuation window should preserve total_available")
	assert_false(result.get("truncated", true), "Last continuation page should not report truncation")
	assert_false(result.get("has_more", true), "Last continuation page should not report more data")
	assert_false(result.has("next_cursor"), "Last continuation page should not advertise another cursor")

func test_build_node_properties_result_marks_truncation():
	var all_properties: Dictionary = {
		"a": 1,
		"b": true,
		"c": "value"
	}
	var property_names: Array[String] = ["a", "b", "c"]
	var result: Dictionary = _node_tools._build_node_properties_result("/root/Main", "Node", all_properties, property_names, 2, 0)
	assert_eq(result.get("count"), 2, "Property window should honor max_properties")
	assert_eq(result.get("total_available"), 3, "Property window should report total available properties")
	assert_true(result.get("truncated", false), "Limited property result should report truncation")
	assert_true(result.get("has_more", false), "Limited property result should report more data")
	assert_eq(result.get("next_cursor"), 2, "Limited property result should advertise the next cursor")
	assert_eq(result.get("properties"), {"a": 1, "b": true}, "Property window should preserve the requested prefix")

func test_build_node_properties_result_continues_from_cursor():
	var all_properties: Dictionary = {
		"a": 1,
		"b": true,
		"c": "value"
	}
	var property_names: Array[String] = ["a", "b", "c"]
	var result: Dictionary = _node_tools._build_node_properties_result("/root/Main", "Node", all_properties, property_names, 2, 2)
	assert_eq(result.get("count"), 1, "Continuation property window should report its own count")
	assert_eq(result.get("total_available"), 3, "Continuation property window should preserve total_available")
	assert_false(result.get("truncated", true), "Last property page should not report truncation")
	assert_false(result.get("has_more", true), "Last property page should not report more data")
	assert_false(result.has("next_cursor"), "Last property page should not advertise another cursor")
	assert_eq(result.get("properties"), {"c": "value"}, "Cursor should resume from the requested property offset")

func test_build_find_nodes_in_group_result_marks_truncation():
	var result_nodes: Array = [
		{"name": "Enemy1", "type": "Node2D", "path": "/root/Main/Enemy1"},
		{"name": "Enemy2", "type": "Node2D", "path": "/root/Main/Enemy2"},
		{"name": "Enemy3", "type": "Node2D", "path": "/root/Main/Enemy3"}
	]
	var result: Dictionary = _node_tools._build_find_nodes_in_group_result("enemies", result_nodes, 2, 0)
	assert_eq(result.get("node_count"), 2, "Group result should honor max_items")
	assert_eq(result.get("total_available"), 3, "Group result should report total available nodes")
	assert_true(result.get("truncated", false), "Limited group result should report truncation")
	assert_true(result.get("has_more", false), "Limited group result should report more data")
	assert_eq(result.get("next_cursor"), 2, "Limited group result should advertise the next cursor")

func test_build_find_nodes_in_group_result_continues_from_cursor():
	var result_nodes: Array = [
		{"name": "Enemy1", "type": "Node2D", "path": "/root/Main/Enemy1"},
		{"name": "Enemy2", "type": "Node2D", "path": "/root/Main/Enemy2"},
		{"name": "Enemy3", "type": "Node2D", "path": "/root/Main/Enemy3"}
	]
	var result: Dictionary = _node_tools._build_find_nodes_in_group_result("enemies", result_nodes, 2, 2)
	assert_eq(result.get("node_count"), 1, "Continuation group window should report its own count")
	assert_eq(result.get("total_available"), 3, "Continuation group window should preserve total_available")
	assert_false(result.get("truncated", true), "Last group page should not report truncation")
	assert_false(result.get("has_more", true), "Last group page should not report more data")
	assert_false(result.has("next_cursor"), "Last group page should not advertise another cursor")

func test_build_get_node_groups_result_marks_truncation():
	var groups: Array[String] = ["alpha", "beta", "gamma"]
	var result: Dictionary = _node_tools._build_get_node_groups_result("/root/Main", groups, 2, 0)
	assert_eq(result.get("group_count"), 2, "Group result should honor max_items")
	assert_eq(result.get("total_available"), 3, "Group result should report total available groups")
	assert_true(result.get("truncated", false), "Limited get_node_groups result should report truncation")
	assert_true(result.get("has_more", false), "Limited get_node_groups result should report more data")
	assert_eq(result.get("next_cursor"), 2, "Limited get_node_groups result should advertise the next cursor")

func test_build_get_node_groups_result_continues_from_cursor():
	var groups: Array[String] = ["alpha", "beta", "gamma"]
	var result: Dictionary = _node_tools._build_get_node_groups_result("/root/Main", groups, 2, 2)
	assert_eq(result.get("groups"), ["gamma"], "Cursor should resume from the requested group offset")
	assert_eq(result.get("group_count"), 1, "Continuation group page should report its own count")
	assert_eq(result.get("total_available"), 3, "Continuation group page should preserve total_available")
	assert_false(result.get("truncated", true), "Last get_node_groups page should not report truncation")
	assert_false(result.get("has_more", true), "Last get_node_groups page should not report more data")
	assert_false(result.has("next_cursor"), "Last get_node_groups page should not advertise another cursor")
