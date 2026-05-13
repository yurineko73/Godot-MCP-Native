extends "res://addons/gut/test.gd"

func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

func _assert_contains(text: String, expected: String, label: String) -> void:
	assert_true(text.contains(expected), "%s should contain '%s'" % [label, expected])

func _extract_quoted_field(line: String, field_name: String) -> String:
	var prefix := "\"%s\": \"" % field_name
	var start := line.find(prefix)
	if start == -1:
		return ""
	start += prefix.length()
	var line_end := line.find("\"", start)
	if line_end == -1:
		return ""
	return line.substr(start, line_end - start)

func _extract_classifier_entries(text: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for line in text.split("\n"):
		if not line.contains("{\"name\": "):
			continue
		var name := _extract_quoted_field(line, "name")
		var category := _extract_quoted_field(line, "category")
		var group := _extract_quoted_field(line, "group")
		if name.is_empty() or category.is_empty() or group.is_empty():
			continue
		entries.append({
			"name": name,
			"category": category,
			"group": group
		})
	return entries

func _extract_numbered_tool_headings(text: String) -> Array[Dictionary]:
	var headings: Array[Dictionary] = []
	for line in text.split("\n"):
		if not line.begins_with("### "):
			continue
		var rest := line.substr(4).strip_edges()
		var dot_index := rest.find(". ")
		if dot_index == -1:
			continue
		var number_text := rest.substr(0, dot_index)
		if not number_text.is_valid_int():
			continue
		headings.append({
			"number": int(number_text),
			"name": rest.substr(dot_index + 2).strip_edges()
		})
	return headings

func _extract_tools_reference_overview_rows(text: String) -> Dictionary:
	var rows := {}
	for line in text.split("\n"):
		if not line.begins_with("| [") or not line.contains("](#"):
			continue
		var columns := line.split("|")
		if columns.size() < 6:
			continue
		var label := columns[1].strip_edges()
		if not label in [
			"[Node Tools](#node-tools)",
			"[Script Tools](#script-tools)",
			"[Scene Tools](#scene-tools)",
			"[Editor Tools](#editor-tools)",
			"[Debug Tools](#debug-tools)",
			"[Project Tools](#project-tools)"
		]:
			continue
		rows[label] = {
			"core": int(columns[2].strip_edges()),
			"supplementary": int(columns[3].strip_edges()),
			"total": int(columns[4].strip_edges())
		}
	return rows

func _extract_registered_resources(text: String) -> Array[Dictionary]:
	var resources: Array[Dictionary] = []
	var lines := text.split("\n")
	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		if not line.contains("register_resource("):
			i += 1
			continue
		var j := i + 1
		var values: Array[String] = []
		while j < lines.size() and values.size() < 4:
			var stripped := lines[j].strip_edges()
			if stripped.begins_with("\""):
				var quote_end := stripped.find("\"", 1)
				if quote_end > 1:
					values.append(stripped.substr(1, quote_end - 1))
			j += 1
		if values.size() >= 4:
			resources.append({
				"uri": values[0],
				"name": values[1],
				"mime_type": values[2],
				"description": values[3]
			})
		i = j
	return resources

func _extract_documented_resource_rows(text: String) -> Array[Dictionary]:
	var resources: Array[Dictionary] = []
	for line in text.split("\n"):
		if not line.begins_with("| `godot://"):
			continue
		var columns := line.split("|")
		if columns.size() < 5:
			continue
		resources.append({
			"uri": columns[1].strip_edges().trim_prefix("`").trim_suffix("`"),
			"name": columns[2].strip_edges(),
			"mime_type": columns[3].strip_edges().trim_prefix("`").trim_suffix("`"),
			"description": columns[4].strip_edges()
		})
	return resources

func _get_family_label(group: String) -> String:
	if group.begins_with("Node"):
		return "[Node Tools](#node-tools)"
	if group.begins_with("Script"):
		return "[Script Tools](#script-tools)"
	if group.begins_with("Scene"):
		return "[Scene Tools](#scene-tools)"
	if group.begins_with("Editor"):
		return "[Editor Tools](#editor-tools)"
	if group.begins_with("Debug"):
		return "[Debug Tools](#debug-tools)"
	if group.begins_with("Project"):
		return "[Project Tools](#project-tools)"
	return ""

func test_published_tool_counts_match_classifier():
	var classifier: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_tool_classifier.gd").new()
	var total_tools: int = classifier.get_all_tools().size()
	var core_tools: int = classifier.get_core_tools().size()
	var supplementary_tools: int = classifier.get_supplementary_tools().size()

	var readme: String = _read_text("res://README.md")
	var readme_zh: String = _read_text("res://README.zh.md")
	var addon_readme: String = _read_text("res://addons/godot_mcp/README.md")
	var addon_readme_zh: String = _read_text("res://addons/godot_mcp/README.zh.md")
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")
	var architecture: String = _read_text("res://docs/current/architecture.md")

	_assert_contains(readme, "%d tools" % total_tools, "README.md")
	_assert_contains(readme, "%d core + %d supplementary" % [core_tools, supplementary_tools], "README.md")
	_assert_contains(readme_zh, "%d 个工具" % total_tools, "README.zh.md")
	_assert_contains(readme_zh, "%d 核心 + %d 补充" % [core_tools, supplementary_tools], "README.zh.md")
	_assert_contains(addon_readme, "%d tools" % total_tools, "addons/godot_mcp/README.md")
	_assert_contains(addon_readme, "%d core + %d supplementary" % [core_tools, supplementary_tools], "addons/godot_mcp/README.md")
	_assert_contains(addon_readme_zh, "%d 个工具" % total_tools, "addons/godot_mcp/README.zh.md")
	_assert_contains(addon_readme_zh, "%d 核心 + %d 补充" % [core_tools, supplementary_tools], "addons/godot_mcp/README.zh.md")
	_assert_contains(tools_reference, "%d 个工具" % total_tools, "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "%d 核心 + %d 补充" % [core_tools, supplementary_tools], "docs/current/tools-reference.md")
	_assert_contains(architecture, "%d 个工具" % total_tools, "docs/current/architecture.md")

func test_tools_reference_numbered_sections_match_classifier_catalog():
	var classifier_source: String = _read_text("res://addons/godot_mcp/native_mcp/mcp_tool_classifier.gd")
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")
	var expected_entries := _extract_classifier_entries(classifier_source)
	var actual_headings := _extract_numbered_tool_headings(tools_reference)
	var expected_names := {}
	var documented_names := {}
	var classifier_name_counts := {}
	var heading_name_counts := {}

	assert_eq(actual_headings.size(), expected_entries.size(), "tools-reference should have one numbered section per classified tool")
	for entry in expected_entries:
		classifier_name_counts[entry["name"]] = int(classifier_name_counts.get(entry["name"], 0)) + 1
		expected_names[entry["name"]] = true
	for index in range(actual_headings.size()):
		var expected_number := index + 1
		assert_eq(actual_headings[index]["number"], expected_number, "tools-reference heading numbers should stay contiguous")
		heading_name_counts[actual_headings[index]["name"]] = int(heading_name_counts.get(actual_headings[index]["name"], 0)) + 1
		documented_names[actual_headings[index]["name"]] = true

	for tool_name in expected_names.keys():
		assert_true(documented_names.has(tool_name), "tools-reference should include the classified tool %s" % tool_name)
	for tool_name in documented_names.keys():
		assert_true(expected_names.has(tool_name), "tools-reference should not publish unknown tool %s" % tool_name)
	for tool_name in classifier_name_counts.keys():
		assert_eq(classifier_name_counts[tool_name], 1, "classifier should not define duplicate tool %s" % tool_name)
	for tool_name in heading_name_counts.keys():
		assert_eq(heading_name_counts[tool_name], 1, "tools-reference should not document duplicate tool section %s" % tool_name)

func test_tools_reference_overview_rows_match_classifier_family_counts():
	var classifier_source: String = _read_text("res://addons/godot_mcp/native_mcp/mcp_tool_classifier.gd")
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")
	var entries := _extract_classifier_entries(classifier_source)
	var published_rows := _extract_tools_reference_overview_rows(tools_reference)
	var expected_rows := {}

	for label in [
		"[Node Tools](#node-tools)",
		"[Script Tools](#script-tools)",
		"[Scene Tools](#scene-tools)",
		"[Editor Tools](#editor-tools)",
		"[Debug Tools](#debug-tools)",
		"[Project Tools](#project-tools)"
	]:
		expected_rows[label] = {"core": 0, "supplementary": 0, "total": 0}

	for entry in entries:
		var label := _get_family_label(entry["group"])
		assert_false(label.is_empty(), "classifier groups should map to a published tools-reference family row")
		var row: Dictionary = expected_rows[label]
		if entry["category"] == "core":
			row["core"] += 1
		else:
			row["supplementary"] += 1
		row["total"] += 1
		expected_rows[label] = row

	for label in expected_rows.keys():
		assert_true(published_rows.has(label), "tools-reference overview should publish %s" % label)
		assert_eq(published_rows[label], expected_rows[label], "tools-reference overview counts should match classifier for %s" % label)

func test_classifier_groups_map_to_published_tool_families():
	var classifier_source: String = _read_text("res://addons/godot_mcp/native_mcp/mcp_tool_classifier.gd")
	var entries := _extract_classifier_entries(classifier_source)
	var seen_groups := {}

	assert_gt(entries.size(), 0, "classifier should publish at least one tool")
	for entry in entries:
		var label := _get_family_label(entry["group"])
		assert_false(label.is_empty(), "classifier group should map to a published family row: %s" % entry["group"])
		seen_groups[entry["group"]] = true
	assert_gt(seen_groups.size(), 0, "classifier should define at least one tool group")

func test_tools_reference_resource_catalog_matches_registered_resources():
	var server_native_source: String = _read_text("res://addons/godot_mcp/mcp_server_native.gd")
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")
	var expected_resources := _extract_registered_resources(server_native_source)
	var documented_resources := _extract_documented_resource_rows(tools_reference)
	var expected_by_uri := {}
	var documented_by_uri := {}
	var expected_uri_counts := {}
	var documented_uri_counts := {}

	_assert_contains(tools_reference, "%d 个 MCP 资源" % expected_resources.size(), "docs/current/tools-reference.md")
	assert_eq(documented_resources.size(), expected_resources.size(), "tools-reference should have one resource row per registered MCP resource")

	for entry in expected_resources:
		expected_uri_counts[entry["uri"]] = int(expected_uri_counts.get(entry["uri"], 0)) + 1
		expected_by_uri[entry["uri"]] = entry
	for entry in documented_resources:
		documented_uri_counts[entry["uri"]] = int(documented_uri_counts.get(entry["uri"], 0)) + 1
		documented_by_uri[entry["uri"]] = entry

	for uri in expected_by_uri.keys():
		assert_true(documented_by_uri.has(uri), "tools-reference should include the registered resource %s" % uri)
		if documented_by_uri.has(uri):
			assert_eq(documented_by_uri[uri]["name"], expected_by_uri[uri]["name"], "Resource name should match for %s" % uri)
			assert_eq(documented_by_uri[uri]["mime_type"], expected_by_uri[uri]["mime_type"], "Resource MIME type should match for %s" % uri)
			assert_eq(documented_by_uri[uri]["description"], expected_by_uri[uri]["description"], "Resource description should match for %s" % uri)

	for uri in documented_by_uri.keys():
		assert_true(expected_by_uri.has(uri), "tools-reference should not publish unknown resource %s" % uri)
	for uri in expected_uri_counts.keys():
		assert_eq(expected_uri_counts[uri], 1, "server should not register duplicate resource %s" % uri)
	for uri in documented_uri_counts.keys():
		assert_eq(documented_uri_counts[uri], 1, "tools-reference should not document duplicate resource %s" % uri)

func test_get_editor_screenshot_reference_covers_generated_scene_capture():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	_assert_contains(tools_reference, "### 37. get_editor_screenshot", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`scene_path`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`viewport_width`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`viewport_height`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`render_mode`", "docs/current/tools-reference.md")

func test_get_scene_tree_reference_covers_truncation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	_assert_contains(tools_reference, "### 6. get_scene_tree", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`truncated`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`max_depth_applied`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_max_depth`", "docs/current/tools-reference.md")

func test_list_nodes_reference_covers_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	_assert_contains(tools_reference, "### 5. list_nodes", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`max_items`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`cursor`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`total_available`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_cursor`", "docs/current/tools-reference.md")

func test_get_node_properties_reference_covers_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	_assert_contains(tools_reference, "### 4. get_node_properties", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`max_properties`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`cursor`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`total_available`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_cursor`", "docs/current/tools-reference.md")

func test_find_nodes_in_group_reference_covers_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	_assert_contains(tools_reference, "### 16. find_nodes_in_group", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`max_items`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`cursor`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`total_available`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_cursor`", "docs/current/tools-reference.md")

func test_get_node_groups_reference_covers_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	_assert_contains(tools_reference, "### 14. get_node_groups", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`max_items`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`cursor`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`total_available`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_cursor`", "docs/current/tools-reference.md")

func test_get_editor_logs_reference_covers_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	_assert_contains(tools_reference, "### 40. get_editor_logs", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`truncated`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_cursor`", "docs/current/tools-reference.md")

func test_debug_history_references_cover_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	for section in [
		"### 50. get_debugger_messages",
		"### 90. get_debug_state_events",
		"### 91. get_debug_output"
	]:
		_assert_contains(tools_reference, section, "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`truncated`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_cursor`", "docs/current/tools-reference.md")

func test_debug_variable_references_cover_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	for section in [
		"### 93. get_debug_variables",
		"### 94. expand_debug_variable"
	]:
		_assert_contains(tools_reference, section, "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`truncated`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_cursor`", "docs/current/tools-reference.md")

func test_project_diagnostics_references_cover_rerun_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	for section in [
		"### 151. scan_missing_resource_dependencies",
		"### 152. scan_cyclic_resource_dependencies",
		"### 153. detect_broken_scripts",
		"### 154. audit_project_health"
	]:
		_assert_contains(tools_reference, section, "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`max_results_applied`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_max_results`", "docs/current/tools-reference.md")

func test_script_symbol_discovery_references_cover_rerun_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	for section in [
		"### 76. find_script_symbol_definition",
		"### 77. find_script_symbol_references"
	]:
		_assert_contains(tools_reference, section, "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`truncated`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`max_results_applied`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_max_results`", "docs/current/tools-reference.md")

func test_search_in_files_reference_covers_rerun_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	_assert_contains(tools_reference, "### 25. search_in_files", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`truncated`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`max_results_applied`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_max_results`", "docs/current/tools-reference.md")

func test_rename_script_symbol_reference_covers_rerun_continuation_metadata():
	var tools_reference: String = _read_text("res://docs/current/tools-reference.md")

	_assert_contains(tools_reference, "### 78. rename_script_symbol", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`truncated`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`has_more`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`max_results_applied`", "docs/current/tools-reference.md")
	_assert_contains(tools_reference, "`next_max_results`", "docs/current/tools-reference.md")
